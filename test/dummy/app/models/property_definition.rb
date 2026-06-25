# A user-defined column. The app turns each definition into a
# CrudComponents::DynamicColumn (see #to_crud_column) and hands the set to
# `crud_collection` via `extra_columns:` — the model (Book) stays untouched.
#
# This is the *adapter* the gem expects you to write: it knows where your custom
# data lives (here: property_values rows) and how to read/filter/sort it. Swap
# the three lambdas for JSONB lookups or API calls and nothing else changes.
class PropertyDefinition < ApplicationRecord
  has_many :property_values, dependent: :destroy

  FLAVORS = %w[string number boolean date].freeze

  # The renderer the value's type wants — drives currency/✓✗/date formatting.
  def renderer
    { 'number' => :number, 'boolean' => :boolean, 'date' => :date }.fetch(flavor, :string)
  end

  # Text → typed value, so the renderer formats it like a real column.
  def cast(raw)
    return nil if raw.nil?

    case flavor
    when 'number'  then BigDecimal(raw)
    when 'boolean' then raw == 'true'
    when 'date'    then Date.parse(raw)
    else raw
    end
  rescue ArgumentError
    raw
  end

  # Build the gem-facing column. `subject_model` is the AR class whose rows the
  # column decorates (Book here).
  def to_crud_column(subject_model)
    definition = self
    CrudComponents::DynamicColumn.new(
      key.to_sym,
      label: label.presence || key.humanize,
      as: renderer,
      unit: unit.presence,
      # One query per page for this column's values, keyed by subject id.
      preload: ->(records) { definition.values_by_subject(subject_model, records) },
      # Reachable in SQL, so the column filters and sorts like any other.
      filter: ->(scope, value) { definition.filter_scope(scope, subject_model, value) },
      sort:   ->(scope, dir)   { definition.sort_scope(scope, subject_model, dir) }
    ) { |record, loaded| definition.cast(loaded[record.id]&.value) }
  end

  # Batch-load: { subject_id => PropertyValue }.
  def values_by_subject(subject_model, records)
    property_values
      .where(subject_type: subject_model.name, subject_id: records.map(&:id))
      .index_by(&:subject_id)
  end

  # Filter: subjects whose value contains the term (case-insensitive enough for
  # the demo; safely escaped).
  def filter_scope(scope, subject_model, value)
    ids = property_values
          .where(subject_type: subject_model.name)
          .where('value LIKE ?', "%#{PropertyValue.sanitize_sql_like(value)}%")
          .select(:subject_id)
    scope.where(id: ids)
  end

  # Sort: order by the value via a correlated subquery (`dir` is the gem's
  # validated :asc/:desc, never raw input). Relation#to_sql inlines the literal
  # definition_id/subject_type binds; the correlation to the outer row is raw SQL.
  def sort_scope(scope, subject_model, dir)
    correlation = "#{PropertyValue.table_name}.subject_id = " \
                  "#{subject_model.quoted_table_name}.#{subject_model.primary_key}"
    sub = property_values.where(subject_type: subject_model.name).where(correlation).select(:value)
    scope.order(Arel.sql("(#{sub.to_sql}) #{dir == :desc ? 'DESC' : 'ASC'}"))
  end
end

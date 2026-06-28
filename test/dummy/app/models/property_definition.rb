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
      # Reachable in SQL, so the column filters and sorts like any other — with a
      # control matching the property's flavor (see #filter_for).
      filter: definition.filter_for(subject_model),
      sort:   ->(scope, dir)   { definition.sort_scope(scope, subject_model, dir) }
    ) { |record, loaded| definition.cast(loaded[record.id]&.value) }
  end

  # Batch-load: { subject_id => PropertyValue }.
  def values_by_subject(subject_model, records)
    property_values
      .where(subject_type: subject_model.name, subject_id: records.map(&:id))
      .index_by(&:subject_id)
  end

  # The filter block — its control follows the column's `as:` flavor (date → date
  # range, number → number range, boolean → yes/no, string → text). Each block
  # declares the keywords its type supplies (geq:/leq: for a range, eq: for a
  # boolean, contains: for text) and is handed values already cast to the type — a
  # Date, a BigDecimal, true/false — or nil when blank/unparseable.
  def filter_for(subject_model)
    case flavor
    when 'date'
      lambda do |scope, geq:, leq:|
        rows = values_for(subject_model)
        rows = rows.where('value >= ?', geq.iso8601) if geq   # ISO dates sort lexically
        rows = rows.where('value <= ?', leq.iso8601) if leq
        scope.where(id: rows.select(:subject_id))
      end
    when 'number'
      lambda do |scope, geq:, leq:|
        rows = values_for(subject_model)
        rows = rows.where('CAST(value AS REAL) >= ?', geq) if geq
        rows = rows.where('CAST(value AS REAL) <= ?', leq) if leq
        scope.where(id: rows.select(:subject_id))
      end
    when 'boolean'
      lambda do |scope, eq:|
        next scope if eq.nil?   # "any"

        scope.where(id: values_for(subject_model).where(value: eq.to_s).select(:subject_id))
      end
    else
      lambda do |scope, contains:|
        next scope if contains.blank?

        rows = values_for(subject_model).where('value LIKE ?', "%#{PropertyValue.sanitize_sql_like(contains)}%")
        scope.where(id: rows.select(:subject_id))
      end
    end
  end

  # This definition's values, scoped to the subject model — a relation to refine
  # into a subject-id subquery.
  def values_for(subject_model)
    property_values.where(subject_type: subject_model.name)
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

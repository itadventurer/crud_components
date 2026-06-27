module CrudComponents
  module Presenters
    # The single `record_presenter` local of the record partial.
    class Record < Base
      include ColumnSelection

      attr_reader :record, :model, :structure, :fieldset, :param_prefix

      def initialize(view:, record:, fieldset: nil, actions: true, picked_columns: :auto,
                     param_prefix: nil, extra_columns: nil)
        super(view: view)
        @record = record
        @model = record.class
        @structure = Structure.for(@model)
        @fieldset = @structure.fieldset(fieldset || :show)
        @actions_enabled = actions
        @param_prefix = param_prefix
        # Dynamic columns work on a detail view too — user-defined properties
        # whose data lives outside the model's table, shown as extra rows.
        @dynamic_fields = Array(extra_columns).map { |c| c.to_field(@model).preload!([record]) }
        # A column picker can narrow/order this dl too, but a detail view has no
        # inline gear of its own (no `picker:` knob) — the gear is a standalone
        # `crud_column_picker` on the page. So pass `picked_columns:` an Array you
        # resolved (e.g. via `CrudComponents.selected_columns(params)`); `:auto`
        # here means "don't narrow" (no gear → a stray `?cols=` is ignored).
        # (`fields`, `column_visible?` and the picker logic come from ColumnSelection.)
        @picker = false
        @picked_columns = normalize_picked_columns(picked_columns)
      end

      def title
        structure.label_for(record, view)
      end

      # Every field this user may see on this record — declared fields plus the
      # dynamic columns; the picker's universe.
      def available_fields
        @available_fields ||= (structure.fieldset_fields(fieldset) + @dynamic_fields)
                              .select { |f| f.permitted?(permission_context, record) }
      end

      def value_html(field)
        render_cell(field, record, surface: :record)
      end

      # Row actions for this record; a derived :show button to the page we
      # are already on would be noise.
      def actions
        return nil unless @actions_enabled

        @actions ||= Actions.new(view: view, subject: record, structure: structure,
                                 actions: structure.fieldset_actions(fieldset, on: :row),
                                 suppress_show: true)
      end
    end
  end
end

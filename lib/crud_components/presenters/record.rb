module CrudComponents
  module Presenters
    # The single `record_presenter` local of the record partial.
    class Record < Base
      include ColumnSelection

      attr_reader :record, :model, :structure, :fieldset, :param_prefix

      def initialize(view:, record:, fieldset: nil, actions: true, visible_columns: nil, param_prefix: nil,
                     extra_columns: nil)
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
        # A column picker can drive a detail view too: ?cols= (or a `visible_columns:`
        # Array default) narrows/orders the dl just like a table. A detail view has
        # no inline gear, so an Array is the only meaningful value here. `fields`,
        # `column_visible?` and `visible_columns` come from ColumnSelection.
        @visible_override = visible_columns.is_a?(Array) ? visible_columns.map(&:to_sym) : nil
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

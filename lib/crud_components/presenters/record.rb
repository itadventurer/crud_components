module CrudComponents
  module Presenters
    # The single `record_presenter` local of the record partial.
    class Record < Base
      attr_reader :record, :model, :structure, :fieldset

      def initialize(view:, record:, fieldset: nil, actions: true)
        super(view: view)
        @record = record
        @model = record.class
        @structure = Structure.for(@model)
        @fieldset = @structure.fieldset(fieldset || :show)
        @actions_enabled = actions
      end

      def title
        structure.label_for(record, view)
      end

      def fields
        @fields ||= structure.fieldset_fields(fieldset)
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

module CrudComponents
  module Presenters
    # The single `form` local of the form partial. Derives a form from the
    # same field metadata everything else uses; the host app's controller
    # owns saving (with the matching CrudComponents.permitted_attributes list).
    #
    # Field selection falls back: the action's fieldset → :form → :default.
    # A visible field that isn't editable (by type or permission) renders
    # read-only rather than vanishing.
    class Form < Base
      attr_reader :record, :model, :structure, :action

      def initialize(view:, record:, fieldset: nil, action: nil, url: nil, method: nil)
        super(view: view)
        @record = record
        @model = record.class
        @structure = Structure.for(@model)
        @action = (action || (record.persisted? ? :edit : :new)).to_sym
        @fieldset = fieldset ? @structure.fieldset(fieldset) : @structure.form_fieldset(@action)
        @url = url
        @method = method
      end

      # Visible fields that have a form representation (computed/json skipped).
      def fields
        structure.fieldset_fields(@fieldset)
                 .select { |f| f.form_control && f.permitted?(permission_context, record) }
      end

      def editable?(field)
        field.editable? && field.editable_permitted?(permission_context, record)
      end

      def control(field)
        editable?(field) ? field.form_control : :readonly
      end

      def errors_for(field)
        record.errors[field.name]
      end

      def any_errors?
        record.errors.any?
      end

      # form_with options; nil url/method let Rails infer from the record.
      def form_options
        { url: @url, method: @method }.compact
      end

      # Read-only display reuses the value renderer (record surface).
      def display(field)
        render_cell(field, record, surface: :record)
      end
    end
  end
end

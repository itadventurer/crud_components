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

      # Renders one editable field through the simple_form builder `f`, mapping
      # the field flavor to the right simple_form input. simple_form supplies
      # the label, wrapper, per-field error and your design-system styling.
      def simple_input(f, field)
        case field.form_control
        when :text       then f.input field.name, as: :text
        when :boolean    then f.input field.name, as: :boolean
        when :enum       then f.input field.name, collection: field.form_choices
        when :belongs_to then f.association field.reflection.name, collection: field.form_choices
        when :habtm      then f.association field.reflection.name, as: :check_boxes, collection: field.form_choices
        when :file       then f.input field.name, as: :file
        else                  f.input field.name
        end
      end

      def any_errors?
        record.errors.any?
      end

      # Errors not attached to a visible field — base errors, or errors on a
      # column the form doesn't show. Rendered in the summary so "fix N errors"
      # is never a dead end with nothing to fix.
      def summary_errors
        shown = fields.map(&:name)
        record.errors.reject { |error| shown.include?(error.attribute) }.map(&:full_message)
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

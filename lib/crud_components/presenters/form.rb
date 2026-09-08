# frozen_string_literal: true

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

      # ── nested rows ────────────────────────────────────────────────────────
      # A crafted `?crud_add[x]=100000` must not render a hundred thousand rows.
      MAX_ADDED_ROWS = 25

      # How many blank rows the (+) has asked for, capped by what the field can
      # still hold.
      def added_rows(field, existing_count)
        asked = view.params.dig(:crud_add, field.name.to_s).to_i.clamp(0, MAX_ADDED_ROWS)
        room = field.max_rows - existing_count
        room.infinite? ? asked : asked.clamp(0, room.to_i)
      end

      def room_for_another?(field, rendered_count)
        rendered_count < field.max_rows
      end

      # The same page with one more row asked for. Turbo replaces only the frame
      # this link sits in, so what is already typed above stays where it is.
      def add_url(field, count)
        query = view.request.query_parameters.deep_merge('crud_add' => { field.name.to_s => count.to_s })
        "#{view.request.path}?#{query.to_query}"
      end

      # Stable across renders: the frame holding the nth added row is the one the
      # response is cut out of.
      def nested_frame_id(field, ordinal)
        "crud_add_#{model.model_name.param_key}_#{field.name}_#{ordinal}"
      end

      def add_label(field)
        view.t('crud_components.nested.add', name: field.target.model_name.human,
                                             default: 'Add %<name>s')
      end

      def remove_label
        view.t('crud_components.nested.remove', default: 'Remove')
      end
    end
  end
end

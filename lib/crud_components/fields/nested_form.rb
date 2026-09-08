# frozen_string_literal: true

module CrudComponents
  module Fields
    # The form side of `nested:` — which of the target's fields the block
    # carries, what it permits and which records it renders. Mixed into the
    # singular and the collection flavor, which keep their own display, filter
    # and sort behaviour from the plain association fields.
    module NestedForm
      def default_form_control = :nested
      def default_editable? = true

      # The target's own form fields, in its own declared order. `nested:` on the
      # attribute narrows them; without it the target's form fieldset decides,
      # which for a model without one is everything it can show.
      def nested_fields
        @nested_fields ||= begin
          structure = target_structure
          fields = if options[:nested].is_a?(Array)
                     options[:nested].map { |field_name| structure.field(field_name) }
                   else
                     structure.fieldset_fields(structure.form_fieldset)
                   end
          fields.select(&:form_control)
        end
      end

      # `id` so an existing record is updated instead of replaced; `_destroy`
      # only where the model allows it.
      def permit_param
        keys = [:id]
        keys << :_destroy if removable?
        { "#{name}_attributes": keys + nested_fields.map(&:permit_param) }
      end

      delegate :collection?, to: :reflection

      # Whether a row carries a "remove" box.
      def removable? = nested_options[:allow_destroy].present?

      # How many rows this block can ever hold.
      def max_rows = collection? ? Float::INFINITY : 1

      # The records the block renders. A singular association is a list of none
      # or one, so both flavors render through the same partial.
      def existing_records(parent)
        value = parent.public_send(name)
        collection? ? value.to_a : Array(value)
      end

      # A row the (+) asked for. Built through the association so the target
      # knows its parent — a field of the target may well ask for it.
      def build_row(parent)
        collection? ? parent.public_send(name).build : parent.public_send(:"build_#{name}")
      end

      private

      def nested_options
        model.nested_attributes_options[name] || {}
      end
    end
  end
end

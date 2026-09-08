# frozen_string_literal: true

module CrudComponents
  module Fields
    # A record edited in place rather than picked from a list, asked for with
    # `nested:` on the attribute. The form renders the target's own fields, and
    # the permit list carries `<name>_attributes` with exactly those keys — the
    # same pairing the rest of the gem rests on.
    #
    # `nested: true` takes the target's form fields; `nested: %i[street zip]`
    # takes those. The model has to declare `accepts_nested_attributes_for`, or
    # the params would arrive and go nowhere — that is checked when the
    # structure is built.
    #
    # A record that isn't there yet is built, so the form can create one — a
    # form that cannot enter what it declares is rarely what anybody wants.
    # `build: false` says the opposite: no record, no block, and the gem builds
    # nothing. That is the choice for a record only some parents should ever
    # have.
    #
    # Singular associations only (belongs_to / has_one). A collection keeps its
    # picker; adding and removing rows is a different feature.
    class NestedField < Base
      def default_renderer = :association

      def reflection
        @reflection ||= model.reflect_on_association(name)
      end

      def target = reflection.klass
      def target_structure = Structure.for(target)
      def group_model = target

      def default_form_control = :nested
      def default_editable? = true

      # Whether a missing record is built so the form can create one.
      def build_missing? = options[:build] != false

      # The record the block edits: the parent's own, or a fresh one when this
      # field builds. nil (and no block at all) when it doesn't — an empty
      # bordered box with a heading and nothing in it helps nobody.
      def record_for(parent)
        parent.public_send(name) || (build_missing? ? parent.public_send(:"build_#{name}") : nil)
      end

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
        keys << :_destroy if nested_options[:allow_destroy]
        { "#{name}_attributes": keys + nested_fields.map(&:permit_param) }
      end

      private

      def nested_options
        model.nested_attributes_options[name] || {}
      end
    end
  end
end

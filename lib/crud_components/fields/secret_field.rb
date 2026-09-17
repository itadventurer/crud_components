# frozen_string_literal: true

module CrudComponents
  module Fields
    # `attribute :api_token, secret: true` — a credential. Writable, never shown:
    # a cell says only whether a value is stored, the input starts empty, and it
    # is neither filterable, sortable nor searched. Leaving the input empty keeps
    # the stored value; `remove_<name>` clears it (see {Model}).
    class SecretField < Base
      def default_renderer = :secret
      def secret? = true
      def default_form_control = :secret
      def default_editable? = true

      def filterable? = false
      def sortable? = false
      def search_spec_entry = nil

      # A text column takes a textarea, so a pasted key keeps its line breaks.
      def multiline? = column&.type == :text

      # Whether the record holds a value — all a cell ever tells.
      def stored?(record) = record.public_send(name).present?

      def value(record) = stored?(record) # rubocop:disable Naming/PredicateMethod -- the cell's value

      def remove_param = :"remove_#{name}"

      def permit_params = [name, remove_param]
    end
  end
end

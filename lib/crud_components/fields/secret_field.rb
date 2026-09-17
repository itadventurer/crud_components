# frozen_string_literal: true

module CrudComponents
  module Fields
    # `attribute :api_token, secret: true` — a credential. Its value is written,
    # never read back: a cell shows only whether a value is stored, filtering and
    # sorting go by that presence, search skips it, and the input starts empty.
    # Leaving the input empty keeps the stored value; `remove_<name>` clears it
    # (see {Model}).
    class SecretField < Base
      def default_renderer = :secret
      def secret? = true
      def default_form_control = :secret
      def default_editable? = true
      def search_spec_entry = nil

      # ── presence, never the value ───────────────────────────────────────
      def derived_filterable? = true
      def derived_filter_control = :presence
      def derived_sortable? = true

      # `filter:` and `sort:` blocks would reach the value; the structure rejects
      # them (see Structure#validate_secrets!), so only `false` gets here.
      def filter_facet = nil
      def typed_filter = nil
      def sort_facet = nil

      def apply_derived_filter(scope, value: nil, **)
        case value
        when CrudComponents::PRESENT_FILTER_VALUE then scope.where.not(name => [nil, ''])
        when CrudComponents::ABSENT_FILTER_VALUE then scope.where(name => [nil, ''])
        else scope
        end
      end

      # Stored first when descending, as a boolean sorts.
      def apply_sort(scope, dir)
        column = model.arel_table[name]
        blank = column.eq(nil).or(column.eq(''))
        stored = Arel::Nodes::Case.new.when(blank).then(0).else(1)
        scope.reorder(stored.public_send(dir))
      end

      # A text column takes a textarea, so a pasted key keeps its line breaks.
      def multiline? = column&.type == :text

      # Whether the record holds a value — all a cell ever tells.
      def stored?(record) = record.public_send(name).present?

      def value(record) = stored?(record) # rubocop:disable Naming/PredicateMethod -- the cell's value

      # The presence filter value a cell links to.
      def filter_value(stored)
        stored ? CrudComponents::PRESENT_FILTER_VALUE : CrudComponents::ABSENT_FILTER_VALUE
      end

      def remove_param = :"remove_#{name}"

      def permit_params = [name, remove_param]
    end
  end
end

module CrudComponents
  module Fields
    # boolean column: ✓/✗ cell, any/yes/no select; values cast & validated,
    # invalid ones leave the scope unchanged.
    class BooleanField < Base
      def default_renderer = :boolean
      def derived_filterable? = true
      def derived_sortable? = true
      def derived_filter_control = :boolean
      def default_editable? = true
      def form_control = :boolean

      # Stricter than ActiveModel's cast (which makes any junk string true):
      # only recognizable values filter, everything else is ignored.
      TRUE_VALUES = %w[true t 1 yes on].freeze
      FALSE_VALUES = %w[false f 0 no off].freeze

      def apply_derived_filter(scope, exact: nil, **)
        case exact&.downcase
        when *TRUE_VALUES then scope.where(name => true)
        when *FALSE_VALUES then scope.where(name => false)
        else scope
        end
      end
    end
  end
end

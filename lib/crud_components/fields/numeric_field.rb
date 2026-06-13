module CrudComponents
  module Fields
    # numeric column: min–max range plus exact match; unparsable values ignored.
    class NumericField < Base
      def default_renderer = :number
      def derived_filterable? = true
      def derived_sortable? = true
      def derived_filter_control = :number_range
      def default_editable? = !NON_EDITABLE_COLUMNS.include?(name.to_s)
      def form_control = :number

      def apply_derived_filter(scope, exact: nil, geq: nil, leq: nil)
        scope = scope.where(name => cast(exact)) if cast(exact)
        scope = scope.where(arel_column.gteq(cast(geq))) if cast(geq)
        scope = scope.where(arel_column.lteq(cast(leq))) if cast(leq)
        scope
      end

      private

      def cast(value)
        return nil if value.nil?

        BigDecimal(value)
      rescue ArgumentError, TypeError
        nil
      end
    end
  end
end

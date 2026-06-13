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
        if (v = cast(exact)) then scope = scope.where(name => v) end
        if (v = cast(geq)) then scope = scope.where(arel_column.gteq(v)) end
        if (v = cast(leq)) then scope = scope.where(arel_column.lteq(v)) end
        scope
      end

      private

      def cast(value)
        return nil if value.nil?

        decimal = BigDecimal(value)
        decimal.finite? ? decimal : nil # reject NaN / Infinity — they aren't filters
      rescue ArgumentError, TypeError
        nil
      end
    end
  end
end

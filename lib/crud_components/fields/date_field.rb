module CrudComponents
  module Fields
    # date/datetime column: from–to range plus exact day; datetime ranges are
    # whole-day-inclusive (a `leq` of 2026-01-31 includes that entire day).
    class DateField < Base
      def datetime?
        @datetime ||= %i[datetime timestamp timestamptz].include?(model.columns_hash[name.to_s]&.type)
      end

      def default_renderer = datetime? ? :datetime : :date
      def derived_filterable? = true
      def derived_sortable? = true
      def derived_filter_control = :date_range
      def default_editable? = !NON_EDITABLE_COLUMNS.include?(name.to_s)
      def form_control = datetime? ? :datetime : :date

      def apply_derived_filter(scope, value: nil, geq: nil, leq: nil)
        if (d = cast(value)) then scope = apply_day(scope, d) end
        if (d = cast(geq)) then scope = scope.where(arel_column.gteq(lower_bound(d))) end
        if (d = cast(leq)) then scope = scope.where(arel_column.lteq(upper_bound(d))) end
        scope
      end

      private

      def apply_day(scope, day)
        if datetime?
          scope.where(arel_column.gteq(lower_bound(day)).and(arel_column.lteq(upper_bound(day))))
        else
          scope.where(name => day)
        end
      end

      def lower_bound(day)
        datetime? ? day.beginning_of_day : day
      end

      def upper_bound(day)
        datetime? ? day.end_of_day : day
      end

      def cast(value)
        return nil if value.nil?

        Date.parse(value)
      rescue ArgumentError, TypeError, RangeError
        nil
      end
    end
  end
end

module CrudComponents
  module Fields
    # enum: badge cell, select of enum keys, values validated against the
    # enum definition — invalid ones leave the scope unchanged.
    class EnumField < Base
      def default_renderer = :enum
      def derived_filterable? = true
      def derived_sortable? = true
      def derived_filter_control = :select
      def default_editable? = true
      def form_control = :enum

      def form_choices
        enum_keys.map { |key| [human_value(key), key] }
      end

      def enum_keys
        model.defined_enums[name.to_s].keys
      end

      def filter_choices(_query = nil)
        enum_keys.map { |key| [human_value(key), key] }
      end

      def human_value(key)
        model.human_attribute_name("#{name}.#{key}", default: key.to_s.humanize)
      end

      # A nullable column offers a "not set" (IS NULL) choice in the filter.
      def filter_includes_null? = nullable?

      def apply_derived_filter(scope, exact: nil, **)
        return scope.where(name => nil) if exact == CrudComponents::NULL_FILTER_VALUE && nullable?
        return scope unless exact && enum_keys.include?(exact)

        scope.where(name => exact)
      end
    end
  end
end

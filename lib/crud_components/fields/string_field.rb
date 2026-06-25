module CrudComponents
  module Fields
    # string column: text cell, text input, escaped case-insensitive contains.
    class StringField < Base
      # A column named email / url / website / link gets the matching smart
      # renderer by default (a mailto: / http link). `as:` still overrides.
      def default_renderer = SemanticRenderer.renderer_for(name) || :string

      def derived_filterable? = true
      def derived_sortable? = true
      def default_editable? = !NON_EDITABLE_COLUMNS.include?(name.to_s)
      def form_control = :string

      def apply_derived_filter(scope, exact: nil, **)
        return scope unless exact

        # explicit escape char: backslash is not SQLite's default
        scope.where(arel_column.matches(like_pattern(exact), '\\'))
      end
    end
  end
end

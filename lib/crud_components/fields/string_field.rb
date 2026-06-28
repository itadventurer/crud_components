module CrudComponents
  module Fields
    # string column: text cell, text input, escaped case-insensitive contains.
    class StringField < Base
      # Name-gated smart renderers: a column literally named `email` (or `*_email`)
      # renders as a `mailto:` link; one named `url`, `website`, `link` or
      # `homepage` renders an http(s) value as a link. Gated on the column *name*,
      # never the value — a column that merely happens to hold a URL or an "@" is
      # left alone, so the behaviour is predictable and you can't accidentally turn
      # arbitrary text into links. `as:` overrides (opt out, or force a renderer).
      URL_NAMES = %w[url website link homepage].freeze

      # A column named email / url / website / link gets the matching smart
      # renderer by default (a mailto: / http link). `as:` still overrides.
      def default_renderer = smart_renderer || :string

      # The renderer the column *name* implies (:email / :url), or nil for none.
      # Public so a path column (publisher.email, authors.email) can reuse the same
      # name rules by delegating to this field rather than duplicating them.
      def smart_renderer
        n = name.to_s
        return :email if n == 'email' || n.end_with?('_email')
        return :url if URL_NAMES.include?(n)

        nil
      end

      def derived_filterable? = true
      def derived_sortable? = true
      def default_editable? = !NON_EDITABLE_COLUMNS.include?(name.to_s)
      def form_control = :string

      def apply_derived_filter(scope, value: nil, **)
        return scope unless value

        # explicit escape char: backslash is not SQLite's default
        scope.where(arel_column.matches(like_pattern(value), '\\'))
      end
    end
  end
end

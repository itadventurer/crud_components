module CrudComponents
  # Name-gated "smart" renderers. A column literally named `email` (or `*_email`)
  # renders as a `mailto:` link; one named `url`, `website`, `link` or `homepage`
  # renders an http(s) value as a link. Gated on the column *name*, never the
  # value — a column that merely happens to hold a URL or an "@" is left alone, so
  # the behaviour is predictable and you can't accidentally turn arbitrary text
  # into links. Override per field with `as:` to opt out or force a renderer.
  module SemanticRenderer
    URL_NAMES = %w[url website link homepage].freeze

    module_function

    # The renderer a column name implies (:email / :url), or nil for none.
    def renderer_for(name)
      n = name.to_s
      return :email if n == 'email' || n.end_with?('_email')
      return :url if URL_NAMES.include?(n)

      nil
    end
  end
end

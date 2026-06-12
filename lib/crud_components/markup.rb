module CrudComponents
  # Soft-dependency markup rendering: works with whichever gem the host app
  # already has; raises at structure build (not here) when none is present.
  module Markup
    module_function

    def markdown(source)
      source = source.to_s
      if defined?(Commonmarker)
        Commonmarker.to_html(source)
      elsif defined?(CommonMarker)
        CommonMarker.render_html(source)
      elsif defined?(Redcarpet)
        @redcarpet ||= Redcarpet::Markdown.new(Redcarpet::Render::HTML.new)
        @redcarpet.render(source)
      elsif defined?(Kramdown)
        Kramdown::Document.new(source).to_html
      else
        source
      end
    end

    def asciidoc(source)
      return source.to_s unless defined?(Asciidoctor)

      Asciidoctor.convert(source.to_s, safe: :safe)
    end

    def highlight_json(pretty)
      return nil unless defined?(Rouge)

      formatter = Rouge::Formatters::HTMLInline.new(Rouge::Themes::Github.new)
      formatter.format(Rouge::Lexers::JSON.new.lex(pretty))
    end
  end
end

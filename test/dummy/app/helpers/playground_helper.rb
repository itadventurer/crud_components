module PlaygroundHelper
  REPO = 'https://github.com/itadventurer/crud_components/blob/main'.freeze

  # The "how this page is built" panel shown at the top of each playground page.
  # `intro` is a short explanation (may contain markup); the block holds the
  # code sections (use `code_file`); `docs` is a { label => repo-path } hash of
  # links into the real documentation.
  def docs_panel(intro:, docs: {}, &block)
    return if params[:bare] # ?bare=1 hides the panel — used when capturing screenshots
    render 'shared/docs_panel', intro: intro.html_safe, docs: docs, body: capture(&block)
  end

  # One labelled code section inside a docs_panel. Pass the code as the block;
  # write ERB tags / angle brackets as &lt; &gt; entities so they render as
  # text instead of executing.
  def code_file(path, lang = :ruby, &block)
    render 'shared/code_file', path: path, lang: lang.to_s, code: capture(&block).to_s.strip.html_safe
  end

  def doc_link(label, path)
    link_to label, "#{REPO}/#{path}", class: 'link-secondary fw-medium',
                                       target: '_blank', rel: 'noopener'
  end
end

module CrudComponents
  module Presenters
    # Fast inline cell renderers — Ruby equivalents of the
    # crud_components/fields/_*.html.erb partials, built with the tag/link
    # helpers so a big table skips one partial render per cell (the dominant
    # cost: a partial cell is ~200µs, this is ~10–20µs). Output matches the
    # partials (same elements, classes, links, escaping).
    #
    # Used only when the renderer is one of these built-ins AND the host hasn't
    # overridden its partial (Base#render_cell checks both). markdown/asciidoc
    # and any custom `as:` renderer keep using their partials.
    class Cells
      BUILTINS = %i[string text number boolean date datetime enum
                    association association_list json attachment].freeze

      def self.handles?(renderer) = BUILTINS.include?(renderer)

      def initialize(view)
        @v = view
      end

      def render(renderer, value:, record:, field:, surface:, cell_context:)
        public_send(renderer, value, record, field, surface, cell_context)
      end

      def string(value, _record, _field, surface, _cc)
        return dash if blank?(value)

        surface == :collection ? @v.truncate(value.to_s, length: 120) : esc(value)
      end

      def text(value, _record, _field, surface, _cc)
        return dash if blank?(value)
        return @v.truncate(value.to_s, length: 120) if surface == :collection

        @v.tag.div(esc(value), class: 'crud-text', style: 'white-space: pre-line')
      end

      def number(value, _record, field, _surface, _cc)
        return dash if value.nil?

        o = field.renderer_options
        formatted = o[:digits] ? @v.number_with_precision(value, precision: o[:digits], delimiter: ',')
                               : @v.number_with_delimiter(value)
        o[:unit] ? @v.safe_join([formatted, " #{o[:unit]}"]) : @v.safe_join([formatted])
      end

      def boolean(value, _record, field, _surface, cc)
        return dash if value.nil?

        icon = @v.tag.span(value ? '✓' : '✗', class: value ? css.boolean_true : css.boolean_false)
        filter_link(cc, field, value, icon) { icon }
      end

      def date(value, _record, _field, _surface, _cc)
        value.nil? ? dash : esc(@v.l(value.to_date))
      end

      def datetime(value, _record, _field, _surface, _cc)
        value.nil? ? dash : esc(@v.l(value, format: :short))
      end

      def enum(value, _record, field, _surface, cc)
        return dash if value.nil?

        label = field.respond_to?(:human_value) ? field.human_value(value) : value
        badge = @v.tag.span(label, class: css.badge)
        filter_link(cc, field, value, badge,
                    title: @v.t('crud_components.filter_by', name: label, default: "Filter by #{label}")) { badge }
      end

      def association(value, record, field, _surface, _cc)
        return dash if value.nil?

        label = @v.crud_association_label(field, value)
        path = @v.crud_record_path(value, owner: record)
        path ? @v.link_to(label, path, data: { turbo_action: 'advance' }) : esc(label)
      end

      def association_list(value, record, field, surface, _cc)
        items = value.to_a
        return dash if items.empty?

        shown = surface == :collection ? items.first(3) : items
        links = @v.safe_join(shown.map { |item| association_item(field, item, record) }, ', ')
        return links if items.size <= shown.size

        more = @v.t('crud_components.more', count: items.size - shown.size, default: '+%{count} more')
        index_path = @v.crud_association_index_path(record, field)
        more_html = index_path ? @v.link_to(more, index_path, class: css.muted, data: { turbo_action: 'advance' })
                               : @v.tag.span(more, class: css.muted)
        @v.safe_join([links, ' ', more_html])
      end

      def json(value, _record, _field, surface, _cc)
        return dash if value.nil?

        pretty = value.is_a?(String) ? value : JSON.pretty_generate(value)
        pretty = @v.truncate(pretty, length: 120) if surface == :collection
        highlighted = CrudComponents::Markup.highlight_json(pretty)
        inner = highlighted ? @v.raw(highlighted) : pretty
        @v.tag.pre(@v.tag.code(inner), class: 'crud-json mb-0')
      end

      def attachment(value, _record, field, surface, _cc)
        return dash unless value.respond_to?(:attached?) && value.attached?

        if field.respond_to?(:many?) && field.many?
          thumbs = value.map { |a| attachment_thumb(a, surface) }
          @v.tag.span(@v.safe_join(thumbs), class: 'd-inline-flex flex-wrap gap-1')
        else
          attachment_thumb(value, surface)
        end
      end

      private

      def config = CrudComponents.config
      def css = config.css

      def blank?(value) = value.nil? || value == ''

      # The muted em-dash shown for a nil/blank value.
      def dash = @v.tag.span('—', class: css.muted)

      # html_escape — matches ERB `<%= value %>` (passes SafeBuffers through).
      def esc(value) = ERB::Util.html_escape(value)

      # Wrap `content` in a click-to-filter link when the query would act on the
      # field, else yield the bare content (the no-JS / no-query path).
      def filter_link(cell_context, field, value, content, **link_options)
        return yield unless cell_context&.filterable?(field)

        @v.link_to(content, cell_context.filter_url(field, value),
                   class: css.filter_link, data: { turbo_action: 'advance' }, **link_options)
      end

      def association_item(field, item, owner)
        label = @v.crud_association_label(field, item)
        path = @v.crud_record_path(item, owner: owner)
        path ? @v.link_to(label, path, data: { turbo_action: 'advance' }) : label.to_s
      end

      def attachment_thumb(attachment, surface)
        style = surface == :record ? 'max-height: 16rem' : 'max-height: 2.5rem'
        if attachment.image?
          @v.image_tag(attachment, class: 'rounded crud-image', style: style)
        elsif attachment.previewable? && CrudComponents.previews_available?
          @v.image_tag(attachment.preview(resize_to_limit: [600, 600]), class: 'rounded crud-image', style: style)
        else
          @v.link_to(@v.rails_blob_path(attachment, disposition: 'attachment'),
                     class: 'd-inline-flex align-items-center gap-1 text-decoration-none') do
            @v.safe_join([@v.tag.i('', class: "#{css.icon_prefix}#{@v.crud_file_icon(attachment.filename)}"),
                          @v.tag.span(attachment.filename)])
          end
        end
      end
    end
  end
end

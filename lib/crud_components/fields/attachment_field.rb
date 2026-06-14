module CrudComponents
  module Fields
    # Active Storage attachment: rendered by content type — image inline,
    # previewable (e.g. PDF) as a preview, otherwise an icon + filename link.
    class AttachmentField < Base
      def default_renderer = :attachment

      def many?
        @many ||= model.reflect_on_attachment(name).macro == :has_many_attached
      end

      def eager_load_name
        many? ? :"#{name}_attachments" : :"#{name}_attachment"
      end

      # ── forms ────────────────────────────────────────────────────────────
      def default_editable? = true
      def form_control = :file
      def permit_param = many? ? { name => [] } : name
    end
  end
end

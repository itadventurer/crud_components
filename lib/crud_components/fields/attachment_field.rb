module CrudComponents
  module Fields
    # Active Storage attachment: rendered by content type — image inline,
    # previewable (e.g. PDF) as a preview, otherwise an icon + filename link.
    class AttachmentField < Base
      # present / absent filter — "has a cover / has no cover" — joining through
      # the underlying *_attachment(s) association (see #presence_association).
      include PresenceFilter

      def default_renderer = :attachment

      def many?
        @many ||= model.reflect_on_attachment(name).macro == :has_many_attached
      end

      def eager_load
        [many? ? :"#{name}_attachments" : :"#{name}_attachment", *declared_preloads]
      end

      # The Active Storage join `where.associated` / `where.missing` test: the
      # column's backing has_one_attached / has_many_attached reflection.
      def presence_association = many? ? :"#{name}_attachments" : :"#{name}_attachment"

      # ── forms ────────────────────────────────────────────────────────────
      def default_editable? = true
      def form_control = :file
      def permit_param = many? ? { name => [] } : name
    end
  end
end

module CrudComponents
  module Fields
    # Active Storage attachment: image thumb in collections, larger on records.
    class AttachmentField < Base
      def default_renderer = :image

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

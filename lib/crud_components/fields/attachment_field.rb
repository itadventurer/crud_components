module CrudComponents
  module Fields
    # Active Storage attachment: rendered by content type — image inline,
    # previewable (e.g. PDF) as a preview, otherwise an icon + filename link.
    class AttachmentField < Base
      def default_renderer = :attachment

      def many?
        @many ||= model.reflect_on_attachment(name).macro == :has_many_attached
      end

      def eager_load
        [attachment_reflection, *declared_preloads]
      end

      # ── filtering ──────────────────────────────────────────────────────────
      # An attachment has no value to type into a box, but "has a cover / has no
      # cover" is the natural question — so it filters by presence: a 3-state
      # any/present/absent control that composes into the query as an EXISTS /
      # NOT EXISTS over the backing *_attachment(s) association.
      def derived_filterable? = true
      def derived_filter_control = :presence

      def apply_derived_filter(scope, value: nil, **)
        case value
        when CrudComponents::PRESENT_FILTER_VALUE then scope.where.associated(attachment_reflection)
        when CrudComponents::ABSENT_FILTER_VALUE  then scope.where.missing(attachment_reflection)
        else scope
        end
      end

      # ── forms ────────────────────────────────────────────────────────────
      def default_editable? = true
      def form_control = :file
      def permit_param = many? ? { name => [] } : name

      private

      # The has_one_attached / has_many_attached association the eager-load and the
      # presence filter join through.
      def attachment_reflection = many? ? :"#{name}_attachments" : :"#{name}_attachment"
    end
  end
end

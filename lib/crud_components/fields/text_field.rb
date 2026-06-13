module CrudComponents
  module Fields
    # text column: truncated in collections, line breaks preserved on records.
    class TextField < StringField
      def default_renderer = :text
      def form_control = :text
    end
  end
end

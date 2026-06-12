module CrudComponents
  module Fields
    # text column: truncated in collections, line breaks preserved on records.
    class TextField < StringField
      def default_renderer = :text
    end
  end
end

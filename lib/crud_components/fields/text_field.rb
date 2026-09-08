# frozen_string_literal: true

module CrudComponents
  module Fields
    # text column: truncated in collections, line breaks preserved on records.
    class TextField < StringField
      def default_renderer = :text
      def default_form_control = :text
    end
  end
end

module CrudComponents
  module Fields
    # Active Storage attachment: image thumb in collections, larger on records.
    class AttachmentField < Base
      def default_renderer = :image

      def eager_load_name
        :"#{name}_attachment"
      end
    end
  end
end

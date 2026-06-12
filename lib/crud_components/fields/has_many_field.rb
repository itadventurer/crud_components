module CrudComponents
  module Fields
    # has_many / habtm: truncated list of links ("a, b +3 more"). No derived
    # filter or sort; opt in with `filter like: :assoc` (delegation).
    class HasManyField < Base
      def default_renderer = :association_list

      def reflection
        @reflection ||= model.reflect_on_association(name)
      end

      def target
        reflection.klass
      end

      def eager_load_name
        name
      end
    end
  end
end

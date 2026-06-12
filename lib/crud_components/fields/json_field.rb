module CrudComponents
  module Fields
    # json/jsonb column: pretty-printed <pre>; no derived filter or sort.
    class JsonField < Base
      def default_renderer = :json
    end
  end
end

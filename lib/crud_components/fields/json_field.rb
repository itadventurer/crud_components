module CrudComponents
  module Fields
    # json/jsonb column: pretty-printed <pre>; no derived filter or sort.
    class JsonField < Base
      def default_renderer = :json
      # JSON columns are not form-editable in v1: round-tripping raw JSON
      # through a textarea needs parse-on-assign. Renders read-only.
    end
  end
end

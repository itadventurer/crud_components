module CrudComponents
  # Extended onto every scope handed to filter/search blocks, so custom query
  # logic keeps the safe ILIKE machinery without hand-written SQL:
  #
  #   filter do |scope, value|
  #     scope.where(active: true).where_like({ authors: :name }, value)
  #   end
  module WhereLike
    def where_like(spec, value)
      CrudComponents::LikeSpec.apply(self, spec, value)
    end
  end
end

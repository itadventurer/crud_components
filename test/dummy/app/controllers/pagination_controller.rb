class PaginationController < ApplicationController
  # Pagination is the host app's job, on purpose: the gem stays
  # pagination-agnostic so it needn't depend on (or guess) your pager. You take
  # the query into your own hands and add your gem's pager — here, kaminari.
  #
  # That's the whole integration, two lines:
  #   1. build the Query and apply it to a scope you control;
  #   2. paginate the result with your gem (.page/.per for kaminari; pagy is similar).
  #
  # `query: @query` then tells crud_collection the records arrive pre-filtered,
  # so it renders the toolbar/sort links against your query and leaves the rows
  # exactly as you paginated them. The pager links are plain GET params, so they
  # compose with the gem's own filter/search/sort params automatically.
  def index
    @query = CrudComponents::Query.new(Book, params, ability: self)
    @books = @query.apply(Book.all).page(params[:page]).per(15)
  end
end

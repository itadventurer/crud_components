class ColumnsController < ApplicationController
  # The column picker: a user hides/reorders the columns they may see. The picker
  # submits `?cols[]=` to this same URL — exactly like sort and filter — so it
  # needs no endpoint of its own, and this controller stays a one-liner: the
  # current selection rides in the URL, which the gem reads for you.
  #
  # Persisting it per user is the app's call and not the gem's problem. To make
  # the choice stick across visits you'd add ~3 lines — read, store, replay:
  #
  #   user.update!(book_columns: params[:cols]) if params.key?(:cols)
  #   # then: crud_collection @books, ..., visible: user.book_columns
  #
  # `?cols=` (a fresh pick) always wins over `visible:` (the stored default).
  def index
    @books = Book.all
    @columns = PropertyDefinition.order(:id).map { |defn| defn.to_crud_column(Book) }
  end
end

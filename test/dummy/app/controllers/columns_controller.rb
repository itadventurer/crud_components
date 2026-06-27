class ColumnsController < ApplicationController
  # The column picker: a user hides/reorders the columns they may see. The picker
  # submits `?cols[]=` to this same URL — exactly like sort and filter — so it
  # needs no endpoint of its own, and this controller stays a one-liner: the
  # current selection rides in the URL, which the gem reads for you.
  #
  # Here `picker: true` with the default `picked_columns: :auto` lets the gem read
  # `?cols=` for you — ephemeral, nothing stored. Persisting it per user is the
  # app's call, not the gem's. To make the choice stick you read, store, replay:
  #
  #   CrudComponents.selected_columns(params) { |cols| user.update!(book_columns: cols) }
  #   # then: crud_collection @books, picker: true, picked_columns: user.book_columns
  #
  # When you pass an explicit Array the gem shows exactly that and never re-reads
  # the param — so you capture the fresh pick yourself (above) before replaying.
  def index
    @books = Book.all
    @columns = PropertyDefinition.order(:id).map { |defn| defn.to_crud_column(Book) }
  end
end

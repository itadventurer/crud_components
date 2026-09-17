# frozen_string_literal: true

# The target of `resources :book_authors` — an author's credit on a book, kept
# apart from the authors a book lists.
class BookAuthorsController < ApplicationController
  def show = render plain: "Credit #{params[:id]}"
end

class BooksController < ApplicationController
  # The auto-params mode needs zero controller code: the helper reads the
  # request params, builds the query and applies it.
  def index
    @publisher = Publisher.find_by(slug: params[:publisher_id]) if params[:publisher_id]
  end

  def show
    @book = find_book
  end

  def edit
    @book = find_book
  end

  def preview
    @book = find_book
  end

  def new; end

  def destroy
    find_book.destroy!
    redirect_to books_path, notice: 'Book deleted.'
  end

  private

  def find_book
    Book.find_by!(slug: params[:id])
  end
end

class BooksController < ApplicationController
  # The auto-params mode needs zero controller code: the helper reads the
  # request params, builds the query and applies it.
  def index
    @publisher = Publisher.find_by(slug: params[:publisher_id]) if params[:publisher_id]
    @author = Author.find(params[:author_id]) if params[:author_id]
  end

  def show
    @book = find_book
  end

  def new
    @book = Book.new
  end

  def create
    @book = Book.new(book_params)
    if @book.save
      redirect_to @book, notice: 'Book created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @book = find_book
  end

  def update
    @book = find_book
    if @book.update(book_params)
      redirect_to @book, notice: 'Book updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def preview
    @book = find_book
  end

  def import; end

  def destroy
    find_book.destroy!
    redirect_to books_path, notice: 'Book deleted.'
  end

  private

  def find_book
    Book.find_by!(slug: params[:id])
  end

  # The gem is the single source of truth for what's editable — the form and
  # this permit list derive from the same metadata, so they can't drift.
  def book_params
    params.require(:book).permit(*Book.crud_attribute_names(action_name.to_sym, ability: self))
  end
end

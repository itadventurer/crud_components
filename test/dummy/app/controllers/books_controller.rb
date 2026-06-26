class BooksController < ApplicationController
  # You hand crud_collection a scope — so authorization/scoping happens here,
  # in your controller (e.g. Book.accessible_by(current_ability)), not in the gem.
  def index
    @publisher = Publisher.find_by(slug: params[:publisher_id]) if params[:publisher_id]
    @author = Author.find(params[:author_id]) if params[:author_id]
    @books = @publisher&.books || @author&.books || Book.all
  end

  def show
    @book = find_book
    # The standalone column picker on this page submits ?cols= here; extract it
    # so crud_record can honor it (and persist it per user if you want to).
    @visible = CrudComponents.selected_columns(params)
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

  # Bulk actions on the ticked rows. The gem resolves selected[]=<slug> back to
  # records via the model's identify_by — one line, your scope, your call.
  def delete_selected
    n = CrudComponents.selected(Book, params).destroy_all.size
    redirect_to books_path, notice: "Deleted #{n} book(s)."
  end

  def export_selected
    @books = CrudComponents.selected(Book, params)
  end

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
    params.require(:book).permit(*CrudComponents.permitted_attributes(Book, action: action_name.to_sym, ability: self))
  end
end

# Author is a zero-config model (no include, no crud_structure) — yet it gets
# a working table, record view AND form, all derived.
class AuthorsController < ApplicationController
  def index = @authors = Author.all

  def show
    @author = Author.find(params[:id])
  end

  def new
    @author = Author.new
  end

  def create
    @author = Author.new(author_params)
    if @author.save
      redirect_to @author, notice: 'Author created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @author = Author.find(params[:id])
  end

  def update
    @author = Author.find(params[:id])
    if @author.update(author_params)
      redirect_to @author, notice: 'Author updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    Author.find(params[:id]).destroy!
    redirect_to authors_path, notice: 'Author deleted.'
  end

  private

  # Works for a model that doesn't even include CrudComponents::Model.
  def author_params
    params.require(:author).permit(*CrudComponents.permitted_attributes(Author, action: action_name.to_sym, ability: self))
  end
end

class RenderersController < ApplicationController
  # Soft-dependency renderers (markdown, JSON) + manual action placement.
  def index
    @book = Book.order(:id).first
  end
end

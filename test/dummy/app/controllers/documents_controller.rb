class DocumentsController < ApplicationController
  # STI (Document / Manual), an asciidoc body, and polymorphic comments.
  def index
    @documents = Document.all
    @manual = Manual.order(:id).first
    @comments = Comment.order(:id)
  end
end

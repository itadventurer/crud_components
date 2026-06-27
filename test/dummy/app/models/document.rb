# STI base — Manual (manual.rb) inherits this crud_structure (the gem walks the
# superclass for the declaration). The `type` column is the STI discriminator.
class Document < ApplicationRecord
  include CrudComponents::Model

  has_many :comments, as: :commentable   # the polymorphic side, for the comments demo

  crud_structure do
    label :title

    attribute :body, as: :asciidoc   # soft-dependency renderer (asciidoctor)

    fieldset :index, %i[type title created_at]   # `type` shows Document vs Manual (STI)
    fieldset :show, %i[type title body created_at]
  end
end

# Polymorphic belongs_to — the demo renders `commentable` as a nil-safe link to
# whichever model owns the comment (a Book or a Document).
class Comment < ApplicationRecord
  include CrudComponents::Model

  belongs_to :commentable, polymorphic: true

  crud_structure do
    label { |c| c.body.to_s.truncate(40) }

    fieldset :index, %i[commentable body created_at]
  end
end

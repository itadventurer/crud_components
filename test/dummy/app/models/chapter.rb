# frozen_string_literal: true

# A chapter of a book. It exists only as part of its book — nobody browses
# chapters — so the book's form edits the rows in place (`nested:`) instead of
# offering a picker.
class Chapter < ApplicationRecord
  include CrudComponents::Model

  belongs_to :book

  validates :title, presence: true

  crud_structure do
    admin false # not a thing of its own; reached through its book

    label :title
    fieldset :form, %i[title pages]
  end
end

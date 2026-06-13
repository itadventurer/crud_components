class Review < ApplicationRecord
  include CrudComponents::Model

  belongs_to :book

  crud_structure do
    label { |review| "#{review.reviewer_name} on #{review.book.title}" }
    search_in :reviewer_name, :body, :book   # :book delegates to Book's search_in

    attribute :rating, as: :stars            # custom renderer partial in the host app

    fieldset :index, %i[book reviewer_name rating body created_at]
    fieldset :form,  %i[book rating body reviewer_name]
  end
end

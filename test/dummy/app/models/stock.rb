# frozen_string_literal: true

# The copies of a book in the warehouse, one row per book. Its `count` column
# answers `stock.count` with a number of copies, not with a number of records.
class Stock < ApplicationRecord
  include CrudComponents::Model

  belongs_to :book

  crud_structure do
    admin false # reached through its book

    label { |stock| "#{stock.count.to_i} in stock" }
  end
end

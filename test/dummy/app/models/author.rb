# Deliberately has no CrudComponents configuration at all — not even the
# include. The proof of rule zero: a bare model renders, filters and sorts.
class Author < ApplicationRecord
  has_and_belongs_to_many :books
end

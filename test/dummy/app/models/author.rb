# Deliberately has no CrudComponents configuration at all — not even the
# include. The proof of rule zero: a bare model renders, filters and sorts —
# and even has_many_attached is derived (an image-list cell + a multiple file
# field in the form, with `{ images: [] }` in the permit list), no config.
class Author < ApplicationRecord
  has_and_belongs_to_many :books
  has_many_attached :images   # author photos — derived as an image field

  validates :name, presence: true   # exercised in the form even with zero CrudComponents config
end

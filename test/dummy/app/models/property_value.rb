# One custom-property cell: this definition's value for one subject (a Book).
# Stored as text and cast per flavor on read — the classic EAV value row.
class PropertyValue < ApplicationRecord
  belongs_to :property_definition
  belongs_to :subject, polymorphic: true
end

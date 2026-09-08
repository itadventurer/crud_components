# frozen_string_literal: true

# One custom-property cell: this definition's value for one subject (a Book).
# Stored as text and cast per flavor on read — the classic EAV value row.
class PropertyValue < ApplicationRecord
  include CrudComponents::Model

  belongs_to :property_definition
  belongs_to :subject, polymorphic: true

  crud_structure do
    # Rows the app writes; the admin only ever looks. No write route is drawn.
    admin group: 'Custom properties', actions: %i[index show]
  end
end

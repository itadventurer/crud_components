# frozen_string_literal: true

# The person to ring at a publisher. It exists only as part of its publisher —
# nobody browses contacts — so the publisher's form edits it in place
# (`attribute :contact, nested: …`) instead of offering a picker.
class Contact < ApplicationRecord
  include CrudComponents::Model

  belongs_to :publisher

  validates :name, presence: true

  crud_structure do
    admin false # not a thing of its own; reached through its publisher

    label :name
    fieldset :form, %i[name email]
  end
end

# frozen_string_literal: true

class Publisher < ApplicationRecord
  include CrudComponents::Model

  has_many :books, dependent: :nullify
  has_one :contact, dependent: :destroy
  accepts_nested_attributes_for :contact
  has_one_attached :brochure # an .adoc — a non-previewable file: shows as an icon + filename

  before_validation { self.slug = name.to_s.parameterize if slug.blank? }

  def to_param = slug

  crud_structure do
    label :name
    identify_by :slug
    icon 'building' # explicit per-model icon (overrides the name-based guess)
    search_in :name

    fieldset :index, %i[name founded_on brochure books]
    # The contact is written through the publisher, so the form edits it in
    # place. `nested:` names which of its fields to show.
    attribute :contact, nested: %i[name email]

    fieldset :form, %i[name slug founded_on contact brochure]
  end
end

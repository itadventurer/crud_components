# frozen_string_literal: true

class Publisher < ApplicationRecord
  include CrudComponents::Model

  has_many :books, dependent: :nullify
  has_one :contact, dependent: :destroy
  # reject_if so a block the (+) opened and nobody filled in is dropped.
  accepts_nested_attributes_for :contact, reject_if: :all_blank
  has_one_attached :brochure # an .adoc — a non-previewable file: shows as an icon + filename

  before_validation { self.slug = name.to_s.parameterize if slug.blank? }

  def to_param = slug

  crud_structure do
    label :name
    identify_by :slug
    icon 'building' # explicit per-model icon (overrides the name-based guess)
    search_in :name

    fieldset :index, %i[name founded_on brochure books api_token]
    # The contact is written through the publisher, so the form edits it in
    # place. `nested:` names which of its fields to show.
    attribute :contact, nested: %i[name email]

    # Credentials: the form writes them, a cell shows only whether one is set.
    attribute :api_token, secret: true
    attribute :signing_key, secret: true

    fieldset :form, %i[name slug founded_on contact brochure api_token signing_key]
  end
end

class Publisher < ApplicationRecord
  include CrudComponents::Model

  has_many :books, dependent: :nullify
  has_one_attached :brochure   # an .adoc — a non-previewable file: shows as an icon + filename

  before_validation { self.slug = name.to_s.parameterize if slug.blank? }

  def to_param = slug

  crud_structure do
    label :name
    identify_by :slug
    search_in :name

    fieldset :index, %i[name founded_on brochure books]
    fieldset :form,  %i[name slug founded_on brochure]
  end
end

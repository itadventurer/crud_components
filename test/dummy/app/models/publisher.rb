class Publisher < ApplicationRecord
  include CrudComponents::Model

  has_many :books

  def to_param = slug

  crud_structure do
    label :name
    identify_by :slug
    search_in :name

    fieldset :index, %i[name founded_on books]
  end
end

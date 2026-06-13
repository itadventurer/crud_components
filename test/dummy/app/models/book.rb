class Book < ApplicationRecord
  include CrudComponents::Model

  belongs_to :publisher, optional: true
  has_many :reviews, dependent: :destroy
  has_and_belongs_to_many :authors
  has_one_attached :cover

  enum :genre, { fiction: 0, scifi: 1, nonfiction: 2 }

  validates :title, presence: true
  # a base (whole-record) error, to exercise the "not tied to a field" path
  validate { errors.add(:base, 'A book priced at 0 must be inactive (free giveaway).') if price&.zero? && active? }

  before_validation { self.slug = title.to_s.parameterize if slug.blank? }

  def to_param = slug

  def shop_margin
    price && purchase_price ? price - purchase_price : nil
  end

  crud_structure do
    identify_by :slug
    search_in :title, :subtitle, :publisher, :authors   # :authors delegates to Author's spec

    attribute :price, as: :number, unit: '€', digits: 2
    attributes :purchase_price, :shop_margin, if: :manage   # visible only to managers
    attribute :slug, editable: false                        # shown in forms, but read-only
    attribute :active, editable: :manage                    # everyone sees it; only managers edit it
    attribute :cover, as: :image

    attribute :author_names do
      render { |book| book.authors.map(&:name).to_sentence }
      filter like: { authors: :name }
      sort { |scope, dir| scope.left_joins(:authors).order(Author.arel_table[:name].public_send(dir)) }
    end

    action :preview, icon: 'eye'
    action :import, on: :collection, icon: 'upload'

    fieldset :index, %i[cover title author_names genre price publisher active],
             actions: %i[preview edit destroy]
    fieldset :catalog, %i[cover title subtitle author_names genre price purchase_price
                          shop_margin pages published_on publisher reviews active created_at],
             filters: %i[blurb]
    fieldset :compact, %i[title price]
    fieldset :form, %i[title subtitle slug blurb price purchase_price pages
                       published_on genre active publisher authors cover]
  end
end

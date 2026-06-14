require 'test_helper'

class StructureTest < ActiveSupport::TestCase
  # ── rule zero: a model with no configuration at all ───────────────────────
  test 'zero-config model resolves all columns and associations with derived flavors' do
    structure = structure_of(Author) # Author has no include, no declarations
    # columns first, then attachments (has_many_attached :images), then
    # non-belongs_to associations (the habtm :books)
    assert_equal %i[id name email created_at updated_at images books], structure.default_field_names
    assert_instance_of CrudComponents::Fields::AttachmentField, structure.field(:images)
    assert structure.field(:images).many?
    # Active Storage's own join associations are not surfaced as fields
    refute_includes structure.default_field_names, :images_attachments
    refute_includes structure.default_field_names, :images_blobs
    assert_instance_of CrudComponents::Fields::StringField, structure.field(:name)
    assert_instance_of CrudComponents::Fields::NumericField, structure.field(:id)
    assert_instance_of CrudComponents::Fields::DateField, structure.field(:created_at)
    assert_instance_of CrudComponents::Fields::HasManyField, structure.field(:books)
  end

  test 'belongs_to arrives via the FK swap, has_many/habtm appended' do
    names = structure_of(Book).default_field_names
    assert_includes names, :publisher           # belongs_to, FK-swapped
    assert_includes names, :reviews             # has_many, appended
    assert_includes names, :authors             # habtm, appended
    refute_includes names, :publisher_id
  end

  test 'zero-config identity: label, identify_by, search_in are derived' do
    structure = structure_of(Author)
    assert_equal :name, structure.label_source
    assert_equal :id, structure.identify_by
    assert_equal %i[name email], structure.search_in_spec
  end

  test 'zero-config fieldsets: default exists, index/show fall back to it' do
    structure = structure_of(Author)
    assert_equal :default, structure.fieldset(:index).name
    assert_equal :default, structure.fieldset(:show).name
    assert_raises(CrudComponents::UnknownFieldsetError) { structure.fieldset(:playground) }
  end

  # ── derivation details ─────────────────────────────────────────────────────
  test 'foreign keys are swapped for their belongs_to in the field universe' do
    names = structure_of(Book).default_field_names
    assert_includes names, :publisher
    refute_includes names, :publisher_id
  end

  test 'declared computed fields join the universe; flavors resolve correctly' do
    structure = structure_of(Book)
    assert_includes structure.default_field_names, :author_names

    expectations = {
      genre: CrudComponents::Fields::EnumField,         # enum wins over integer
      price: CrudComponents::Fields::NumericField,
      published_on: CrudComponents::Fields::DateField,
      active: CrudComponents::Fields::BooleanField,
      metadata: CrudComponents::Fields::JsonField,
      blurb: CrudComponents::Fields::TextField,
      publisher: CrudComponents::Fields::BelongsToField,
      reviews: CrudComponents::Fields::HasManyField,
      cover: CrudComponents::Fields::AttachmentField,
      shop_margin: CrudComponents::Fields::ComputedField,
      author_names: CrudComponents::Fields::ComputedField
    }
    expectations.each do |name, klass|
      assert_instance_of klass, structure.field(name), "field :#{name}"
    end
  end

  test 'date vs datetime columns are told apart' do
    structure = structure_of(Book)
    refute structure.field(:published_on).datetime?
    assert structure.field(:created_at).datetime?
    assert_equal :date, structure.field(:published_on).default_renderer
    assert_equal :datetime, structure.field(:created_at).default_renderer
  end

  # ── per-facet override: custom render keeps derived filter/sort ───────────
  test 'a render facet on a real column keeps the derived filter and sort' do
    model = define_model do
      attribute(:title) { |book| "fancy #{book.title}" }
    end
    field = structure_of(model).field(:title)
    assert_instance_of CrudComponents::Fields::StringField, field
    assert field.render_block
    assert field.filterable?
    assert field.sortable?
  end

  test 'facet opt-outs: filter false / sort false disable one facet only' do
    model = define_model do
      attribute :title do
        filter false
        sort false
      end
    end
    field = structure_of(model).field(:title)
    refute field.filterable?
    refute field.sortable?
    assert_nil field.render_block
  end

  test 'computed fields are inert in the query until facets say otherwise' do
    field = structure_of(Book).field(:shop_margin)
    refute field.filterable?
    refute field.sortable?

    with_facets = structure_of(Book).field(:author_names)
    assert with_facets.filterable?
    assert with_facets.sortable?
  end

  test 'computed fields render by value type' do
    field = structure_of(Book).field(:shop_margin)
    book = Book.new(price: 10, purchase_price: 4)
    assert_equal :number, field.renderer(book)
  end

  test 'a public model method is a usable field without any declaration' do
    klass = Class.new(ApplicationRecord) do
      self.table_name = 'books'
      define_singleton_method(:name) { 'MethodFieldBook' }
      def display_size = "#{pages} pages"
    end
    field = structure_of(klass).field(:display_size)
    assert_instance_of CrudComponents::Fields::ComputedField, field
    refute field.filterable?
    refute field.sortable?
    assert_equal '310 pages', field.value(klass.new(pages: 310))
  end

  # ── identity ───────────────────────────────────────────────────────────────
  test 'label falls back through name, title, first string column' do
    assert_equal :title, structure_of(Book).label_source # no name column
    assert_equal :name, structure_of(Publisher).label_source
  end

  test 'block labels run with the record; label_field_name is nil for them' do
    review = Review.new(reviewer_name: 'Ada', book: Book.new(title: 'Arc'))
    structure = structure_of(Review)
    assert_equal 'Ada on Arc', structure.label_for(review)
    assert_nil structure.label_field_name
    assert_equal :title, structure_of(Book).label_field_name
  end

  # ── actions ────────────────────────────────────────────────────────────────
  test 'default actions exist; declared customs slot in before destroy' do
    actions = structure_of(Book).actions
    assert_equal %i[new show edit preview import destroy], actions.keys
    assert actions[:new].collection?
    assert actions[:destroy].danger?
    assert_equal :delete, actions[:destroy].http_method
  end

  test 'fieldset action lists filter by kind' do
    structure = structure_of(Book)
    fieldset = structure.fieldset(:index)
    row = structure.fieldset_actions(fieldset, on: :row)
    assert_equal %i[preview edit destroy], row.map(&:name)
    collection = structure.fieldset_actions(structure.default_fieldset, on: :collection)
    assert_equal %i[new import], collection.map(&:name)
  end

  # ── fieldsets ──────────────────────────────────────────────────────────────
  test 'filters: extends the filterable set beyond visible fields' do
    structure = structure_of(Book)
    catalog = structure.fieldset(:catalog)
    filter_names = structure.fieldset_filter_fields(catalog).map(&:name)
    assert_includes filter_names, :blurb
    refute_includes structure.fieldset_fields(catalog).map(&:name), :blurb
  end

  test 'fieldset :default, [] is the off switch' do
    model = define_model { fieldset :default, [] }
    structure = structure_of(model)
    assert_empty structure.fieldset_fields(structure.fieldset(:default))
  end

  # ── permissions ────────────────────────────────────────────────────────────
  test 'if: symbol gates a field through can?' do
    field = structure_of(Book).field(:purchase_price)
    assert field.permitted?(CrudTestHelpers::AllowAll.new)
    refute field.permitted?(CrudComponents::PermissionContext.new(nil))
  end

  # ── if:/editable: callable arities (the documented contract) ───────────────
  test 'permission callables: symbol, zero-arity lambda, record lambda, it-proc' do
    allow = CrudTestHelpers::AllowAll.new
    deny  = CrudTestHelpers::DenyAll.new
    P = CrudComponents::Permission

    # symbol sugar → can?(symbol, model)
    assert P.permitted?(:manage, Book, allow)
    refute P.permitted?(:manage, Book, deny)

    # zero-arity lambda → run in the can? context, no record needed
    gate = -> { can?(:manage, Book) }
    assert P.permitted?(gate, Book, allow)
    refute P.permitted?(gate, Book, deny)

    # one-arity lambda and an `it` proc → receive the record
    assert P.permitted?(->(rec) { rec.active }, Book, allow, Book.new(active: true))
    refute P.permitted?(->(rec) { rec.active }, Book, allow, Book.new(active: false))
    assert P.permitted?(proc { it.active }, Book, allow, Book.new(active: true))
  end

  test 'editable_permitted? gates writability independently of visibility' do
    field = structure_of(Book).field(:active) # editable: :manage, visible to all
    assert field.permitted?(CrudComponents::PermissionContext.new(nil))      # visible
    refute field.editable_permitted?(CrudComponents::PermissionContext.new(nil)) # not editable
    assert field.editable_permitted?(CrudTestHelpers::AllowAll.new)
  end

  # ── belongs_to select/text threshold (config.select_limit) ─────────────────
  test 'belongs_to filter control flips to text above select_limit' do
    Publisher.create!(name: 'A', slug: 'a')
    Publisher.create!(name: 'B', slug: 'b')
    original = CrudComponents.config.select_limit
    CrudComponents.config.select_limit = 5
    assert_equal :select, CrudComponents::Fields::BelongsToField.new(:publisher, Book).filter_control
    CrudComponents.config.select_limit = 1
    assert_equal :text, CrudComponents::Fields::BelongsToField.new(:publisher, Book).filter_control
  ensure
    CrudComponents.config.select_limit = original
  end

  # ── reflection categories ──────────────────────────────────────────────────
  test 'polymorphic belongs_to: type column hidden, association non-filterable' do
    structure = structure_of(Comment)
    names = structure.default_field_names
    assert_includes names, :commentable
    refute_includes names, :commentable_id
    refute_includes names, :commentable_type
    field = structure.field(:commentable)
    assert_instance_of CrudComponents::Fields::BelongsToField, field
    refute field.filterable?
    refute field.editable?
  end

  test 'STI subclass inherits the base crud_structure' do
    assert_equal :title, structure_of(Manual).label_source
    assert_equal %i[title body], structure_of(Manual).fieldset(:index).field_names
  end
end

# frozen_string_literal: true

require 'test_helper'

# Every raising DSL combination — errors must arrive at structure build time
# (boot / first use) with a message that says what to do instead.
class DslValidationTest < ActiveSupport::TestCase
  test 'crud_structure declared twice raises immediately' do
    model = define_model
    model.crud_structure { label :title }
    error = assert_raises(CrudComponents::DefinitionError) do
      model.crud_structure { label :title }
    end
    assert_match(/already declared/, error.message)
    assert_match(/merge/, error.message)
  end

  test 'unknown field name without a render facet raises with guidance' do
    model = define_model { attribute :certainly_not_a_thing }
    error = assert_raises(CrudComponents::DefinitionError) { structure_of(model) }
    assert_match(/no column, enum, association or public method/, error.message)
    assert_match(/render facet/, error.message)
  end

  test 'a form fieldset that lists a field with no form control raises' do
    model = define_model do
      attribute(:display_title) { |book| book.title.to_s.upcase }
      fieldset :form, %i[title display_title]
    end
    error = assert_raises(CrudComponents::DefinitionError) { structure_of(model) }
    assert_match(/fieldset :form lists :display_title/, error.message)
    assert_match(/no form control/, error.message)
    assert_match(/Give it one with form_as:/, error.message)
  end

  test 'and form_as: is the way out of that' do
    model = define_model do
      attribute(:display_title, form_as: :string) { |book| book.title.to_s.upcase }
      fieldset :form, %i[title display_title]
    end

    assert structure_of(model)
  end

  test 'the same field is fine in a fieldset that is not a form' do
    model = define_model do
      attribute(:display_title) { |book| book.title.to_s.upcase }
      fieldset :index, %i[title display_title]
    end

    assert structure_of(model)
  end

  test 'the default fieldset may hold fields that no form can show' do
    model = define_model do
      attribute(:display_title) { |book| book.title.to_s.upcase }
      fieldset :default, %i[title display_title]
    end

    assert structure_of(model)
  end

  # define_model's block declares the structure, not the class body, so these
  # build the association themselves.
  def model_with(table:, &body)
    klass = Class.new(ApplicationRecord) do
      self.table_name = table
      include CrudComponents::Model

      define_singleton_method(:name) { 'NestedTempModel' }
    end
    klass.class_eval(&body)
    klass
  end

  test 'nested: without accepts_nested_attributes_for raises' do
    model = model_with(table: 'books') do
      belongs_to :publisher, optional: true
      crud_structure { attribute :publisher, nested: true }
    end
    error = assert_raises(CrudComponents::DefinitionError) { structure_of(model) }
    assert_match(/accepts_nested_attributes_for :publisher/, error.message)
    assert_match(/thrown away/, error.message)
  end

  test 'nested: on a collection without allow_destroy raises' do
    model = model_with(table: 'publishers') do
      has_many :books, dependent: :nullify
      accepts_nested_attributes_for :books
      crud_structure { attribute :books, nested: true }
    end
    error = assert_raises(CrudComponents::DefinitionError) { structure_of(model) }

    assert_match(/allow_destroy: true/, error.message)
    assert_match(/never removed/, error.message)
  end

  test 'nested: on a collection that allows removing is fine' do
    model = model_with(table: 'publishers') do
      has_many :books, dependent: :nullify
      accepts_nested_attributes_for :books, allow_destroy: true
      crud_structure { attribute :books, nested: true }
    end

    assert_instance_of CrudComponents::Fields::NestedCollectionField, structure_of(model).field(:books)
  end

  test 'nested: on something that is not an association raises' do
    model = define_model { attribute :title, nested: true }
    error = assert_raises(CrudComponents::DefinitionError) { structure_of(model) }
    assert_match(/needs an association/, error.message)
  end

  test 'attribute declared twice raises' do
    model = define_model do
      attribute :title
      attribute :title
    end
    error = assert_raises(CrudComponents::DefinitionError) { structure_of(model) }
    assert_match(/attribute :title declared twice/, error.message)
  end

  test 'reserved param names cannot be fields' do
    model = define_model { attribute :sort }
    error = assert_raises(CrudComponents::DefinitionError) { structure_of(model) }
    assert_match(/reserved param name/, error.message)
  end

  test 'label takes a method or a block, not both, not neither, not twice' do
    assert_raises(CrudComponents::DefinitionError) { structure_of(define_model { label(:title, &:title) }) }
    assert_raises(CrudComponents::DefinitionError) { structure_of(define_model { label }) }
    assert_raises(CrudComponents::DefinitionError) do
      structure_of(define_model do
        label :title
        label :subtitle
      end)
    end
  end

  test 'identify_by and search_in declared twice raise' do
    assert_raises(CrudComponents::DefinitionError) do
      structure_of(define_model do
        identify_by :slug
        identify_by :id
      end)
    end
    assert_raises(CrudComponents::DefinitionError) do
      structure_of(define_model do
        search_in :title
        search_in :subtitle
      end)
    end
  end

  test 'search_in takes a spec or a block, not both' do
    error = assert_raises(CrudComponents::DefinitionError) do
      structure_of(define_model { search_in(:title) { |scope, _q| scope } })
    end
    assert_match(/not both/, error.message)
  end

  test 'filter facet takes a spec, `false`, or a block — not a spec and a block' do
    error = assert_raises(CrudComponents::DefinitionError) do
      structure_of(define_model do
        attribute :title do
          filter(:title) { |scope, _value| scope }
        end
      end)
    end
    assert_match(/filter takes/, error.message)

    assert_raises(CrudComponents::DefinitionError) do
      structure_of(define_model { attribute(:title) { filter } })
    end
  end

  test 'sort facet rejects anything but false, a symbol or a block' do
    error = assert_raises(CrudComponents::DefinitionError) do
      structure_of(define_model { attribute(:title) { sort 'title' } })
    end
    assert_match(/own-column symbol/, error.message)
  end

  test 'render facet rejects positional arguments' do
    error = assert_raises(CrudComponents::DefinitionError) do
      structure_of(define_model { attribute(:title) { render :image } })
    end
    assert_match(/as: keyword/, error.message)
  end

  test 'unknown facet raises and lists the real ones' do
    error = assert_raises(CrudComponents::DefinitionError) do
      structure_of(define_model { attribute(:title) { badger } })
    end
    assert_match(/unknown facet 'badger'/, error.message)
    assert_match(/render, filter and sort/, error.message)
  end

  test 'facets declared twice raise' do
    assert_raises(CrudComponents::DefinitionError) do
      structure_of(define_model do
        attribute :title do
          render(&:title)
          render(&:title)
        end
      end)
    end
  end

  test 'attributes needs at least one name' do
    assert_raises(CrudComponents::DefinitionError) { structure_of(define_model { attributes }) }
  end

  test 'action declared twice and unknown action options raise' do
    assert_raises(CrudComponents::DefinitionError) do
      structure_of(define_model do
        action :go
        action :go
      end)
    end

    error = assert_raises(CrudComponents::DefinitionError) do
      structure_of(define_model { action :go, iconn: 'x' })
    end
    assert_match(/unknown option/, error.message)
  end

  test 'fieldset declared twice raises' do
    assert_raises(CrudComponents::DefinitionError) do
      structure_of(define_model do
        fieldset :index, %i[title]
        fieldset :index, %i[title]
      end)
    end
  end

  test 'fieldset referencing an unknown field raises' do
    model = define_model { fieldset :index, %i[title nope] }
    assert_raises(CrudComponents::DefinitionError) { structure_of(model) }
  end

  test 'fieldset referencing an unknown action raises with the available ones' do
    model = define_model { fieldset :index, %i[title], actions: %i[bogus] }
    error = assert_raises(CrudComponents::DefinitionError) { structure_of(model) }
    assert_match(/no action :bogus/, error.message)
    assert_match(/:edit/, error.message)
  end

  test 'fieldset filters: listing an unfilterable field raises with guidance' do
    model = define_model { fieldset :index, %i[title], filters: %i[metadata] }
    error = assert_raises(CrudComponents::DefinitionError) { structure_of(model) }
    assert_match(/not filterable/, error.message)
    assert_match(/filter facet/, error.message)
  end

  test 'rendering an unknown fieldset raises and lists the declared ones' do
    model = define_model { fieldset :catalog, %i[title] }
    error = assert_raises(CrudComponents::UnknownFieldsetError) { structure_of(model).fieldset(:catalogue) }
    assert_match(/:catalog/, error.message)
    assert_match(/:default/, error.message)
  end

  test 'as: :markdown without a markdown gem raises naming the gems' do
    # the playground bundles a real markdown gem, so point the renderer at gems
    # that are genuinely absent to exercise the "missing gem" raise.
    with_renderer_gems(markdown: %w[absent_md_gem_a absent_md_gem_b]) do
      model = define_model { attribute :blurb, as: :markdown }
      error = assert_raises(CrudComponents::DefinitionError) { structure_of(model) }
      assert_match(/absent_md_gem_a, absent_md_gem_b/, error.message)
    end
  end

  test 'like-spec delegation to a block-labelled target raises with a way out' do
    target = define_model(table: 'publishers', name: 'BlockLabelPublisher') do
      label { |publisher| publisher.name.upcase }
    end
    Object.const_set(:BlockLabelPublisher, target)

    model = Class.new(ApplicationRecord) do
      self.table_name = 'books'
      include CrudComponents::Model

      define_singleton_method(:name) { 'TempBookWithBlockTarget' }
      belongs_to :publisher, class_name: 'BlockLabelPublisher', optional: true
    end
    model.crud_structure { search_in :publisher }

    error = assert_raises(CrudComponents::DefinitionError) do
      CrudComponents::LikeSpec.apply(model.all, structure_of(model).search_in_spec, 'x')
    end
    assert_match(/custom block/, error.message)
    assert_match(/spell the columns out/, error.message)
  ensure
    Object.send(:remove_const, :BlockLabelPublisher) if Object.const_defined?(:BlockLabelPublisher)
  end

  test 'like-spec referencing nonsense raises' do
    model = define_model { attribute(:title) { filter :no_such_thing } }
    error = assert_raises(CrudComponents::DefinitionError) do
      structure_of(model).field(:title).apply_filter(model.all, value: 'x')
    end
    assert_match(/neither a column nor an association/, error.message)
  end

  # ── admin ────────────────────────────────────────────────────────────────
  test 'admin declared twice raises' do
    model = define_model do
      admin group: 'A'
      admin group: 'B'
    end
    error = assert_raises(CrudComponents::DefinitionError) { structure_of(model) }
    assert_match(/admin declared twice/, error.message)
  end

  test 'admin with a non-boolean raises' do
    model = define_model { admin :yes }
    error = assert_raises(CrudComponents::DefinitionError) { structure_of(model) }
    assert_match(/takes true or false/, error.message)
  end

  test 'admin false with options raises' do
    model = define_model { admin false, group: 'Catalog' }
    error = assert_raises(CrudComponents::DefinitionError) { structure_of(model) }
    assert_match(/takes no options/, error.message)
  end

  test 'admin with an unknown option raises' do
    model = define_model { admin sidebar: true }
    error = assert_raises(CrudComponents::DefinitionError) { structure_of(model) }
    assert_match(/unknown option/, error.message)
    assert_match(/:actions/, error.message)
  end

  test 'admin with a non-RESTful action raises' do
    model = define_model { admin actions: %i[index publish] }
    error = assert_raises(CrudComponents::DefinitionError) { structure_of(model) }
    assert_match(/:publish/, error.message)
    assert_match(/not RESTful actions/, error.message)
  end

  test 'app_path declared twice raises' do
    model = define_model do
      app_path { |book| "/a/#{book.id}" }
      app_path { |book| "/b/#{book.id}" }
    end
    error = assert_raises(CrudComponents::DefinitionError) { structure_of(model) }
    assert_match(/app_path declared twice/, error.message)
  end

  test 'action data: that is not a hash raises' do
    model = define_model { action(:preview, data: 'controller=preview') { '/preview' } }
    error = assert_raises(CrudComponents::DefinitionError) { structure_of(model) }
    assert_match(/data: takes a hash/, error.message)
    assert_match(/String/, error.message)
  end

  test 'app_path without a block raises' do
    model = define_model { app_path }
    error = assert_raises(CrudComponents::DefinitionError) { structure_of(model) }
    assert_match(/app_path requires a block/, error.message)
  end
end

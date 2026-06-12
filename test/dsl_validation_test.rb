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
    assert_raises(CrudComponents::DefinitionError) { structure_of(define_model { label(:title) { |r| r.title } }) }
    assert_raises(CrudComponents::DefinitionError) { structure_of(define_model { label }) }
    assert_raises(CrudComponents::DefinitionError) { structure_of(define_model { label :title; label :subtitle }) }
  end

  test 'identify_by and search_in declared twice raise' do
    assert_raises(CrudComponents::DefinitionError) { structure_of(define_model { identify_by :slug; identify_by :id }) }
    assert_raises(CrudComponents::DefinitionError) { structure_of(define_model { search_in :title; search_in :subtitle }) }
  end

  test 'search_in takes a spec or a block, not both' do
    error = assert_raises(CrudComponents::DefinitionError) do
      structure_of(define_model { search_in(:title) { |scope, q| scope } })
    end
    assert_match(/not both/, error.message)
  end

  test 'filter facet takes exactly one of false, like: or a block' do
    error = assert_raises(CrudComponents::DefinitionError) do
      structure_of(define_model do
        attribute :title do
          filter(like: :title) { |scope, value| scope }
        end
      end)
    end
    assert_match(/exactly one/, error.message)

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
          render { |r| r.title }
          render { |r| r.title }
        end
      end)
    end
  end

  test 'attributes needs at least one name' do
    assert_raises(CrudComponents::DefinitionError) { structure_of(define_model { attributes }) }
  end

  test 'action declared twice and unknown action options raise' do
    assert_raises(CrudComponents::DefinitionError) { structure_of(define_model { action :go; action :go }) }

    error = assert_raises(CrudComponents::DefinitionError) do
      structure_of(define_model { action :go, iconn: 'x' })
    end
    assert_match(/unknown option/, error.message)
  end

  test 'fieldset declared twice raises' do
    assert_raises(CrudComponents::DefinitionError) do
      structure_of(define_model { fieldset :index, %i[title]; fieldset :index, %i[title] })
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
    model = define_model { attribute :blurb, as: :markdown }
    error = assert_raises(CrudComponents::DefinitionError) { structure_of(model) }
    assert_match(/commonmarker|redcarpet|kramdown/, error.message)
  end

  test 'like-spec delegation to a block-based search_in raises with a way out' do
    target = define_model(table: 'publishers', name: 'BlockSearchPublisher') do
      search_in { |scope, q| scope }
    end
    Object.const_set(:BlockSearchPublisher, target)

    model = Class.new(ApplicationRecord) do
      self.table_name = 'books'
      include CrudComponents::Model
      define_singleton_method(:name) { 'TempBookWithBlockTarget' }
      belongs_to :publisher, class_name: 'BlockSearchPublisher', optional: true
    end
    model.crud_structure { search_in :publisher }

    error = assert_raises(CrudComponents::DefinitionError) do
      CrudComponents::LikeSpec.apply(model.all, structure_of(model).search_in_spec, 'x')
    end
    assert_match(/custom block/, error.message)
    assert_match(/spell the columns out/, error.message)
  ensure
    Object.send(:remove_const, :BlockSearchPublisher) if Object.const_defined?(:BlockSearchPublisher)
  end

  test 'like-spec referencing nonsense raises' do
    model = define_model { attribute(:title) { filter like: :no_such_thing } }
    error = assert_raises(CrudComponents::DefinitionError) do
      structure_of(model).field(:title).apply_filter(model.all, exact: 'x')
    end
    assert_match(/neither a column nor an association/, error.message)
  end
end

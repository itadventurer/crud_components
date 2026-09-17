# frozen_string_literal: true

require 'test_helper'

# has_many / habtm cells list only the records the ability may see, and
# "+n more" counts only those — one query per column, whatever the row count.
class ScopedAssociationCellsTest < ActiveSupport::TestCase
  include CrudTestHelpers

  class CellsController < ApplicationController
    helper_method :current_ability
    cattr_accessor :ability
    def current_ability = ability
  end

  def setup
    @dune = Book.create!(title: 'Dune', slug: 'dune-scoped')
    @emma = Book.create!(title: 'Emma', slug: 'emma-scoped')
    @public = %w[Ann Ben Cid Dee].map { |name| @dune.reviews.create!(reviewer_name: name, rating: 5) }
    @hidden = %w[Hal Ivy].map { |name| @dune.reviews.create!(reviewer_name: name, rating: 1) }
    @emma_review = @emma.reviews.create!(reviewer_name: 'Joe', rating: 4)
    CellsController.ability = CrudTestHelpers::ScopingAbility.new(@dune, @emma, *@public, @emma_review)
  end

  def teardown
    CellsController.ability = nil
  end

  def render(template, **assigns)
    CellsController.render(inline: template, assigns: assigns)
  end

  def table(records = Book.where(id: [@dune.id, @emma.id]).order(:id))
    render('<%= crud_collection(@books, fieldset: :catalog, actions: false) %>', books: records)
  end

  test 'a table lists and counts only the reviews the ability may see' do
    html = table

    assert_includes html, 'Ann on Dune'
    assert_not_includes html, 'Hal on Dune'
    assert_not_includes html, 'Ivy on Dune'
    assert_includes html, '+1 more' # four visible, three shown
    assert_not_includes html, '+3 more'
  end

  test 'a record view lists only the reviews the ability may see' do
    html = render('<%= crud_record(@book) %>', book: @dune)

    @public.each { |review| assert_includes html, "#{review.reviewer_name} on Dune" }
    assert_not_includes html, 'Hal on Dune'
  end

  test 'without an ability every review is listed as before' do
    CellsController.ability = nil

    assert_includes render('<%= crud_record(@book) %>', book: @dune), 'Hal on Dune'
    assert_includes table, '+3 more'
  end

  test 'scope_by_ability: false lists every review' do
    model = define_model
    model.has_many :reviews, foreign_key: :book_id, class_name: 'Review', inverse_of: false
    model.crud_structure { attribute :reviews, scope_by_ability: false }
    book = model.find(@dune.id)
    scope = CrudComponents::Presenters::AssociationScope.new(CellsController.ability, -> { [book] })

    assert_equal 6, scope.value(structure_of(model).field(:reviews), book).size
    assert_equal 4, scope.value(structure_of(Book).field(:reviews), @dune).size
  end

  test 'the reviews column costs one scoping query, whatever the row count' do
    more = Array.new(3) { |i| Book.create!(title: "Extra #{i}", slug: "extra-scoped-#{i}") }
    more.each { |book| book.reviews.create!(reviewer_name: 'Kim', rating: 1) }
    sql = []
    callback = ->(*, payload) { sql << payload[:sql] if payload[:sql].include?('"reviews"') }
    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { table(Book.order(:id)) }

    assert_equal 2, sql.size, sql.join("\n") # the preload, then the scoping query
  end
end

# The admin scopes the same cells by the ability it authorizes with.
class ScopedAssociationCellsAdminTest < ActionDispatch::IntegrationTest
  CONTROLLER = CrudComponents::Admin::ResourcesController

  def setup
    @book = Book.create!(title: 'Dune', slug: 'dune-admin-scoped')
    shown = @book.reviews.create!(reviewer_name: 'Ann', rating: 5)
    @book.reviews.create!(reviewer_name: 'Hal', rating: 1)
    ability = CrudTestHelpers::ScopingAbility.new(@book, shown)
    CONTROLLER.define_method(:current_ability) { ability }
  end

  def teardown
    CONTROLLER.remove_method(:current_ability)
  end

  test 'a book page in the admin lists only the reviews the ability may see' do
    get "/admin/books/#{@book.slug}"

    assert_response :success
    assert_includes response.body, 'Ann on Dune'
    assert_not_includes response.body, 'Hal on Dune'
  end
end

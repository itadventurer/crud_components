# frozen_string_literal: true

require 'test_helper'

# A route helper that exists is not yet a route to link to. The dummy app draws
# two traps: `resources :reviews, only: %i[create update destroy]` under books
# (book_review_path / book_reviews_path exist, but not for GET), and
# `resources :book_authors, only: :show` (book_author_path exists, but belongs
# to another resource and takes one argument).
class RouteResolverTest < ActionDispatch::IntegrationTest
  def setup
    @tolkien = Author.create!(name: 'J. R. R. Tolkien', email: 'jrr@example.com')
    @hobbit = Book.create!(title: 'The Hobbit', slug: 'hobbit', authors: [@tolkien])
    @reviews = Array.new(5) { |i| @hobbit.reviews.create!(rating: 3, reviewer_name: "R#{i}", body: 'x') }
  end

  def view
    @view ||= ApplicationController.new.tap { |c| c.request = ActionDispatch::TestRequest.create }.view_context
  end

  def helpers_for(routes)
    url_helpers = routes.url_helpers
    Class.new { include url_helpers }.new
  end

  def action(name, **) = CrudComponents::Action.new(name, derived: true, **)

  # ── in the app ─────────────────────────────────────────────────────────────
  test 'a record page links a review to its own page, not to the write-only nested route' do
    get book_path(@hobbit)

    assert_select "a[href='#{review_path(@reviews.first)}']"
    assert_select "a[href^='/books/hobbit/reviews']", count: 0
  end

  test '+n more skips a nested collection route that only accepts POST' do
    get books_path(view: 'catalog')

    assert_select "a[href*='/reviews?book=hobbit']", text: /\+\d+ more/
    assert_select "a[href='/books/hobbit/reviews']", count: 0
  end

  test "a book's author links to the author, not to another resource with a look-alike helper" do
    get book_path(@hobbit)

    assert_select "a[href='#{author_path(@tolkien)}']"
    assert_select "a[href^='/book_authors']", count: 0
  end

  # ── the resolver ───────────────────────────────────────────────────────────
  test 'record_path passes over nested helpers that do not fit' do
    assert_equal [review_path(@reviews.first), :show],
                 CrudComponents::RouteResolver.record_path(view, @reviews.first, owner: @hobbit)
    assert_equal [author_path(@tolkien), :show],
                 CrudComponents::RouteResolver.record_path(view, @tolkien, owner: @hobbit)
  end

  test 'a non-GET action still uses the nested route that serves its verb' do
    path = CrudComponents::RouteResolver.action_path(view, action(:destroy), record: @reviews.first, owner: @hobbit)

    assert_equal "/books/hobbit/reviews/#{@reviews.first.id}", path
  end

  test 'a GET action falls through to the flat route' do
    path = CrudComponents::RouteResolver.action_path(view, action(:edit), record: @reviews.first, owner: @hobbit)

    assert_equal edit_review_path(@reviews.first), path
  end

  test 'a member helper whose route only serves other verbs is skipped' do
    routes = ActionDispatch::Routing::RouteSet.new
    routes.draw do
      resources :books, only: %i[update destroy edit]
    end
    helpers = helpers_for(routes)

    assert_equal ["/books/#{@hobbit.to_param}/edit", :edit],
                 CrudComponents::RouteResolver.record_path(helpers, @hobbit)
    assert_equal "/books/#{@hobbit.to_param}",
                 CrudComponents::RouteResolver.action_path(helpers, action(:destroy), record: @hobbit)
  end

  test 'leading route segments filled by the url options still resolve' do
    routes = ActionDispatch::Routing::RouteSet.new
    routes.draw do
      scope ':locale' do
        resources :books, only: :show
      end
    end
    helpers = helpers_for(routes)
    helpers.define_singleton_method(:default_url_options) { { locale: 'de' } }

    assert_equal ["/de/books/#{@hobbit.to_param}", :show],
                 CrudComponents::RouteResolver.record_path(helpers, @hobbit)
  end
end

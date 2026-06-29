require 'test_helper'

# The present / absent filter for association and attachment columns (issue #32):
# a value match makes no sense there, but "has one / has none" does, and it has to
# compose into the query as an EXISTS / NOT EXISTS like any other filter.
class PresenceFilterTest < ActiveSupport::TestCase
  include CrudTestHelpers

  def setup
    @tor = Publisher.create!(name: 'Tor Books', slug: 'tor-books')
    @tolkien = Author.create!(name: 'J. R. R. Tolkien', email: 'jrr@example.com')

    # cover + a review + an author — the "present" row on every flavor.
    @full = Book.create!(title: 'The Hobbit', slug: 'hobbit', genre: :fiction,
                         publisher: @tor, authors: [@tolkien])
    @full.cover.attach(io: StringIO.new('img'), filename: 'cover.png', content_type: 'image/png')
    @full.reviews.create!(reviewer_name: 'Ed', rating: 5)

    # nothing attached, no reviews, no authors — the "absent" row.
    @bare = Book.create!(title: 'Galley Proof', slug: 'galley', genre: :nonfiction)
  end

  def field(name) = structure_of(Book).field(name)

  def filtered(field_name, value, fieldset: :catalog)
    CrudComponents::Query.new(Book, { field_name.to_s => value }, fieldset: fieldset).apply(Book.all)
  end

  # ── has_one_attached (Book#cover), end to end through the query ─────────────
  test 'has_one_attached renders the presence control' do
    assert_equal :presence, field(:cover).filter_control
    assert field(:cover).filterable?
  end

  test 'has_one_attached present keeps only attached rows, absent only the rest' do
    assert_equal [@full],  filtered(:cover, 'present').to_a
    assert_equal [@bare],  filtered(:cover, 'absent').to_a
  end

  test 'a blank or unknown presence value is inert (the "any" choice)' do
    assert_equal 2, filtered(:cover, '').count
    assert_equal 2, filtered(:cover, 'bogus').count
  end

  # ── has_many (Book#reviews) ────────────────────────────────────────────────
  test 'has_many filters by presence out of the box' do
    assert_equal :presence, field(:reviews).filter_control
    assert_equal [@full], filtered(:reviews, 'present').to_a
    assert_equal [@bare], filtered(:reviews, 'absent').to_a
  end

  test 'an explicit filter facet still wins over the derived presence control' do
    # author_names declares `filter authors: :name` — a value match, not presence.
    assert_equal :text, field(:author_names).filter_control
  end

  # ── habtm (Book#authors) ───────────────────────────────────────────────────
  test 'habtm filters by presence' do
    authors = field(:authors)
    assert_equal :presence, authors.filter_control
    assert_equal [@full], authors.apply_filter(Book.all, value: 'present').to_a
    assert_equal [@bare], authors.apply_filter(Book.all, value: 'absent').to_a
  end

  # ── has_many_attached (Author#images), no CrudComponents config at all ──────
  test 'has_many_attached joins through the *_attachments reflection' do
    images = structure_of(Author).field(:images)
    assert_equal :presence, images.filter_control
    assert_equal :images_attachments, images.presence_association

    @tolkien.images.attach(io: StringIO.new('photo'), filename: 'jrr.png', content_type: 'image/png')
    bare_author = Author.create!(name: 'Anon', email: 'anon@example.com')

    present = images.apply_filter(Author.all, value: 'present')
    assert_equal [@tolkien], present.to_a
    refute_includes images.apply_filter(Author.all, value: 'absent').to_a, @tolkien
    assert_includes images.apply_filter(Author.all, value: 'absent').to_a, bare_author
  end

  # ── plain has_one ──────────────────────────────────────────────────────────
  # No dummy model declares one, so build a throwaway: a Book viewed as having
  # one Review (its book_id FK already exists). has_one has no value to match, so
  # it gets the presence control rather than the belongs_to value picker.
  test 'a plain has_one filters by presence' do
    model = Class.new(ApplicationRecord) do
      self.table_name = 'books'
      include CrudComponents::Model
      has_one :a_review, class_name: 'Review', foreign_key: :book_id
      def self.name = 'BookWithReview'
    end
    review = structure_of(model).field(:a_review)

    assert review.filterable?
    assert_equal :presence, review.filter_control
    assert_equal [@full.id], review.apply_filter(model.all, value: 'present').pluck(:id)
    refute_includes review.apply_filter(model.all, value: 'absent').pluck(:id), @full.id
  end

  # ── a belongs_to keeps its value filter (no regression) ────────────────────
  test 'belongs_to still filters by value, not presence' do
    refute_equal :presence, field(:publisher).filter_control
    assert_equal [@full], filtered(:publisher, @tor.slug).to_a
  end
end

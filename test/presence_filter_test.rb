require 'test_helper'

# The present / absent filter for Active Storage attachment columns (issue #32):
# an attachment has no value to match, but "has one / has none" does, and it has
# to compose into the query as an EXISTS / NOT EXISTS like any other filter. Other
# association flavors keep their standard behavior (a belongs_to value filter; no
# derived filter on has_many until a `filter` facet opts in) — asserted below.
class PresenceFilterTest < ActiveSupport::TestCase
  include CrudTestHelpers

  def setup
    @tor = Publisher.create!(name: 'Tor Books', slug: 'tor-books')

    @with_cover = Book.create!(title: 'The Hobbit', slug: 'hobbit', genre: :fiction, publisher: @tor)
    @with_cover.cover.attach(io: StringIO.new('img'), filename: 'cover.png', content_type: 'image/png')

    @no_cover = Book.create!(title: 'Galley Proof', slug: 'galley', genre: :nonfiction)
  end

  def field(name) = structure_of(Book).field(name)

  def filtered(field_name, value, fieldset: :catalog)
    CrudComponents::Query.new(Book, { field_name.to_s => value }, fieldset: fieldset).apply(Book.all)
  end

  # ── has_one_attached (Book#cover), end to end through the query ─────────────
  test 'has_one_attached renders the presence control' do
    assert field(:cover).filterable?
    assert_equal :presence, field(:cover).filter_control
  end

  test 'has_one_attached present keeps only attached rows, absent only the rest' do
    assert_equal [@with_cover], filtered(:cover, 'present').to_a
    assert_equal [@no_cover],   filtered(:cover, 'absent').to_a
  end

  test 'a blank or unknown presence value is inert (the "any" choice)' do
    assert_equal 2, filtered(:cover, '').count
    assert_equal 2, filtered(:cover, 'bogus').count
  end

  # ── has_many_attached (Author#images), no CrudComponents config at all ──────
  test 'has_many_attached joins through the *_attachments reflection' do
    images = structure_of(Author).field(:images)
    assert_equal :presence, images.filter_control

    tolkien = Author.create!(name: 'J. R. R. Tolkien', email: 'jrr@example.com')
    tolkien.images.attach(io: StringIO.new('photo'), filename: 'jrr.png', content_type: 'image/png')
    bare = Author.create!(name: 'Anon', email: 'anon@example.com')

    assert_equal [tolkien], images.apply_filter(Author.all, value: 'present').to_a
    present_absent = images.apply_filter(Author.all, value: 'absent').to_a
    assert_includes present_absent, bare
    refute_includes present_absent, tolkien
  end

  # ── non-attachment associations keep their standard behavior ───────────────
  test 'belongs_to still filters by value, not presence' do
    refute_equal :presence, field(:publisher).filter_control
    assert_equal [@with_cover], filtered(:publisher, @tor.slug).to_a
  end

  test 'has_many has no derived filter (opt-in via a filter facet, unchanged)' do
    refute field(:reviews).filterable?
  end
end

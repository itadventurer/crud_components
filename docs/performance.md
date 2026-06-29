# Performance

The gem keeps derived surfaces cheap by default and hands you the controls for the cases
config can't guess.

## On by default

- **No N+1 from derived columns.** Associations of visible fields (`belongs_to` *and*
  `has_many`/habtm, plus Active Storage attachments) are eager-loaded for the rendered set.
  When a `label` or `render` block reaches *further* into associations, declare those deps
  once — see [Eager-loading render dependencies](#eager-loading-render-dependencies).
- **Fast cells** — built-in cell types are rendered inline, not a partial per cell — see
  [Fast cell rendering](#fast-cell-rendering).
- **belongs_to filters degrade gracefully.** A belongs_to filter renders a `<select>` of
  the target's records up to `config.select_limit` (default 250); beyond that it switches
  to a text input over the target's `label`, so a 50k-row association never builds a
  giant `<select>`. (A typeahead/autocomplete is a later version.)
- **Long text truncates** in collections — the full value renders on the record page.

## Eager-loading render dependencies

*Advanced.* Visible association and attachment columns are eager-loaded automatically.
The cases the gem **can't** infer are a custom `label` or `render` block that reaches
*further* into associations (the classic source of a per-row query). Declare those once
and they compose into the collection's `includes` — declare where the dependency lives,
and it's correct everywhere that thing is shown:

```ruby
class Review < ApplicationRecord
  include CrudComponents::Model
  crud_structure do
    # this label reaches :book — eager-loaded whenever a Review is shown as another
    # model's association column (e.g. a Book's reviews list):
    label(preload: %i[book]) { |review| "#{review.reviewer_name} on #{review.book.title}" }

    # the `book` column, re-titled for this context, reaches :publisher → nested:
    attribute :book, label: ->(book) { "#{book.title} (#{book.publisher.name})" }, preload: %i[publisher]
  end
end

class Book < ApplicationRecord
  include CrudComponents::Model
  crud_structure do
    # a render block reaching associations on *this* model → top-level:
    attribute :author_names, preload: %i[authors] do
      render { |book| book.authors.map(&:name).to_sentence }
    end
    # …or model-level and standalone (additive with `label …, preload:`):
    preload :publisher
  end
end
```

How it composes: an **association column** nests the target's declared preloads — a Book's
`reviews` column becomes `includes(reviews: %i[book])` because `Review` declared
`label … preload: %i[book]`; the re-titled `book` column above becomes
`includes(book: %i[publisher])`. A `preload:` on a **non-association** column loads
top-level. There's nothing to wire at the call site — the gem adds these to whatever scope
you render, so `crud_collection @books` is already N+1-free.

## Pagination (you bring it)

The gem **never paginates on its own** — no surprise row limits, no records silently
dropped. Rendering a 50k-row table unbounded is the documented footgun; bound it yourself:

- Pass a paginated relation and the gem renders a footer pager automatically when it
  detects one (kaminari / will_paginate, which decorate the relation):

  ```ruby
  @query = CrudComponents::Query.new(Book, params, ability: current_ability)
  @books = @query.apply(Book.accessible_by(current_ability)).page(params[:page])  # kaminari
  ```
  ```erb
  <%= crud_collection @books, query: @query %>
  ```

- Or pass any bounded scope. See [Views → the manual query](views.md#the-manual-query-pagination-and-big-tables)
  for the full story (including pagy, whose state lives off the relation, so you render its
  nav yourself).

## Big associations in forms

The derived habtm/has_many input is a `<select multiple>` (optionally enhanced by the
`crud-multiselect` controller). It loads every option client-side — fine up to a few
hundred. For thousands of options, don't render them all: override that one field's form
input with `form_as:` and a [custom partial](forms.md#customising-an-input) that talks to
your own autocomplete endpoint. Same for a huge belongs_to select — point it at a
server-backed picker.

See also: [Security](security.md) · [Views](views.md) · [Forms](forms.md).

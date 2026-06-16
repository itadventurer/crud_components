# Performance

The gem keeps derived surfaces cheap by default and hands you the controls for the cases
config can't guess.

## On by default

- **No N+1 from derived columns.** Associations of visible fields (`belongs_to` *and*
  `has_many`/habtm, plus Active Storage attachments) are eager-loaded for the rendered set.
- **belongs_to filters degrade gracefully.** A belongs_to filter renders a `<select>` of
  the target's records up to `config.select_limit` (default 250); beyond that it switches
  to a text input over the target's `search_in`, so a 50k-row association never builds a
  giant `<select>`. (A typeahead/autocomplete is a later version.)
- **Long text truncates** in collections — the full value renders on the record page.

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

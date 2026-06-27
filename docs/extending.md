# Extending & styling

The gem ships **no CSS** but is designed for **Bootstrap 5 by default**, and is built to
drop into an app that has its own design — even one on a CSS framework that works nothing
like Bootstrap. The class map and the partials cover overrides: swap cosmetic classes in
the map, override individual partials where the structure differs. For a whole different
framework, PRs are welcome — open an issue to talk it through first. Two facts make that
practical:

1. **Everything visual is a partial**, and a file at the same path in your app wins
   (standard Rails view-path precedence — the same mechanism as Devise or Kaminari
   views). That one rule is the entire extension API.
2. **The surfaces are decomposed**, so overriding one piece doesn't mean reimplementing
   the others — you reuse the presenter and the sub-partials.

## How far do you need to go?

| You want to…                                                    | Do this                                                | Reach for                                  |
| --------------------------------------------------------------- | ------------------------------------------------------ | ------------------------------------------ |
| tweak colours / button styles                                   | change CSS class names                                 | the [class map](#styling)                  |
| restructure **one** surface (different table markup, your grid) | override **one** partial                               | `rails g crud_components:views`, then edit |
| add a whole new arrangement (cards, list, kanban)               | add a layout partial                                   | [Add a layout](#add-a-layout)              |
| change a single field's display rendering                       | add a renderer partial                                 | [renderers](#add-a-field-renderer)         |
| move to a different CSS framework                               | override the partials (class map covers the easy bits) | this whole doc                             |

The class map is the *simplest* lever and deliberately covers only the common, cosmetic
cases — colours, sizes, button variants. It is **not** a full theming engine: structural
and utility classes (`d-flex`, `input-group`, `form-check`, `table-responsive`) live in
the partials, because pretending every framework shares Bootstrap's class vocabulary
would be a leaky abstraction. For a framework that works differently, you override the
relevant partials — and because they're small and decomposed, that stays cheap.
**When in doubt, copy the whole partial and rewrite it; that is a supported, first-class
path, not a failure.**

```sh
bin/rails generate crud_components:views   # copy the gem's partials into your app to edit
```

```
crud_components/
  layouts/_table.html.erb          # collection layouts (layout: :table, …)
  _toolbar.html.erb                # search box + reset + collection actions (reused by layouts)
  _pager.html.erb                  # footer pager in the table (shown when the relation is paginated)
  _actions.html.erb                # a group of action buttons
  fields/_string.html.erb …        # value renderers (as: :string, …)
  filters/_text.html.erb …         # filter controls
  _record.html.erb
  _filter.html.erb
  _form.html.erb                   # _form renders via simple_form
```

## Overriding one surface without rewriting the rest

Say you want a completely different collection table — your own `<table>` markup, your
framework's classes. Override `crud_components/layouts/_table.html.erb` and rewrite the
shell only. You do **not** reimplement search, filtering, sorting, cells or actions —
the `collection` presenter and the sub-partials hand them to you:

```erb
<%# your app/views/crud_components/layouts/_table.html.erb %>
<%= render 'crud_components/toolbar', collection: collection %>   <%# search + actions %>
<table class="my-table">
  <thead><tr>
    <% collection.fields.each do |field| %>
      <th>
        <% if collection.sortable_field?(field) %>
          <a href="<%= collection.sort_url(field) %>">
            <%= field.human_name %>
            <%# sort_direction is :asc / :desc / nil (nil = not the active column).
                sort_numeric? picks a numeric vs alphabetic icon; css.icon_prefix is
                the library prefix. %>
            <% if (dir = collection.sort_direction(field)) %>
              <% family = collection.sort_numeric?(field) ? 'sort-numeric' : 'sort-alpha' %>
              <i class="<%= collection.css.icon_prefix %><%= family %>-<%= dir == :desc ? 'up' : 'down' %>"></i>
            <% else %>
              <i class="<%= collection.css.icon_prefix %>arrow-down-up text-muted opacity-25"></i>
            <% end %>
          </a>
        <% else %>
          <%= field.human_name %>
        <% end %>
      </th>
    <% end %>
  </tr></thead>
  <tbody>
    <% collection.records.each do |record| %>
      <tr id="<%= dom_id(record) %>">
        <% collection.fields.each do |field| %>
          <td><%= collection.cell(field, record) %></td>   <%# type-aware cell, links, click-to-filter %>
        <% end %>
        <td><%= render 'crud_components/actions', actions: collection.row_actions(record) %></td>
      </tr>
    <% end %>
  </tbody>
</table>
```

The reusable building blocks the `collection` presenter exposes:

| Method                                   | Returns                                                                                       |
| ---------------------------------------- | --------------------------------------------------------------------------------------------- |
| `fields`                                 | the permitted fields (columns) to show, in order                                              |
| `records`                                | the resolved, filtered, sorted rows (an array)                                                |
| `cell(field, record)`                    | the type-aware cell HTML — value renderer, label link, click-to-filter                        |
| `sortable_field?(field)`                 | boolean: is this column sortable                                                              |
| `sort_url(field)`                        | the link that toggles/sets this column's sort                                                 |
| `sort_active?(field)`                    | boolean: is the result currently sorted by this column                                        |
| `sort_direction(field)`                  | `:asc` / `:desc`, or `nil` when not the active sort column — turn it into a glyph yourself    |
| `sort_numeric?(field)`                   | boolean: does this column sort numerically (vs alphabetically) — pick a numeric vs alpha icon |
| `filterable_field?(field)`               | boolean: does this column have a filter control                                               |
| `render_filter_control(field, query, …)` | the inline filter control HTML for a field                                                    |
| `row_actions(record)`                    | an `Actions` presenter for one row — feed to `_actions`                                       |
| `collection_actions`                     | an `Actions` presenter for collection-level actions (e.g. "New")                              |
| `searchable?`                            | boolean: is there a free-text search (`?q=`)                                                  |
| `search_param_name`                      | the query-param name for the search box (respects `param_prefix:`)                            |
| `filtered?`                              | boolean: is any filter/search/sort currently active                                           |
| `reset_url`                              | URL that clears *this* collection's filter/search/sort/page params                            |
| `filter_form_id`                         | the id of the external `<form>` the inline filter inputs bind to                              |
| `preserved_params`                       | params to re-emit as hidden inputs so the filter form keeps unrelated state                   |
| `paginated?`                             | boolean: was the relation handed in already `.page`-d (kaminari/will_paginate)                |
| `page_scope`                             | the underlying (possibly paginated) relation, for driving your own pager                      |
| `page_url(n)`                            | a URL for page `n` that keeps this collection's state and others' params                      |
| `pager_pages(window:)`                   | page numbers to render, with `:gap` markers for elided ranges                                 |

For pagination, either render the gem's `_pager` sub-partial, or feed `page_scope` (the underlying relation) to your own pager — e.g. `<%= paginate collection.page_scope %>` for kaminari (you style its markup, as always with kaminari). Sub-partials you can drop in: `_toolbar`, `_pager`, `_actions`. Filtering and the whitelist are never reimplemented in a layout — the presenter has already done that.

## Add a field renderer

A renderer named `:stars` is the partial `crud_components/fields/_stars.html.erb`. It
receives `value`, `record`, `field`, `surface` (`:collection` or `:record`), and
`cell_context` (for click-to-filter; nil on surfaces without a query):

```erb
<%# app/views/crud_components/fields/_stars.html.erb %>
<span title="<%= value %>/5"><%= '★' * value.to_i %><%= '☆' * (5 - value.to_i) %></span>
```

```ruby
attribute :rating, as: :stars
```

`surface:` is how the built-in `:text` truncates in tables but not on record pages, and
`:image` sizes itself. Built-in renderers are the same kind of partial at the same paths —
**shadow one in your app to change it everywhere.**

## Form inputs

Each input renders through a per-type partial,
`crud_components/form_fields/_<type>.html.erb`: **the partial decides *what* to render
(which `f.input`, its collection, blank options, …) and simple_form does the rest** (the
wrapper, label, hint and error markup, following your app's simple_form config). See
[Forms and your design system](#forms-and-your-design-system).

Two ways to customize:

* **Restyle a whole type** — shadow the partial, e.g. `form_fields/_enum.html.erb`, and it
  changes everywhere that type appears.
* **Point one field at a different partial** — `attribute :slug, form_as: :string` renders
  `slug` through `form_fields/_string.html.erb` (this mirrors `as:` for the display
  renderer). There is no `form` facet.

To take over form rendering entirely, override `crud_components/_form.html.erb`.

## Add a layout

A layout named `:cards` is the partial `crud_components/layouts/_cards.html.erb`,
receiving one `collection` presenter with resolved fields, rows, query state and sort
URLs — a custom layout never reimplements filtering or whitelisting:

```erb
<%= crud_collection @books, layout: :cards %>
```

![A custom cards layout: the same collection presenter rendered as a responsive card grid (cover image pulled out, fields below), reusing the gem's search, filter sidebar and row actions](screenshots/cards.png)

A layout calls the same presenter interface [listed above](#overriding-one-surface-without-rewriting-the-rest)
— `fields`, `records`, `cell`, the sort/filter/action helpers, the pagination helpers — so
the built-in `_table` is a good starting point; copy it. For a worked example that pulls
an image field out as a card image, see the dummy app's
[`_cards.html.erb`](https://github.com/itadventurer/crud_components/blob/main/test/dummy/app/views/crud_components/layouts/_cards.html.erb).

## Progressive enhancement

The progressive-enhancement story is deliberately **one mechanism, not a fork**: the
markup is *always* the plain, accessible, no-JS baseline, and JavaScript enhances that
same markup in place via Stimulus controllers attached with `data-controller`. There are
**no** parallel "raw" vs. "fancy" template trees to keep in sync, and Bootstrap-vs-other
lives in the [class map](#styling), not in template variants. A controller that isn't
loaded simply leaves the baseline as-is.

The gem ships **four** optional controllers, copied in by the install generator (you
register them with Stimulus; the gem depends on none):

```sh
bin/rails generate crud_components:install
# initializer + crud-filter + crud-multiselect + crud-columns + crud-select
```

- **`crud-filter`** strips empty params on submit (clean URLs) and auto-submits selects in
  the inline filter row only (the standalone filter form never auto-submits — users
  compose several filters there).
- **`crud-multiselect`** turns a habtm `<select multiple>` into a chips-list (each removable)
  + an "add" dropdown. The select stays the hidden source of truth, so the form submits
  identically with or without JS. Good up to a few hundred options; for thousands, render
  an autocomplete against your own endpoint instead (see [forms.md](forms.md)).
- **`crud-columns`** lets the user drag the column-picker rows to reorder, and collapses
  the submitted `?cols[]=a&cols[]=b` into a tidier `?cols=a,b`. Without it the picker still
  works (tick + Apply is a plain GET); you just lose drag-reorder and the prettier URL.
- **`crud-select`** adds a "select all visible" / per-group master checkbox and a live
  "N selected" count to selectable tables (bulk/selection actions). Without it the row
  checkboxes still submit; you just tick them individually.

Each follows the same recipe, which is the whole pattern for any enhancement (a belongs_to
text input into an autocomplete, a date field into a range picker, …):

1. The gem's partial renders the accessible baseline and, where useful, carries a
   `data-controller` hook.
2. Your Stimulus controller reads that markup and enhances it in place, manipulating the
   underlying inputs so form submission is unchanged with or without JS.
3. Ship the controller however you ship Stimulus (importmap pin, `app/javascript`, …).

## Styling

The gem ships **no CSS** and produces markup meant to look native in the host app —
Bootstrap 5 class names by default, concentrated in one overridable class map for the
common cosmetic cases:

```ruby
# config/initializers/crud_components.rb  (created by `rails g crud_components:install`)
CrudComponents.configure do |config|
  config.css.table  = 'table table-sm table-hover'
  config.css.button = 'btn btn-outline-dark'
  config.css.badge  = 'badge text-bg-secondary'
  config.select_limit = 250    # belongs_to filter: select → text input threshold
end
```

The full key list is `CrudComponents::Config::DEFAULT_CSS`. Each key feeds the `class="…"`
of one kind of element (table, button, badge, inputs, the toolbar, the filter row, …).

**Scope, honestly.** The class map is the *simplest* lever, not a theming engine. It
covers the elements whose class is a single configurable value. It does **not** abstract
away structure — utility classes like `d-flex`, `input-group`, `form-check` and
`table-responsive` live in the partials, because a class map that tried to model every
framework's layout primitives would be a leaky abstraction that helps no one.

Icons are rendered as `<i class="#{css.icon_prefix}#{name}">` — **Bootstrap Icons by
default** (`config.css.icon_prefix = 'bi bi-'`). Switch icon libraries by setting the
prefix, e.g. `config.css.icon_prefix = 'fa fa-'` for Font Awesome (the built-in icon
*names* are Bootstrap Icons, so a different library may need its own names — see below).

The icon **names** (the part after the prefix) live in two maps, so a different library is
a config change rather than a partial override:

```ruby
config.action_icons[:destroy] = 'trash-fill'   # per derived action; nil = no icon
config.file_icons['zip'] = 'file-earmark-zip'   # attachment glyph by file extension
config.file_fallback_icon = 'file-earmark-text' # extension not in the map
```

`config.action_icons` keys are the derived actions (`:new`/`:show`/`:edit`/`:destroy`);
`config.file_icons` maps a file extension to a full icon name (the whole Bootstrap
`filetype-*` family ships by default). Full lists: `Config::DEFAULT_ACTION_ICONS` /
`Config::DEFAULT_FILE_ICONS`.

So the real cost of a different framework is: **swap the class map for the cosmetic
classes, and override the few partials whose structure differs.** For a utility-first
framework like Tailwind (no semantic class names at all), you put the utility strings in
the map and override the structural partials:

```ruby
config.css.button     = 'inline-flex items-center rounded px-3 py-1.5 bg-gray-100 hover:bg-gray-200'
config.css.input      = 'block w-full rounded border-gray-300'
config.css.toolbar    = 'flex items-center justify-between gap-2 mb-2'
config.css.badge      = 'inline-flex rounded-full bg-gray-100 px-2 text-xs'
# …then `rails g crud_components:views` and adjust _form / _toolbar / the filter
#   controls where the *structure* (not just the class) needs to change.
```

This is the intended path, not a fork: you keep all the derivation, the query layer and
the presenters; you rewrite only the markup that your framework shapes differently.

## Forms and your design system

Forms are the **one** surface you mostly don't have to reskin by hand: they render through
[simple_form](https://github.com/heartcombo/simple_form), so they inherit your app's
simple_form wrapper config automatically — Bootstrap by default, and the community ships
Tailwind/Bulma/Foundation wrappers. Configure simple_form for your framework (its install
generator does this) and the gem's forms follow, including per-field error display (so
there's no `field_with_errors` wart to neutralize). The gem still derives *which* fields,
their types, the [permit list](forms.md) and the read-only/permission rules; simple_form
owns the markup.

Need to go further than wrappers allow? Override a per-type partial under
`crud_components/form_fields/` (see [Form inputs](#form-inputs)), or override
`crud_components/_form.html.erb` itself and render the fields however you like — the
`form` presenter hands you `fields`, `editable?(field)`, `form_options`, `summary_errors`
and `display(field)`, and each `field` knows its own `form_partial`.

## i18n

Headers come from `human_attribute_name` (computed fields included), so your existing
ActiveRecord i18n applies. Every gem-generated string is looked up with a
`t(..., default:)` fallback, so the gem works with **zero** locale setup and is fully
translatable when you want it. Relevant keys live under `crud_components.*` (actions,
filter labels, "+n more", confirm dialogs, empty state).

See also: [Views](views.md) · [Fields](fields.md) · [Forms](forms.md).

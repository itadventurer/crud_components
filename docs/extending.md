# Extending & styling

The gem ships **no CSS** and is built to drop into an app that has its own design — even
one on a CSS framework that works nothing like Bootstrap. Two facts make that practical:

1. **Everything visual is a partial**, and a file at the same path in your app wins
   (standard Rails view-path precedence — the same mechanism as Devise or Kaminari
   views). That one rule is the entire extension API; there are no registries.
2. **The surfaces are decomposed**, so overriding one piece doesn't mean reimplementing
   the others — you reuse the presenter and the sub-partials.

## How far do you need to go?

| You want to… | Do this | Reach for |
| --- | --- | --- |
| tweak colours / button styles | change CSS class names | the [class map](#styling) |
| restructure **one** surface (different table markup, your grid) | override **one** partial | `rails g crud_components:views`, then edit |
| add a whole new arrangement (cards, list, kanban) | add a layout partial | [Add a layout](#add-a-layout) |
| change a single field's display rendering | add a renderer partial | [renderers](#add-a-field-renderer) |
| move to a different CSS framework | override the partials (class map covers the easy bits) | this whole doc |

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
  layouts/_table.html.erb          # collection layouts (as: :table, …)
  _toolbar.html.erb                # search box + reset + collection actions (reused by layouts)
  _pager.html.erb                  # footer pager (shown when the relation is paginated)
  _actions.html.erb                # a group of action buttons
  fields/_string.html.erb …        # value renderers (as: :string, …)
  filters/_text.html.erb …         # filter controls
  _record.html.erb _filter.html.erb _form.html.erb   # _form renders via simple_form
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
          <a href="<%= collection.sort_url(field) %>"><%= field.human_name %><%= collection.sort_indicator(field) %></a>
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

The reusable building blocks the `collection` presenter exposes: `fields`, `records`,
`cell(field, record)`, `sortable_field?` / `sort_url` / `sort_indicator`,
`filterable_field?` / `render_filter_control(field, query, …)`, `row_actions(record)`,
`collection_actions`, `searchable?` / `search_param_name`, `filtered?` / `reset_url`,
`filter_form_id` / `preserved_params`. Sub-partials you can drop in: `_toolbar`,
`_actions`. Filtering and the whitelist are never reimplemented in a layout — the
presenter has already done that.

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

Form inputs are simple_form's job, not a per-control partial — see
[Forms and your design system](#forms-and-your-design-system). The flavor → simple_form
mapping lives in `Presenters::Form#simple_input`; to change it, override
`crud_components/_form.html.erb`.

## Add a layout

A layout named `:cards` is the partial `crud_components/layouts/_cards.html.erb`,
receiving one `collection` presenter with resolved fields, rows, query state and sort
URLs — a custom layout never reimplements filtering or whitelisting:

```erb
<%= crud_collection @books, as: :cards %>
```

The presenter's interface (the methods a layout calls — `fields`, `records`,
`cell(field, record)`, `sortable_field?`, `sort_url`, `filterable?`,
`render_filter_control`, `row_actions`, `collection_actions`, `searchable?`,
`reset_url`, …) is what the built-in `_table` uses; copy it as a starting point. See the
dummy app's `_cards.html.erb` for a worked example that pulls an image field out as a
card image.

## Progressive enhancement

The progressive-enhancement story is deliberately **one mechanism, not a fork**: the
markup is *always* the plain, accessible, no-JS baseline, and JavaScript enhances that
same markup in place via Stimulus controllers attached with `data-controller`. There are
**no** parallel "raw" vs. "fancy" template trees to keep in sync, and Bootstrap-vs-other
lives in the [class map](#styling), not in template variants. A controller that isn't
loaded simply leaves the baseline as-is.

The gem ships **two** optional controllers, copied in by the install generator (you
register them with Stimulus; the gem depends on neither):

```sh
bin/rails generate crud_components:install   # initializer + crud-filter + crud-tokens
```

- **`crud-filter`** strips empty params on submit (clean URLs) and auto-submits selects in
  the inline filter row only (the standalone filter form never auto-submits — users
  compose several filters there).
- **`crud-tokens`** turns a habtm `<select multiple>` into a chips-list (each removable)
  + an "add" dropdown. The select stays the hidden source of truth, so the form submits
  identically with or without JS. Good up to a few hundred options; for thousands, render
  an autocomplete against your own endpoint instead (see [forms.md](forms.md)).

Both follow the same recipe, which is the whole pattern for any enhancement (a belongs_to
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
framework's layout primitives would be a leaky abstraction that helps no one. Icons are
rendered as `<i class="bi bi-…">` in `_actions.html.erb`; a different icon set means
overriding that one partial.

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

Need to go further than wrappers allow? `crud_components/_form.html.erb` is a partial —
override it and render the fields however you like (the `form` presenter hands you
`fields`, `editable?`, `simple_input(f, field)`, `summary_errors`, `display`).

## i18n

Headers come from `human_attribute_name` (computed fields included), so your existing
ActiveRecord i18n applies. Every gem-generated string is looked up with a
`t(..., default:)` fallback, so the gem works with **zero** locale setup and is fully
translatable when you want it. Relevant keys live under `crud_components.*` (actions,
filter labels, "+n more", confirm dialogs, empty state).

See also: [Views](views.md) · [Fields](fields.md) · [Forms](forms.md).

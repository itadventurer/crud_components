# Extending & styling

Everything visual is a partial, and a file at the same path in your app wins (standard
Rails view-path precedence — the same mechanism as Devise or Kaminari views). **That one
rule is the entire extension API. There are no registries.**

```sh
bin/rails generate crud_components:views   # copy the gem's partials into your app to edit
```

The partials live under `app/views/crud_components/`:

```
crud_components/
  layouts/_table.html.erb          # collection layouts (as: :table, …)
  fields/_string.html.erb …        # value renderers (as: :string, …)
  filters/_text.html.erb …         # filter controls
  forms/_string.html.erb …         # form inputs
  _record.html.erb _filter.html.erb _actions.html.erb _form.html.erb
```

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

## Add a form input

Form inputs work identically: `crud_components/forms/_<control>.html.erb`, receiving the
form builder `f`, the `field`, and the `form` presenter. Map a field to a control with
`as:` on the attribute, or override an existing control by shadowing its partial.

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

The gem ships **one** optional controller, copied in by the install generator:

```sh
bin/rails generate crud_components:install   # initializer + the crud-filter controller
```

`crud-filter` strips empty params on submit (clean URLs) and auto-submits selects in the
inline filter row only (the standalone filter form never auto-submits — users compose
several filters there).

Richer widgets follow the same pattern. The dummy app ships a worked example: a
token/chip controller that upgrades the habtm **checkbox list** (the no-JS baseline) into
removable chips + an "add" dropdown, keeping the checkboxes as the hidden source of truth
so the form submits identically with or without JS. The recipe:

1. The gem's partial renders the accessible baseline and adds a `data-controller` hook
   (e.g. the habtm checkbox list carries `data-controller="crud-tokens"`).
2. Your Stimulus controller reads that markup and enhances it in place, manipulating the
   underlying inputs so form submission is unchanged.
3. Ship the controller however you ship Stimulus (importmap pin, `app/javascript`, etc.).
   The gem never depends on it.

## Styling

The gem ships **no CSS** and produces markup meant to look native in the host app —
Bootstrap 5 class names by default, concentrated in one overridable class map:

```ruby
# config/initializers/crud_components.rb  (created by `rails g crud_components:install`)
CrudComponents.configure do |config|
  config.css.table  = 'table table-sm table-hover'
  config.css.button = 'btn btn-outline-dark'
  config.css.badge  = 'badge text-bg-secondary'
  config.select_limit = 250    # belongs_to filter: select → text input threshold
end
```

The full key list is `CrudComponents::Config::DEFAULT_CSS`. Swapping the CSS framework
entirely means a class map plus a handful of partials — never a fork. For structural
changes, override the markup itself (above).

## i18n

Headers come from `human_attribute_name` (computed fields included), so your existing
ActiveRecord i18n applies. Every gem-generated string is looked up with a
`t(..., default:)` fallback, so the gem works with **zero** locale setup and is fully
translatable when you want it. Relevant keys live under `crud_components.*` (actions,
filter labels, "+n more", confirm dialogs, empty state).

See also: [Views](views.md) · [Fields](fields.md) · [Forms](forms.md).

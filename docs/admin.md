# The admin UI

Everything else in this gem renders *inside your app*: your layout, your routes, your
controllers. The admin is the one exception — an optional, mountable engine that supplies
the controller and the routes for you, for **every model at once**:

```ruby
# config/routes.rb
mount CrudComponents::Admin::Engine => '/admin'
```

That gives you a browsable backend over your whole schema: an index per model with the
filtering, sorting and searching the gem already does, a record view, working create /
edit / destroy forms, and a sidebar to move between models. Models that declare a
`crud_structure` get their declared columns, labels, renderers and permissions; models
that declare nothing get the zero-config derivation. It is the same rendering path as a
hand-written page — there is no second, admin-only code path to keep in sync.

## Why this is a small feature

The gem is a view layer. The *only* thing standing between a model and a working CRUD page
is a controller and a set of conventional routes. So the admin is exactly that and nothing
more: **the engine draws real `resources` routes per model**, all pointing at one generic
controller.

That matters more than it sounds. Every link the gem emits goes through
[`RouteResolver`](../lib/crud_components/route_resolver.rb), which asks one question —
does `book_path` exist here? Inside an isolated engine whose route set defines
`resources :books`, the answer is yes. So derived actions, association links, the
`+n more` links, `crud_form`'s inferred URL and method — all of it works inside the admin
with **no admin-specific code**. There is no parallel link layer, no path registry, no
`admin_url_for`.

The whole feature is therefore a registry, a route file, one controller and some chrome.

## What it is not

- **Not a replacement for hand-written screens.** It is generic by construction. The moment
  a screen deserves real design, write it in your app with `crud_collection` and drop that
  model from the admin (or leave it — the two coexist).
- **Not a permission system.** It renders what your ability object allows and nothing more,
  but it does not invent the ability object. See [Authorization](#authorization-is-mandatory).
- **Not a dashboard builder.** The dashboard is a model list with counts. Charts, KPIs and
  business views belong in your app.

## Authorization is mandatory

The engine exposes every registered model's table, including create, update and destroy.
There is no configuration under which that should be open, so the engine **refuses to
serve a request until you have told it who may in**:

```ruby
# config/initializers/crud_components.rb
CrudComponents::Admin.configure do |config|
  config.authorize_with { redirect_to main_app.root_path unless current_user&.admin? }
end
```

The block runs as a `before_action` in the engine's controller, in the controller's own
context — so `current_user`, your session, `redirect_to` and `head :forbidden` all work as
usual. Raising (e.g. `CanCan::AccessDenied`) is fine too; your app's `rescue_from` handles
it as it would anywhere else.

Booting without it is not an error — a missing `authorize_with` only bites when a request
arrives, and then it raises `CrudComponents::Admin::UnauthorizedError` with this text
rather than rendering anything. For a public demo or a local playground, say so explicitly:

```ruby
config.allow_without_authentication!   # every visitor is an admin. Never in production.
```

### Secrets

The admin shows every column, so it is where a password hash or an API key would otherwise
turn up on screen. It does not: a column whose name matches `config.filtered_columns` —
by default the app's own `config.filter_parameters` — renders as `[FILTERED]`, and is
neither filterable, sortable, searchable nor editable. See
[Security → columns that are never printed](security.md#columns-that-are-never-printed).

### Per-record and per-column authorization

Beyond the gate, the usual machinery applies, unchanged:

- when [CanCanCan](https://github.com/CanCanCommunity/cancancan) is present, every index is
  scoped with `accessible_by(current_ability)` and every member action is `authorize!`-ed,
  so the admin cannot show or touch a record the ability withholds;
- `if:` and `editable:` on attributes work exactly as they do elsewhere — a column hidden
  from a user in the app is hidden from that user in the admin, and is not filterable or
  sortable either (see [Security](security.md));
- forms permit exactly `CrudComponents.permitted_attributes(model, action:, ability:)` —
  the same list the form renders from, so the two cannot drift.

The admin adds no way to bypass any of that. It is a different set of routes onto the same
rendering and the same permit lists.

## Which models appear

By default, every `ActiveRecord::Base` descendant with a table — minus the ones nobody
means to administer:

| Dropped | Why |
| --- | --- |
| abstract classes (`ApplicationRecord`) | no table |
| `ActiveStorage::*`, `ActionText::*`, `ActionMailbox::*` | framework internals; you manage them through their owner |
| the schema-migration and internal-metadata models | Rails bookkeeping |
| background-job, cache and cable backing models (Solid Queue / Cache / Cable and friends) | infrastructure, and their tables are large and dull |
| other gems' bookkeeping models (`FriendlyId::Slug`, `PgSearch::Document`, …) | a gem's own table, not your data |
| HABTM join models | they have no independent identity |
| STI subclasses | the base class's index already lists them, `type` column and all. A subclass that wants its own entry declares `admin` itself |
| anonymous classes | a route needs a name that resolves back to the same class |
| models whose table is missing | a half-migrated database should not 500 the sidebar |

Discovery loads the constants under your model directories — the app's and every engine's
— which is what makes route generation possible at all (see [Trade-offs](#trade-offs)). A
model that lives somewhere else is not discovered; list it in `config.only`.

## Turning models off, and on

Two levers, deliberately at two different levels.

**Globally**, in the initializer, when the decision is about the admin:

```ruby
CrudComponents::Admin.configure do |config|
  config.except = %w[Review]                    # everything but these
  # or, to be exhaustive about it:
  config.only   = %w[Book Publisher Author]     # exactly these, in this order
end
```

**Per model**, in the `crud_structure` it already has, when the decision belongs to the
model:

```ruby
class Book < ApplicationRecord
  include CrudComponents::Model

  crud_structure do
    admin group: 'Catalog', actions: %i[index show edit update]
    # …
  end
end

class Review < ApplicationRecord
  include CrudComponents::Model
  crud_structure { admin false }        # not in the admin at all
end
```

`admin` is inert when the admin engine isn't loaded, so declaring it costs a non-admin app
nothing.

| `admin` option | Meaning |
| --- | --- |
| `false` | never registered — no route, no sidebar entry |
| `actions:` | which of `%i[index show new create edit update destroy]` exist. Anything omitted has **no route**, so it is unreachable, not merely unlinked |
| `group:` | the sidebar heading to file this model under |
| `label:` | the sidebar label (defaults to the model's human name) |
| `fieldset:` | the fieldset the admin renders (defaults to `:admin` when declared, else every field) |
| `scope:` | a callable narrowing the base relation, e.g. `scope: -> { order(:title) }` |

A read-only model is just `actions: %i[index show]` — and because the routes for the write
actions are never drawn, a hand-crafted `POST /admin/books` 404s instead of relying on a
hidden button.

## Configuration reference

```ruby
CrudComponents::Admin.configure do |config|
  config.authorize_with { head :forbidden unless current_user&.admin? }
  config.title  = 'Bookstore admin'      # brand line in the sidebar
  config.layout = 'crud_components/admin'  # the bundled shell, or any layout of yours
  config.only   = nil                    # Array of model names, or nil for "all discovered"
  config.except = []                     # Array of model names (or the classes)
  config.groups = ['Catalog', 'People']  # sidebar group order; unlisted groups follow, alphabetically
  config.counts = true                   # show record counts on the dashboard
  config.excluded_namespaces << 'Legacy' # more model-name prefixes discovery should skip
  config.per_page = 50                   # rows per index page, when a pager gem is present
  config.parent_controller = '::ApplicationController'   # what the engine's controllers inherit
  config.stylesheets = [...]             # what the bundled layout loads (Bootstrap 5 + icons)
end
```

`parent_controller` is how the admin reaches your `current_user`, your session and your
`rescue_from`s: the engine's controllers inherit from it. It falls back to
`ActionController::Base` when the named class does not exist.

Index pages paginate when a pagination gem is loaded — the relation is handed `.page` /
`.per` if it responds to them, so kaminari and will_paginate both work and neither is a
dependency. Without one, an index renders every row.

### The layout and the sidebar

The bundled layout is a plain Bootstrap 5 shell: a brand bar, a sidebar listing every
registered model (grouped, iconed, current one marked) and the page. Its only assets are
the two CDN stylesheets in `config.stylesheets` — swap them for your own, or point
`config.layout` at a layout of yours and load whatever you already load.

Two things to know when you do point it at your own layout:

- **Render the sidebar yourself** if you want it — `render 'crud_components/admin/sidebar'`.
  Most apps that go this route already have navigation and don't.
- **Route helpers in that layout must go through `main_app`.** The admin renders inside an
  isolated engine, so a bare `root_path` in your layout resolves against the *engine's*
  routes and raises. `main_app.root_path` is the fix, and it is safe everywhere else too.

The sidebar and the dashboard only list models the current ability lets you `:index`, so a
model an operator may not open is not advertised to them.

`only` is a directive rather than a filter: a model listed there is registered even if
discovery would have skipped it, and the list is also the sidebar order. `admin false`
still wins over it — a model that opted out stays out.

## Show in App

An admin row is half useful if you cannot get from it to the page a visitor would see. So
every record view and every index row offers **Show in App** — when, and only when, such a
page exists:

```
/admin/books/the-hobbit   →   [Show in App]   →   /books/the-hobbit
```

The resolution is the same candidate logic every other link in the gem uses, run against
the host application's routes (`main_app`) instead of the engine's. If no host route
resolves, the button is absent. The gem never renders a link it could not build — that
rule holds here too.

When your app's URL for a record is not the conventional one, say so in the structure:

```ruby
crud_structure do
  app_path { |book| main_app.publisher_book_path(book.publisher, book) }
end
```

The block runs in the view context, so all your helpers are available — including
`main_app`, which you will need, since the admin renders in the engine's route set. Return
`nil` to suppress the button for a particular record.

The helper behind the button is public, so an ordinary page can use it too:
`crud_app_path(record)`.

### The other direction

The same idea, mirrored: from an ordinary app page, link into the admin.

```erb
<% if (url = crud_admin_path(@book, :edit)) %>
  <%= link_to 'Edit in admin', url %>
<% end %>
```

`crud_admin_path(record, action = :show)` — also `:index`, `:new` — returns `nil` when the
admin isn't mounted, the model isn't registered, or the action isn't enabled for it, so
guard it rather than assuming it resolves. It finds the mount point itself; you don't pass
one, and it keeps working if you remount the engine somewhere else.

### How the button gets there

Both surfaces take an `extra_actions:` list — row actions appended beyond the model's own:

```erb
<%= crud_collection @books, extra_actions: [my_action] %>
<%= crud_record @book,      extra_actions: [my_action] %>
```

The admin passes its "Show in app" action that way, which is why the button is admin-only
without the model having to know the admin exists. Extra actions go through the same
permission check and the same route resolution as declared ones — an action whose path
does not resolve is omitted, not rendered broken.

## Fieldsets in the admin

The admin shows **every field** unless the model declares an `:admin` fieldset. It
deliberately does *not* inherit the model's `:index` fieldset: that one is a decision about
what the app's own pages show, and the column it leaves out is often exactly the one you
opened the admin to look at. The column-picker gear narrows a wide table per view.

```ruby
crud_structure do
  fieldset :index, %i[cover title genre price]              # what the shop shows
  fieldset :admin, %i[title genre price stock slug active]  # what an operator needs
end
```

Forms are the exception: they use the usual `:form` fieldset, since that is already the
"what may be edited" list rather than a display choice.

Nothing here is required. A model with no fieldsets at all still gets a complete admin.

## Associations

Every to-many association between two registered models gets a **nested index**:
`/admin/publishers/tor-books/books` renders that publisher's books, with the same
filtering and sorting as the flat one. Two things follow from having those routes:

- the `+n more` link in a has_many cell resolves to the owner's own list instead of
  falling back to plain text — including for `has_and_belongs_to_many`, which cannot be
  expressed as a filter on the target;
- the owner is authorized in its own right: you cannot read a publisher's books through
  the nested route if the ability withholds that publisher.

Polymorphic and `:through` associations are skipped — there is no single target model to
draw a route to.

## Bulk delete

A model with a destroy route also gets `DELETE /admin/books/destroy_selected`, wired to the
row checkboxes the gem already renders. Each ticked record is checked against the ability
on its own before it is destroyed, so a bulk action can never delete more than the
equivalent one-by-one clicks would.

## Trade-offs

Worth knowing before you mount it:

- **A host helper that shares a name with a route helper wins inside the admin.** The admin
  renders in the host's helper context on purpose — that is what lets a model's custom
  render block reach the host's partials and helpers. So an app that defines, say,
  `ApplicationHelper#map_path` (wrapping a nested route) keeps that meaning in the admin
  too: the label cell links to the *app's* page rather than the admin's, and the row's
  `Show` button steps aside for it as it always does when a label link is present. `Edit`
  and everything else still point into the admin. Rename the helper if you would rather
  have the admin's own link.
- **Route helpers the engine does not have fall through to `main_app`**, so those host
  partials and blocks resolve their own routes rather than raising.

- **Routes are drawn from the registry at boot**, so model discovery loads your model
  files in every process that boots the app — including rake tasks and asset builds, which
  switch eager loading off on purpose. It loads *only* the model directories, never the
  whole application, so a service that needs credentials at load time is not dragged into
  an asset build. A *newly added* model needs a server restart (or a `reload_routes!`)
  before it appears. This is the price of real, named, conventional routes — and it buys
  the entire "no admin-specific linking code" property above.
- **The route file runs even when the engine is not mounted.** Rails hands every engine's
  routes to the application's route reloader, mounted or not, so the registry resolves on
  boot either way. That is cheap (a directory of model files), but it is not zero.
- **Dashboard counts are `SELECT COUNT(*)`**, one per model. On a schema with very large
  tables, set `config.counts = false`.
- **The admin renders what the model declares.** A model with 60 columns gets a 60-column
  table. That is a prompt to declare an `:admin` fieldset, not a bug.
- **Namespaced models** (`Catalog::Book`) get the route key Rails derives
  (`catalog_books`), and are grouped by their namespace by default.

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
| HABTM join models | they have no independent identity |
| models whose table is missing | a half-migrated database should not 500 the sidebar |

Discovery eager-loads your models, which is what makes route generation possible at all
(see [Trade-offs](#trade-offs)).

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
| `fieldset:` | the fieldset the admin's index uses (defaults to `:admin`, then `:index`) |
| `scope:` | a callable narrowing the base relation, e.g. `scope: -> { order(:title) }` |

A read-only model is just `actions: %i[index show]` — and because the routes for the write
actions are never drawn, a hand-crafted `POST /admin/books` 404s instead of relying on a
hidden button.

## Configuration reference

```ruby
CrudComponents::Admin.configure do |config|
  config.authorize_with { head :forbidden unless current_user&.admin? }
  config.title  = 'Bookstore admin'    # brand line in the sidebar
  config.layout = 'admin'              # 'admin' (bundled) or any layout of yours
  config.only   = nil                  # Array of model names, or nil for "all discovered"
  config.except = []                   # Array of model names
  config.groups = ['Catalog', 'People']  # sidebar group order; unlisted groups follow, alphabetically
  config.counts = true                 # show record counts on the dashboard
end
```

`config.layout = 'application'` renders the admin inside your app's own chrome — the
closest the admin gets to the gem's usual "not an island" posture. The bundled `admin`
layout is a plain Bootstrap 5 shell with the sidebar, for apps that would rather keep the
backend visually separate.

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

The block runs in the view context, so all your helpers are available. Return `nil` to
suppress the button for a particular record.

### The other direction

The same idea, mirrored: from an ordinary app page, link into the admin.

```erb
<%= link_to 'Edit in admin', crud_admin_path(@book, :edit) %>
```

`crud_admin_path(record, action = :show)` returns `nil` when the model isn't registered or
the action isn't enabled for it, so wrap it in a condition (or an `if` on the link) rather
than assuming it resolves.

## Fieldsets in the admin

The admin looks for an `:admin` fieldset first and falls back to the usual `:index` /
`:show` / form fieldsets. That lets a model present a lean set of columns to the app and
the full set to the backend without either view having to know about the other:

```ruby
crud_structure do
  fieldset :index, %i[cover title genre price]              # what the shop shows
  fieldset :admin, %i[title genre price stock slug active]  # what an operator needs
end
```

Nothing here is required. A model with no fieldsets at all still gets a complete admin.

## Trade-offs

Worth knowing before you mount it:

- **Routes are drawn from the registry at boot**, which means model discovery eager-loads
  your models even in development. A *newly added* model therefore needs a server restart
  (or a `reload_routes!`) before it appears. This is the price of real, named, conventional
  routes — and it buys the entire "no admin-specific linking code" property above.
- **Dashboard counts are `SELECT COUNT(*)`**, one per model. On a schema with very large
  tables, set `config.counts = false`.
- **The admin renders what the model declares.** A model with 60 columns gets a 60-column
  table. That is a prompt to declare an `:admin` fieldset, not a bug.
- **Namespaced models** (`Catalog::Book`) get the route key Rails derives
  (`catalog_books`), and are grouped by their namespace by default.

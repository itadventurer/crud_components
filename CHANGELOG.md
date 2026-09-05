# Changelog

Notable changes since [v0.1.0](https://github.com/itadventurer/crud_components/releases/tag/v0.1.0).
This project follows [semantic versioning](https://semver.org).

## Unreleased

### Added

- `action ..., data: { … }` in `crud_structure` — data attributes for one action, on the element you click: the `<a>` of a GET action, the `<button>` of any other. A Stimulus controller (`data: { controller: 'clipboard', action: 'click->clipboard#copy' }`) or a `data-turbo-frame` breakout no longer needs a hand-written actions partial for the whole cell. What the gem sets itself stays unless you name the same key, so a GET action keeps `data-turbo-action="advance"` and `confirm:` keeps writing `data-turbo-confirm`.

## v0.3.0 — 2026-08-13

### Added

- **An optional, mountable admin UI.** `mount CrudComponents::Admin::Engine => '/admin'` gives every model an index, a record view and working forms, derived from the same `crud_structure` your own pages use — no scaffold per model and no second rendering path. The engine draws real conventional `resources` routes per model, which is why every existing link (derived actions, association links, `+n more`, `crud_form`'s inferred URL) resolves inside it unchanged. Models are discovered automatically; framework tables, HABTM join models and STI subclasses are skipped. Who may in is one line in the ability you already have — `can :access, :crud_admin` — and it decides exactly that one thing: past the door your ordinary rules keep deciding, model by model and action by action, so an operator with no rule for a model gets an admin without it. Where there is no CanCanCan, `auth_with { … }` takes a gate of your own and `auth_with :none` serves without one on purpose. Beyond the gate `accessible_by`, `if:`/`editable:` and the derived permit list apply exactly as they do elsewhere. Includes a sidebar whose group headings go through i18n (`crud_components.admin.groups.*`, ordered by the declared name so the order holds in every locale) and counts, nested indexes per to-many association, bulk delete, and German/English strings. ([#45](https://github.com/itadventurer/crud_components/issues/45)–[#51](https://github.com/itadventurer/crud_components/issues/51), [#69](https://github.com/itadventurer/crud_components/issues/69), [#73](https://github.com/itadventurer/crud_components/issues/73))
- `admin` in `crud_structure` — the per-model half of that: `admin false` keeps a model out entirely, `admin actions: %i[index show]` makes it read-only (the write routes are never drawn, so a hand-crafted `POST` 404s), plus `group:`, `label:`, `fieldset:` and `scope:`. Inert when the admin engine isn't loaded.
- `app_path { |book| … }` in `crud_structure`, and the `crud_app_path(record)` helper: the host application's own page for a record, for when it is not the conventional route. Backs the admin's "Show in app" button.
- `crud_admin_path(record, action = :show)` — the way back in, from an ordinary page to the mounted admin. Finds the mount point itself; nil when the admin isn't mounted or that action isn't enabled for the model.
- **The admin's delete goes through a confirmation page** that counts what the delete would take with it: associations declaring `dependent: :destroy`/`:delete_all` (with a marker when those cascade further), Active Storage attachments, what `:nullify` would orphan, and what `:restrict_with_*` blocks — the Delete button stays disabled while anything blocks. Each group **names** its records rather than only counting them: the first ten, each a link to its own page (an attachment names its file and links to it), then a link to the index holding the rest. **Delete selected** reaches the same page for the whole selection — one record is a selection of one, so it is literally the same template and the same code path — with the ticked records named and their dependents counted across all of them, instead of deleting behind a browser dialog. A group the ability would not let you delete one by one is marked as such — a cascade takes it either way. Delete buttons follow the ability too: what is refused is not offered. A browser dialog cannot say any of that.
- `crud_collection` and `crud_record` take `except_actions:` — action names one render drops, whatever the model declares. The admin uses it to replace the derived `:destroy` button with a link to that page.
- `crud_collection` and `crud_record` take `extra_actions:` — row (or selection) actions appended for one render, for a button that belongs to the surface rather than to the model. Same permission check and route resolution as declared actions.

### Fixed

- A declared action whose `path` block names a route helper that does not exist in the current route set now omits the button instead of raising — the rule derived actions already followed. Only for names ending in `_path`/`_url`, so a typo in an app's own block still raises loudly.
- The bundled playground (`test/dummy`) boots on hosts without the native libvips — the demo image is one, and so is any checkout that installed the gems but not the library. Active Storage's variant processor is switched off when libvips is missing, so attachments show as icon + filename instead of aborting the boot with `LoadError: Could not open library 'libvips.so.42'`. Nothing in the gem itself changes.

## v0.2.1 — 2026-08-01

### Changed

- Verified against **Rails 8.1** — the CI matrix now covers it alongside 7.1, 7.2 and 8.0. The gem's runtime API and its declared dependencies are unchanged; the rest is tooling (GitHub Actions bumped, demo image on Ruby 4.0, CI installs libvips so the playground's Active Storage previews load).

### Fixed

- An association column whose target labels itself with a *method* rather than a column (e.g. `label :display_title`) no longer raises `DefinitionError` ("… is neither a column nor an association of …") when its filter or `?q=` search runs. The label-based text match — and the `belongs_to` sort — are skipped whenever there is no column behind the label, as they already were for a block label. A `belongs_to` still filters by value; spell the columns out (`filter publisher: :name`) to match such a target as text.

## v0.2.0 — 2026-07-14

### Added

- Typed filter controls for dynamic columns: a `filter:` block with keyword params (`geq:`/`leq:`, `eq:`, `contains:`) filters as the column's `as:` type — a number/date range, a yes/no or a dropdown instead of a text box (override with `filter_as:`/`filter_choices:`). ([#20](https://github.com/itadventurer/crud_components/issues/20))
- `crud_filter` accepts `extra_columns:` and an opt-in `sort:` picker for headerless layouts. ([#22](https://github.com/itadventurer/crud_components/issues/22))
- A `belongs_to` column sorts by its target's label (via a join), matching the existing filter-by-label. ([#27](https://github.com/itadventurer/crud_components/pull/27))
- `crud_collection` takes `search_bar:` (default true) to drop the toolbar's `?q=` search box for one collection. ([#29](https://github.com/itadventurer/crud_components/pull/29))
- `Query` exposes the params it understands: `#permitted_keys` (the strong-params list for the filters it reads), `#filter_params` (the present subset of this request, for filter-preserving links) and `#active_filters` (active values by logical name, for chips) — so a host no longer hand-maintains a permit list that mirrors the columns. ([#31](https://github.com/itadventurer/crud_components/issues/31))
- Active Storage attachment columns filter by **presence**: a 3-state _any / present / absent_ dropdown (`EXISTS` / `NOT EXISTS`), covering `has_one_attached` and `has_many_attached`. ([#32](https://github.com/itadventurer/crud_components/issues/32))
- A `has_many`/habtm column filters by its children's **label** — the names shown in the cell — matching `belongs_to`'s filter-by-label; skipped when the target labels itself with a block. ([#36](https://github.com/itadventurer/crud_components/pull/36))

### Changed

- "Search what you see": searching an association (the `?q=` of a model, the belongs_to text filter, or a bare association name in a spec) now matches the target's **label** — the name shown in its cell — instead of the target's full `search_in`. A free-text filter can no longer reach a target's hidden columns (passwords, tokens), so a `belongs_to` to a model without its own `crud_structure` is safe by default. The undeclared `search_in` default is likewise derived from the displayed fields (own string/text columns plus associations' labels). Declare `search_in` to override. ([#28](https://github.com/itadventurer/crud_components/issues/28))

### Fixed

- Dynamic columns keep their inline filter and sort link when a prebuilt `Query` is passed. ([#21](https://github.com/itadventurer/crud_components/issues/21))
- A proc `sort` facet overrides a prior order (e.g. a search rank) instead of appending to it. ([#23](https://github.com/itadventurer/crud_components/issues/23))
- The inline filter row's apply/reset button now renders on any filterable table, even one with row actions and the column picker both off (previously the button was missing). ([#35](https://github.com/itadventurer/crud_components/pull/35))
- `LikeSpec` dedupes joined matches with an id subquery instead of `SELECT DISTINCT`, fixing `PG::UndefinedFunction` on Postgres when a model carrying a `json` column has one of its associations filtered. ([#37](https://github.com/itadventurer/crud_components/pull/37))

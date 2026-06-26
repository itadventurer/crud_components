# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Per-model icons** — declare `icon 'building'` in a model's `crud_structure`, or let the
  gem guess one from the model name (`config.model_icons`, e.g. `User → person`,
  `Publisher → building`). Reach it with `crud_model_icon(record_or_class)` (the `<i>` tag,
  paired with `config.css.icon_prefix`) or `crud_model_icon_name(…)` (the bare name); the gem
  uses it to badge column-picker groups, association links and path-column cells. An unmapped,
  undeclared model shows no icon unless you set `config.model_fallback_icon`. See
  `docs/fields.md#identity-label-identify_by-search_in-icon`.

- **`CrudComponents.where_like(relation, spec, value)`** — the safe escaped-ILIKE builder
  (`filter like:` / `search_in`) as a module function, for relations you build yourself (e.g. a
  subquery on another model in a `DynamicColumn` `filter:` block). The scope handed to a
  filter/search block already carries `#where_like`; this is for the others, so you never
  hand-write `where("col LIKE ?", "%#{value}%")`. See `docs/fields.md`.

- **Custom column headers + column actions** — a column can carry a `header:` (an HTML-safe
  String or a view-context block, e.g. `-> { link_to mail.name, mail }`) and `header_actions:`
  (a list of `CrudComponents::Action`s rendered in the `<th>`). A header action's `on:` decides
  how it acts: **`on: :selection`** acts on the **ticked rows** × that column's object — it
  submits the shared select-form (so `selected[]` rides along, resolved with
  `CrudComponents.selected`) and **makes the table selectable automatically**; `on: :collection`
  is a plain selection-independent button (`:post` → a CSRF-safe `button_to` form). Available on a
  `DynamicColumn` *and* on a declared `attribute :x, header_actions: […]`. Lets a column that *is*
  a domain object (a mail, a resource) own its header link and bulk controls, so a participants ×
  mails / × resources matrix lives entirely in `crud_collection`. Works in the grouped and
  non-grouped layouts and with the column picker. See
  `docs/fields.md#custom-headers-and-column-actions`.

### Changed

- `render:` cell blocks now receive the field **value** as a second argument
  (`->(record, value) { … }`), so a block on a `preload:`-ed dynamic column can format its
  loaded value without an `as:` partial. Backward-compatible — existing one-arg blocks ignore
  the extra argument.

## [0.2.0]

### Added

- **Dynamic columns** — `crud_collection ..., extra_columns:` renders user-defined
  properties that live outside the model's table (a definitions/values store, JSONB,
  an API) as extra columns. A `CrudComponents::DynamicColumn` carries a store-agnostic
  `preload:` (one batch query per page, no N+1), a value resolver block, and optional
  `filter:`/`sort:` facets so the column queries like any other (display-only without
  them, keeping the query whitelist tight). See `docs/fields.md#dynamic-columns`.
- **Path columns** — a dotted field name (`publisher.name`, `authors.email`) reaches
  through associations. Single-valued paths (belongs_to/has_one) render type-aware and
  sort via a LEFT JOIN; list paths (has_many/habtm) render joined and filter through the
  association. Eager-loaded automatically. Limits: `config.max_path_depth` (default 3)
  and at most one to-many hop. See `docs/fields.md#path-columns`.
- **Column picker** — `column_picker: true` adds a gear to the header row that lets a
  user hide/reorder the columns they may see. It submits `?cols[]=` to the same URL
  (no endpoint, works without JavaScript via native `<details>`; the optional
  `crud-columns` Stimulus controller adds drag-to-reorder). The selection is always
  intersected with the permitted set. Path columns are grouped under their association.
  Standalone `crud_column_picker` helper places it outside a table (e.g. above a detail
  view); `CrudComponents.selected_columns(params)` extracts the selection to persist.
  See `docs/views.md#column-picker`.
- **`visible:` / `?cols=` on `crud_collection` and `crud_record`** — narrow and order the
  shown columns/fields; `?cols=` (a picker submit) wins over the `visible:` default.
- **`extra_columns:` on `crud_record`** — the same dynamic columns on a detail view,
  shown as extra rows (batch-loaded on the single record).
- **Name-gated smart renderers** — a column named `email`/`*_email` renders as a
  `mailto:` link; one named `url`/`website`/`link`/`homepage` renders an http(s) value as
  a link. Gated on the column name, never the value. New `:email` / `:url` renderers
  (overridable partials); `as:` overrides. See `docs/fields.md#renderers`.
- **`config.max_path_depth`** — caps how deep a path column may chain (default 3).

- **Bundled stylesheet + `crud_components_styles` helper** — the gem now ships the one
  bit of CSS it needs the host to load (the column-picker float) as
  `app/assets/stylesheets/crud_components.css`. Load it pipeline-agnostically by
  inlining `<%= crud_components_styles %>` in the layout `<head>` (no compilation —
  works the same under cssbundling/sass, importmap, sprockets or propshaft), or link
  the same file with `stylesheet_link_tag "crud_components"` where the asset pipeline
  serves engine assets. `CrudComponents.bundled_css` exposes the raw CSS.

### Fixed

- A column's `label:` is now honoured as the table header and picker label for every
  field flavor (computed and dynamic columns included), not just path columns. Previously
  `DynamicColumn.new(:slug, label: 'Custom')` fell back to the humanized slug in the
  header, so user-defined property labels were lost. `human_name` checks a String `label:`
  first, then `human_attribute_name`.

## [0.1.0]

- Initial release: declarative CRUD tables, record views and filter forms derived from
  ActiveRecord models; fieldsets, the safe ILIKE query/LikeSpec mini-language, derived
  actions, forms via simple_form, grouping, selection/bulk actions, and the security
  model (you can only filter/sort what you can see).

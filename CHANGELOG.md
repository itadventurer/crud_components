# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

## [0.1.0]

- Initial release: declarative CRUD tables, record views and filter forms derived from
  ActiveRecord models; fieldsets, the safe ILIKE query/LikeSpec mini-language, derived
  actions, forms via simple_form, grouping, selection/bulk actions, and the security
  model (you can only filter/sort what you can see).

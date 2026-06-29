# Changelog

Notable changes since [v0.1.0](https://github.com/itadventurer/crud_components/releases/tag/v0.1.0).
This project follows [semantic versioning](https://semver.org).

## Unreleased

### Added

- Typed filter controls for dynamic columns: a `filter:` block with keyword params (`geq:`/`leq:`, `eq:`, `contains:`) filters as the column's `as:` type — a number/date range, a yes/no or a dropdown instead of a text box (override with `filter_as:`/`filter_choices:`). ([#20](https://github.com/itadventurer/crud_components/issues/20))
- `crud_filter` accepts `extra_columns:` and an opt-in `sort:` picker for headerless layouts. ([#22](https://github.com/itadventurer/crud_components/issues/22))
- A `belongs_to` column sorts by its target's label (via a join), matching the existing filter-by-label. ([#27](https://github.com/itadventurer/crud_components/pull/27))
- `crud_collection` takes `search_bar:` (default true) to drop the toolbar's `?q=` search box for one collection. ([#29](https://github.com/itadventurer/crud_components/pull/29))

### Changed

- "Search what you see": searching an association (the `?q=` of a model, the belongs_to text filter, or a bare association name in a spec) now matches the target's **label** — the name shown in its cell — instead of the target's full `search_in`. A free-text filter can no longer reach a target's hidden columns (passwords, tokens), so a `belongs_to` to a model without its own `crud_structure` is safe by default. The undeclared `search_in` default is likewise derived from the displayed fields (own string/text columns plus associations' labels). Declare `search_in` to override. ([#28](https://github.com/itadventurer/crud_components/issues/28))

### Fixed

- Dynamic columns keep their inline filter and sort link when a prebuilt `Query` is passed. ([#21](https://github.com/itadventurer/crud_components/issues/21))
- A proc `sort` facet overrides a prior order (e.g. a search rank) instead of appending to it. ([#23](https://github.com/itadventurer/crud_components/issues/23))

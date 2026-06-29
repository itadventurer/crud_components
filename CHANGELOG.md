# Changelog

Notable changes since [v0.1.0](https://github.com/itadventurer/crud_components/releases/tag/v0.1.0).
This project follows [semantic versioning](https://semver.org).

## Unreleased

### Added

- Typed filter controls for dynamic columns: a `filter:` block with keyword params (`geq:`/`leq:`, `eq:`, `contains:`) filters as the column's `as:` type — a number/date range, a yes/no or a dropdown instead of a text box (override with `filter_as:`/`filter_choices:`). ([#20](https://github.com/itadventurer/crud_components/issues/20))
- `crud_filter` accepts `extra_columns:` and an opt-in `sort:` picker for headerless layouts. ([#22](https://github.com/itadventurer/crud_components/issues/22))
- A `belongs_to` column sorts by its target's label (via a join), matching the existing filter-by-label. ([#27](https://github.com/itadventurer/crud_components/pull/27))

### Fixed

- Dynamic columns keep their inline filter and sort link when a prebuilt `Query` is passed. ([#21](https://github.com/itadventurer/crud_components/issues/21))
- A proc `sort` facet overrides a prior order (e.g. a search rank) instead of appending to it. ([#23](https://github.com/itadventurer/crud_components/issues/23))

# Fields & rendering

Everything in a `crud_structure` is, ultimately, about fields: what they are, how they
render, how they filter and sort. This is the reference for that. For the one-page
summary read the [combination table](../README.md#the-combination-table) in the README
first; this doc is the per-flavor depth behind it.

Running example: the bookstore from the [README](../README.md#the-running-example).

## You rarely declare fields

![A zero-config model (not even `include CrudComponents::Model`): the table, columns, search, filters and the auto-derived habtm "Books" column are all inferred from the schema](screenshots/zero-config-table.png)

All columns, enums and associations are already fields — derived from what Rails knows.
Declare an `attribute` only to *improve* one:

```ruby
attribute :price, as: :number, unit: '€', digits: 2   # renderer + options
attribute :internal_notes, if: :manage                # column-level permission
attribute :token, filter: false                       # opt a derived field out of filtering
```

`attributes` (plural) applies shared options to several fields at once:

```ruby
attributes :participants, :owner, if: :manage
```

The field universe is always *all* derived columns/associations plus declared computed
fields. `attribute` never adds or removes a column from a table — that is exclusively
the job of [fieldsets](views.md#fieldsets).

## Renderers

![A record view (crud_record) as a definition list: each value rendered type-aware — currency, a boolean check, a genre badge, pretty-printed JSON, and association links](screenshots/record.png)

Every field has a derived renderer. Name one explicitly with `as:` to override it, and
pass renderer options inline:

```ruby
attribute :price,  as: :number, unit: '€', digits: 2
attribute :cover,  as: :image
attribute :blurb,  as: :markdown
attribute :rating, as: :stars       # a custom renderer, see Extending
```

`as:` reads the same as on `crud_collection` ("present this as a …") and as simple_form's
`f.input :price, as: :string`.

Built-in renderers: `:text`, `:number`, `:date`, `:datetime`, `:boolean`, `:enum`,
`:association`, `:association_list`, `:image`, `:json`, `:markdown`, `:asciidoc`.

**Renderers are surface-aware.** Each receives `surface:` (`:collection` or `:record`):

- `:text` truncates inside a collection, preserves line breaks on a record page.
- `:image` uses a small size in table cells, a larger one on the record view.
- `:json` pretty-prints into a `<pre>` (syntax-highlighted when `rouge` is present),
  truncated in collections.

**Soft-dependency renderers** use other gems *when present*, never as dependencies:
`:markdown` → commonmarker / redcarpet / kramdown (whichever your app has); `:asciidoc`
→ asciidoctor; `:json` highlighting → rouge. Declaring `as: :markdown` with no markdown
gem in the bundle raises **at boot** with the list of gems to choose from — never a
silent blank cell in production.

To add your own renderer, see [Extending](extending.md#add-a-field-renderer).

## Computed fields

A name that is not a column, enum or association falls back to a **public model
method**, rendered by its value type — no ceremony:

```ruby
def shop_margin = price - purchase_price
# `shop_margin` is already a usable, display-only field
```

A name that is *nothing* (no column/enum/association/method) and has no `render` facet
raises at boot, telling you to add one.

### Custom markup

For custom HTML, a block that takes the record is the shortest form:

```ruby
attribute(:cover) { |book| image_tag book.cover.variant(:large), class: 'rounded' }
```

Blocks are **stored** in the model but **executed in the view context at render time** —
which is why `image_tag`, `link_to`, route helpers, `t` and your app's own helpers all
work inside them even though the block lives in a model file.

> **The view-context rule.** Presentation blocks (`render`, `label`, action path
> blocks) are `instance_exec`'d in the view with the record as the sole argument. Inside
> such a block `self` is the view — so call model methods *on the record argument*, not
> on `self`. Local variables captured by the closure are available; instance variables
> of the surrounding class body are not.

Customizing how a field renders costs nothing else: a string column with a custom
`render` block **keeps** its derived filter and sort. Overrides are per facet.

## Facets

When a field needs more than rendering, its facets live together in one block — never
in separate `filter_for` / `path_for` declarations elsewhere:

```ruby
attribute :author_names do
  render { |book| book.authors.map(&:name).to_sentence }
  filter like: { authors: :name }
  sort   { |scope, dir| scope.left_joins(:authors).order('authors.name' => dir) }
end
```

| Facet | Takes | Effect |
| --- | --- | --- |
| `render { \|record\| … }` | a block (markup) | overrides the rendered cell. Named renderers are `as:`'s job; this facet is block-only |
| `filter like: spec` / `filter { \|scope, value\| … }` | a like-spec or block | overrides/adds the filter. `filter false` switches a derived filter off |
| `sort :column` / `sort { \|scope, dir\| … }` | an own-column symbol or block | overrides/adds the sort (`dir` is guaranteed `:asc`/`:desc`). `sort false` switches it off |

Why filter/sort are opt-in for computed fields: **filtering and sorting run in SQL**, so
they stay correct on large tables and under pagination. A Ruby-computed value has no SQL
meaning until a facet tells the gem how to express it.

> **Query-block contract.** `filter`/`sort`/`search_in` blocks receive `(scope, value)`
> (or `(scope, dir)` for sort) and return a relation. There is no view context at query
> time; the scope arrives extended with `where_like` (below).

## The like-spec

One declarative mini-language for "case-insensitive contains across these columns,
joining as needed" — shared by `filter like:` and `search_in`:

```ruby
filter like: :title                              # own column
filter like: %i[title subtitle]                  # several own columns, OR-combined
filter like: { authors: %i[name email] }         # join, explicit columns
filter like: { user: { address: %i[street town] } }  # nested joins, explicit columns
filter like: :publisher                          # join, DELEGATE to Publisher's search_in
filter like: [:title, { authors: :name }]        # mixed
```

The **delegation form** — an association name *without* columns — means "search it the
way that model defines being searched" (its `search_in`). It is the idiomatic style and
stays correct as the target model's definition evolves.

The gem turns a spec into `left_joins` plus parameterized, wildcard-escaped `ILIKE`
(via `sanitize_sql_like` with an explicit `\` escape char, so `%`, `_` and `\` are all
literal). A spec contains only column/association names you wrote — **no SQL strings**,
nothing to sanitize. A joined match is `DISTINCT`; an own-column spec is not (no join to
dedupe). Delegation cycles are guarded (max 5 delegation hops) and raise rather than
stack-overflow.

### The escape hatch

A block is the escape hatch for genuinely custom logic; the scope it receives carries
the same machinery, so you keep the safe pit of success without `sanitize_sql_like`:

```ruby
filter do |scope, value|
  scope.where(active: true).where_like({ authors: :name }, value)
end
```

`where_like(spec, value)` is available on every scope handed to a filter/search block.
Raw SQL in a block is possible — and then explicitly your responsibility.

## Identity: `label`, `identify_by`, `search_in`

```ruby
label :title              # method or block; default: name → title → first string column
identify_by :slug         # default: :id
search_in :title, :subtitle, :publisher   # default: own string/text columns
```

- **`label`** — the record's display name: links, select options, record headings.
  Block form: `label { |p| "#{p.user.name} @ #{p.training.title}" }`. With no string
  column at all it falls back to `"Book #42"`.
- **`identify_by`** — the column URL params use to identify a record of this model. With
  `identify_by :slug`, a filter URL reads `?publisher=tor-books` and resolves via
  `Publisher.where(slug: …)` — never raw ids (no enumerable numeric ids in shareable
  URLs). See [security](security.md).
- **`search_in`** — the model's text identity: what `?q=` searches, what the belongs_to
  text-filter fallback matches, and what delegated specs (`like: :publisher`) expand to.

### Identity composes through associations

These three are not just for the model's own pages — they define how **other** models
render, link and filter it through their associations:

```ruby
class Publisher < ApplicationRecord
  include CrudComponents::Model
  crud_structure do
    label :name
    identify_by :slug
    search_in :name
  end
end
```

Every model with a `belongs_to :publisher` now gets, for free: a column rendering the
publisher's name as a link (or a muted placeholder when nil), a filter valued by slug,
and — wherever a spec says `like: :publisher` — text search through the publisher's
name. Declared once, where Publisher lives; correct everywhere it appears. This is the
gem's central idea: per-model declarations composed over the association graph.

## Field flavors in depth

| Flavor | Renderer | Filter | Sort | Notes |
| --- | --- | --- | --- | --- |
| string column | text | `ILIKE %v%` (escaped) | yes | |
| text column | truncated / line-breaks on record | `ILIKE %v%` | yes | |
| numeric column | number (`as: :number` for `unit:`/`digits:`) | `_geq`/`_leq` range + `?f=v` exact | yes | non-finite (`NaN`/`Inf`) ignored |
| date / datetime | localized | from–to range + exact day | yes | datetime ranges whole-day-inclusive |
| boolean | ✓/✗ icon, click-to-filter | any/yes/no select | yes | accepts `t/f/1/0/yes/no/on/off`; else ignored |
| enum | i18n'd badge, click-to-filter | select of keys | yes | values validated against the enum |
| json | `<pre>` (rouge if present) | — | — | not form-editable in v1 |
| Active Storage attachment | image (sized by surface) | — | — | file field in forms |
| `belongs_to` | nil-safe link via target `label` | select (≤ `select_limit`) / text over target `search_in` | v2 | resolves by `identify_by` |
| `has_many` / habtm | "a, b +n more" links | opt-in `filter like:` | no | "+n more" links to nested/filtered index |
| public method | by value type | — | — | needs a facet to filter/sort |
| `render` block | block output | — | — | facets add filter/sort |

Click-to-filter: in a collection, an enum badge and a boolean icon link to set their own
column's filter (respecting the fieldset whitelist and `param_prefix`). The inline
filter row uses compact controls; the standalone `crud_filter` form uses full-size ones.

See also: [Views & fieldsets](views.md) · [Forms](forms.md) · [Security](security.md) ·
[Extending](extending.md).

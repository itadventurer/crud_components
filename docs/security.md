# Security

The gem has two security jobs:

1. **Show only what the user is allowed to see** — and never let them filter or sort by it
   either. Visibility is permission-aware, end to end.
2. **Turn untrusted URL params into SQL with no injection** — every value, name and spec
   that reaches the query is whitelisted, validated and parameterized.

   Both are encoded as tests in
   [`test/query_security_test.rb`](../test/query_security_test.rb).

## Permissions: `if:` and `editable:`

Two dimensions, declared on an attribute:

```ruby
attribute :purchase_price, if: :manage          # visible only to managers — hidden everywhere otherwise
attribute :state,          editable: :publish   # everyone sees it; only :publish may change it in a form
attribute :slug,           editable: false      # shown read-only in the form, never submitted
```

- **`if:`** governs **visibility** — and it is total. A field whose `if:` fails is absent
  from the table, the record view, the form *and the query layer*: you cannot filter,
  sort or `?q=`-search by a column you may not see. (See [the whitelist](#the-whitelist) and
  [`?q=` and permissions](#q-search-and-permissions).)
- **`editable:`** governs **writability in forms** only — a field can be visible but not
  changeable. `false` (or an unmet permission) renders it read-only and drops it from the
  [permit list](forms.md#the-permit-list); it stays visible for context.

### Callable forms

Both `if:` and `editable:` accept the same three forms:

```ruby
if: :manage                                       # Symbol — sugar for can?(:manage, record)
if: -> { can?(:publish, Book) }                   # zero-arity lambda — ability only
if: ->(book) { book.draft? }                      # one-arity lambda — receives the record
if: ->(book) { can?(:edit, book) && book.draft? } # …and can? is in scope too — depend on both
```

- **Symbol** → `can?(symbol, record)` — the record being decided about (so it matches the
  derived action check, `can?(:edit, @book)`), or the model class for a column-level
  decision, where there is no record.
- **Zero-arity lambda** runs in a context where `can?` works (the view when rendering, a
  thin ability wrapper when querying); it receives no record.
- **One-arity lambda** receives the record **and** runs where `can?` works — so a condition
  can depend on the ability, the record, or both. Where there is no record — a column-level
  or strong-params check that can't depend on a single row — the lambda is **not run**; it
  defers to a safe default: visibility (`if:`) shows the column, editability (`editable:`)
  withholds the field (a class-level permit list can't grant per-record write access).

### The `can?` dependency (there isn't one)

`can?` is **feature-detected**, not required. The gem depends on no authorization library;
it works with [CanCanCan](https://github.com/CanCanCommunity/cancancan) or anything exposing
a `can?(action, subject)` method.

- Pass the ability where you build the query, or let auto mode pick up `current_ability`:

  ```ruby
  CrudComponents::Query.new(Book, params, ability: current_ability)
  ```

- **No `can?` provider and no ability?** A `Symbol` condition simply evaluates to *not
  permitted* — the field is hidden. It does **not** raise. Safe by default: absent an
  authority to say "yes", the answer is "no". (Lambdas that don't call `can?` are
  unaffected.)

### Links follow the ability too

A record is linked only where the viewer may open it: label cells, association cells
(`book.publisher`, `book.reviews`) and `crud_record_path` ask `can?(:show, record)` (and
`can?(:edit, record)` for the edit fallback). A review a user may not open still appears
by name in the book's reviews column, but without a link — unless the ability can scope a
query, in which case a review the viewer may not see is not listed at all (see
[Association cells and the ability](#association-cells-and-the-ability)). Without `can?`
every record is linked, as before.

### Secrets are write-only

`attribute :api_token, secret: true` keeps a credential's value out of every rendered
surface. Tables, record views and the admin show only whether a value is set. Filtering and
sorting go by that presence (`?api_token=present|absent`, `?sort=api_token` orders by
set / not set); a value in `?api_token=` changes nothing, and neither `?q=` nor `search_in`
reaches the column. `as_json` leaves it out entirely. A `filter`/`sort` block or a
`search_in` naming a secret raises at boot. Its form input is always empty. See
[Forms → Secrets](forms.md#secrets).

## The whitelist

> **A URL param is applied only if it names a filterable field of the fieldset in play
> that the current user may see (or a reserved param). Everything else never reaches SQL.**

Two consequences worth stating plainly:

- **You can only filter and sort what you can see.** The set of filterable/sortable fields
  is the visible fieldset (plus its declared `filters:`), minus anything an `if:` hides.
- **Hidden data can't be probed.** Because a permission-gated column never reaches the
  query, you can't bisect an invisible `purchase_price` by watching which rows survive a
  crafted `purchase_price_geq`.

## The injection-safe URL model

The URL *is* the state — plain GET forms and links, `data-turbo-action="advance"`,
shareable. Flat params:

| Param                                    | Meaning                                             |
| ---------------------------------------- | --------------------------------------------------- |
| `?title=ruby`                            | filter a field (text / enum / boolean / belongs_to) |
| `?price=12` / `?published_on=2026-01-01` | exact match (number / single day)                   |
| `?price_geq=10&price_leq=20`             | ranges (numeric, date; dates whole-day-inclusive)   |
| `?q=tolkien`                             | global search through `search_in`                   |
| `?sort=title&dir=desc`                   | sorting; composes with active filters               |
| `?cols[]=title&cols[]=price`             | column-picker selection (ordered, permitted subset) |

`q`, `sort`, `dir`, `page`, `per`, `cols` are **reserved** — they're the gem's own control params.
A field named after one would silently shadow it, so the gem raises at boot instead; rename
the field (or scope the whole collection with `param_prefix: :books`, which prefixes every
param). With `param_prefix:`, unprefixed params are ignored.

The guarantees, each backed by a test:

- **Unknown / non-scalar params are inert.** Only whitelisted fields are read; `?title[]=…`
  and `?title[x]=…` are ignored.
- **No injection through `sort`/`dir`.** `sort` resolves against sortable fields only —
  `?sort=title;DROP TABLE books` yields *no* `ORDER BY`, not an escaped one. `dir` is
  validated to `asc`/`desc`.
- **`?cols=` can only narrow, never widen.** The column-picker selection is intersected
  with the permitted column set, so a forged or stale `cols` (or a `picked_columns:` default
  naming a now-gated column) can hide or reorder columns but never surface one the `if:`
  gate forbids.
- **Escaped LIKE.** Wildcards (`%`, `_`) and the backslash escape itself are escaped
  (`sanitize_sql_like` with an explicit `\`), so `%` matches a literal percent.
- **Validated casts.** Enum values are checked against the enum; booleans against an
  explicit set (`t/f/1/0/yes/no/on/off`); numeric/date casts reject the unparsable *and*
  the non-finite (`NaN`, `Infinity`). Anything invalid leaves the scope unchanged.
- **belongs_to by `identify_by`.** belongs_to params resolve through the target's
  `identify_by` column as a parameterized subquery — never a raw id (unless `identify_by`
  is `:id` (default)).
- **Specs are author-written.** A search spec contains only column/association names you
  wrote; the gem builds joins + parameterized ILIKE from it. The one place SQL is
  hand-written is the escape-hatch `filter { |scope, value| … }` block — and `where_like`
  exists so you rarely need to. Raw SQL in a block is your responsibility.

## `?q=` search and permissions

`search_in` is the model's **text identity**, powering `?q=`. Three things follow:

- A **declared, permission-gated** column (`attribute :notes, if: :manage`) is dropped from
  the search spec for a user who can't see it — `?q=` upholds "hidden everywhere".
- The **zero-config default is "search what you see"**: the index's own string/text columns
  plus its associations' labels. A column you never display is never searched, and neither
  is an attribute declared `secret: true`, displayed or not. Declare
  `search_in` to override (a narrower column list, or a block for full-text).
- An **association** reached by `?q=`, the belongs_to text fallback, or a spec naming it
  (`filter :publisher`) matches the target's **label** only — never the target's other
  columns. So filtering by a `belongs_to :user` can't probe `users.encrypted_password`,
  even when `User` has no `crud_structure` of its own.

## Association cells and the ability

A book's reviews column, its reviews on the record page and the same cells in the admin
list only the reviews the ability lets the viewer see, and "+n more" counts only those:
with a CanCanCan ability (anything whose relation answers `accessible_by`), a review
hidden from a reader is neither named nor counted. The reviews are still preloaded in one
query; one more query per column, for all rows of the page at once, asks
`Review.accessible_by(current_ability)` which of them to keep. `crud_collection` uses the
ability of its `Query` (`current_ability` unless you passed another), `crud_record` uses
`current_ability`, and the admin the ability it authorizes with.

Without such an ability — a host whose `can?` is a plain helper, or no ability at all —
every associated record is listed, as before, and one the viewer may not open appears by
name without a link. A column that should list everything regardless takes
`scope_by_ability: false`, for instance where the ability narrows by a condition that
does not matter for naming a record:

```ruby
attribute :reviews, scope_by_ability: false
```

The option is for has_many and habtm attributes; anywhere else it raises at build time.
A render block or a custom renderer receives the narrowed list as its value; code that
reads `book.reviews` itself sees every review.

## Association choices and the ability

A `belongs_to` filter select and the `belongs_to` / habtm form selects list the target's
records by name. They list only what the ability lets the viewer see: with a CanCanCan
ability (anything whose relation answers `accessible_by`) the choices come from
`Publisher.accessible_by(current_ability)`, so a user who may see two publishers is not
shown the names of all the others. `crud_collection`, `crud_filter` and `crud_form` pass
`current_ability` on by themselves; a hand-built `Query` gets it through `ability:`.

Without such an ability — a host whose `can?` is a plain helper, or no ability at all — the
target's full table is listed, as before. Narrow it per field with `choices:`, a callable
that receives the target relation (already scoped, when there is a scoping ability) and,
if it takes a second argument, the ability:

```ruby
attribute :publisher, choices: ->(scope) { scope.where(active: true) }
attribute :publisher, choices: ->(scope, ability) { scope.select { |p| ability.can?(:show, p) } }
```

It returns a relation or an array of records and applies to the filter select and the
form select alike. A form still offers the record the book already points at, even when
the ability hides it: otherwise an untouched form would silently move the book to the
first publisher on the list when saved.

  See also: [Performance](performance.md) · [Views](views.md) · [Fields](fields.md) · [Forms](forms.md).

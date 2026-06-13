# Security & the URL model

The gem's job is to turn untrusted URL params into SQL safely. This is the reference for
the guarantees and how they're enforced. Every item here is backed by a test in
[`test/query_security_test.rb`](../test/query_security_test.rb).

## The URL is the state

Plain GET forms and links, `data-turbo-action="advance"`, shareable URLs. Flat params:

| Param | Meaning |
| --- | --- |
| `?title=ruby` | filter a field (text / enum / boolean / belongs_to) |
| `?price=12` / `?published_on=2026-01-01` | exact match (number / single day) |
| `?price_geq=10&price_leq=20` | ranges (numeric, date; dates whole-day-inclusive) |
| `?q=tolkien` | global search through `search_in` |
| `?sort=title&dir=desc` | sorting; composes with active filters |

Reserved: `q`, `sort`, `dir`, `page`, `per` (a field may not be named after them — it
raises at boot). With `param_prefix: :books`, all of these gain a `books_` prefix and
unprefixed params are ignored.

## The one rule

> **A URL param is applied iff it names a filterable field of the fieldset in play that
> the current user may see (or one of the reserved params). Everything else never reaches
> SQL.**

## The guarantees

### 1. Permissions come first

A field gated by `if:` is invisible **and** unfilterable / unsortable for users without
the permission — the whitelist is permission-aware. There is no way to filter or sort by
a column you're not allowed to see. Pass the ability where you build the query:

```ruby
CrudComponents::Query.new(Book, params, ability: current_ability)
# or, in auto mode, current_ability is picked up if your controller defines it
```

No ability passed ⇒ permission-gated fields are treated as not permitted (safe by
default).

### 2. Whitelist by construction — unknown and unseen params are inert

Only the current fieldset's filterable fields (plus its declared `filters:`) are ever
read from the URL. A column that exists but isn't part of the surface, or is
permission-gated, never reaches SQL. So **hidden data cannot be probed** by filtering or
sorting — e.g. you cannot bisect an invisible `purchase_price` by watching which rows
survive a `purchase_price_geq`. Non-scalar param values (`?title[]=…`, `?title[x]=…`) are
ignored.

### 3. No injection through `sort` / `dir`

`sort` resolves against the fieldset's sortable fields only — `?sort=title; DROP TABLE
books` produces **no `ORDER BY` at all**, not an escaped one. `dir` is validated against
`asc` / `desc`, defaulting to `asc`.

### 4. No injection through values

- LIKE wildcards (`%`, `_`) **and the backslash escape char itself** are escaped in every
  gem-generated pattern (`sanitize_sql_like` with an explicit `\` escape), so a search for
  `%` matches a literal percent and `\` a literal backslash.
- Enum values are validated against the enum definition; invalid values leave the scope
  unchanged.
- Boolean values are validated against an explicit set (`t/f/1/0/yes/no/on/off`);
  anything else (`2`, `" true"`, `banana`) is ignored — not coerced to `true`.
- Numeric/date casts reject the unparsable *and* the non-finite (`NaN`, `Infinity`), so
  neither reaches SQL.
- belongs_to params resolve via the target's declared `identify_by` column, as a
  parameterized subquery — never a raw id (unless `identify_by` is `:id`).

### 5. No injection through specs

A like-spec contains only column/association names you wrote — no user-controlled SQL.
The gem builds joins + parameterized ILIKE from it. The only place SQL is hand-written is
an escape-hatch `filter { |scope, value| … }` block, and `where_like` exists so you
rarely write any. Raw SQL in a block is your responsibility.

## `?q=` search and permissions

`search_in` is the model's **text identity**, used model-globally (it powers `?q=`, the
belongs_to text fallback, and delegated specs). Two things follow:

- A **declared, permission-gated** column (`attribute :notes, if: :manage`) is dropped
  from the search spec for a user who can't see it — `?q=` upholds "hidden everywhere".
- An **undeclared** column in the zero-config default spec (which is *all* string/text
  columns) is searched model-globally by design. If a model has a sensitive string column
  you don't want reachable via `?q=`, declare `search_in` explicitly (naming the columns
  you do want) — the default is broad on purpose, so that zero-config search "just finds
  things", but it is the author's call to narrow it.

## Permissions

`if:` / `editable:` accept any of these callable forms:

```ruby
if: :manage                       # sugar for -> { can?(:manage, Model) }
if: -> { can?(:manage, Book) }    # zero-arity lambda, run where can? works
if: ->(record) { record.draft? }  # one-arity lambda — receives the record
if: -> { it.draft? }              # `it` — also receives the record (action context)
```

- Symbol → `can?(symbol, model)`. Requires a `can?` provider (CanCanCan or anything with
  the same interface). The gem depends on **none** of them — `can?` is feature-detected.
- A zero-arity lambda runs in a context where `can?` is available (the view when
  rendering; a thin ability wrapper when querying).
- A one-arity lambda / `it` receives the record (and `nil` for column-level decisions,
  which by nature can't depend on a single row).

## Performance defenses (security-adjacent, on by default)

- Associations of visible fields (`belongs_to` *and* `has_many`) are eager-loaded — no
  N+1 from the derived columns.
- belongs_to filter selects switch to a text input (over the target's `search_in`) beyond
  `config.select_limit` (default 250); autocomplete is a later version.
- Long text truncates in collections (full value on the record page).
- No pagination in auto mode yet — pass a bounded scope or use the
  [manual query](views.md#the-manual-query-pagination-and-big-tables) for big tables. A
  1600-row table rendered unbounded is the documented footgun.

See also: [Views](views.md) · [Fields](fields.md) · [Forms](forms.md).

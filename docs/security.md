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
  with the permitted column set, so a forged or stale `cols` (or a `visible_columns:` default
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

`search_in` is the model's **text identity**, used model-globally (it powers `?q=`, the
belongs_to text fallback, and delegated specs). Two things follow:

- A **declared, permission-gated** column (`attribute :notes, if: :manage`) is dropped from
  the search spec for a user who can't see it — `?q=` upholds "hidden everywhere".
- An **undeclared** column in the zero-config default spec (all string/text columns) is
  searched model-globally by design. If a model has a sensitive string column you don't
  want reachable via `?q=`, declare `search_in` explicitly with only the columns you want.
  The default is broad so zero-config search "just finds things"; narrowing it is the
  author's call.

  See also: [Performance](performance.md) · [Views](views.md) · [Fields](fields.md) · [Forms](forms.md).

# CrudComponents

> **Status: design draft, round 3.** This README is written before the implementation
> (README-first). It is the design document up for sign-off; the code will be built to
> match it.

Declarative CRUD UI for ActiveRecord models, primarily for admin backends — rendered
**inside your app**: your layout, your routes, your authorization, your styling, mixed
freely with hand-written pages. Not an admin island with its own theme and navigation.

The core promise: **zero configuration already works.** A bare ActiveRecord model
renders as a usable, filterable, sortable table in one line. Configuration only ever
*improves* what you get — it never has to *enable* it, and removing any line of config
falls back to a sensible default.

```erb
<%= crud_collection Book.all %>
```

That line gives you a table with type-appropriate cells, sortable headers, an inline
filter row, and working URL params — `?genre=scifi&price_leq=20&sort=title&dir=desc`
filters and sorts it, with or without JavaScript. No controller code, no model code.

## Installation

```ruby
# Gemfile
gem 'crud_components'
```

Requires Rails >= 7.1 and Ruby >= 3.2. There are **no runtime dependencies outside
Rails itself** — see [Dependencies](#dependencies).

## The running example

A small bookstore:

```ruby
class Book < ApplicationRecord
  belongs_to :publisher
  has_many :reviews
  has_and_belongs_to_many :authors
  has_one_attached :cover
  enum :genre, { fiction: 0, scifi: 1, nonfiction: 2 }
  # columns: title, subtitle, slug, blurb (text), price (decimal),
  #          pages (integer), published_on (date), active (boolean)
end

class Publisher < ApplicationRecord   # name, slug, founded_on
  has_many :books
end

class Author < ApplicationRecord      # name, email
  has_and_belongs_to_many :books
end

class Review < ApplicationRecord      # rating (integer), body (text)
  belongs_to :book
end
```

## A table in one line

```erb
<%= crud_collection Book.all %>
```

With zero configuration, derived from what Rails already knows:

- every column gets a type-appropriate cell and filter control (the full mapping is in
  the [combination table](#the-combination-table));
- `genre` renders as a badge and filters as a select of the enum keys;
- `publisher` renders as a nil-safe link, `authors` as a truncated list
  ("Tolkien, Lewis +3 more"), `cover` as a thumbnail;
- headers come from `human_attribute_name`, so your existing model i18n applies;
- filtering, search and sorting are read from the request params automatically —
  every state is a plain GET URL, shareable and bookmark-safe.

A single record and a standalone filter form work the same way:

```erb
<%= crud_record @book %>      <%# definition list, same cell renderers %>
<%= crud_filter Book %>       <%# labelled filter form, e.g. for a modal or sidebar %>
```

The rest of this README is one long "now I want to…" session, building the bookstore
admin up step by step. Every step is optional; nothing below is required for the table
above to work.

## "I want to choose the columns"

Include the DSL and override the `:default` fieldset — the named selection every
surface falls back to:

```ruby
class Book < ApplicationRecord
  include CrudComponents::Model

  crud_structure do
    fieldset :default, %i[cover title genre price publisher]
  end
end
```

A **fieldset** is a named list of fields (and, later, actions). `:default` starts as
"all fields"; declaring it overrides that. `fieldset :default, []` is the off switch —
no columns at all. Curation happens *only* here: declaring or customizing an attribute
elsewhere never adds or removes columns.

More fieldsets for more surfaces come [further down](#i-want-different-tables-on-different-pages).

## "I want nicer cells"

### Pick a renderer, pass it options

Every field already has a derived renderer. Naming one explicitly — with its options —
upgrades a single field:

```ruby
attribute :price, as: :number, unit: '€', digits: 2
attribute :cover, as: :image            # thumb in collections, larger in record view
attribute :blurb, as: :markdown         # needs a markdown gem, see below
```

(`as:` means the same thing here as on `crud_collection` — "present this as a …" —
and will feel familiar from simple_form's `f.input :price, as: :string`.)

Built-in renderers: `:text`, `:number`, `:date`, `:datetime`, `:boolean`, `:enum`,
`:association`, `:image`, `:json`, `:markdown`, `:asciidoc`. Renderers are
**surface-aware**: `:text` truncates inside a collection but preserves line breaks on a
record page; `:image` picks a small variant for table cells and a larger one for the
record view; `:json` pretty-prints into a `<pre>`.

Some renderers use other gems **when they are present** — never as dependencies:
`:markdown` uses commonmarker/redcarpet/kramdown (whichever your app has), `:asciidoc`
uses asciidoctor, `:json` adds syntax highlighting when rouge is available. Declaring
`as: :markdown` without any markdown gem raises at boot with the gem names to choose
from.

### Computed fields

A name that isn't a column, enum or association falls back to a **public model
method** — still zero ceremony, rendered by its value type:

```ruby
def shop_margin = price - purchase_price
# `shop_margin` is already a usable (display-only) field
```

### Custom markup

For custom HTML, a block that takes the record is the shortest form:

```ruby
attribute(:cover) { |book| image_tag book.cover.variant(:large), class: 'rounded' }
```

Blocks are *stored* in the model but **executed in the view context at render time** —
that's why `image_tag`, `link_to`, route helpers, `t` and your app's own helpers all
work inside them. (Trade-off: inside the block `self` is the view, so call model
methods on the record argument.)

Customizing how a field *renders* costs you nothing else: a string column with a custom
block **keeps** its derived filter and sort. Overrides are per facet, which brings us to:

## "I want to filter on a computed column"

Filtering and sorting happen **in SQL** — that's what keeps them correct on large
tables and, later, under pagination. A Ruby-computed value can't be pushed into SQL,
so computed fields get query behavior by declaring it. A field's facets live together
in one block:

```ruby
attribute :author_names do
  render { |book| book.authors.map(&:name).to_sentence }
  filter like: { authors: :name }
  sort   { |scope, dir| scope.left_joins(:authors).order('authors.name' => dir) }
end
```

- `render { |record| … }` — markup. (Named renderers are the `as:` keyword's job;
  this facet is block-only.)
- `filter` — a like-spec (below) or a `{ |scope, value| … }` block. `filter false`
  switches a derived filter off.
- `sort` — an own-column symbol or a `{ |scope, dir| … }` block (`dir` is guaranteed
  `:asc` or `:desc`). `sort false` switches a derived sort off.

### The like-spec

One declarative mini-language for "case-insensitive contains, across these columns,
joining as needed" — shared by `filter like:` and `search_in`:

```ruby
filter like: :title                              # own column
filter like: %i[title subtitle]                  # several own columns, OR-combined
filter like: { authors: %i[name email] }         # join, explicit columns
filter like: :publisher                          # join, delegate to Publisher's search_in
filter like: [:title, { authors: :name }]        # mixed
```

The delegation form — an association name *without* columns — means "search it the way
that model defines being searched" (its `search_in`, next section). Specs contain no
SQL strings: the gem builds `left_joins` plus parameterized, wildcard-escaped `ILIKE`,
so there is nothing to sanitize and nothing to get wrong.

Filter blocks are the escape hatch; the scope they receive carries the same machinery:

```ruby
filter do |scope, value|
  scope.where(active: true).where_like({ authors: :name }, value)
end
```

If you find yourself reaching for `sanitize_sql_like`, there is a spec or `where_like`
form you should be using instead. Raw SQL in a block is possible — and then explicitly
your responsibility.

## "I want global search"

`?q=` searches through the model's `search_in` spec. The default is all own
string/text columns; declaring replaces that:

```ruby
search_in :title, :subtitle, :publisher    # :publisher delegates to Publisher's spec
search_in authors: %i[name email]          # explicit columns when you want control
search_in { |scope, q| … }                 # escape hatch, filter-block contract
```

Delegation is the idiomatic style: `search_in :publisher` means "a book is also
findable by whatever makes its publisher findable" — and stays correct when Publisher's
own definition evolves.

## "I want slugs instead of ids, and proper display names"

```ruby
label :title              # method or block; default: name → title → first string column
identify_by :slug         # default: :id
```

- **`label`** is the record's display name: links, select options, record headings.
- **`identify_by`** is the column URL params use to identify a record of this model.
  With `identify_by :slug`, a filtered URL reads `?publisher=tor-books` — and the param
  resolves via `Publisher.where(slug: 'tor-books')`, never via raw ids. No enumerable
  numeric ids in shareable URLs.

### Identity composes through associations

`label`, `identify_by` and `search_in` are not just for the model's own pages — they
define how **other** models render, link and filter it through their associations:

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
name. Declared once, where Publisher lives; correct everywhere it appears.

## "I want buttons"

Four actions exist by default: **`:new`** (for the whole collection), **`:show`**,
**`:edit`** and **`:destroy`** (per row; destroy is a DELETE with a confirm dialog).
`:show` is special: it renders only when the record isn't already reachable through a
label link in the same row — never two ways to the same page, but always at least one.
Defaults are
**self-disabling**: a derived action renders only if it is permitted
(`can?(:edit, record)` when an ability is around) *and* its conventional route
resolves — a model without RESTful routes simply gets no buttons, never a broken link.

Route resolution always tries the most specific conventional route first and falls
back outward. A collection built from an association — `crud_collection
@publisher.books` — prefers nested routes: `edit_publisher_book_path(publisher, book)`,
then `edit_book_path(book)`, then the button is omitted. Cells linking to associated
records resolve the same way: a review in a book's row tries
`book_review_path(book, review)`, then `review_path(review)`, then renders as plain
text. The label cell links to the record through the same chain (`show`, then
`:edit`); if the label field isn't part of the fieldset, there is no implicit link —
that's exactly when the derived `:show` button appears instead.

Collection actions render in the collection's header; row actions in the rightmost
column; `crud_record` shows the row actions above the definition list. Pass
`actions: false` to any helper to take over placement yourself:

```erb
<%= crud_actions @book %>    <%# the row actions of one record, as a button group %>
<%= crud_actions Book %>     <%# the collection actions %>
```

Declaring adds or refines; the block is the path, run in view context:

```ruby
action :preview, icon: 'eye' do |book|
  book_preview_path(book)
end

action :import, on: :collection, icon: 'upload' do
  import_books_path
end
```

| Keyword | Meaning | Default |
| --- | --- | --- |
| `icon:` | icon name | derived for `new/show/edit/destroy` |
| `title:` | button text | i18n lookup, humanized fallback |
| `class:` | CSS classes | from the [class map](#styling) |
| `confirm:` | `true` or a message | `true` for `:destroy`, else off |
| `method:` | HTTP method | `:delete` for `:destroy`, else GET |
| `on:` | `:row` or `:collection` | `:row` (`:new` is `:collection`) |
| `if:` | permission, see [Permissions](#only-admins-should-see-purchase-prices) | `can?(name, record)` if available |

When a whole actions cell needs fully custom markup, a fieldset names a partial
instead of a list — it receives `record` (everything visual is a partial, see
[Extending](#extending)):

```ruby
fieldset :index, %i[cover title price], actions: 'books/actions'
```

## "I want different tables on different pages"

Any number of named fieldsets; the surface picks one:

```ruby
fieldset :default,   %i[cover title genre price publisher]
fieldset :catalog,   %i[cover title authors price published_on active],
         actions: %i[preview edit destroy]
fieldset :compact,   %i[title price]
```

```erb
<%= crud_collection @books, fieldset: :catalog %>
<%= crud_record @book, fieldset: :compact %>
<%= crud_filter Book, fieldset: :catalog %>
```

Resolution rules, all of them:

- `crud_collection` uses `:index` if declared, `crud_record` uses `:show` if declared;
  both fall back to `:default` (which starts as "all fields + default actions").
- An explicitly requested fieldset must exist — `fieldset: :catalogue` raises, listing
  the fieldsets that do (typo protection). So does a fieldset referencing an unknown
  field or action, at boot.
- Filterability follows the fieldset: **you can only filter and sort what you can
  see.** A curated table ignores params for fields it doesn't show — otherwise hidden
  data could be probed through the URL (filter by an invisible `purchase_price` and
  bisect to its value by watching which rows survive). When a surface should offer
  *more* filters than columns, say so explicitly:

  ```ruby
  fieldset :index, %i[cover title price], filters: %i[genre published_on]
  ```

  `filters:` extends the fieldset's own fields; `crud_filter` renders all of them.

Layout is a separate axis from field selection — the same fieldset can feed different
layouts:

```erb
<%= crud_collection @books, fieldset: :catalog, as: :table %>   <%# default %>
```

v1 ships `:table`. The layout registry is open — a `:list`, `:cards` or `:map` layout
plugs in without touching any model (see [Extending](#extending)).

## "Only admins should see purchase prices"

```ruby
attribute :purchase_price, if: -> { can?(:manage, Book) }
attributes :purchase_price, :shop_margin, if: :manage      # same, for several fields
```

`if:` takes a callable, evaluated in a context where `can?` works (the view when
rendering; a thin wrapper around the ability when filtering). It is called with the
record — `it` in a plain block, as in `if: -> { it.draft? }` on an action — and with
`nil` for column-level decisions, which by nature cannot depend on a single row.
Zero-arity lambdas like the one above work too (the gem checks arity). The symbol form
is sugar for exactly that `can?` lambda — it requires a `can?` provider (CanCanCan or
anything with the same interface); the gem itself depends on none.

A field hidden by permission is hidden **everywhere, including the query layer**: its
URL params are inert for that user. There is no way to filter by a column you're not
allowed to see.

## "I have 50,000 books" — pagination and the manual query

By default `crud_collection` reads the request params itself, builds the query, applies
it to the relation you pass, and renders **everything that matches**. For large tables,
take the query into your own hands — the explicit form of what the helper does
automatically:

```ruby
# controller
@query = CrudComponents::Query.new(Book, params, fieldset: :catalog, ability: current_ability)
@books = @query.apply(Book.accessible_by(current_ability)).page(params[:page])  # kaminari/pagy
```

```erb
<%= crud_collection @books, query: @query %>   <%# pass query: ⇒ records are already filtered %>
<%= paginate @books %>
```

Everything stays an ActiveRecord relation, so any paginator and any pre-existing scope
compose naturally. The manual query is also how you get the filtered relation for
counts, CSV exports, or charts.

`page` and `per` are reserved params (alongside `q`, `sort`, `dir`): a built-in
opt-in pager for the automatic mode is designed for a later version, and reserving the
names now keeps URL semantics stable.

### Several collections on one page

Auto mode reads the shared, flat request params — so two auto collections on one page
would answer to the same `?sort=…` and `?q=`. Two ways out:

- **`query: false`** — a *static* collection: no filter row, no sort links, params
  ignored. Usually what a secondary table wants anyway ("books by this publisher",
  embedded on the publisher page).
- **`param_prefix:`** — a flat param namespace of its own:
  `crud_collection @books, param_prefix: :books` reads `?books_title=…`, `?books_q=…`,
  `?books_sort=…` and ignores everything unprefixed. URLs stay flat and shareable.

## Mental model — the recap

**Rule zero: everything works untouched; declarations only improve.** The field set is
always *all* derived columns/associations plus declared computed fields. Curation is
exclusively the job of fieldsets.

The whole DSL:

| Declaration | Role |
| --- | --- |
| `attribute` / `attributes` | improve one/several fields (model-global) |
| `render` / `filter` / `sort` | facets inside an `attribute` block — override exactly one derived behavior |
| `label`, `identify_by` | identity: display name; the column URL params resolve |
| `search_in` | the model's text identity (`?q=`, and what delegation expands to) |
| `action` | buttons, per row or per collection |
| `fieldset` | a named *selection* of fields and actions |

Three ideas organize it:

1. **Derived vs. declared — per facet.** Everything Rails knows is derived. A declared
   facet overrides that facet only; the rest stays derived.
2. **Definition vs. selection.** `attribute`/`action` define once, model-globally;
   `fieldset` selects per surface. Never visibility flags on definitions.
3. **Identity composes through associations.** `label` + `identify_by` + `search_in`
   define how other models render, link and search this one. Declare once, correct
   everywhere.

And one uniform query rule:

> **A URL param is applied iff it names a filterable field of the fieldset in play
> that the current user may see (or one of the reserved params `q`, `sort`, `dir`,
> `page`, `per`). Everything else never reaches SQL.**

### The combination table

Keyed by what a field *is* — with zero config, every row applies without declarations.

| Field kind | Rendered as | Filter control | Query behavior | Sortable |
| --- | --- | --- | --- | --- |
| string column | text | text input | `ILIKE %v%`, wildcards escaped | yes |
| text column | truncated in collections, line breaks preserved on records | text input | `ILIKE %v%`, wildcards escaped | yes |
| numeric column | number (`as: :number` for `unit:`/`digits:`) | min–max pair | `_geq`/`_leq` ranges, plus `?field=v` exact; unparsable ignored | yes |
| date / datetime column | localized | from–to pair | whole-day-inclusive ranges, plus exact day | yes |
| boolean column | ✓/✗ icon | any/yes/no select | cast & validated; invalid ignored | yes |
| enum | badge, i18n'd | select of enum keys | validated against the enum | yes |
| json column | pretty-printed `<pre>` (rouge-highlighted if available) | — | — | no |
| Active Storage attachment | image thumb (larger on records) | — | — | no |
| `belongs_to` | nil-safe link via target's `label` | ≤ 250 records: select valued by target's `identify_by`; above: text input over target's `search_in` | `where(assoc: Target.where(identify_by => v))`, or delegated ILIKE | v2 |
| `has_many` / habtm | truncated list of links ("a, b +3 more") | off by default; opt-in `filter like: :authors` | delegated joins + ILIKE | no |
| public model method | by value type | — | — | — |
| `render` block / `as:` | as declared | — | — | — |
| … + `filter` facet | | text input | like-spec / block | — |
| … + `sort` facet | | | | yes |

The bottom rows have empty query cells for a principled reason: filtering and sorting
run in SQL, and a Ruby-computed value has no SQL meaning until a facet gives it one.

## URL and security model

The URL is the state: plain GET forms and links, `data-turbo-action="advance"`,
shareable. Flat params:

| Param | Meaning |
| --- | --- |
| `?title=ruby` | filter a field (text/enum/boolean/belongs_to) |
| `?price=12` / `?published_on=2026-01-01` | exact match (number / single day) |
| `?price_geq=10&price_leq=20` | ranges (numeric, date; dates whole-day-inclusive) |
| `?q=tolkien` | global search through `search_in` |
| `?sort=title&dir=desc` | sorting; composes with active filters |

What holds, by construction — encoded as tests, not conventions:

1. **Permissions come first.** A permission-gated field is invisible *and* unfilterable
   for users without the permission; the param whitelist is permission-aware.
2. **Unknown and unseen params are inert.** Only the current fieldset's filterable
   fields (plus its declared `filters:`) are ever read from the URL — a column that
   exists but isn't part of the surface, or is permission-gated, never reaches SQL.
   Hidden data cannot be probed through filters or sorting.
3. **No injection through `sort`/`dir`**: `sort` resolves against sortable fields only
   (`?sort=title; DROP TABLE books` produces no ORDER BY at all); `dir` is validated
   against `asc`/`desc`.
4. **No injection through values**: LIKE wildcards (`%`, `_`) are escaped in every
   gem-generated pattern; enum and boolean values are validated and invalid ones
   ignored; belongs_to params resolve via the declared `identify_by` column,
   parameterized.
5. **No injection through specs**: like-specs contain column names you wrote and no
   user-controlled SQL. Only hand-written SQL in escape-hatch blocks is your
   responsibility — and `where_like` exists so you rarely write any.

## Performance defenses (on by default)

- Associations of visible fields — `belongs_to` *and* `has_many` — are eager-loaded.
- belongs_to filter selects switch to a text input (over the target's `search_in`)
  beyond `config.select_limit` (default 250); autocomplete is designed for a later
  version.
- Long text truncates in collections; full value on the record page.
- No pagination in automatic mode yet — pass a bounded scope or use the
  [manual query](#i-have-50000-books--pagination-and-the-manual-query) for big tables.

## No JavaScript required

Everything works with JavaScript disabled: filtering and sorting are plain GET forms
and links; the standalone filter form has a real submit button; the inline filter row
submits on Enter and via a visible button. (The inline row lives in `<thead>`; its
inputs bind to an external form via the HTML `form` attribute.)

On top of that baseline there is exactly **one optional Stimulus controller**: it
strips empty params on submit (clean URLs) and auto-submits selects in the inline row
only — the standalone filter form never auto-submits, since users compose several
filters there. `bin/rails generate crud_components:install` copies it into your app;
the gem itself has no JS dependency and no build-pipeline integration.

## Turbo Streams

Rows carry `dom_id`s and render independently. Rails' own `broadcasts_refreshes` in
the model plus a `turbo_stream_from` subscription on the page keeps a collection live.
The gem ships no streaming machinery — its markup is simply stream-friendly.

## i18n

Headers via `human_attribute_name` (computed fields included); every gem string is
looked up with a `t(..., default:)` fallback. Zero locale setup works; full
translation is possible.

## Styling

The gem ships **no CSS** and produces markup meant to look native in the host app —
Bootstrap 5 class names by default, concentrated in one overridable class map:

```ruby
# config/initializers/crud_components.rb  (created by `rails g crud_components:install`)
CrudComponents.configure do |config|
  config.css.table  = 'table table-sm table-hover'
  config.css.button = 'btn btn-outline-dark'
  config.css.badge  = 'badge text-bg-secondary'
  config.select_limit = 250    # belongs_to filter: select → text input threshold
end
```

For structural changes, override the markup itself — see Extending. Swapping the CSS
framework entirely means a class map plus a handful of partials, never a fork.

## Extending

Everything visual is a partial, and a file at the same path in your app wins (standard
Rails view-path precedence — the same mechanism as Devise or Kaminari views). That one
rule is the entire extension API; there are no registries.

**Restyle the surfaces.** `rails g crud_components:views` copies the gem's partials
(`app/views/crud_components/…`) into your app for editing.

**Add a field renderer.** A renderer named `:stars` is the partial
`crud_components/fields/_stars.html.erb`, receiving `value`, `record`, `field` and
`surface` (`:collection` or `:record` — that's how `:image` picks a small variant in
tables and a larger one on record pages):

```erb
<%# app/views/crud_components/fields/_stars.html.erb %>
<%= '★' * value.to_i %>
```

```ruby
attribute :rating, as: :stars
```

The built-in renderers are the same kind of partial at the same paths — shadow one in
your app to change it everywhere.

**Add a layout.** A layout named `:cards` is the partial
`crud_components/layouts/_cards.html.erb`, receiving one `collection` presenter with
resolved fields, rows, query state and sort URLs — a custom layout never reimplements
filtering or whitelisting:

```erb
<%= crud_collection @books, as: :cards %>
```

## API reference

### Helpers (the everyday API)

```ruby
crud_collection(records_or_model, fieldset: nil, as: :table, query: nil,
                param_prefix: nil, actions: true)
crud_record(record, fieldset: nil, actions: true)
crud_filter(model, fieldset: nil, query: nil, param_prefix: nil)
crud_actions(record_or_model)
```

A bare model class is sugar for its `all` relation. `query:` is a tri-state:

- *not given* — auto mode: the helper builds the query from the request params (and
  `current_ability` when defined) and applies it to the records;
- *a `Query`* — manual mode: the records are taken as already filtered; the query
  supplies control state, and the helper inherits its fieldset (no need to say it
  twice);
- *`false`* — static: no filter row, no sort links, params ignored.

### DSL (inside `crud_structure do … end`)

```ruby
label(method = nil, &block)
identify_by(column)                               # default :id
search_in(*spec) | search_in { |scope, q| … }     # default: own string/text columns
attribute(name, as: nil, if: nil, **renderer_options, &block)
attributes(*names, **shared_options)
  # bare block (arity 1)  = render markup
  # facet block (arity 0) = render / filter / sort declarations
action(name, icon:, title:, class:, confirm:, method:, on:, if:, &path_block)
fieldset(name, fields = :all, actions: nil, filters: nil)
```

Raises at boot, each with a message that says what to do instead: `crud_structure`
declared twice; a field name that is no column, enum, association or public method;
duplicate `attribute`/`action`/`fieldset` names; fieldsets referencing unknown
fields/actions; fields named `q`/`sort`/`dir`/`page`/`per`; `filter` given both a spec
and a block; an `as:` renderer with no matching partial, or one that needs a missing
gem.

### Runtime

```ruby
CrudComponents::Query.new(model, params, fieldset: :default, ability: nil, param_prefix: nil)
                                            # #apply(scope) → relation; #active?
CrudComponents.configure { |config| … }     # css map, select_limit, defaults
```

## Dependencies

| Gem | Why |
| --- | --- |
| `activerecord` (>= 7.1) | deriving structure from AR reflection is the whole point |
| `activesupport` (>= 7.1) | core extensions, i18n |
| `actionview` (>= 7.1) | rendering (partials, helpers) |

All three ship with Rails — **the gem has no third-party runtime dependencies**.
CanCanCan, simple_form, turbo-rails, Stimulus, Bootstrap, kaminari/pagy, markdown and
highlighting gems: feature-detected or documented integration points, never required.

Development: `minitest`, `rake`, `sqlite3`, plus a minimal dummy Rails app for
component and integration tests.

## Development

```sh
bundle install
bundle exec rake test
ruby script/demo.rb     # bookstore walkthrough
```

Tests mirror the design: one file per field flavor, `dsl_validation_test.rb` for every
raising combination, `query_security_test.rb` for the URL/security model above, render
tests per surface, and one `full_integration_test.rb` against the dummy app.

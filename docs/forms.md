# Forms

`crud_form` derives a create/edit form from the same field metadata everything else uses.
The gem renders the form; **your controller saves it** — there is no gem-owned controller
and no gem-owned routes. The two are kept from drifting by a shared permit list.

```erb
<%= crud_form @book %>          <%# edit if persisted, new if not %>
```

## The permit list — why fields can't silently fail to save

The form and your strong-params both derive from the same metadata, so a field can't be
in one and missing from the other. Use the list the gem derived the form from:

```ruby
def book_params
  params.require(:book)
        .permit(*Book.crud_attribute_names(action_name.to_sym, ability: current_ability))
end
```

The classic "I added a field and it silently doesn't save" bug is structurally
impossible: the permit list *is* the form's field set, projected to param keys. For
models that don't `include CrudComponents::Model`, use
`CrudComponents.permitted_attributes(Model, action:, ability:)` — identical result.

What the list contains, per editable field:

| Field | Permit key |
| --- | --- |
| column (string/number/date/boolean/enum/text) | `:name` |
| `belongs_to` | `:publisher_id` (the foreign key) |
| habtm / has_many (ids) | `{ author_ids: [] }` |
| single attachment | `:cover` |
| `has_many_attached` | `{ images: [] }` |

Excluded automatically: `id`, `created_at`, `updated_at`, computed fields (no form
control), JSON columns (read-only in v1), `has_many` that isn't habtm, and any field that
is non-editable or not permitted for the current user (below).

## Two permission dimensions

Editing introduces a question viewing doesn't: you may *see* a field but not be allowed
to *change* it. So `editable:` sits alongside `if:`:

```ruby
attribute :slug,           editable: false       # shown read-only in the form
attribute :state,          editable: :publish     # editable only if can?(:publish, Book)
attribute :purchase_price, if: :manage            # invisible to non-managers, everywhere
```

- **`if:`** controls **visibility** — a field you can't see isn't in the form, the permit
  list, the query, or any other surface.
- **`editable:`** controls **writability** — a visible-but-not-editable field renders as
  compact read-only text and is left out of the permit list. Same callable contract as
  `if:` (symbol → `can?`, zero-arity lambda, record lambda / `it`); see
  [Security → permissions](security.md#permissions).

Because both are enforced on the permit list *and* the form, the two can never disagree:
a user who can't edit a field can neither see an input for it nor smuggle it through
params.

## Which fields, and where it submits

Form field selection falls back **action → `:form` → `:default`**:

- `fieldset :form, %i[…]` — fields for all forms.
- `fieldset :edit, %i[…]` / `fieldset :new, %i[…]` — override one form (`:update` maps to
  `:edit`, `:create` to `:new`).
- otherwise the `:default` set is used.

New vs. edit (POST vs. PATCH) and the URL are inferred from the record (`persisted?`).
Override with `url:` / `method:` when routes aren't conventional:

```erb
<%= crud_form @book, url: publisher_book_path(@publisher, @book), method: :patch %>
```

## Rendering: simple_form

Forms render through [simple_form](https://github.com/heartcombo/simple_form) (a runtime
dependency). The gem decides *which* fields appear, their flavor, the permit list and the
read-only/permission logic; simple_form does the markup — labels, inputs, wrappers,
required marks, and **per-field error display** — through your app's wrapper config
(Bootstrap by default; the community ships Tailwind/Bulma/Foundation). So the gem's forms
inherit your design system automatically, and there's no hand-rolled `field_with_errors`
to fight.

The flavor → simple_form mapping (`Presenters::Form#simple_input`):

| Field | simple_form call |
| --- | --- |
| string / number / date / datetime | `f.input :name` (type inferred from the column) |
| text | `f.input :name, as: :text` |
| boolean | `f.input :name, as: :boolean` |
| enum | `f.input :name, collection: …` (your i18n'd keys) |
| `belongs_to` | `f.association :publisher, collection: …` — submits the real **id** (forms are POST bodies, not shareable URLs, unlike filters which use `identify_by`) |
| habtm | `f.association :authors, as: :select, multiple` + a chip-picker hook (see below) |
| single attachment | `f.input :cover, as: :file` |
| read-only (not editable) | rendered by the gem as a compact `label: value`, not submitted |

Errors: simple_form shows per-field errors inline; the gem adds a summary for base
errors (`errors[:base]`) and any error on a column the form doesn't show, so "fix N
errors" is never a dead end (see [validation errors](#validation-errors) below).

To customise an input, override the *field's* simple_form options by replacing
`_form.html.erb` (it's a partial) — or use simple_form's own wrapper/component config,
which the gem inherits.

## Associations and attachments

- **belongs_to** → a select valued by record id; permit `:publisher_id`.
- **habtm** → a `<select multiple>` baseline (works no-JS, scales) that carries
  `data-controller="crud-tokens"`; permit `{ author_ids: [] }`. The optional `crud-tokens`
  Stimulus controller (shipped by `crud_components:install`) replaces the select in place
  with a **chips-list + "add" dropdown** — the select stays the hidden source of truth, so
  the form submits identically with or without JS. This handles up to a few hundred options
  client-side.
  - **Thousands of options?** That needs an autocomplete querying *your* endpoint (the gem
    owns no controllers). Override the habtm input — replace `_form.html.erb`, or set a
    different `as:`/`input_html` for that field — and point your library (tom-select,
    select2, a Stimulus+fetch) at your route. The param shape (`author_ids[]`) stays the
    same, so any library drops in.
- **single attachment** → a file field; permit `:cover`.
- **has_many_attached** → a file field with `multiple`; add/remove of *existing* items is
  a later version.

## Validation errors

Validations live on your model; the gem re-renders the form correctly after a failed
save. Your controller renders the form again with the invalid record and a 422:

```ruby
def update
  @book = find_book
  if @book.update(book_params)
    redirect_to @book
  else
    render :edit, status: :unprocessable_entity   # crud_form @book re-renders with errors
  end
end
```

On that re-render:

- **Entered values are kept** — `simple_form_for` reads the in-memory record, which holds
  the submitted (invalid) attributes, so nothing the user typed is lost.
- **Per-field errors** render inline (simple_form, via your wrapper config — Bootstrap's
  `.invalid-feedback` by default).
- **Base / non-field errors** — `errors[:base]`, or errors on a column the form doesn't
  show — render in a summary at the top, so a counted error always has somewhere to be
  fixed.

## Scope (v1)

Single record; flat columns plus belongs_to and habtm. No nested forms /
`accepts_nested_attributes` and no JSON-column editing in v1.

## A complete example

```ruby
# app/models/book.rb
crud_structure do
  attribute :slug,  editable: false
  attribute :active, editable: :manage
  attribute :purchase_price, if: :manage
  fieldset :form, %i[title subtitle slug blurb price purchase_price pages
                     published_on genre active publisher authors cover]
end
```

```ruby
# app/controllers/books_controller.rb
def new   = (@book = Book.new)
def edit  = (@book = Book.find_by!(slug: params[:id]))
def create
  @book = Book.new(book_params)
  @book.save ? redirect_to(@book) : render(:new, status: :unprocessable_entity)
end
def update
  @book.update(book_params) ? redirect_to(@book) : render(:edit, status: :unprocessable_entity)
end

private

def book_params
  params.require(:book).permit(*Book.crud_attribute_names(action_name.to_sym, ability: self))
end
```

```erb
<%# app/views/books/edit.html.erb %>
<%= crud_form @book %>
```

`slug` shows read-only; `active` is an input only for managers (read-only otherwise);
`purchase_price` is absent entirely for non-managers — in the form *and* the permit list.

See also: [Fields & rendering](fields.md) · [Views](views.md) · [Security](security.md) ·
[Extending](extending.md).

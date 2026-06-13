# crud_components — agent & developer notes

Declarative CRUD UI for ActiveRecord models. README.md is the front door (mental
model + tour); `docs/` holds the in-depth reference (`fields`, `views`, `forms`,
`security`, `extending`). Together they are the spec — written before/with the
implementation and kept in sync.

## Layout

| Where | What |
| --- | --- |
| `lib/crud_components/` | Builder (DSL) → immutable Structure; `fields/` one class per combination-table row; Query + LikeSpec (the safe ILIKE mini-language); presenters; RouteResolver |
| `app/views/crud_components/` | everything visual: `layouts/` (collection layouts), `fields/` (renderers), `filters/` (controls), record/filter/actions partials. Apps override by shadowing paths |
| `lib/generators/crud_components/` | `install` (initializer + optional Stimulus controller), `views` (copy partials) |
| `test/` | one concern per file: `dsl_validation_test`, `structure_test`, `like_spec_test`, `query_security_test` (the security model as spec), `full_integration_test` (no-JS, end-to-end) |
| `test/dummy/` | bookstore app: test harness **and** manual playground |

## Commands

| Command | What |
| --- | --- |
| `bundle install` | once (uses rbenv's current Ruby, needs >= 3.2) |
| `bundle exec rake test` | the whole suite |
| `cd test/dummy && bin/rails db:schema:load db:seed` | prepare the playground DB |
| `cd test/dummy && bin/rails server` | run the playground (Bootstrap/Turbo/Stimulus via CDN, no build step) |

## Conventions

- README/docs-first: a behavior change updates the relevant doc (README for the
  mental model / tour; the matching `docs/*.md` for the detail) in the same commit.
- Every raising DSL combination has a test in `dsl_validation_test.rb`; every
  security guarantee has one in `query_security_test.rb`.
- Runtime deps: activerecord/activesupport/actionview + simple_form (forms only).
  CanCanCan, Turbo, Stimulus, markdown/rouge gems: feature-detected only.
- Renderers and layouts are partials resolved by naming convention — no
  registries. Renderer locals: `value`, `record`, `field`, `surface`.

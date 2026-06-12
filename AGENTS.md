# crud_components — agent & developer notes

Declarative CRUD UI for ActiveRecord models. README.md is the spec — it was
written before the implementation and the code is built to match it.
DESIGN.md holds the decision history and host-app-specific material.

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

- README-first: behavior changes update README.md in the same commit.
- Every raising DSL combination has a test in `dsl_validation_test.rb`; every
  security guarantee has one in `query_security_test.rb`.
- No runtime dependencies outside Rails (activerecord/activesupport/actionview).
  CanCanCan, Turbo, Stimulus, markdown/rouge gems: feature-detected only.
- Renderers and layouts are partials resolved by naming convention — no
  registries. Renderer locals: `value`, `record`, `field`, `surface`.

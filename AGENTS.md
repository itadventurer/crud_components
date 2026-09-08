# crud_components — agent & developer notes

Declarative CRUD UI for ActiveRecord models. README.md is the front door (mental
model + tour); `docs/` holds the in-depth reference (`fields`, `views`, `forms`,
`security`, `extending`, `admin`). Together they are the spec — written before/with
the implementation and kept in sync.

`CLAUDE.md` in this directory is a symlink to this file, and so is every
`CLAUDE.md` next to a nested `AGENTS.md`: Claude Code discovers `CLAUDE.md`,
other tools discover `AGENTS.md`, and there is only one file to maintain.

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
| `bundle exec rake test` | the test suite |
| `bundle exec rubocop` | the linter; `-a` fixes what it safely can |
| `bundle exec rake` | both, which is what CI runs |
| `cd test/dummy && bin/rails db:schema:load db:seed` | prepare the playground DB |
| `cd test/dummy && bin/rails server` | run the playground (Bootstrap/Turbo/Stimulus via CDN, no build step) |

The native libvips and poppler are optional: without them the playground turns
Active Storage variants off and attachments render as icon + filename. One CI
leg runs that way.

## This repository is public

It is on GitHub and RubyGems, so **nothing from a private project may appear
here** — not in code, comments, tests, docs, the CHANGELOG, commit messages or
pull request descriptions. That includes private domain models and method names,
production error messages, internal hostnames and internal repository paths.

Use the **bookstore world** of `test/dummy/` instead: `Book`, `Publisher`,
`Author`, `Review`, `Comment`, with fields like `title`, `name`, `shop_margin`,
`display_title`. When a bug arrives from a private application, abstract the
cause and describe it purely in those terms — "a `belongs_to` whose target labels
itself with a method, e.g. `label :display_title` on `Publisher`" — rather than
"production threw …" or a link to an internal merge request. Grep the diff and
the description for leaks before pushing.

## Conventions

- README/docs-first: a behavior change updates the relevant doc (README for the
  mental model / tour; the matching `docs/*.md` for the detail) in the same commit.
- Everything inside a repository file is English: code, comments, docs, and here
  also commit messages and pull request prose, since the audience is public.
- Every raising DSL combination has a test in `dsl_validation_test.rb`; every
  security guarantee has one in `query_security_test.rb`.
- RuboCop runs in CI and must be clean. `.rubocop.yml` holds the deliberate
  decisions, each with the reason next to it; `.rubocop_todo.yml` holds what is
  merely not cleaned up yet, with a count per cop. Put a new exception in the
  first file only when it is a decision — otherwise fix the code, or let
  `--auto-gen-config` extend the second and burn it down later.
- Runtime deps: activerecord/activesupport/actionview + simple_form (forms only).
  CanCanCan, Turbo, Stimulus, markdown/rouge gems: feature-detected only.
- Renderers and layouts are partials resolved by naming convention — no
  registries. Renderer locals: `value`, `record`, `field`, `surface`.

## Pull requests

- Work on a branch off current `origin/main`, one topic per pull request.
- **Never merge a pull request yourself and never enable auto-merge.** Prepare it
  to the point of merging — conflicts resolved, branch pushed, CI green — then
  say it is ready and stop.
- Never force-push a branch that is under review; bring changes in by merging the
  parent branch upward or with a follow-up pull request.
- Answer review comments, do not resolve the threads.

**Stacked pull requests merge along the chain**, base into head, pair by pair.
Merging the same commit into each branch separately produces diverging trees and
therefore conflicts between neighbouring pull requests that had none before. And
a fix belongs in the pull request that introduced the defect, then travels
forward — put it only at the top of the stack and every earlier one stays red.

The tell is a pull request that suddenly reports **"no checks reported"**: GitHub
cannot build `refs/pull/N/merge` for a conflicting branch, so it never starts the
`pull_request` workflow at all — no red cross, just nothing.
`gh pr view N --json mergeable,mergeStateStatus` then says `CONFLICTING`/`DIRTY`.
After resolving, the run is still missing until a new event arrives;
`gh pr close N && gh pr reopen N` is enough, but only once the branch is actually
clean.

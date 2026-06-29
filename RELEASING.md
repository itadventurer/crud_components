# Releasing

Releases are automated: **publish a GitHub Release and CI pushes the gem to
RubyGems** via [Trusted Publishing](https://guides.rubygems.org/trusted-publishing/)
(OIDC — no API key stored anywhere). See `.github/workflows/gem-push.yml`.

## One-time setup

On [rubygems.org](https://rubygems.org) → the `crud_components` gem → **Trusted
Publishers** → *Add* a GitHub Actions publisher:

- Repository: `itadventurer/crud_components`
- Workflow: `gem-push.yml`

For the **very first** publish (the gem doesn't exist on RubyGems yet), use
RubyGems' *“Create a pending trusted publisher”* flow instead, then push the
first release — or do one manual `gem push` to create the gem, then add the
publisher above. After that, every release is hands-off.

(The old `RUBYGEMS_API_KEY` secret is no longer used and can be deleted.)

## Cutting a release

1. **Bump the version and close the changelog.** Set the new version in
   `lib/crud_components/version.rb`, and in `CHANGELOG.md` rename the
   `## Unreleased` heading to `## vX.Y.Z — YYYY-MM-DD`, adding a fresh empty
   `## Unreleased` above it. Open as a normal PR; merge to `main`.

2. **Publish the release** for the matching tag — the workflow expects `vX.Y.Z`
   to equal the version in `version.rb` — using that version's changelog section
   as the notes:

   ```bash
   notes=$(awk '/^## v[0-9]/{ if (seen) exit; seen=1; next } seen' CHANGELOG.md)
   gh release create v0.1.0 --title v0.1.0 --notes "$notes"
   ```

   (or use the GitHub UI → *Draft a new release* → pick the tag, and paste that
   section.) Publishing fires the workflow, which runs the tests, builds the gem,
   attaches a build-provenance attestation, and pushes it.

That's it — `gem-push.yml` does the build + push; you never touch credentials.

### Versioning

[SemVer](https://semver.org): new backward-compatible features → minor (`0.x`),
bug-fixes → patch. Release notes are the version's section in `CHANGELOG.md` —
keep its `## Unreleased` list current as you merge user-facing PRs, and step 1
turns it into the release.

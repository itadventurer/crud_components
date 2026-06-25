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

1. **Bump the version** in `lib/crud_components/version.rb` and move the
   `## [Unreleased]`/top section of `CHANGELOG.md` under the new version number.
   Open it as a normal PR; merge to `main`.

2. **Publish the release** for the matching tag — the workflow expects `vX.Y.Z`
   to equal the version in `version.rb`:

   ```bash
   gh release create v0.2.0 --title v0.2.0 \
     --notes "$(awk '/^## \[0.2.0\]/{f=1;next} /^## \[/{f=0} f' CHANGELOG.md)"
   ```

   (or use the GitHub UI → *Draft a new release* → pick the tag → paste the
   CHANGELOG section). Publishing fires the workflow, which runs the tests,
   builds the gem, attaches a build-provenance attestation, and pushes it.

That's it — `gem-push.yml` does the build + push; you never touch credentials.

### Versioning

[SemVer](https://semver.org): new backward-compatible features → minor (`0.x`),
bug-fixes → patch. The CHANGELOG is grouped `Added` / `Changed` / `Fixed`.

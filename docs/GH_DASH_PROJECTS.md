# gh-dash Projects v2 integration

The declarative CLI environment takes `gh-dash` from a fixed, known-good
nixpkgs revision and applies the Projects-v2 patch there. Home Manager
installs that package through its native `programs.gh.extensions` support, so
`gh dash` uses the same patched package without a custom extension symlink,
activation hook, or local copy. GitHub remains the source of truth for Project
metadata and mutations.

The pinned package is used for every NixOS host, including hosts that use a
different nixpkgs input for the rest of the system. A normal `nix flake update`
does not move this package. Updating `gh-dash` is an explicit pin bump followed
by patch regeneration or rebase and full package, source, and interactive
validation.

Project enrichment and field columns are opt-in in
`~/.config/gh-dash/config.yml`:

```yaml
defaults:
  layout:
    projects:
      enabled: true
      fields:
        - name: Status
          project: infrastructure
          width: 18
        - name: Priority
          project: joshan-kana/1
          width: 14
        - fieldId: PVTF_example
          width: 20
```

`name` selects a runtime-discovered Project field by name. `fieldId` is the
stable escape hatch when a Project contains duplicate field names; the two
selectors must not be silently merged. `project` is optional and may be a
unique Project title, number, node ID, `owner/number`, or `owner/title`.
Unqualified title/number selectors that match multiple memberships render an
ambiguity message and require an owner-qualified selector. Project node IDs
are the canonical identity internally, so Projects with the same number under
different owners remain distinct.

When an issue or pull request is selected, every Project membership and its
available values appear in the preview. Memberships are deterministic; owner
information is shown when titles or numbers collide. Press `E` to choose a
Project, choose a field, and then choose a single-select option or enter a
text/number/date/iteration value. `P` retains gh-dash's preview-position
binding. The editor can be rebound with the `editProject` issue/PR builtin.

Project values support single-select, text, number, date, iteration, users,
labels, and repository-related display values. Unsupported or empty values
degrade to readable empty/display-only output. A successful mutation refetches
the authoritative Project item, including fields that were previously unset;
clearing uses GitHub's `clearProjectV2ItemFieldValue` mutation. No local
database, daemon, or sync process is used.

With enrichment disabled, normal gh-dash issue/PR queries remain unchanged.
When enabled, normal pages are fetched first and then enriched with bounded
Project-item batches. If Project access is missing or enrichment fails, the
ordinary page remains usable without Project metadata. Editing still requires
the relevant GitHub permissions.

The downstream patch is stored at
`patches/gh-dash/projects-v2.patch` and applied by
`overlays/gh-dash-projects.nix`. Future updates should bump the pinned
known-good nixpkgs revision deliberately, regenerate or rebase the patch from
pristine upstream, run the gh-dash tests, validate native `gh dash`, and repeat
the authenticated smoke tests before proposing smaller pieces upstream.

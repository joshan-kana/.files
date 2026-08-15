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

Issue sections follow GitHub search pagination through the actual result total;
`issuesLimit` controls the request page size, not a hard row cap. This keeps a
default view with more than one search page complete without choosing an
arbitrary maximum. Pull-request sections retain gh-dash's existing paging
behavior.

List enrichment is staged. It first fetches Project membership identity, then
fetches each unique Project's field schema once per refresh generation, and
finally asks only for configured visible columns using variable-backed
`fieldValueByName` selections. A zero-column configuration therefore does not
request field values. Duplicate field names remain ambiguous; a configured
field ID takes the targeted field-value fallback needed to resolve that
collision.

When an issue or pull request is selected, the Project block first shows an
explicit loading state while the authoritative full membership/value request is
debounced by 200 ms. It then replaces that block atomically with the complete
GitHub result, or shows a clear unavailable state while leaving the ordinary
issue/PR preview usable. A generation check prevents a stale response from
overwriting the current selection. Memberships are deterministic; owner
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

Project enrichment is optional and independent of ordinary issue/PR fetching.
Issue sections now follow GitHub search pagination through the actual result
total regardless of whether Project enrichment is enabled; `issuesLimit`
controls the request page size rather than a hard row cap. Pull-request
sections retain gh-dash's existing paging behavior. When enabled, the loaded
rows are then enriched with bounded Project-item batches. Project metadata is
cached and coalesced only in the running process and only within one refresh
generation. gh-dash's normal scheduled refetch cadence starts a new generation,
and `r`/`R` force an immediate authoritative Project refresh alongside ordinary
issue/PR data. There is no disk cache, TTL freshness policy, local database, or
stale-value fallback. If Project access is missing or enrichment fails, the
ordinary issue/PR data remains usable without Project metadata. Editing still
requires the relevant GitHub permissions.

The downstream patch is stored at
`patches/gh-dash/projects-v2.patch` and applied by
`overlays/gh-dash-projects.nix`. Future updates should bump the pinned
known-good nixpkgs revision deliberately, regenerate or rebase the patch from
pristine upstream, run the gh-dash tests, validate native `gh dash`, and repeat
the authenticated smoke tests before proposing smaller pieces upstream.

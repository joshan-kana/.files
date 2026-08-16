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
labels, repository, multi-select, pull-request, reviewer, milestone, and issue
field display values. Pull-request links include repository and PR number/title
when GitHub provides them. Unknown future union members are retained as a
readable display-only placeholder and do not invalidate the complete preview.
Display support is broader than edit support: `E` is available only for the
mutation-supported text, number, date, iteration, and single-select field
types; linked PR, reviewer, milestone, issue-field, multi-select, user, label,
and repository values remain read-only. A successful mutation refetches the
authoritative Project item, including fields that were previously unset;
clearing uses GitHub's `clearProjectV2ItemFieldValue` mutation.

Project enrichment is optional and independent of ordinary issue/PR fetching.
The first ordinary issue/PR page is returned before Project work begins, and
later pages continue through GitHub's actual result total; `issuesLimit`
controls request page size rather than a hard row cap. A persistent,
versioned presentation cache stores Project-only metadata at
`os.UserCacheDir()/gh-dash/projects/cache-v1.json` (for example,
`~/Library/Caches/gh-dash/projects/cache-v1.json` on macOS). Entries are
isolated by GitHub host, authenticated account, content node ID, and configured
column shape. The cache contains no credentials or tokens, uses atomic
temporary-file replacement, and may prune entries unused for roughly 30 days.
Pruning is housekeeping only and never decides freshness.

Every process launch with Projects enabled, every native scheduled refetch, and
both `r` and `R` performs a live GitHub Project membership/fingerprint read.
The cache is therefore never authoritative freshness. A matching membership
set plus `ProjectV2Item.updatedAt` and `ProjectV2.updatedAt` changes cached
presentation from `cached-unverified` to `live-verified` without schema/value
refetches. Changed memberships or fingerprints selectively refetch the needed
schema/values. The UI distinguishes `cached-unverified`, `live-verified`,
loading, and live-error states; offline or rate-limited Project access leaves
ordinary issue/PR rows usable and keeps cached values visibly unverified.
Editing requires live-verified item and schema state. No daemon, launch agent,
SQLite database, custom sync process, TTL freshness policy, fast poller, or
stale-as-authoritative fallback is used.

Every initial section load and native section refetch re-enters the selected
Project-preview lifecycle. A cached complete preview can appear immediately
with a verifying marker; the debounced live fingerprint/full fetch then either
verifies it or atomically replaces it. List-only Status/Priority/Area/Kind
values cannot masquerade as complete preview metadata. Failure is shown as a
live error while any retained cache remains visibly unverified. This lifecycle
is independent of ordinary PR detail enrichment, so revisiting an already
enriched PR still contacts GitHub for authoritative Project validation.
Configured visible Project fields are requested for PR list rows as well as
issue rows; repository/branch view PR lookups do not spend Project calls when
those columns are not rendered.

The downstream patch is stored at
`patches/gh-dash/projects-v2.patch` and applied by
`overlays/gh-dash-projects.nix`. Future updates should bump the pinned
known-good nixpkgs revision deliberately, regenerate or rebase the patch from
pristine upstream, run the gh-dash tests, validate native `gh dash`, and repeat
the authenticated smoke tests before proposing smaller pieces upstream.

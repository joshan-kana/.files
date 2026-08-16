# gh-dash native GitHub patches

`.files` applies two small downstream patches to the pinned gh-dash package.
GitHub remains authoritative: gh-dash only presents native state and the
Projects cache is disposable presentation data.

## Upstream base

The package is gh-dash 4.25.2 from upstream commit
`a613ef744c99ef8d8ead33467813c6ee6086af52`, the source behind the v4.25.2
tag. The Nix overlay pins the nixpkgs revision that supplies this version;
patches are regenerated from a pristine checkout of that exact source.

## Patch order

1. `patches/gh-dash/projects-v2.patch`
2. `patches/gh-dash/issue-relationships.patch`

The relationship patch is applied second because it extends the Project-aware
issue and preview models.

## Projects v2

Projects are opt-in through `defaults.layout.projects`. Configured fields are
discovered from live Project schemas and can be shown on issue and PR rows and
in selected previews. The existing editor supports keyboard navigation,
single-select and supported scalar values, including clearing a value. Empty
configured values remain visible as an unset value. `E` is the default editor
binding and can be rebound with `editProject`.

The versioned cache is host/account/content/configuration isolated and is only
a presentation optimization. Cached values are visibly unverified until a
live membership/schema read succeeds; writes require live-verified state and
successful mutations are followed by an authoritative refetch. Missing,
corrupt, or stale cache data causes refetch rather than GitHub reconstruction.

## Native issue relationships

Issue rows and previews expose native GitHub parent, sub-issue, blocked-by,
and blocking relationships. The compact row glyphs are `↳` (parent), `⊞`
(sub-issues), `⇠` (blocked by), and `⇢` (blocking). The preview includes
repository-qualified identifiers, titles, and open/closed state, plus the
sub-issue completion summary when GitHub provides it. Relationship failures
remain non-fatal to ordinary issue rendering.

No labels, issue-body conventions, Project fields, or local task database are
used to represent these relationships. Relationship editing is not included
in this patch revision; no write is attempted from the relationship preview.

## Nix integration

`overlays/gh-dash-native-github.nix` pins the package and applies both patches
sequentially. Home Manager installs the result through the native
`programs.gh.extensions` integration; user configuration lives in
`modules/home/cli.nix`.

## Updating gh-dash

Start from a pristine new upstream release, replay the Projects implementation
and regenerate patch one, replay the relationship implementation on top and
regenerate patch two, then run zero-fuzz patch checks, source-equivalence
checks, Go tests, formatting/lint checks, and the relevant Nix package/build
checks.

## Validation

Useful checks include running both patches from a pristine source checkout:

```sh
src=$(mktemp -d)
git clone --branch v4.25.2 --depth 1 https://github.com/dlvhdr/gh-dash.git "$src"
(cd "$src" && \
  git apply --check /path/to/.files/patches/gh-dash/projects-v2.patch && \
  git apply /path/to/.files/patches/gh-dash/projects-v2.patch && \
  git apply --check /path/to/.files/patches/gh-dash/issue-relationships.patch && \
  git apply /path/to/.files/patches/gh-dash/issue-relationships.patch && \
  git diff --check)
nix flake check --no-build --system aarch64-darwin
```

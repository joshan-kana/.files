# Package sources and updates

Package definitions, selected upstream flakes, compatibility pins and patches live under `overlays/`. Use stock nixpkgs packages by default; prefer upstream binaries or upstream flakes when the official distribution is easier to maintain. Derive the target system from `stdenv.hostPlatform` and translate vendor-specific asset names only at the package boundary.

`nix run .#system-update` selects and updates flake inputs, OCI images and generated schemas. `--all` also refreshes schemas after changing inputs; it **does not** advance patched packages or known-good compatibility pins. Flake-locked Git sources and release metadata require no duplicated version/hash table. For a separately maintained, unpatched package exposing a compatible updater, use `nix run .#system-update -- --package <attr>` to invoke `nix-update` explicitly. If that package has a custom update procedure, put it in its `passthru.updateScript` rather than adding release-discovery logic to the generic updater.

Temporary regressions in nixpkgs may use a local, known-good `builtins.getFlake` override. Keep them isolated in their own overlay so removing the workaround is a single-file change when the upstream fix has been verified. Patched packages also remain pinned until explicitly retested with their patches and relevant runtime behavior; neither type advances during routine updates. Replacing a source revision or applying a patch without testing its behavior is not evidence that an update is safe.

## Schemas

`overlays/lib/schemas/` provides shared schema-to-Nix type conversion. Prefer an existing native Nix module, otherwise read a schema directly from a locked upstream source or release. Generated-only schemas live on the `schema-artifacts` Git branch, separate from the source tree. The flake locks that branch as the non-flake `schema-artifacts` input; no second general package lockfile is needed.

`nix run .#update-schemas` updates generated schemas from the locked package sources, records the exact source revision, publishes the updated files to the artifact branch and advances its flake lock. This command works locally and in CI with ordinary Git write permission to the same repository. Evaluation checks that the schema revision exactly matches its upstream package revision. Failures retain the previous schema commit and are reported instead of silently accepting stale Nix options. No GitHub Actions workflow is required to *generate* or update schemas.

## Validation

`nix flake check --all-systems` checks pure evaluation for every configured system without building architecture-specific tooling. Tests that execute native binaries are exposed as `packages.<system>.native-validation` and must be built on the matching system (as enforced by the fleet build workflow). A successful portable check is not a substitute for native build and runtime validation.

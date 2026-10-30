# Repository structure

**Convention:** Place each change under the idea, application, or capability that owns it, not simply under the native option namespace it uses.

| Path               | Responsibility                                          |
| ------------------ | ------------------------------------------------------- |
| `flake.nix`        | Inputs, host composition, checks, and flake outputs     |
| `hosts/<host>/`    | Host entry points and genuine host-specific differences |
| `modules/`         | Shared semantic modules                                 |
| `lib/`             | Shared Nix helpers and semantic-scope machinery         |
| `overlays/`        | Non-stock packages, overrides, and upstream pins        |
| `scripts/`         | Repo and operational commands                           |
| `tests/`           | Evaluated and behavioral tests                          |
| `docs/manual/src/` | Handwritten conventions and runbooks                    |
| `docs/default.nix` | Generated reference, navigation, and mdBook assembly    |

## Registries and imports

Register a new child in the appropriate existing `default.nix`, such as `modules/server-apps/default.nix`. Keep the shared `modules/default.nix` registry as the discoverable map of semantic areas. Import the existing overlay directory in host composition and register package overlays under `overlays/default.nix`.

Use ordinary Nix module `imports = [ ... ];` when the module is a native import list. Avoid creating another competing package or module registry inside `flake.nix`.

## Shared and local ownership

Common behavior belongs in the shared semantic module. An exception specific to a host belongs to that host's configuration under the same semantic scope. Avoid copying full shared modules just to change one option.

A substantial feature can be split into files by coherent responsibilities. A directory for every tiny expression is not inherently clearer.

## Examples and checks

An application's package installation stays with its application scope; its appearance policy belongs to the theme scope; its custom package construction belongs to overlays. A runbook lives with the manual, while the facts it references are generated from evaluated state.

Review the changed paths, parent registry, and all affected hosts. For structural changes, compare the relevant evaluated derivations before and after. **Exception:** a shared capability can own cross-cutting integration for several consumers.

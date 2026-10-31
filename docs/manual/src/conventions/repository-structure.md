# Repository structure

Organize code by the capability or application that owns it. Native option namespaces do not determine file placement.

| Location           | Responsibility                                 |
| ------------------ | ---------------------------------------------- |
| `flake.nix`        | Flake inputs, outputs, composition, and checks |
| `hosts/`           | Host entry points and host-specific policy     |
| `modules/`         | Shared semantic capabilities                   |
| `lib/`             | Reusable Nix helpers                           |
| `overlays/`        | Package definitions and overrides              |
| `scripts/`         | Reusable repository and operational commands   |
| `tests/`           | Behavioral and evaluation checks               |
| `docs/manual/src/` | Human-maintained guidance and runbooks         |

## Registration and imports

Use the owning directory's existing `default.nix` to register children. Keep package registration in the overlay registry and semantic module registration in the module hierarchy. Avoid parallel registries or special-case composition in the flake when the existing mechanism suffices.

Use native module imports for ordinary native modules. A feature may span multiple files when they have coherent responsibilities; one-file wrappers and extra directories are not inherently improvements.

## Shared versus host-local

Common behavior belongs with its shared owner. Genuine differences belong to the affected host under the same semantic scope. Extend shared definitions instead of copying or replacing them to change a single option.

Keep package construction in overlays, runtime integration with the consuming capability, and appearance policy with the theme. Verify registration, imports, and affected host evaluations after structural changes.

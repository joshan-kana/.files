# Repository structure

Organize code by the capability or application that owns it. Native option namespaces do not determine file placement.

| Location    | Responsibility                                             |
| ----------- | ---------------------------------------------------------- |
| `flake.nix` | Inputs, outputs, host composition, exports, and checks     |
| `hosts/`    | Host entry points, hardware, and host-specific policy      |
| `profiles/` | Reusable selections and defaults for semantic capabilities |
| `modules/`  | Shared semantic capabilities and their implementation      |
| `lib/`      | Reusable Nix helpers                                       |
| `overlays/` | Package definitions and overrides                          |
| `patches/`  | Downstream patches grouped by target package               |
| `scripts/`  | Standalone repository and operational commands             |
| `tests/`    | Repository-integrated verification                         |
| `docs/`     | Manual, runbooks, and documentation generation             |
| `.github/`  | GitHub-specific automation                                 |

## File ownership and placement

Locate authored source by its semantic owner, not its language, callers, or installation destination. A capability has one implementation even when exposed through several interfaces.

| Source                                                         | Location                                                                                    |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| Feature-specific configuration, executable helpers, and assets | Owning semantic module                                                                      |
| Host-specific implementation                                   | Matching host scope                                                                         |
| Shared capability implementation                               | Owning shared scope or independent package                                                  |
| Repository workflow and standalone operational commands        | Root `scripts/`, grouped by responsibility when useful                                      |
| Reusable Nix functions                                         | Nearest owning scope, or `lib/` for genuinely shared functions                              |
| Independent package definition                                 | `overlays/<package>/default.nix`                                                            |
| Downstream patch                                               | `patches/<package>/`                                                                        |
| Repository-integrated tests                                    | Root `tests/`; component-specific tests may follow an independent component's native layout |

For example, a theme-switching command belongs to the theme capability even when used from a desktop picker, CLI, and flake app. A compositor recording helper belongs to the compositor shell. The system updater and shared release-discovery tools operate on the repository itself; a standalone storage installation or recovery command is operational tooling. Both belong under root `scripts/`.

Keep small readable commands inline when native options or Nix executable construction express them directly. Group related implementation files by responsibility when that improves navigation. A single executable helper does not require a nested `scripts/` directory, and a self-contained Nix implementation does not require a directory containing only `default.nix`. Split larger implementations at meaningful boundaries rather than by arbitrary file sizes or languages.

Keep authored configuration and assets with their owner. Generate installed configuration and build outputs through Nix; track generated inputs only when required by the implementation.

## Registration and imports

Register semantic scopes in the owning hierarchy and package overlays in the central overlay registry. Use native imports for ordinary native modules. Source organization does not establish a new independently enabled scope.

The flake composes hosts, locks inputs, and exposes packages, apps, checks, and development environments. Export commands through their existing executable interfaces; do not duplicate implementation in the flake. Alternate flake entry points reuse the canonical locked source and policy.

## Shared versus host-local

Common behavior belongs with its shared owner. Genuine differences belong to the affected host under the same semantic scope. Extend shared definitions instead of copying or replacing them to change a single option.

Keep package construction in overlays, runtime integration with the consuming capability, and appearance policy with the theme. Verify registration, imports, and affected host evaluations after structural changes.

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

Keep source with its semantic owner, independently of language, installation destination, or the number of consumers. Multiple interfaces can expose the same implementation.

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

For example, a command shared by a graphical theme picker and a CLI belongs to the theme scope. A recording helper belongs to the compositor shell. Repository updaters and standalone installation or recovery commands belong under root `scripts/`.

Keep small readable commands inline when native options or Nix executable construction express them directly. Use a single Nix file for a self-contained implementation, or a directory when it has associated source, assets, or meaningful subcomponents. Group helpers by responsibility; a separate `scripts/` directory is optional. Split implementations along functional boundaries.

Keep authored configuration and assets with their owner. Generate installed configuration and build outputs through Nix; track generated inputs only when required by the implementation.

## Registration and imports

Register semantic scopes in the owning hierarchy and package overlays in the central overlay registry. Use native imports for ordinary native modules. A file or directory is not by itself a semantic scope.

The flake composes hosts, locks inputs, and exposes packages, apps, checks, and development environments. Export commands through their existing executable interfaces; do not duplicate implementation in the flake. Alternate flake entry points reuse the canonical locked source and policy.

See [semantic scopes](semantic-scopes.md) for shared and host-local composition.

# Repository structure

Organize code by the capability or application that owns it. Native option namespaces do not determine file placement.

| Location           | Responsibility                                   |
| ------------------ | ------------------------------------------------ |
| `flake.nix`        | Flake inputs, outputs, composition, and checks   |
| `hosts/`           | Host entry points and host-specific policy       |
| `modules/`         | Shared semantic capabilities                     |
| `lib/`             | Reusable Nix helpers                             |
| `overlays/`        | Package definitions and overrides                |
| `scripts/`         | Repository-wide commands and cross-owner helpers |
| `patches/`         | Downstream patches grouped by target package     |
| `tests/`           | Shared, integration, and evaluation checks       |
| `docs/manual/src/` | Human-maintained guidance and runbooks           |

## File ownership and placement

Choose a file's location from its **semantic owner**, not from the syntax, the tool that loads it, or the number of places that reference it. Separate source ownership from executable packaging and deployment.

| Source                                                 | Default location                                                                       | Boundary                                                                                                                            |
| ------------------------------------------------------ | -------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| Shared feature implementation                          | `modules/<scope>/` or the owning child                                                 | Include native options, runtime source, assets, and feature-specific helpers                                                        |
| Host-only implementation                               | `hosts/<host>/` with the same semantic scope                                           | Use for genuine host-specific policy or hardware behavior, not a substitute for shared implementation                               |
| One feature's executable script                        | `modules/<scope>/<feature>/scripts/`                                                   | Keep it with its owner even when several components of that feature invoke it                                                       |
| Script shared within one semantic capability           | `modules/<scope>/scripts/`                                                             | Share at the nearest meaningful semantic owner; do not elevate it to repository-wide tooling merely because it has multiple callers |
| Repository workflow or independent cross-owner command | `scripts/`, grouped by purpose where useful                                            | Includes tools exported by `flake.nix` to operate on the repository itself                                                          |
| Package definition or compatibility override           | `overlays/<package>/default.nix`                                                       | Consumers configure applications; overlays construct packages                                                                       |
| Downstream patch                                       | `patches/<package>/`                                                                   | Reference the patch from its overlay or package definition; do not maintain a competing patch tree                                  |
| Runtime application assets and configuration sources   | Beside their consuming implementation                                                  | QML, Lua, JavaScript, CSS, templates, and similar files are not operational scripts merely because they contain executable code     |
| Tests                                                  | Beside a feature for focused internal tests; `tests/` for shared or flake-level checks | Keep check registration at the appropriate entry point without relocating test ownership                                            |

Use these cases to resolve ambiguous placement:

1. **Called by `flake.nix`:** a command for building, updating, validating, or inspecting the repository belongs in root `scripts/`. A feature's script remains under its semantic owner even when the flake exports or packages it. The caller is not necessarily the owner.
2. **One configuration consumer:** put substantial feature-specific source next to that consumer. Keep a truly small, readable command inline where a native Nix option or `writeShellApplication` already expresses it clearly.
3. **Several consumers:** share source with the policy or capability that owns the behavior. Only use root `scripts/` if the command is genuinely cross-owner or repository-wide; two call sites do not prove shared ownership.
4. **Only one host:** use the host's matching semantic scope for host-specific behavior. Platform support alone does not justify creating host-local copies of shared source.
5. **Generated or installed files:** keep authored templates and application sources with their owners. Let Nix build/install generated outputs; do not commit generated build artifacts unless they are intentionally tracked inputs required by the project.

Do not introduce an executable script when a supported native option, application API, or existing utility expresses the same behavior reliably. Avoid extra `default.nix` wrappers, subdirectories, shared libraries, or registries unless they establish a real ownership boundary or reduce duplication. When extracting or relocating source, preserve its runtime dependencies, consumers, behavior, and formatter coverage.

## Registration and imports

Use the owning directory's existing `default.nix` to register children. Keep package registration in the overlay registry and semantic module registration in the module hierarchy. Avoid parallel registries or special-case composition in the flake when the existing mechanism suffices.

Use native module imports for ordinary native modules. A feature may span multiple files when they have coherent responsibilities; one-file wrappers and extra directories are not inherently improvements.

## Shared versus host-local

Common behavior belongs with its shared owner. Genuine differences belong to the affected host under the same semantic scope. Extend shared definitions instead of copying or replacing them to change a single option.

Keep package construction in overlays, runtime integration with the consuming capability, and appearance policy with the theme. Verify registration, imports, and affected host evaluations after structural changes.

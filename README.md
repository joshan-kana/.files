# .files

Nix flake for my NixOS systems, macOS workstation, Home Manager configuration, and home infrastructure.

Configuration is organised by **semantic ownership**: code lives with the application, capability, or idea it belongs to rather than being grouped by native Nix option namespace.

## Development

```sh
nix develop -c $SHELL
```

Common commands:

```sh
nix fmt | fmt               # apply repository formatting/fixes
nix flake check | chk       # run repository validation
nix run .#theme-warm        # prebuild and cache all theme variants
docs                        # build the generated manual
docs-serve                  # live-preview the generated manual
nf                          # browse evaluated Nix options
```

Use native NixOS/Home Manager options inside semantic scopes. Shared behaviour belongs under `modules/`; host-specific differences stay with the same semantic scope under `hosts/<host>/`.

Install user-facing programs through Home Manager by default, using native `programs.*` modules when available and `home.packages` otherwise. Reserve system-level installations for services, login/session integration, and administration or recovery. Avoid redundant user/system package installation unless the responsibilities differ.

## Documentation

`docs` builds reference pages from evaluated Nix together with operational runbooks. Generated reference pages are build artifacts and are not committed.

The cross-project operating handbook is included as the `docs/infrastructure-docs` submodule.

## Repository layout

```text
flake.nix                 Flake outputs, checks, packages, apps, and host composition
hosts/                    Host entrypoints and host-specific policy
modules/                  Shared semantic configuration scopes
lib/                      Semantic-scope and shared Nix helpers
overlays/                 Package overlays
scripts/                  Repository and operational commands
tests/                    Evaluated and behavioural checks
docs/manual/              Manual runbooks and generated-reference source
docs/infrastructure-docs/ Cross-project operating handbook submodule
```

Use `nix flake show` for the current hosts, packages, apps, checks, and development shells.

## Clone

```sh
git clone --recurse-submodules git@github.com:joshan-kana/.files.git
```

For an existing checkout:

```sh
git submodule update --init --recursive
```

## Validation

```sh
nix fmt
git diff --check
nix flake check
```

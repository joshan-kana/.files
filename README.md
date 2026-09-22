# .files

Nix flake containing the NixOS system and home configuration for my machines and home infrastructure.

The repository is the source of truth for current implementation. Configuration is organised by **semantic ownership**: code lives with the application, capability, or idea it belongs to rather than being grouped around native Nix option namespaces.

## Documentation

Implementation reference material is generated from the repository instead of being maintained as a second copy of the configuration.

```sh
nix build .#docs
```

The resulting mdBook combines:

- project-owned `dotfiles.*` option documentation generated with `nixosOptionsDoc`;
- semantic-scope documentation extracted from RFC 145 `/** ... */` comments with `nixdoc`;
- evaluated host, scope, storage, network, container, and backup reference data;
- human-authored install, recovery, migration, and maintenance runbooks whose current configuration values are injected at build time.

Generated pages are build artifacts and are not committed. Inside the development shell:

```sh
docs
docs-serve
```

`docs` builds the current manual. `docs-serve` regenerates the mdBook source when Nix, host, module, library, or manual sources change and serves a live local preview. Normal development-shell entry does not build the manual; documentation generation stays explicit during ordinary work and automatic while `docs-serve` is running.

The documentation rule is deliberately simple: do not manually copy implementation facts that can be derived from evaluated Nix. Use normal code comments for surprising local behaviour, option descriptions for configurable interfaces, RFC 145 doc comments when a larger scope needs prose, and runbooks for procedures where ordering, safety, recovery, or judgement matters.

The cross-project operating handbook is included as the `docs/infrastructure-docs` submodule.

## Development

Enter the reproducible development environment:

```sh
nix develop
```

Common commands:

```sh
nix fmt              # apply repository formatting/fixes
nix flake check      # run repository validation
docs                 # build the generated manual
docs-serve           # live-preview the generated manual
nf                    # interactively browse evaluated Nix options
```

The flake dev shell installs the repository pre-commit hooks and provides the Nix/editor tooling used by the project.

Before changing configuration, identify the semantic owner of the behaviour. Shared behaviour belongs in the relevant module under `modules/`; genuine host-specific differences stay with the same semantic scope under `hosts/<host>/`.

Use native NixOS/Home Manager options inside a semantic scope. `home = _: { ... };` is the Home Manager boundary for configuration owned by the same idea. Host-specific semantic-scope enable overrides live under `dotfiles.scopes`.

## Repository layout

```text
flake.nix                 Flake outputs, checks, packages, apps, and host composition
hosts/                    Host entrypoints and host-specific policy
modules/                  Shared semantic configuration scopes
lib/                      Semantic-scope and shared Nix helpers
overlays/                 Package overlays
scripts/                  Repository and operational commands
tests/                    Evaluated and behavioural checks
docs/manual/              Authored mdBook pages and runbooks
docs/infrastructure-docs/ Cross-project operating handbook submodule
```

Use `nix flake show` for the current set of hosts, packages, apps, checks, and development shells rather than maintaining another list here.

## Clone

Clone with the documentation submodule:

```sh
git clone --recurse-submodules git@github.com:joshan-kana/.files.git
```

For an existing checkout:

```sh
git submodule update --init --recursive
```

## Validation

For normal repository work:

```sh
nix fmt
git diff --check
nix flake check
```

Build or runtime validation should be added when evaluation alone cannot prove the behaviour being changed.

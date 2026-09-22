# .files Manual

This manual is built from the exact `.files` revision being inspected.

Generated reference pages describe the repository's project-owned Nix interfaces and evaluated host/scope structure without committing generated Markdown back into Git.

```sh
nix build .#docs
```

Inside the development shell, `docs` builds the manual and `docs-serve` starts a live local preview that regenerates when relevant sources change.

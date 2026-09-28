# .files Manual

Reference data is built from the checked-out `.files` revision.

Project-owned Nix interfaces and evaluated host/scope state are rendered without committing generated Markdown.

```sh
nix build .#docs
```

Inside the development shell, `docs` builds the manual and `docs-serve` starts a live local preview that regenerates when relevant sources change.

# Documentation

**Convention:** Document the implemented decision once, at its owning source. Separate human-written guidance, evaluated reference pages, operational runbooks, and cross-project architecture.

## Manual sources

This manual uses [mdBook](https://rust-lang.github.io/mdBook/) and the existing `docs/default.nix` assembly:

- `docs/manual/src/conventions/`: handwritten contributor conventions.
- `docs/manual/src/runbooks/`: handwritten installation, recovery, and troubleshooting procedures.
- Generated pages: evaluated hosts, scope inventory, options, infrastructure facts, and selected package lists. These are **build outputs**, not checked-in copies of current state.
- `docs/default.nix`: navigation (generated `SUMMARY.md`), page generation, and source overlay assembly.

Do not maintain a second manual entry point or commit generated pages to make a Markdown link work. Add a convention page to the generated sidebar in `summaryMarkdown` and keep the link relative to the assembled book.

## Source of truth

Repository implementation details and runnable commands belong in `.files`. Cross-project architecture, broad access/recovery policy, and accepted operational decisions belong in the [infrastructure handbook](https://github.com/joshan-kana/infrastructure-docs). Link to it instead of duplicating policy in divergent documents.

Use the repository's evaluated state to describe current hosts and services; do not hand-maintain lists of package versions, interfaces, secret values, or hardware inventory here.

This conventions section explains how to **contribute to this repository**. New conventions or material changes to established ones should update the relevant page in the same PR. Routine implementations that simply comply need no manual edit.

## Authoring and review

Write the actual rule, rationale, relevant exception, and verification approach. Prefer a concise real example; avoid meta-describing a request or repeating it as a policy. Never include private credentials, secrets, or generated runtime state in Markdown.

Validate Markdown with Treefmt, build the generated source tree and book, verify navigation and links, and inspect representative pages. Generated references and runbooks must remain present after the new pages are added.

An unrelated code behavior change belongs in a separate implementation PR, not hidden inside a documentation reorganization.

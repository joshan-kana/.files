# Reference Data

This directory is intentionally small and documentation-only.

Do not commit extracted Home Assistant backups, sanitized copies, or raw export
contents into this repo. Keep any inspection copy under:

```text
ha/reference-local/
```

That path is ignored by Git.

Suggested workflow:

1. Keep the real Home Assistant backup archives in Dropbox or another encrypted
   backup location.
2. When you need to inspect one, extract it into `ha/reference-local/`.
3. Use the mapping in `ha/README.md` to restore the needed pieces into
   `/var/lib/...` on the server.

The runtime server does not read anything from `ha/reference/` or
`ha/reference-local/`.

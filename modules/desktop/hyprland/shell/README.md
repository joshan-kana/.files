# Command palette

The Hyprland shell's `Super+Space` palette searches installed applications, registered desktop actions, live windows and workspaces, local indexed files, browser bookmarks, saved snippets, and Quicklinks. Arithmetic and unit conversions work directly in Unified search.

The native Quickshell palette remains the only launcher. `Alt+1` through `Alt+4` select its existing Unified, Apps, Actions, and Emoji scopes. `Tab` changes between typing and list navigation; `Alt+Enter` reveals contextual actions for the selected result. The dedicated clipboard-history picker remains separate.

## Website searches

The built-in Quicklinks are `gh` (GitHub), `np` (Nix Packages), `wiki` (Wikipedia), and `yt` (YouTube). For example, `gh nixpkgs` opens a GitHub search immediately. Selecting a Quicklink without parameters opens its inline query input.

For custom searches, create `~/.config/linux-desktop/quicklinks.json`:

```json
[
  {
    "name": "Search GitHub",
    "alias": "gh",
    "url": "https://github.com/search?q={query}",
    "keywords": ["code", "repositories"]
  },
  {
    "name": "Search ArchWiki",
    "alias": "aw",
    "url": "https://wiki.archlinux.org/index.php?search={query}"
  }
]
```

The optional file replaces the built-in Quicklinks. Aliases are short lower-case identifiers; templates must use HTTP(S) and contain `{query}`. Search terms are URL-encoded. Invalid entries and executable URL schemes are rejected, and the file is reloaded when changed. Browser bookmarks are indexed read-only from supported Firefox and Chromium-family profiles rather than duplicated in this file.

## Local search

The `linux-desktop-palette-index` user service refreshes a private SQLite filename/bookmark index at desktop startup; native filesystem change events trigger debounced updates without recurring polling. The first index must finish before file and bookmark results appear. Searches read the index asynchronously, not the filesystem directly on each keystroke.

The default indexed roots are existing `~/Documents`, `~/Downloads`, `~/Desktop`, `~/Projects`, `~/repos`, `~/src` and `~/Uni` directories. Hidden directories, symlinks and common build/cache/secrets directories are excluded. To replace the roots, create `~/.config/linux-desktop/files.json`:

```json
{
  "roots": [
    "~/Documents",
    "~/repos"
  ]
}
```

Paths must be absolute after tilde expansion; the home directory itself and Nix store paths are not indexed. Rebuild the index after changing roots using:

```sh
systemctl --user restart linux-desktop-palette-index.service
```

The index is stored in `$XDG_CACHE_HOME/linux-desktop/search.sqlite3` (or `~/.cache/linux-desktop/search.sqlite3`) with user-only permissions. Query results are bounded. Document contents are **not** indexed.

## Saved text

Optional text snippets are read from `~/.config/linux-desktop/snippets.json`:

```json
[
  {
    "name": "Support address",
    "text": "support@example.com",
    "keywords": ["contact", "email"]
  }
]
```

Selecting a snippet copies its contents to the clipboard. The file is explicit user-owned content; the palette does not harvest passwords, other documents or clipboard history to populate snippets.

## Privacy and command safety

The local palette preferences file stores favourite identities and, when enabled, a bounded list of recently used application/command identities, not search terms. Search for **Disable Palette Recent Usage** to stop collecting these and clear the saved list, or **Clear Recent Palette Items** to delete it. Quicklinks open through the configured URL opener; the palette does not evaluate arbitrary shell input.

System-control commands call the existing shell state/action owners. `volume 35` sets audio volume to 35%, and `brightness 40` targets supported hardware brightness. Selecting **Set Volume** or **Set Brightness** exposes an inline percentage input. Workspace moves use the existing compositor dispatcher.

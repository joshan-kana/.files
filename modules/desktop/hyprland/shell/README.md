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

To target a specific installed browser, add a desktop-entry ID such as \`"browser": "firefox.desktop"\` to an entry. The launcher resolves it from installed application directories and uses its declared application handler; an unavailable browser produces visible feedback. You may also use \`{clipboard}\` in a URL template for an explicit, one-time clipboard search. Clipboard values are read only after a separate confirmation showing that they will be sent to the website. Clipboard searches are never run implicitly or stored in search history.

The optional file replaces the built-in Quicklinks. Aliases are short lower-case identifiers; templates must use HTTP(S) and contain `{query}`. Search terms are URL-encoded. Invalid entries and executable URL schemes are rejected, and the file is reloaded when changed. Browser bookmarks are indexed read-only from supported Firefox and Chromium-family profiles rather than duplicated in this file.

## Local search

The `linux-desktop-palette-index` user service refreshes a private SQLite filename/bookmark index at desktop startup; native filesystem change events trigger debounced updates without recurring polling. The first index must finish before file and bookmark results appear. Searches read the index asynchronously, not the filesystem directly on each keystroke.

The default indexed roots are existing `~/Documents`, `~/Downloads`, `~/Desktop`, `~/Projects`, `~/repos`, `~/src` and `~/Uni` directories. Hidden directories, symlinks and common build/cache/secrets directories are excluded. To replace the roots, create `~/.config/linux-desktop/files.json`:

```json
{
  "roots": ["~/Documents", "~/repos"]
}
```

Paths must be absolute after tilde expansion; the home directory itself and Nix store paths are not indexed. Rebuild the index after changing roots using:

```sh
systemctl --user restart linux-desktop-palette-index.service
```

The index is stored in `$XDG_CACHE_HOME/linux-desktop/search.sqlite3` (or `~/.cache/linux-desktop/search.sqlite3`) with user-only permissions. Query results are bounded. Document contents are **not** indexed.

A file result has **Open With…** (choose an installed desktop-entry application), **Preview File Details** (on-demand MIME type, size, modified time and a bounded UTF-8 excerpt for small text files), **Reveal in File Manager** and **Copy Path**. Previews are served from the private local index socket only for explicitly indexed paths, and are never persisted to the index. No document contents are scanned during ordinary search.

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

## Extension contract and ownership

A palette result is a small descriptor, not a process:

| Field           | Purpose                                                                                                             |
| --------------- | ------------------------------------------------------------------------------------------------------------------- |
| `kind`          | The built-in provider/result class (command, application, file, bookmark, quicklink, snippet, window or workspace). |
| `name`          | Human-readable label shown in the result list.                                                                      |
| `genericName`   | One-line context and state.                                                                                         |
| `icon`          | Desktop icon-theme name.                                                                                            |
| `keywords`      | Optional search aliases, used by deterministic fuzzy matching.                                                      |
| `key`           | Optional existing shortcut hint; the keyboard binding itself remains owned by the compositor.                       |
| `commandId`     | Registered first-party action identifier, not a shell command.                                                      |
| `parameterMode` | Optional validated input mode (percentage, target or confirmation).                                                 |

The **first-party command provider** is the declarative `commands` list at the shell's `CommandPalette` instance. Keep it close to the relevant `Actions` owner. New first-party commands must call the existing state/action owner; use `parameterMode` and the typed argument signal if values are needed, rather than constructing command lines from search text.

The **applications provider** reads Quickshell's existing desktop-entry model; the **window and workspace provider** reads live Hyprland state; the **file and bookmark provider** uses the private event-driven local index; and the **Quicklinks and snippets providers** read the two optional JSON files above. These are the current declarative entry points. No separate extension process, general shell-script registry, plugin marketplace or second state owner is introduced. Add new first-party providers only when the existing inputs cannot express the required type, and keep indexing and external I/O off the QML render/input path.

## Evaluated optional capabilities

**Document content search:** Not enabled by default. Even with opt-in roots, scanning text requires MIME-specific extraction, a separate index lifecycle, privacy protections for excerpts, and a much larger data footprint than filename matching. The existing private filename index, with explicit roots, hidden/secret exclusions and an event-driven watcher, covers the immediate launcher use case. Content extraction is deferred until there is a concrete need and an explicit private, resource-bounded design. No file contents are uploaded or globally indexed.

**Multi-step workflows:** Not introduced. Simple named actions with validated arguments cover the common use cases without creating a second automation platform. A workflow engine would require cancellation, progress reporting, recoverable partial failure and re-confirmation when composing destructive operations. For now, the palette dispatches one supported action at a time; longer automation belongs to its existing owning service. Arbitrary shell text remains unsupported by design.

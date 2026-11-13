# Command palette

The Hyprland shell's unified palette searches installed applications, registered desktop actions, live windows and workspaces, local indexed files, browser bookmarks, saved snippets, and Quicklinks. Arithmetic and unit conversions work directly in Unified search.

The native Quickshell palette remains the only launcher. Its scope shortcuts select Unified, Apps, Actions and Emoji; the text/list navigation and contextual-action controls have separate keyboard modes. The dedicated clipboard-history picker remains separate. Compositor-level bindings are declared in `modules/desktop/hyprland/keybindings.nix` and are presented by the generated shortcut registry, rather than duplicated in this document.

## Hub navigation

Home, Controls and Activity share a fixed header. Back on the left and Keyboard Help on the right remain available across root pages and detail views; the three page tabs sit between them. Back and `Esc` use the active page's navigation action. An open confirmation, picker, search detail or contextual help closes first; otherwise a detail returns to its owning page, and Back from a root page closes the hub. Calendar visibility and notification reply editing retain their in-place cancellation behavior. `Shift+Esc` bypasses nested history and closes the hub.

## Website searches

Quicklinks are configured by `desktop.hyprland.shell.quicklinks` in `shell/default.nix` and transported through the Nix-generated `runtime.json`. Search directly by alias, for example `gl nixpkgs` for GitLab or `gh nixpkgs` for GitHub. Selecting an alias alone opens the inline query field.

| Category             | Aliases                                                                                                                                                                         |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nix and Linux        | `np` Nix Packages, `no` NixOS Options, `nw` NixOS Wiki, `aw` ArchWiki, `man` Linux manuals                                                                                      |
| Development          | `gh` GitHub, `ghc` GitHub code, `gl` GitLab, `mdn` MDN, `so` Stack Overflow, `crates` crates.io, `docsrs` docs.rs, `pypi` PyPI, `npm` npm, `brew` Homebrew, `docker` Docker Hub |
| Web search           | `ddg` DuckDuckGo, `gg` Google, `bing` Bing, `kagi` Kagi                                                                                                                         |
| Knowledge            | `wiki` Wikipedia, `wikt` Wiktionary, `scholar` Google Scholar, `arxiv` arXiv                                                                                                    |
| Media and community  | `yt` YouTube, `rd` Reddit, `imdb` IMDb                                                                                                                                          |
| Maps and translation | `osm` OpenStreetMap, `trans` Google Translate                                                                                                                                   |

Custom providers belong in the Nix option, not another `quicklinks.json`. Each alias must be unique and lower-case. Providers may use an installed browser's desktop-entry ID; the default is the system URL opener. HTTP(S) URL templates support `{query}` and `{clipboard}` and encode values safely. Clipboard links require an explicit confirmation showing the destination before any clipboard text is read or transmitted. Clipboard text and search terms are never stored in recent usage.

## Local search

The `linux-desktop-palette-index` user service refreshes a private SQLite filename/bookmark index at desktop startup; native filesystem change events trigger debounced updates without recurring polling. Browser bookmarks are discovered from local Chromium-compatible and Gecko-compatible profiles using their standard file layouts, including profiles registered in `profiles.ini`. Bookmarks open through the current XDG default URL handler; installed browsers are not hardcoded into the palette. The first index must finish before file and bookmark results appear. Searches read the index asynchronously, not the filesystem directly on each keystroke.

Index roots are declared in `desktop.hyprland.shell.fileSearchRoots` in `shell/default.nix`; defaults are `Documents`, `Downloads`, `Desktop`, `Projects`, `repos`, `src` and `Uni`, relative to home. Absolute paths work too. The Nix-generated runtime config is the indexer's only configuration. The home directory itself, Nix store paths, hidden files, symlinks, common build directories and secrets are not indexed.

The watcher observes the generated runtime configuration and updates its watched roots as directories appear or change. To force a rescan:

```sh
systemctl --user restart linux-desktop-palette-index.service
```

The index is stored in `$XDG_CACHE_HOME/linux-desktop/search.sqlite3` (or `~/.cache/linux-desktop/search.sqlite3`) with user-only permissions. Query results are bounded. Document contents are **not** indexed.

A file result has **Open With…** (choose an installed desktop-entry application), **Preview File Details** (on-demand MIME type, size, modified time and a bounded UTF-8 excerpt for small text files), **Reveal in File Manager** and **Copy Path**. Previews are served from the private local index socket only for explicitly indexed paths, and are never persisted to the index. No document contents are scanned during ordinary search.

## Saved text

Non-sensitive default snippets belong in `desktop.hyprland.shell.snippets`; optional user-owned `~/.config/linux-desktop/snippets.json` overrides that list. For example:

```json
[
  {
    "name": "Support address",
    "text": "support@example.com",
    "keywords": ["contact", "email"]
  }
]
```

Selecting a snippet copies its contents to the clipboard. Keep private values out of the world-readable Nix store. The user-owned file is explicit content; the palette does not harvest passwords, other documents or clipboard history to populate snippets.

## Configuration and preference ownership

Reproducible shell defaults are declared under `desktop.hyprland.shell` in `modules/desktop/hyprland/shell/default.nix` and materialized as the generated, read-only `~/.config/linux-desktop/runtime.json`. Presentation tokens such as panel opacity, focus opacity, scrim opacity, and squircle shape are theme-owned: `modules/theme/default.nix` supplies them to `~/.config/linux-desktop/theme.json` through `scopeEdits.desktop.hyprland.shell`. The shell consumes those values; it does not establish a second palette or typography owner.

The `Appearance` section of `~/.config/linux-desktop/preferences.ini` records explicit overrides for wallpaper spectrum, wallpaper fit/crop mode and display target, music-reactive shell, bar and frame visibility, window transparency and opacity, shell glass and opacity, media visualizer mode, lyrics visibility, and the media seek interval. The `Motion`, `Session`, and `Capture` sections cover animations, window restoration, and frozen capture. Notification preferences are stored in the `Notifications` section of the XDG configuration file `linux-desktop/preferences.ini`; the earlier `notifications.ini` is read only for migration. In all these cases, **explicit user choices take precedence** over their declared defaults. Restore defaults returns the affected preferences to Nix inheritance without deleting unrelated personal content.

Palette favourites and recent-history consent live in the user-owned XDG config file `linux-desktop/palette.ini`; recent-usage identities live in `$XDG_STATE_HOME/linux-desktop/palette.ini` (normally `~/.local/state/linux-desktop/palette.ini`). Existing recent-usage entries are migrated once from the previous config location. None of these values are written by the Nix generator. Personal snippets can override the declared snippet list through the optional `snippets.json` file. Website Quicklinks and the index's root list are declarative-only, while browser bookmarks and other indexed files remain owned by their original applications and users. A generated `runtime.json` is not itself a personal-state override file.

## Privacy and command safety

The local palette preferences file stores favourite identities and, when enabled, a bounded list of recently used application/command identities, not search terms. Search for **Disable Palette Recent Usage** to stop collecting these and clear the saved list, or **Clear Recent Palette Items** to delete it. Quicklinks open through the configured URL opener; the palette does not evaluate arbitrary shell input.

System-control commands call the existing shell state/action owners. `volume 35` sets audio volume to 35%, and `brightness 40` targets supported hardware brightness. Selecting **Set Volume** or **Set Brightness** exposes an inline percentage input. Workspace moves use the existing compositor dispatcher.

## Connectivity and calendar ownership

Quickshell's NetworkManager backend owns live devices, Wi-Fi scanning, connection state and available Wi-Fi credentials. The saved-profile details panel reads matching native `Network.nmSettings` entries without spawning a command. NetworkManager remains the authority for profiles not exposed by live device models, including offline Wi-Fi, Ethernet, VPN and WireGuard profiles; these are queried on demand with `nmcli`, not continuously polled. Live interface address and DNS diagnostics also use NetworkManager's existing interface reporting. The advanced profile editor is `nm-connection-editor`, rather than a second network configuration implementation.

The calendar uses `vdirsyncer`'s read-only `singlefile` and `filesystem` storages for per-subscription vdir collections under `$XDG_DATA_HOME/calendars/subscriptions/`. The sync adapter reads each private URL only from `~/.secrets/calendar-icals/*.url` (or the legacy single-feed secret), enforces HTTPS-only redirects and a 12 MiB response limit, and passes a temporary local iCalendar file to `vdirsyncer`. Neither feed URLs nor event contents enter Nix configuration or journal output. All previous imported events remain unchanged in `$XDG_DATA_HOME/calendars/personal/` for rollback. After a successful synchronization, an ephemeral khal configuration exposes the new collections while the agenda suppresses duplicate legacy imports. Existing local events remain visible, per-source visibility uses khal's native calendar identity, and the user's khal configuration is not rewritten. The systemd user timer refreshes subscriptions every 30 minutes; errors keep previous cached data available.

## Power and session

The Power & Session panel provides Lock, Suspend, Log out, Reboot, Power off and a keyboard-accessible **Restore ON/OFF** choice. H/J/K/L or arrow keys select a tile; Enter activates it, with a second confirmation for actions that end or suspend the session.

Restore defaults to **off** through `desktop.hyprland.shell.restoreWindowsOnExit`. A user selection is retained in the `Session` group of `~/.config/linux-desktop/preferences.ini` and takes precedence over the Nix default across shell restarts and reboots. Restoring declared desktop defaults clears that override, allowing future Nix defaults to apply. The same preference precedence applies to appearance, motion, capture freeze and notification silence; existing preferences migrate without changing their effective values.

For logout, reboot or poweroff from the panel, Restore ON saves `hypr-persist`'s `last` session first and aborts the action if saving fails. Restore OFF disarms any outstanding one-shot request without deleting the saved layout. Lock and Suspend never save or disarm sessions. Ordinary terminal `reboot` and `poweroff` do not consult the panel preference; they follow `hypr-persist`'s explicit one-shot request semantics.

## Night Light and output support

Night Light uses the session-scoped `linux-desktop-night-light` user service and Hyprsunset, with manual temperature changes persisted across sessions. The Controls state indicates backend availability and whether that service is active, not whether the display hardware actually applied the colour transform.

Hyprsunset sends a colour transformation matrix (CTM) to Hyprland. A display driver must support the relevant DRM/KMS colour properties for a visible result. The Parallels `virtio_gpu` virtual output does not expose `CTM`, `GAMMA_LUT` or `DEGAMMA_LUT` properties, so enabling Night Light there can report an active service without warming the virtual display. Screenshots and recordings omit hardware CTM effects by design. Validate the visible colour change on a physical output with supported colour controls; do not add a competing screen-shader fallback solely for VM screenshots.

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

The **applications provider** reads Quickshell's existing desktop-entry model; the **window and workspace provider** reads live Hyprland state; the **file and bookmark provider** uses the private event-driven local index; and the **Quicklinks provider** reads Nix-generated runtime data. Snippets use Nix defaults except when an explicit user-owned file is present. These are the current declarative entry points. No separate extension process, general shell-script registry, plugin marketplace or second state owner is introduced. Add new first-party providers only when the existing inputs cannot express the required type, and keep indexing and external I/O off the QML render/input path.

## Evaluated optional capabilities

**Document content search:** Not enabled by default. Even with opt-in roots, scanning text requires MIME-specific extraction, a separate index lifecycle, privacy protections for excerpts, and a much larger data footprint than filename matching. The existing private filename index, with explicit roots, hidden/secret exclusions and an event-driven watcher, covers the immediate launcher use case. Content extraction is deferred until there is a concrete need and an explicit private, resource-bounded design. No file contents are uploaded or globally indexed.

**Multi-step workflows:** Not introduced. Simple named actions with validated arguments cover the common use cases without creating a second automation platform. A workflow engine would require cancellation, progress reporting, recoverable partial failure and re-confirmation when composing destructive operations. For now, the palette dispatches one supported action at a time; longer automation belongs to its existing owning service. Arbitrary shell text remains unsupported by design.

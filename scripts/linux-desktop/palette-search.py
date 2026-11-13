#!/usr/bin/env python3
"""Local filename and bookmark index for the native desktop palette."""

import json
import mimetypes
import os
import signal
import sqlite3
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from urllib.parse import urlsplit

BASE = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "linux-desktop"
DB = BASE / "search.sqlite3"
MAX_ITEMS = 80000
EXCLUDED = {
    ".git",
    ".hg",
    ".svn",
    ".direnv",
    ".cache",
    ".local",
    ".config",
    ".ssh",
    ".gnupg",
    ".secrets",
    ".venv",
    "node_modules",
    "target",
    "result",
    "__pycache__",
    ".next",
    "dist",
    "build",
}


def declared_roots():
    """Resolve user-selected roots from the generated Nix runtime config."""
    home = Path.home()
    config = Path(
        os.environ.get(
            "LINUX_DESKTOP_RUNTIME", str(Path(os.environ.get("XDG_CONFIG_HOME", str(home / ".config"))) / "linux-desktop/runtime.json")
        )
    )
    try:
        roots = json.loads(config.read_text())["palette"]["fileRoots"]
        if not isinstance(roots, list):
            return []
        defaults = [
            Path(os.path.expanduser(root)) if root.startswith(("/", "~")) else home / root
            for root in roots
            if isinstance(root, str) and root
        ]
    except (OSError, ValueError, KeyError, TypeError):
        return []
    return defaults


def search_roots():
    """Return existing safe search roots for local file discovery."""
    home = Path.home()
    store = Path("/nix/store")
    result = [
        root
        for root in declared_roots()
        if root.is_absolute()
        and root.is_dir()
        and not root.is_symlink()
        and root != home
        and root != store
        and root not in store.parents
        and store not in root.parents
    ]
    return list(dict.fromkeys(result))


def files():
    """Yield indexable paths until the configured item limit is reached."""
    count = 0
    for root in search_roots():
        for directory, folders, names in os.walk(root, followlinks=False):
            folders[:] = sorted(
                n for n in folders if not n.startswith(".") and n not in EXCLUDED and not (Path(directory) / n).is_symlink()
            )
            for name in folders + sorted(names):
                if name.startswith(".") or name in EXCLUDED:
                    continue
                path = Path(directory) / name
                if path.is_symlink():
                    continue
                yield (str(path), name, 1 if name in folders else 0, "")
                count += 1
                if count >= MAX_ITEMS:
                    return


def browser_profile_roots():
    """Find Chromium/Gecko profile stores by layout, never by browser brand."""
    home = Path.home()
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", str(home / ".config")))
    data_home = Path(os.environ.get("XDG_DATA_HOME", str(home / ".local/share")))
    bases = [config_home, data_home, home, home / ".var/app"]
    flatpak_apps = home / ".var/app"
    if flatpak_apps.is_dir() and not flatpak_apps.is_symlink():
        for app in sorted(flatpak_apps.iterdir())[:128]:
            if app.is_dir() and not app.is_symlink():
                bases.extend((app / "config", app / "data"))

    seen = set()

    def matching(root):
        if root in seen or root.name in EXCLUDED or not root.is_dir() or root.is_symlink():
            return False
        seen.add(root)
        return (
            (root / "profiles.ini").is_file()
            or (root / "Default/Bookmarks").is_file()
            or any(root.glob("Profile */Bookmarks"))
            or any(root.glob("*.default*/places.sqlite"))
        )

    for base in bases:
        if not base.is_dir() or base.is_symlink():
            continue
        if matching(base):
            yield base
        try:
            children = sorted(base.iterdir())[:512]
        except OSError:
            continue
        for root in children:
            if not root.is_dir() or root.is_symlink():
                continue
            if matching(root):
                yield root
            # Recognize nested standard profile layouts, without recursively
            # scanning arbitrary home data.
            try:
                nested = sorted(root.iterdir())[:128]
            except OSError:
                continue
            for folder in nested:
                if matching(folder):
                    yield folder


def browser_watch_containers():
    """Watch XDG roots and top-level hidden homes without per-app trees.

    XDG roots are watched recursively with one inotify emitter each. Only
    hidden home directories need individual nonrecursive watchers; known
    browser profiles are watched recursively by their discovered root.
    """
    home = Path.home()
    config = Path(os.environ.get("XDG_CONFIG_HOME", str(home / ".config")))
    data = Path(os.environ.get("XDG_DATA_HOME", str(home / ".local/share")))
    flatpak = home / ".var/app"
    roots = (home, config, data, flatpak)
    for root in roots:
        if root.is_dir() and not root.is_symlink():
            yield root
    # The home-directory watcher sees creation of a new hidden application
    # directory. The next event-driven layout refresh subscribes to its
    # immediate children without scanning arbitrary non-browser file trees.
    try:
        children = sorted(home.iterdir())[:512]
    except OSError:
        return
    for child in children:
        if child.name.startswith(".") and child.name not in EXCLUDED and child.is_dir() and not child.is_symlink() and child not in roots:
            yield child


def bookmark_sources():
    """Return supported bookmark files and their discovered profile labels."""
    import configparser

    seen = set()
    for root in browser_profile_roots():
        label = root.name.strip(".") or "Browser"
        for source in sorted(root.glob("*/Bookmarks"))[:24]:
            if source.is_file() and not source.is_symlink() and source not in seen:
                seen.add(source)
                yield source, "chromium", label

        profiles = root / "profiles.ini"
        candidates = list(root.glob("*/places.sqlite"))[:24]
        if profiles.is_file() and not profiles.is_symlink():
            parser = configparser.ConfigParser(interpolation=None)
            try:
                parser.read(profiles, encoding="utf-8")
                for section in parser.sections():
                    if not section.startswith("Profile"):
                        continue
                    path = parser.get(section, "Path", fallback="")
                    if not path or ".." in Path(path).parts:
                        continue
                    directory = root / path if parser.getboolean(section, "IsRelative", fallback=True) else Path(path)
                    candidates.append(directory / "places.sqlite")
            except (configparser.Error, OSError, ValueError):
                pass
        for source in candidates:
            if source.is_file() and not source.is_symlink() and source not in seen:
                seen.add(source)
                yield source, "gecko", label


def bookmarks():
    """Index HTTP(S) bookmarks from discovered local browser profile formats."""
    for source, kind, label in bookmark_sources():
        if kind == "chromium":
            try:
                data = json.loads(source.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                continue

            def visit(node, source_label=label):
                if not isinstance(node, dict):
                    return
                if node.get("type") == "url" and isinstance(node.get("url"), str):
                    url = node["url"]
                    if url.startswith(("http://", "https://")):
                        yield url, str(node.get("name", url))[:200], 2, source_label
                for child in node.get("children", []) or []:
                    yield from visit(child)

            for node in data.get("roots", {}).values():
                yield from visit(node)
        else:
            try:
                # Read-only access to a live WAL database; never copy or mutate
                # the browser's profile. URI encoding handles special paths.
                db = sqlite3.connect(source.as_uri() + "?mode=ro", uri=True, timeout=0.5)
                try:
                    rows = db.execute(
                        "SELECT p.url, b.title FROM moz_bookmarks b JOIN moz_places p ON p.id=b.fk WHERE b.type=1 AND p.url LIKE 'http%' LIMIT 10000"
                    )
                    for url, title in rows:
                        if isinstance(url, str) and url.startswith(("http://", "https://")):
                            yield url, (title or url)[:200], 2, label
                finally:
                    db.close()
            except (OSError, sqlite3.Error):
                continue


def index():
    """Rebuild the searchable SQLite index atomically."""
    BASE.mkdir(mode=0o700, parents=True, exist_ok=True)
    temp = BASE / f".search-{os.getpid()}.sqlite3"
    connection = sqlite3.connect(temp)
    try:
        connection.execute("CREATE TABLE items (path TEXT PRIMARY KEY, name TEXT NOT NULL, kind INTEGER NOT NULL, browser TEXT NOT NULL)")
        connection.executemany("INSERT OR IGNORE INTO items VALUES (?,?,?,?)", files())
        connection.executemany("INSERT OR IGNORE INTO items VALUES (?,?,?,?)", bookmarks())
        connection.execute("CREATE INDEX search_names ON items(name COLLATE NOCASE)")
        connection.commit()
    finally:
        connection.close()
    os.chmod(temp, 0o600)
    os.replace(temp, DB)


def query(text):
    """Search local indexed items and return ranked palette results."""
    if not DB.is_file() or not text.strip() or len(text) > 150:
        return []
    phrase = text.strip().lower()
    # Escape wildcard characters. This is a substring match, not user SQL.
    escaped = phrase.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    db = None
    try:
        db = sqlite3.connect(f"file:{DB}?mode=ro", uri=True, timeout=0.25)
        rows = db.execute(
            """SELECT path, name, kind, browser
               FROM items
               WHERE name LIKE ? ESCAPE '\\' OR path LIKE ? ESCAPE '\\'
               ORDER BY CASE
                 WHEN LOWER(name) = ? THEN 0
                 WHEN LOWER(name) LIKE ? ESCAPE '\\' THEN 1
                 WHEN LOWER(name) LIKE ? ESCAPE '\\' THEN 2
                 ELSE 3 END,
                 LENGTH(name), name COLLATE NOCASE
               LIMIT 32""",
            (f"%{escaped}%", f"%{escaped}%", phrase, f"{escaped}%", f"%{escaped}%"),
        ).fetchall()
    except (OSError, sqlite3.Error):
        return []
    finally:
        if db:
            db.close()

    def rank(item):
        name = item[1].lower()
        return (0 if name == phrase else 1 if name.startswith(phrase) else 2 if phrase in name else 3, len(name), item[1])

    return [
        {
            "kind": "bookmark" if kind == 2 else "file",
            "name": name,
            "path": path if kind != 2 else "",
            "url": path if kind == 2 else "",
            "browser": browser,
            "icon": "internet-web-browser" if kind == 2 else "folder" if kind == 1 else "text-x-generic",
            "genericName": (browser + " bookmark") if kind == 2 else path,
            "key": "",
            "keywords": [],
        }
        for path, name, kind, browser in sorted(rows, key=rank)[:32]
    ]


def update_changed_files(paths, roots):
    """Update ordinary files from inotify events without rescanning each root."""
    if not DB.is_file():
        index()
        return
    with sqlite3.connect(DB, timeout=2.0) as connection:
        for path in paths:
            if not any(is_indexable(path, root) for root in roots):
                continue
            connection.execute("DELETE FROM items WHERE path = ? AND kind != 2", (str(path),))
            if path.is_file() and not path.is_symlink():
                connection.execute(
                    "INSERT OR REPLACE INTO items VALUES (?, ?, ?, ?)",
                    (str(path), path.name, 0, ""),
                )


def update_bookmarks():
    """Refresh browser bookmarks without walking any indexed directories."""
    if not DB.is_file():
        index()
        return
    with sqlite3.connect(DB, timeout=2.0) as connection:
        connection.execute("DELETE FROM items WHERE kind = 2")
        connection.executemany("INSERT OR IGNORE INTO items VALUES (?, ?, ?, ?)", bookmarks())


def installed_desktop_entry(desktop_id):
    """Resolve a safe desktop entry name against installed applications."""
    if not isinstance(desktop_id, str) or not desktop_id or len(desktop_id) > 240:
        return None
    if "/" in desktop_id or "\\" in desktop_id or desktop_id.startswith("."):
        return None
    data_home = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
    entries = [data_home / "applications"]
    entries += [
        Path(root) / "applications"
        for root in os.environ.get(
            "XDG_DATA_DIRS",
            "/run/current-system/sw/share:/etc/profiles/per-user/" + os.environ.get("USER", "") + "/share",
        ).split(":")
        if root
    ]
    name = desktop_id if desktop_id.endswith(".desktop") else desktop_id + ".desktop"
    for directory in entries:
        entry = directory / name
        if entry.is_file():
            return entry
    return None


def launch_with_application(desktop_id, filename):
    """Open a previously indexed file with an installed desktop entry."""
    entry = installed_desktop_entry(desktop_id)
    if entry is None or preview_indexed_file(filename) is None:
        return 2
    try:
        subprocess.Popen(
            ["gio", "launch", str(entry), filename],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        return 0
    except OSError:
        return 1


def launch_url_with_application(desktop_id, url):
    """Open an HTTP(S) URL using a user-selected, installed desktop entry."""
    entry = installed_desktop_entry(desktop_id)
    if entry is None or not isinstance(url, str) or len(url) > 4096:
        return 2
    parsed = urlsplit(url)
    if parsed.scheme not in ("http", "https") or not parsed.hostname or any(ord(char) < 32 for char in url):
        return 2
    try:
        subprocess.Popen(
            ["gio", "launch", str(entry), url],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        return 0
    except OSError:
        return 1


def preview_indexed_file(filename):
    """Only inspect currently indexed local paths, never arbitrary user input."""
    path = Path(filename)
    roots = [root for root in search_roots() if is_indexable(path, root)]
    if not path.is_absolute() or not roots:
        return None
    try:
        with sqlite3.connect(f"file:{DB}?mode=ro", uri=True, timeout=0.25) as db:
            indexed = db.execute("SELECT kind FROM items WHERE path = ? LIMIT 1", (str(path),)).fetchone()
        if indexed is None or indexed[0] == 2:
            return None
        relative = path.relative_to(roots[0])
        if any((roots[0] / Path(*relative.parts[:index])).is_symlink() for index in range(1, len(relative.parts) + 1)):
            return None
        details = path.stat()
        if not (path.is_dir() or path.is_file()):
            return None
        mime = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        info = {
            "name": path.name,
            "path": str(path),
            "type": "Directory" if path.is_dir() else mime,
            "size": details.st_size if path.is_file() else None,
            "modified": datetime.fromtimestamp(details.st_mtime).astimezone().strftime("%Y-%m-%d %H:%M"),
            "excerpt": "",
        }
        if (
            path.is_file()
            and details.st_size <= 131072
            and (mime.startswith("text/") or path.suffix.lower() in {".md", ".json", ".yaml", ".yml", ".toml", ".nix"})
        ):
            with path.open("rb") as source:
                info["excerpt"] = source.read(768).decode("utf-8", errors="replace").replace("\r", "").replace("\n", " ↵ ").strip()[:480]
        return info
    except (OSError, sqlite3.Error, ValueError):
        return None


def start_search_socket():
    """Serve index searches from the existing watcher without spawning Python per key."""
    import socket
    import socketserver
    import stat
    import threading

    runtime = Path(os.environ["XDG_RUNTIME_DIR"])
    endpoint = runtime / "linux-desktop-palette.sock"
    if endpoint.exists() or endpoint.is_symlink():
        info = endpoint.lstat()
        if not stat.S_ISSOCK(info.st_mode) or info.st_uid != os.getuid():
            raise RuntimeError("palette search socket path is not an owned socket")
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as probe:
            if probe.connect_ex(str(endpoint)) == 0:
                raise RuntimeError("palette search service already running")
        endpoint.unlink()

    class Server(socketserver.ThreadingUnixStreamServer):
        daemon_threads = True
        request_queue_size = 8

        def __init__(self, address, handler):
            self.clients = set()
            self.write_lock = threading.RLock()
            super().__init__(address, handler)

        def notify(self):
            with self.write_lock:
                for client in list(self.clients):
                    try:
                        client.sendall(b'{"event":"updated"}\n')
                    except OSError:
                        self.clients.discard(client)

    class Handler(socketserver.StreamRequestHandler):
        def setup(self):
            super().setup()
            with self.server.write_lock:
                self.server.clients.add(self.request)

        def handle(self):
            while True:
                line = self.rfile.readline(1025)
                if not line:
                    break
                if len(line) > 1024 or not line.endswith(b"\n"):
                    break
                try:
                    request = json.loads(line)
                    identifier = request["id"]
                    phrase = request.get("query")
                    inspection = request.get("inspect")
                    if not isinstance(identifier, int) or not 0 <= identifier <= 2147483647:
                        break
                    if isinstance(phrase, str) and inspection is None:
                        payload = json.dumps({"id": identifier, "items": query(phrase)}, ensure_ascii=False)
                    elif isinstance(inspection, str) and len(inspection) <= 4096 and phrase is None:
                        payload = json.dumps({"id": identifier, "info": preview_indexed_file(inspection)}, ensure_ascii=False)
                    else:
                        break
                except (KeyError, TypeError, ValueError):
                    break
                with self.server.write_lock:
                    self.request.sendall((payload + "\n").encode())

        def finish(self):
            with self.server.write_lock:
                self.server.clients.discard(self.request)
            super().finish()

    original_mask = os.umask(0o077)
    try:
        server = Server(str(endpoint), Handler)
        os.chmod(endpoint, 0o600)
    finally:
        os.umask(original_mask)
    thread = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 3600}, daemon=True)
    thread.start()
    return server, endpoint


def watch():
    """Rebuild on relevant Linux inotify changes, never on a recurring timer."""
    signal.signal(signal.SIGTERM, lambda _signal, _frame: sys.exit(0))

    home = Path.home()
    config = Path(
        os.environ.get(
            "LINUX_DESKTOP_RUNTIME", str(Path(os.environ.get("XDG_CONFIG_HOME", str(home / ".config"))) / "linux-desktop/runtime.json")
        )
    )
    search_server, search_endpoint = start_search_socket()
    try:
        watch_changes(search_server, home, config)
    finally:
        search_server.server_close()
        search_endpoint.unlink(missing_ok=True)


def watch_changes(search_server, home, config):
    """Apply filesystem and browser changes using event-driven watching."""
    from queue import Empty, Queue

    from watchdog.events import FileSystemEventHandler
    from watchdog.observers import Observer

    while True:
        index()
        search_server.notify()
        roots = search_roots()
        notifications = Queue()
        observer = Observer()
        watch_paths = set()
        browser_layout = set(browser_watch_containers())

        class Changes(FileSystemEventHandler):
            def on_any_event(self, event, roots=roots, notifications=notifications, browser_layout=browser_layout):
                if event.event_type in ("opened", "closed_no_write"):
                    return
                source = Path(event.src_path)
                paths = (source, Path(event.dest_path)) if getattr(event, "dest_path", "") else (source,)
                for path in paths:
                    if path == config or any(is_indexable(path, root) for root in roots):
                        notifications.put(event)
                        return
                    if is_bookmark_change(path):
                        notifications.put(event)
                        return
                    if event.is_directory and (path.parent in browser_layout or is_watch_layout_change(path, roots)):
                        notifications.put(event)
                        return

        handler = Changes()

        def add(path, recursive, observer=observer, handler=handler, watch_paths=watch_paths):
            if path.is_dir() and not path.is_symlink() and (str(path), recursive) not in watch_paths:
                observer.schedule(handler, str(path), recursive=recursive)
                watch_paths.add((str(path), recursive))

        add(home, False)
        add(config.parent, False)
        for root in roots:
            add(root, True)
        # A handful of recursive XDG observers covers any installed browser
        # layout. Avoid one watchdog emitter (thread, pipe and FD) per app or
        # profile directory, which exhausts the normal 1024-FD service limit.
        xdg_roots = (
            Path(os.environ.get("XDG_CONFIG_HOME", str(home / ".config"))),
            Path(os.environ.get("XDG_DATA_HOME", str(home / ".local/share"))),
            home / ".var/app",
        )
        for base in xdg_roots:
            add(base, True)
        for base in browser_profile_roots():
            if not any(base == root or base.is_relative_to(root) for root in xdg_roots if root.is_dir()):
                add(base, True)
        for base in browser_layout:
            if not any(base == root or base.is_relative_to(root) for root in xdg_roots if root.is_dir()):
                add(base, False)

        observer.start()
        try:
            while True:
                event = notifications.get()
                batch = [event]
                # Wait only after receiving an event to coalesce write bursts.
                while True:
                    try:
                        batch.append(notifications.get(timeout=0.35))
                    except Empty:
                        break
                change_layout = any(event.is_directory or Path(event.src_path) == config for event in batch)
                if change_layout:
                    break
                changed = {Path(path) for event in batch for path in (event.src_path, getattr(event, "dest_path", "")) if path}
                if any(is_bookmark_change(path) for path in changed):
                    update_bookmarks()
                update_changed_files(changed, roots)
                search_server.notify()
        finally:
            observer.stop()
            observer.join()


def is_indexable(path, root):
    """Check that an indexed path stays inside a permitted search root."""
    try:
        relative = path.relative_to(root)
    except ValueError:
        return False
    return not any(part.startswith(".") or part in EXCLUDED for part in relative.parts)


def is_bookmark_change(path):
    """Recognize browser bookmark files that require reindexing."""
    return path.name in {"Bookmarks", "places.sqlite", "profiles.ini"} or path.name.startswith("places.sqlite-")


def is_watch_layout_change(path, roots):
    """Detect filesystem changes that require rebuilding the watcher layout."""
    if path in roots:
        return True
    if path.parent == Path.home() and path in declared_roots():
        return True
    config = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
    data = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
    return path.parent in {Path.home(), config, data, Path.home() / ".var/app"} or path in set(browser_profile_roots())


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "index":
        index()
    elif len(sys.argv) == 2 and sys.argv[1] == "watch":
        watch()
    elif len(sys.argv) == 3 and sys.argv[1] == "search":
        print(json.dumps(query(sys.argv[2]), ensure_ascii=False))
    elif len(sys.argv) == 4 and sys.argv[1] == "launch":
        raise SystemExit(launch_with_application(sys.argv[2], sys.argv[3]))
    elif len(sys.argv) == 4 and sys.argv[1] == "launch-url":
        raise SystemExit(launch_url_with_application(sys.argv[2], sys.argv[3]))
    else:
        raise SystemExit("usage: palette-search {index|watch|search <query>|launch <desktop-id> <path>|launch-url <desktop-id> <url>}")

#!/usr/bin/env python3
"""Local filename and bookmark index for the native desktop palette."""

import json
import os
import sqlite3
import sys
from pathlib import Path

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


def search_roots():
    home = Path.home()
    defaults = [home / name for name in ("Documents", "Downloads", "Desktop", "Projects", "repos", "src", "Uni")]
    config = Path(os.environ.get("XDG_CONFIG_HOME", str(home / ".config"))) / "linux-desktop/files.json"
    try:
        value = json.loads(config.read_text())
        if isinstance(value.get("roots"), list):
            defaults = [Path(os.path.expanduser(x)) for x in value["roots"] if isinstance(x, str)]
    except (OSError, ValueError, TypeError):
        pass
    result = []
    for root in defaults:
        if root.is_absolute() and root.is_dir() and not root.is_symlink() and root != home and not str(root).startswith("/nix/"):
            result.append(root)
    return list(dict.fromkeys(result))


def files():
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


def bookmarks():
    home = Path.home()
    configs = [
        (home / ".config/chromium", "chromium"),
        (home / ".config/google-chrome", "google-chrome-stable"),
        (home / ".config/BraveSoftware/Brave-Browser", "brave-browser"),
    ]
    for folder, browser in configs:
        for source in [folder / "Default/Bookmarks"] + sorted(folder.glob("Profile */Bookmarks"))[:12]:
            try:
                data = json.loads(source.read_text())
            except (OSError, ValueError):
                continue

            def visit(node):
                if isinstance(node, dict):
                    if node.get("type") == "url" and isinstance(node.get("url"), str):
                        url = node["url"]
                        if url.startswith(("http://", "https://")):
                            yield (url, str(node.get("name", url))[:200], 2, browser)
                    for child in node.get("children", []) or []:
                        yield from visit(child)

            for node in data.get("roots", {}).values():
                yield from visit(node)

    firefox = home / ".mozilla/firefox"
    for source in sorted(firefox.glob("*.default*/places.sqlite"))[:12]:
        try:
            db = sqlite3.connect(f"file:{source}?mode=ro", uri=True, timeout=0.5)
            try:
                rows = db.execute(
                    "SELECT p.url, b.title FROM moz_bookmarks b JOIN moz_places p ON p.id=b.fk WHERE b.type=1 AND p.url LIKE 'http%' LIMIT 10000"
                )
                for url, title in rows:
                    if isinstance(url, str) and url.startswith(("http://", "https://")):
                        yield (url, (title or url)[:200], 2, "firefox")
            finally:
                db.close()
        except (OSError, sqlite3.Error):
            continue


def index():
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
    if not DB.is_file() or not text.strip() or len(text) > 150:
        return []
    phrase = text.strip().lower()
    # Escape wildcard characters. This is a substring match, not user SQL.
    escaped = phrase.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    db = None
    try:
        db = sqlite3.connect(f"file:{DB}?mode=ro", uri=True, timeout=0.25)
        rows = db.execute(
            "SELECT path, name, kind, browser FROM items WHERE name LIKE ? ESCAPE '\\' OR path LIKE ? ESCAPE '\\' LIMIT 256",
            (f"%{escaped}%", f"%{escaped}%"),
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
                    phrase = request["query"]
                    if not isinstance(identifier, int) or not 0 <= identifier <= 2147483647 or not isinstance(phrase, str):
                        break
                    payload = json.dumps({"id": identifier, "items": query(phrase)}, ensure_ascii=False)
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

    home = Path.home()
    config = Path(os.environ.get("XDG_CONFIG_HOME", str(home / ".config"))) / "linux-desktop/files.json"
    search_server, search_endpoint = start_search_socket()
    try:
        watch_changes(search_server, home, config)
    finally:
        search_server.server_close()
        search_endpoint.unlink(missing_ok=True)


def watch_changes(search_server, home, config):
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

        def add(path, recursive):
            if path.is_dir() and not path.is_symlink() and (str(path), recursive) not in watch_paths:
                observer.schedule(handler, str(path), recursive=recursive)
                watch_paths.add((str(path), recursive))

        class Changes(FileSystemEventHandler):
            def on_any_event(self, event):
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
                    if event.is_directory and is_watch_layout_change(path, roots):
                        notifications.put(event)
                        return

        handler = Changes()
        add(home, False)
        add(config.parent, False)
        for root in roots:
            add(root, True)
        for base in (
            home / ".config/chromium",
            home / ".config/google-chrome",
            home / ".config/BraveSoftware/Brave-Browser",
            home / ".mozilla/firefox",
        ):
            add(base, False)
            if base.is_dir():
                for child in base.iterdir():
                    if child.is_dir() and (child.name == "Default" or child.name.startswith("Profile ") or ".default" in child.name):
                        add(child, False)

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
    try:
        relative = path.relative_to(root)
    except ValueError:
        return False
    return not any(part.startswith(".") or part in EXCLUDED for part in relative.parts)


def is_bookmark_change(path):
    if path.name == "Bookmarks" and (path.parent.name == "Default" or path.parent.name.startswith("Profile ")):
        return True
    return path.name.startswith("places.sqlite") and ".default" in path.parent.name


def is_watch_layout_change(path, roots):
    if path in roots:
        return True
    if path.parent == Path.home() and path.name in {"Documents", "Downloads", "Desktop", "Projects", "repos", "src", "Uni"}:
        return True
    return path.parent.name in {"chromium", "google-chrome", "Brave-Browser", "firefox"}


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "index":
        index()
    elif len(sys.argv) == 2 and sys.argv[1] == "watch":
        watch()
    elif len(sys.argv) == 3 and sys.argv[1] == "search":
        print(json.dumps(query(sys.argv[2]), ensure_ascii=False))
    else:
        raise SystemExit("usage: palette-search {index|watch|search <query>}")

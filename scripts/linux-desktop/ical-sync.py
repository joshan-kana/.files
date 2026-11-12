#!/usr/bin/env python3
"""Mirror private read-only iCalendar feeds into vdirsyncer-managed collections."""

import hashlib
import json
import os
import stat
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request
from pathlib import Path

MAX_FEED_BYTES = 12 * 1024 * 1024


class HttpsRedirects(urllib.request.HTTPRedirectHandler):
    """Refuse to follow a private feed URL onto an insecure transport."""

    def redirect_request(self, request, fp, code, msg, headers, url):
        """Reject insecure redirects before their destination is requested."""
        if urllib.parse.urlsplit(url).scheme != "https":
            raise ValueError("insecure calendar redirect")
        return super().redirect_request(request, fp, code, msg, headers, url)


def private_sources(home):
    """Discover subscribed feeds without moving their URLs into Nix or logs."""
    private_root = home / ".secrets"
    legacy = private_root / "calendar-ical-url"
    if legacy.exists() or legacy.is_symlink():
        yield hashlib.sha256(b"legacy").hexdigest()[:24], legacy

    directory = private_root / "calendar-icals"
    if not directory.exists() and not directory.is_symlink():
        return
    if directory.is_symlink() or not directory.is_dir():
        raise ValueError("invalid private calendar directory")
    if stat.S_IMODE(directory.stat().st_mode) & 0o077:
        raise ValueError("calendar directory is not private")
    for source in sorted(directory.glob("*.url")):
        identity = hashlib.sha256(("file:" + source.name).encode()).hexdigest()[:24]
        yield identity, source


def download(source):
    """Download a bounded HTTPS feed with the existing fail-closed policy."""
    if source.is_symlink() or not source.is_file():
        raise ValueError("invalid private calendar source")
    if stat.S_IMODE(source.stat().st_mode) & 0o077:
        raise ValueError("calendar source is not private")
    url = source.read_text(encoding="utf-8").strip()
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "https" or not parsed.hostname or "\n" in url or "\r" in url:
        raise ValueError("invalid calendar transport")
    opener = urllib.request.build_opener(HttpsRedirects())
    with opener.open(urllib.request.Request(url), timeout=18) as response:
        if urllib.parse.urlsplit(response.geturl()).scheme != "https":
            raise ValueError("invalid calendar redirect")
        body = response.read(MAX_FEED_BYTES + 1)
    if len(body) > MAX_FEED_BYTES:
        raise ValueError("calendar feed exceeds limit")
    return body


def sync_source(identity, source, data_home, state_home, runtime):
    """Let vdirsyncer own vdir generation, recurrence handling and updates."""
    collection = data_home / "calendars" / "subscriptions" / identity
    if collection.is_symlink():
        raise ValueError("calendar collection cannot be a symlink")
    collection.mkdir(parents=True, exist_ok=True, mode=0o700)
    status_root = state_home / "linux-desktop" / "vdirsyncer"
    if status_root.is_symlink():
        raise ValueError("calendar status directory cannot be a symlink")
    status_root.mkdir(parents=True, exist_ok=True, mode=0o700)

    with tempfile.TemporaryDirectory(prefix="ical-subscription-", dir=runtime) as scratch:
        scratch = Path(scratch)
        feed = scratch / "feed.ics"
        feed.write_bytes(download(source))
        feed.chmod(0o600)
        config = scratch / "vdirsyncer.conf"
        config.write_text(
            "\n".join(
                [
                    "[general]",
                    "status_path = " + json.dumps(str(status_root / identity)),
                    "[pair subscription]",
                    'a = "local"',
                    'b = "remote"',
                    "collections = null",
                    'partial_sync = "error"',
                    "[storage local]",
                    'type = "filesystem"',
                    "path = " + json.dumps(str(collection)),
                    'fileext = ".ics"',
                    "[storage remote]",
                    'type = "singlefile"',
                    "path = " + json.dumps(str(feed)),
                    "read_only = true",
                ]
            ),
            encoding="utf-8",
        )
        config.chmod(0o600)
        for action in ("discover", "sync"):
            subprocess.run(
                ["vdirsyncer", "--config", str(config), action],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=True,
                timeout=35,
            )


def main():
    """Activate new vdir subscriptions only after all feeds have synced."""
    home = Path.home()
    data_home = Path(os.environ.get("XDG_DATA_HOME", home / ".local/share"))
    state_home = Path(os.environ.get("XDG_STATE_HOME", home / ".local/state"))
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", tempfile.gettempdir()))
    try:
        feeds = list(private_sources(home))
    except Exception:
        print("Calendar subscription configuration invalid", file=sys.stderr)
        return 1

    failures = 0
    for identity, source in feeds:
        try:
            sync_source(identity, source, data_home, state_home, runtime)
        except Exception:
            failures += 1
    if failures:
        print(
            f"Calendar refresh failed for {failures} subscription(s); cached events retained",
            file=sys.stderr,
        )
        return 1
    if not feeds:
        return 0

    try:
        # The previous khal vdir is retained as a rollback source. Agenda
        # queries suppress its subscription copies after vdir activation.
        marker = state_home / "linux-desktop" / "ical-vdir-ready"
        marker.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        temporary = marker.with_suffix(".tmp")
        temporary.write_text("1\n", encoding="utf-8")
        temporary.chmod(0o600)
        os.replace(temporary, marker)
    except Exception:
        print("Calendar migration incomplete; existing data retained", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

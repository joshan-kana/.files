#!/usr/bin/env python3
"""Read-only private calendar integration for the desktop agenda."""

import hashlib
import os
import re
import stat
import sys
import tempfile
import urllib.parse
import urllib.request
from pathlib import Path

from icalendar import Calendar

MAX_FEED_BYTES = 12 * 1024 * 1024
PREFIX = "google-ical-"
FEED_DIRECTORY = "calendar-icals"
LEGACY_FILENAME = "calendar-ical-url"


class HttpsRedirects(urllib.request.HTTPRedirectHandler):
    """Prevent HTTPS subscriptions from redirecting to insecure transports."""

    def redirect_request(self, req, fp, code, msg, headers, url):
        """Reject downgrades before requesting a redirected calendar."""
        if urllib.parse.urlsplit(url).scheme != "https":
            raise ValueError("insecure calendar redirect")
        return super().redirect_request(req, fp, code, msg, headers, url)


def sources():
    """Discover private iCalendar source descriptions."""
    private_root = Path.home() / ".secrets"
    legacy = private_root / LEGACY_FILENAME
    if legacy.exists() or legacy.is_symlink():
        yield "legacy", legacy
    directory = private_root / FEED_DIRECTORY
    if not directory.exists() and not directory.is_symlink():
        return
    if directory.is_symlink() or not directory.is_dir():
        raise ValueError("invalid calendar directory")
    if stat.S_IMODE(directory.stat().st_mode) & 0o077:
        raise ValueError("calendar directory must be private")
    for entry in sorted(directory.iterdir()):
        if entry.name.endswith(".url"):
            yield "file:" + entry.name, entry


def read_feed(source_file):
    """Fetch a bounded HTTPS-only iCalendar subscription."""
    if source_file.is_symlink() or not source_file.is_file():
        raise ValueError("calendar source must be a regular file")
    if stat.S_IMODE(source_file.stat().st_mode) & 0o077:
        raise ValueError("calendar source must be private")
    url = source_file.read_text(encoding="utf-8").strip()
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "https" or not parsed.hostname:
        raise ValueError("calendar URL must use HTTPS")
    opener = urllib.request.build_opener(HttpsRedirects())
    with opener.open(urllib.request.Request(url), timeout=18) as response:
        if urllib.parse.urlsplit(response.geturl()).scheme != "https":
            raise ValueError("insecure calendar redirect")
        data = response.read(MAX_FEED_BYTES + 1)
    if len(data) > MAX_FEED_BYTES:
        raise ValueError("calendar feed too large")
    return data


def namespace_for(source):
    """Derive a stable, private namespace for a feed identifier."""
    return PREFIX + hashlib.sha256(source.encode("utf-8")).hexdigest()[:24] + "--"


def split_events(data, namespace=PREFIX):
    """Split a subscribed calendar into one file per event UID."""
    if not data.strip().startswith(b"BEGIN:VCALENDAR") or b"END:VCALENDAR" not in data:
        raise ValueError("not an iCalendar feed")
    feed = Calendar.from_ical(data)
    if str(feed.get("VERSION", "")) != "2.0":
        raise ValueError("unsupported calendar version")
    zones = [entry for entry in feed.subcomponents if entry.name == "VTIMEZONE"]
    events = {}
    event_count = 0
    for entry in feed.subcomponents:
        if entry.name != "VEVENT":
            continue
        uid = str(entry.get("UID", "")).strip()
        if not uid:
            raise ValueError("calendar event without UID")
        events.setdefault(uid, []).append(entry)
        event_count += 1
        if event_count > 40000:
            raise ValueError("too many calendar events")
    files = {}
    for uid, entries in events.items():
        item = Calendar()
        item.add("VERSION", "2.0")
        item.add("PRODID", "-//linux-desktop//local iCalendar subscription//")
        for zone in zones:
            item.add_component(zone)
        for event in entries:
            item.add_component(event)
        name = namespace + hashlib.sha256(uid.encode("utf-8")).hexdigest() + ".ics"
        files[name] = item.to_ical()
    return files


def sync_files(files, namespace=PREFIX):
    """Atomically update only the cache for one source namespace."""
    base = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "calendars" / "personal"
    if base.is_symlink():
        raise ValueError("calendar directory cannot be a symlink")
    base.mkdir(parents=True, exist_ok=True, mode=0o700)
    staged = []
    try:
        for name, data in files.items():
            fd, filename = tempfile.mkstemp(prefix=".ical-stage-", dir=base)
            staged.append((Path(filename), base / name))
            with os.fdopen(fd, "wb") as destination:
                destination.write(data)
            os.chmod(filename, 0o600)
        for tmp, destination in staged:
            os.replace(tmp, destination)
        existing = set(files)
        for path in base.glob(namespace + "*.ics"):
            if path.name not in existing and path.is_file() and not path.is_symlink():
                path.unlink()
    finally:
        for temporary, _ in staged:
            temporary.unlink(missing_ok=True)


def main():
    """Refresh subscribed calendars without exposing private event details."""
    try:
        feed_sources = list(sources())
    except Exception:
        print("iCalendar source configuration invalid", file=sys.stderr)
        return 1
    failed = 0
    for source, path in feed_sources:
        try:
            namespace = namespace_for(source)
            files = split_events(read_feed(path), namespace)
            sync_files(files, namespace)
            if source == "legacy":
                # The original single-feed format lacked a source
                # namespace. Retire only its 64-hex-name files after
                # the legacy feed is successfully imported.
                base = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "calendars" / "personal"
                for old in base.glob(PREFIX + "*.ics"):
                    suffix = old.name[len(PREFIX) : -4]
                    if len(suffix) == 64 and all(c in "0123456789abcdef" for c in suffix) and old.is_file() and not old.is_symlink():
                        old.unlink()
        except Exception:
            failed += 1
    directory = Path.home() / ".secrets" / FEED_DIRECTORY
    if directory.is_dir() and not directory.is_symlink():
        # Removing or renaming a .url file intentionally removes only
        # that source's previously imported events. When the private
        # source directory itself is unavailable, retain all caches.
        active_namespaces = {namespace_for(source) for source, _ in feed_sources}
        base = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "calendars" / "personal"
        if base.is_dir() and not base.is_symlink():
            for cached in base.glob(PREFIX + "*.ics"):
                if not re.fullmatch(r"google-ical-[0-9a-f]{24}--[0-9a-f]{64}\.ics", cached.name):
                    continue
                if not any(cached.name.startswith(name) for name in active_namespaces) and cached.is_file() and not cached.is_symlink():
                    cached.unlink()
    if failed:
        # Do not write private feed URLs or event titles to the journal.
        print("iCalendar refresh failed for " + str(failed) + " source(s); cached events retained", file=sys.stderr)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

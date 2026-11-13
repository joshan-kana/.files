#!/usr/bin/env python3
"""Read-only private calendar integration for the desktop agenda."""

import contextlib
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", str(HOME / ".config")))
DATA = Path(os.environ.get("XDG_DATA_HOME", str(HOME / ".local/share")))
STATE = Path(os.environ.get("XDG_STATE_HOME", str(HOME / ".local/state")))
VDIR_READY = STATE / "linux-desktop/ical-vdir-ready"
SUBSCRIPTIONS = DATA / "calendars/subscriptions"
SOURCES = HOME / ".secrets/calendar-icals"
CACHE = DATA / "calendars/personal"
SETTINGS = CONFIG / "linux-desktop/calendar-visibility.json"
EVENT_FILENAME = re.compile(r"^google-ical-([a-f0-9]{24})--([a-f0-9]{64})\.ics$")
DATE = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$")


def calendars():
    """Enumerate locally configured, private calendar subscriptions."""
    feeds = []
    if SOURCES.is_dir() and not SOURCES.is_symlink():
        for path in sorted(SOURCES.glob("*.url")):
            if path.is_file() and not path.is_symlink():
                key = hashlib.sha256(("file:" + path.name).encode()).hexdigest()[:24]
                feeds.append({"id": key, "name": path.stem})
    legacy = HOME / ".secrets/calendar-ical-url"
    if legacy.is_file() and not legacy.is_symlink():
        feeds.append({"id": hashlib.sha256(b"legacy").hexdigest()[:24], "name": "Calendar"})
    return feeds


def disabled_ids():
    """Read the calendar IDs hidden by the current user."""
    if not SETTINGS.is_file() or SETTINGS.is_symlink():
        return set()
    try:
        contents = json.loads(SETTINGS.read_text(encoding="utf-8"))
        return {value for value in contents.get("disabled", []) if isinstance(value, str)}
    except (ValueError, OSError, AttributeError, TypeError):
        return set()


def set_enabled(source, enabled):
    """Persist a visibility override for a known calendar source."""
    if source not in {item["id"] for item in calendars()}:
        raise ValueError("unknown calendar source")
    disabled = disabled_ids()
    if enabled:
        disabled.discard(source)
    else:
        disabled.add(source)
    SETTINGS.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".calendar-visibility-", dir=SETTINGS.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump({"disabled": sorted(disabled)}, stream)
        os.chmod(temporary, 0o600)
        os.replace(temporary, SETTINGS)
    finally:
        Path(temporary).unlink(missing_ok=True)


def read_index():
    """Map cached event identifiers to their source namespaces."""
    # The importer namespaces each file by source and hashes its UID.
    # Resolve khal's recurring instances without reparsing every ICS.
    index = {}
    if CACHE.is_dir():
        for path in CACHE.glob("google-ical-*.ics"):
            match = EVENT_FILENAME.fullmatch(path.name)
            if match:
                index.setdefault(match.group(2), set()).add(match.group(1))
    return index


def subscriptions_ready(feeds):
    """Use the new view only when all current subscriptions have a vdir."""
    return (
        VDIR_READY.is_file()
        and not VDIR_READY.is_symlink()
        and all((SUBSCRIPTIONS / feed["id"]).is_dir() and not (SUBSCRIPTIONS / feed["id"]).is_symlink() for feed in feeds)
    )


@contextlib.contextmanager
def khal_config(feeds):
    """Add standard vdir collections without modifying the user's khal config."""
    original = CONFIG / "khal/config"
    if not subscriptions_ready(feeds):
        yield original
        return
    text = original.read_text(encoding="utf-8")
    if "[calendars]" not in text:
        raise ValueError("khal calendar configuration missing")
    entries = []
    for feed in feeds:
        folder = SUBSCRIPTIONS / feed["id"]
        if folder.is_dir() and not folder.is_symlink():
            entries.append("[[subscription-" + feed["id"] + "]]\n" + "path = " + str(folder) + "\n" + "type = calendar\nreadonly = True\n")
    content = text.replace("[calendars]", "[calendars]\n" + "\n".join(entries), 1)
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", tempfile.gettempdir()))
    with tempfile.TemporaryDirectory(prefix="khal-subscriptions-", dir=runtime) as scratch:
        config = Path(scratch) / "config"
        config.write_text(content, encoding="utf-8")
        config.chmod(0o600)
        yield config


def agenda(start):
    """Return the selected week with per-calendar visibility applied."""
    feeds = calendars()
    disabled = disabled_ids()
    selected = [{"id": feed["id"], "name": feed["name"], "enabled": feed["id"] not in disabled} for feed in feeds]
    if not (CONFIG / "khal/config").is_file():
        return {"configured": False, "calendars": selected, "events": []}
    from datetime import date, timedelta

    last_day = date.fromisoformat(start) + timedelta(days=6)
    end = last_day.isoformat()
    args = [
        "khal",
        "list",
        "--json",
        "calendar",
        "--json",
        "uid",
        "--json",
        "title",
        "--json",
        "start-date",
        "--json",
        "start-time",
        "--json",
        "end-date",
        "--json",
        "end-time",
        "--json",
        "location",
        start,
        end,
    ]
    with khal_config(feeds) as config:
        output = subprocess.run(
            ["khal", "--config", str(config), *args[1:]],
            capture_output=True,
            text=True,
            check=True,
        ).stdout
    native = subscriptions_ready(feeds)
    index = read_index()
    known = {feed["id"]: feed["name"] for feed in feeds}
    events = []
    for line in output.splitlines():
        if not line.strip():
            continue
        for event in json.loads(line):
            uid_hash = hashlib.sha256(str(event.get("uid", "")).encode()).hexdigest()
            origins = index.get(uid_hash, set())
            if native:
                calendar = str(event.get("calendar", ""))
                identity = calendar.removeprefix("subscription-") if calendar.startswith("subscription-") else ""
                if identity and (identity not in known or identity in disabled):
                    continue
                # Keep the old imported files for rollback but do not show
                # the same subscribed event twice in the agenda.
                if calendar == "personal" and origins:
                    continue
                source = known.get(identity, calendar if calendar != "personal" else "Local")
            else:
                if origins and not any(source in known and source not in disabled for source in origins):
                    continue
                source = next((known[item] for item in sorted(origins) if item in known), "Local")
            event_start = event.get("start-date", "")
            event_end = event.get("end-date", "")
            if event_start > end:
                continue
            carried = event_start < start
            display_date = event_start
            display_time = event.get("start-time", "")
            if carried:
                if not event_end:
                    continue
                # Khal also includes events spanning the entire week.
                # Do not put month-old starting dates before this week's
                # appointments. Include carryovers only when they end
                # within the selected week.
                finish = date.fromisoformat(event_end)
                if not event.get("start-time") and not event.get("end-time"):
                    finish -= timedelta(days=1)  # all-day end is exclusive
                if not date.fromisoformat(start) <= finish <= last_day:
                    continue
                display_date = finish.isoformat()
                display_time = event.get("end-time", "")
            events.append(
                {
                    "calendar": source,
                    "date": display_date,
                    "time": display_time,
                    "dateKind": "ENDS" if carried else "",
                    "endTime": event.get("end-time", ""),
                    "title": event.get("title", ""),
                    "location": event.get("location", "") or "",
                }
            )
    events.sort(key=lambda entry: (entry["date"], entry["time"], entry["title"]))
    return {"configured": True, "calendars": selected, "events": events}


def main():
    """Dispatch a calendar query or visibility change."""
    if len(sys.argv) == 4 and sys.argv[1] == "--set-enabled" and sys.argv[3] in ("true", "false"):
        set_enabled(sys.argv[2], sys.argv[3] == "true")
        return
    if len(sys.argv) != 2 or not DATE.fullmatch(sys.argv[1]):
        raise ValueError("usage: linux-desktop-agenda-query YYYY-MM-DD")
    print(json.dumps(agenda(sys.argv[1])))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # Never print private event contents or feed URLs to journald.
        print("Calendar query failed", file=sys.stderr)
        sys.exit(1)

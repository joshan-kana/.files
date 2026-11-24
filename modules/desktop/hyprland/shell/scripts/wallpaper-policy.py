#!/usr/bin/env python3
"""Wallpaper favourites and rotation policy; the wallpaper library owns application."""

import contextlib
import fcntl
import json
import os
import random
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path.home() / "wallpapers"
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "desktop-shell/wallpapers"
STATE = STATE_DIR / "policy.json"
PROGRESS = STATE_DIR / "rotation.json"
TIMER = "desktop-shell-wallpaper-rotation.timer"
DEFAULTS = json.loads(os.environ["DESKTOP_WALLPAPER_POLICY_DEFAULTS"])


def read(path):
    """Read a persisted object without trusting unrelated fields."""
    try:
        value = json.loads(path.read_text())
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError):
        return {}


def save(path, value):
    """Replace a user-owned policy atomically with private permissions."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=path.name + "-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(value, stream)
            stream.write("\n")
        os.replace(name, path)
    finally:
        with contextlib.suppress(FileNotFoundError):
            os.unlink(name)


def command(*args):
    """Invoke an existing wallpaper or user service command."""
    result = subprocess.run(args, check=True, capture_output=True, text=True, timeout=45)
    return result.stdout.strip()


def library(*args):
    """Use the same library and state owner as the manual wallpaper gallery."""
    return command(os.environ["DESKTOP_WALLPAPER_LIBRARY"], *args)


def relative(value):
    """Accept only paths under the user's existing wallpaper library."""
    path = Path(value)
    if path.is_absolute():
        path = path.relative_to(ROOT)
    if ".." in path.parts or "\n" in str(path) or "\x00" in str(path):
        raise ValueError("Invalid wallpaper library path")
    return "" if str(path) == "." else str(path)


def validate(key, value):
    """Validate one policy field."""
    if key == "mode" and value in ("off", "interval", "dayNight"):
        return value
    if key == "target" and isinstance(value, str) and re.fullmatch(r"[A-Za-z0-9_.-]+", value):
        return value
    if key == "intervalMinutes" and value in (5, 15, 30, 60, 120):
        return int(value)
    if key == "favoritesOnly" and isinstance(value, bool):
        return value
    if key in ("dayStart", "nightStart") and isinstance(value, int) and 0 <= value <= 1439:
        return value
    if key in ("collection", "dayWallpaper", "nightWallpaper") and isinstance(value, str):
        return relative(value)
    raise ValueError("Invalid wallpaper policy " + key)


def resolved(state):
    """Resolve declared defaults with independent user overrides."""
    config = dict(DEFAULTS)
    overrides = state.get("overrides", {})
    if isinstance(overrides, dict):
        for key, value in overrides.items():
            with contextlib.suppress(ValueError, TypeError):
                config[key] = validate(key, value)
    return config


def favorites(state):
    """Return saved library-relative favourites."""
    result = []
    values = state.get("favorites", [])
    for value in values if isinstance(values, list) else []:
        if isinstance(value, str):
            with contextlib.suppress(ValueError):
                result.append(relative(value))
    return list(dict.fromkeys(result))


def entries():
    """Enumerate real library entries through the existing service."""
    return [relative(path) for path in json.loads(library("list"))]


def phase_at(minute, day_start, night_start):
    """Determine the day/night phase, including schedules across midnight."""
    if day_start == night_start:
        return ""
    if day_start < night_start:
        return "day" if day_start <= minute < night_start else "night"
    return "day" if minute >= day_start or minute < night_start else "night"


def candidates(config, state, all_entries):
    """Filter rotation sources without including unlisted or missing files."""
    allowed = set(favorites(state)) if config["favoritesOnly"] else None
    folder = config["collection"]
    return [item for item in all_entries if (allowed is None or item in allowed) and (not folder or item.startswith(folder + "/"))]


def status(state, progress):
    """Expose confirmed policy state and the last observed outcome."""
    return {
        "policy": resolved(state),
        "favorites": [str(ROOT / path) for path in favorites(state)],
        "nextDue": progress.get("nextDue", 0),
        "error": progress.get("error", ""),
        "phase": progress.get("phase", ""),
    }


def apply(state, progress, force=False):
    """Run one policy evaluation, with no application while the schedule is off."""
    config = resolved(state)
    mode, target = config["mode"], config["target"]
    if mode == "off":
        command("systemctl", "--user", "stop", TIMER)
        save(PROGRESS, {})
        return {}
    command("systemctl", "--user", "start", TIMER)
    now = time.time()
    local = time.localtime(now)
    minute = local.tm_hour * 60 + local.tm_min
    signature = json.dumps(config, sort_keys=True)
    try:
        current = library("current", target)
        if progress.get("signature") != signature:
            progress = {"signature": signature, "nextDue": now + config["intervalMinutes"] * 60, "lastPath": current}
        if mode == "interval":
            if current != progress.get("lastPath") and not force:
                # Manual selection starts a new interval instead of fighting
                # the user at the next timer wakeup.
                progress.update(lastPath=current, nextDue=now + config["intervalMinutes"] * 60)
            if force or now >= progress.get("nextDue", 0):
                choices = candidates(config, state, entries())
                if not choices:
                    raise ValueError("No wallpapers match the rotation source")
                others = [item for item in choices if str(ROOT / item) != current]
                selected = random.choice(others or choices)
                apply_wallpaper(target, selected)
                progress.update(lastPath=str(ROOT / selected), nextDue=now + config["intervalMinutes"] * 60)
        else:
            phase = phase_at(minute, config["dayStart"], config["nightStart"])
            if not phase:
                raise ValueError("Day and night start times must differ")
            if progress.get("phase") != phase or force:
                selected = config[phase + "Wallpaper"]
                available = entries()
                if not selected or any(not config[key] or config[key] not in available for key in ("dayWallpaper", "nightWallpaper")):
                    raise ValueError("Choose an existing wallpaper for both day and night")
                apply_wallpaper(target, selected)
                progress.update(phase=phase, lastPath=str(ROOT / selected))
            progress["nextDue"] = 0
        progress["error"] = ""
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        progress["error"] = str(error)[:240]
    save(PROGRESS, progress)
    return progress


def apply_wallpaper(target, selected):
    """Preserve the effective native fit and require service readback."""
    resize = library("current-resize", target)
    if resize not in ("fit", "crop"):
        raise ValueError("Wallpaper fit unavailable")
    library("set", target, resize, str(ROOT / selected))
    if library("current", target) != str(ROOT / selected):
        raise ValueError("Wallpaper application was not confirmed")


def main(args):
    """Serialize edits and timer callbacks under the existing user state root."""
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    with (STATE_DIR / "policy.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        action = args[0] if args else "status"
        state, progress = read(STATE), read(PROGRESS)
        if action == "favorite":
            selected = relative(args[1])
            if selected not in entries():
                raise ValueError("Wallpaper is no longer in the library")
            items = favorites(state)
            state["favorites"] = [item for item in items if item != selected] if selected in items else [*items, selected]
            save(STATE, state)
        elif action == "set":
            key = args[1]
            value = validate(key, json.loads(args[2]))
            next_overrides = dict(state.get("overrides", {}))
            next_overrides[key] = value
            state["overrides"] = next_overrides
            save(STATE, state)
            progress = apply(state, progress)
        elif action == "reset":
            state["overrides"] = {}
            save(STATE, state)
            progress = apply(state, {})
        elif action == "apply":
            progress = apply(state, progress)
        elif action == "next":
            if resolved(state)["mode"] != "interval":
                raise ValueError("Interval rotation is disabled")
            progress = apply(state, progress, force=True)
        elif action != "status":
            raise ValueError("Unknown wallpaper policy action")
        print(json.dumps(status(state, progress)))


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except (OSError, ValueError, KeyError, IndexError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)

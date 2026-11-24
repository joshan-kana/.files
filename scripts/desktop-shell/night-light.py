#!/usr/bin/env python3
"""Single session service owner for manual, scheduled and solar colour temperature."""

import contextlib
import datetime as dt
import fcntl
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from zoneinfo import ZoneInfo

SERVICE = "desktop-shell-night-light.service"
TIMER = "desktop-shell-night-light-apply.timer"
DEFAULTS = {
    "mode": "off",
    "temperature": 4500,
    "startMinute": 1140,
    "endMinute": 420,
    "days": 127,
    "transitionMinutes": 15,
    "latitude": None,
    "longitude": None,
}
DEFAULTS.update(json.loads(os.environ.get("DESKTOP_NIGHT_LIGHT_DEFAULTS", "{}")))
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "desktop-shell"
STATE = STATE_DIR / "night-light"
RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR", str(STATE_DIR))) / "desktop-shell-night-light.json"


def local_zone():
    """Read the host's timezone with daylight-saving rules."""
    try:
        with open("/etc/localtime", "rb") as source:
            return ZoneInfo.from_file(source)
    except OSError:
        return dt.datetime.now().astimezone().tzinfo


def atomic_write(path, value):
    """Replace state atomically with private permissions."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=path.name + "-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as output:
            json.dump(value, output, separators=(",", ":"))
            output.write("\n")
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def read_json(path):
    """Read a valid object or return an empty state."""
    try:
        value = json.loads(path.read_text())
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError):
        return {}


def validated(key, value):
    """Validate a single persisted policy setting."""
    if key == "mode":
        if value in ("off", "manual", "custom", "solar"):
            return value
    elif key in ("temperature", "startMinute", "endMinute", "days", "transitionMinutes"):
        ranges = {
            "temperature": (2500, 6500),
            "startMinute": (0, 1439),
            "endMinute": (0, 1439),
            "days": (0, 127),
            "transitionMinutes": (0, 60),
        }
        if isinstance(value, int) and not isinstance(value, bool) and ranges[key][0] <= value <= ranges[key][1]:
            return value
    raise ValueError("Invalid Night Light " + key)


def read_overrides(now):
    """Read overrides and migrate the previous state format."""
    try:
        text = STATE.read_text().strip()
    except FileNotFoundError:
        return {}
    try:
        saved = json.loads(text)
        if not isinstance(saved, dict):
            return {}
        result = {}
        for key in DEFAULTS:
            if key in saved and key not in ("latitude", "longitude"):
                with contextlib.suppress(ValueError):
                    result[key] = validated(key, saved[key])
        if saved.get("override") in ("on", "off") and isinstance(saved.get("until"), (int, float)):
            result.update(override=saved["override"], until=saved["until"])
        return result
    except ValueError:
        # Preserve the previous manual state and the legacy auto migration.
        parts = text.split()
        if len(parts) != 2:
            return {}
        mode = parts[0]
        if mode == "auto":
            mode = "manual" if now.hour >= 19 or now.hour < 7 else "off"
        try:
            return {"mode": validated("mode", mode), "temperature": validated("temperature", int(parts[1]))}
        except ValueError:
            return {}


def solar_available(config):
    """Check whether explicitly configured solar coordinates are valid."""
    lat, lon = config["latitude"], config["longitude"]
    return isinstance(lat, (int, float)) and isinstance(lon, (int, float)) and -90 <= lat <= 90 and -180 <= lon <= 180


def intervals(now, config):
    """Return local aware intervals, including the previous day's overnight window."""
    result = []
    mode = config["mode"]
    if mode not in ("custom", "solar"):
        return result
    if mode == "solar":
        if not solar_available(config):
            return result
        from astral import Observer
        from astral.sun import sunrise, sunset

        observer = Observer(latitude=config["latitude"], longitude=config["longitude"])
    for offset in range(-1, 9):
        day = now.date() + dt.timedelta(days=offset)
        if mode == "solar":
            try:
                start = sunset(observer, date=day, tzinfo=now.tzinfo)
                end = sunrise(observer, date=day + dt.timedelta(days=1), tzinfo=now.tzinfo)
            except ValueError:
                continue
        else:
            if not config["days"] & (1 << ((day.weekday() + 1) % 7)):
                continue
            start_minute, end_minute = config["startMinute"], config["endMinute"]
            if start_minute == end_minute:
                continue
            end_day = day + dt.timedelta(days=int(end_minute < start_minute))
            start = dt.datetime.combine(day, dt.time(start_minute // 60, start_minute % 60), now.tzinfo)
            end = dt.datetime.combine(end_day, dt.time(end_minute // 60, end_minute % 60), now.tzinfo)
        result.append((start.timestamp(), end.timestamp()))
    return result


def effective(now, config, saved):
    """Calculate the target temperature, next boundary and active override."""
    current = now.timestamp()
    mode = config["mode"]
    windows = intervals(now, config)
    active_window = next(((start, end) for start, end in windows if start <= current < end), None)
    future = [boundary for window in windows for boundary in window if boundary > current]
    next_change = min(future, default=0)
    override = saved.get("override", "") if saved.get("until", 0) > current else ""
    target = config["temperature"] if mode == "manual" or active_window else 6500
    if active_window and mode in ("custom", "solar") and config["transitionMinutes"]:
        start, end = active_window
        duration = config["transitionMinutes"] * 60
        fraction = min(1, (current - start) / duration, (end - current) / duration)
        target = round(6500 + (config["temperature"] - 6500) * max(0, fraction))
    if override == "off":
        target = 6500
    elif override == "on" and mode in ("custom", "solar"):
        target = config["temperature"]
    return target, next_change, override


def run_command(*args, check=True):
    """Run a service command and capture its reply."""
    return subprocess.run(args, check=check, capture_output=True, text=True)


def service_active():
    """Check the service's current activation state."""
    return run_command("systemctl", "--user", "--quiet", "is-active", SERVICE, check=False).returncode == 0


def status(now, config, saved):
    """Return the resolved policy and applied runtime status."""
    target, next_change, override = effective(now, config, saved)
    running = service_active()
    applied = read_json(RUNTIME)
    return {
        **config,
        "active": running and applied.get("effectiveTemperature", target) < 6500,
        "effectiveTemperature": applied.get("effectiveTemperature", target) if running else 6500,
        "nextTransition": int(next_change),
        "override": override,
        "until": int(saved.get("until", 0)) if override else 0,
        "solarAvailable": solar_available(config),
        "supported": True,
        "error": applied.get("error", ""),
    }


def apply(now, config, saved):
    """Reconcile the service and schedule with the effective policy."""
    target, _, override = effective(now, config, saved)
    previous = read_json(RUNTIME)
    try:
        scheduled = config["mode"] in ("custom", "solar") or bool(override)
        run_command("systemctl", "--user", "start" if scheduled else "stop", TIMER)
        if target < 6500:
            if not service_active():
                run_command("systemctl", "--user", "start", SERVICE)
            elif previous.get("effectiveTemperature") != target:
                reply = run_command("hyprctl", "hyprsunset", "temperature", str(target))
                if reply.stdout.strip().lower() != "ok":
                    raise subprocess.CalledProcessError(1, reply.args, stderr=reply.stdout)
        elif service_active():
            run_command("systemctl", "--user", "stop", SERVICE)
        atomic_write(RUNTIME, {"effectiveTemperature": target, "error": ""})
    except subprocess.CalledProcessError as error:
        atomic_write(
            RUNTIME,
            {
                "effectiveTemperature": previous.get("effectiveTemperature", 6500),
                "error": (error.stderr or "Night Light apply failed").strip()[:300],
            },
        )
        raise


def main(argv):
    """Dispatch a command, serializing all policy mutations."""
    now = dt.datetime.now(local_zone())
    command = argv[0] if argv else "state"
    saved = read_overrides(now)
    config = {**DEFAULTS, **{key: value for key, value in saved.items() if key in DEFAULTS}}
    if command == "run":
        target, _, _ = effective(now, config, saved)
        os.execvp("hyprsunset", ["hyprsunset", "--temperature", str(target)])
    if command == "state":
        print(json.dumps(status(now, config, saved)))
        return
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    with (STATE_DIR / "night-light.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        now = dt.datetime.now(local_zone())
        saved = read_overrides(now)
        config = {**DEFAULTS, **{key: value for key, value in saved.items() if key in DEFAULTS}}
        if command == "reset":
            saved = {}
        elif command == "mode":
            value = validated("mode", argv[1])
            if value == "solar" and not solar_available(config):
                raise ValueError("Configure an explicit solar latitude and longitude in Nix")
            saved["mode"] = value
            saved.pop("override", None)
            saved.pop("until", None)
        elif command == "toggle":
            if config["mode"] in ("custom", "solar") or effective(now, config, saved)[2]:
                target, boundary, override = effective(now, config, saved)
                if override:
                    saved.pop("override", None)
                    saved.pop("until", None)
                else:
                    saved["override"] = "off" if target < 6500 else "on"
                    saved["until"] = boundary or now.timestamp() + 3600
            else:
                saved["mode"] = "off" if config["mode"] == "manual" else "manual"
        elif command == "pause":
            minutes = int(argv[1])
            if config["mode"] == "off":
                raise ValueError("Night Light is off")
            if minutes not in (0, 30, 60):
                raise ValueError("Invalid pause duration")
            _, boundary, _ = effective(now, config, saved)
            saved["override"] = "off"
            saved["until"] = now.timestamp() + minutes * 60 if minutes else boundary or now.timestamp() + 3600
        elif command == "resume":
            saved.pop("override", None)
            saved.pop("until", None)
        elif command in ("set", "start", "end", "days", "transition"):
            key = {"set": "temperature", "start": "startMinute", "end": "endMinute", "days": "days", "transition": "transitionMinutes"}[
                command
            ]
            saved[key] = validated(key, int(argv[1]))
        elif command in ("warmer", "cooler"):
            saved["temperature"] = max(2500, min(6500, config["temperature"] + (-500 if command == "warmer" else 500)))
        elif command != "apply":
            raise ValueError("Unknown Night Light action")
        if saved.get("until", 0) <= now.timestamp():
            saved.pop("override", None)
            saved.pop("until", None)
        if command != "apply" or saved != read_overrides(now) or (STATE.exists() and not STATE.read_text().lstrip().startswith("{")):
            atomic_write(STATE, saved)
        config = {**DEFAULTS, **{key: value for key, value in saved.items() if key in DEFAULTS}}
        apply(now, config, saved)


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except (ValueError, IndexError, OSError, subprocess.CalledProcessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)

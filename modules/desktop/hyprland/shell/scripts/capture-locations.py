#!/usr/bin/env python3
"""Resolve capture locations consistently for the picker, recorder and library."""

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

HOME = Path.home()
STATE = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "desktop-shell/capture-locations.json"
DEFAULTS = {
    "screenshots": os.environ.get("DESKTOP_SHELL_SCREENSHOT_DIR")
    or str(Path(os.environ.get("XDG_PICTURES_DIR", HOME / "Pictures")) / "Screenshots"),
    "recordings": os.environ.get("DESKTOP_SHELL_RECORDING_DIR") or str(HOME / "Videos/Screencasts"),
}


def read():
    """Read stored destination overrides."""
    if not STATE.exists():
        return {}
    saved = json.loads(STATE.read_text())
    if not isinstance(saved, dict):
        raise ValueError("Invalid capture location settings")
    return saved


def validate(value, existing=False):
    """Validate a capture directory without creating it."""
    path = Path(value)
    if not path.is_absolute() or "\n" in value or "\r" in value or "\x00" in value:
        raise ValueError("Choose an absolute directory")
    if existing and (not path.is_dir() or not os.access(path, os.W_OK | os.X_OK)):
        raise ValueError("Choose an existing writable directory")
    return str(path)


def effective(saved):
    """Merge runtime overrides with native defaults."""
    return {key: validate(saved.get(key, default)) for key, default in DEFAULTS.items()}


def write(saved):
    """Persist destination overrides atomically."""
    STATE.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=STATE.parent, delete=False) as stream:
        temporary = Path(stream.name)
        try:
            json.dump(saved, stream)
            stream.flush()
            os.replace(temporary, STATE)
        finally:
            temporary.unlink(missing_ok=True)


def main():
    """Dispatch the destination command."""
    action = sys.argv[1]
    saved = read()
    if action == "get":
        print(effective(saved)[sys.argv[2]])
        return
    if action in ("choose", "reset", "set"):
        if subprocess.run(["systemctl", "--user", "is-active", "--quiet", "desktop-shell-recording.service"], check=False).returncode == 0:
            raise ValueError("Stop recording before changing destinations")
        if action == "reset":
            saved = {}
        else:
            key = sys.argv[2]
            if key not in DEFAULTS:
                raise ValueError("Unknown capture type")
            if action == "choose":
                result = subprocess.run(
                    ["kdialog", "--title", "Choose capture destination", "--getexistingdirectory", effective(saved)[key]],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                if result.returncode != 0:
                    print(json.dumps(effective(saved)))
                    return
                value = result.stdout.rstrip("\n")
            else:
                value = sys.argv[3]
            saved[key] = validate(value, existing=True)
        write(saved)
    elif action != "status":
        raise ValueError("Unknown capture location action")
    print(json.dumps(effective(saved)))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError, TypeError, IndexError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)

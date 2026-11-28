#!/usr/bin/env python3
"""Bounded, explicitly retained clipboard pins and cliphist operations."""

import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

LIMIT_BYTES = 8 * 1024 * 1024
LIMIT_ITEMS = 24
PIN_ID = re.compile(r"^pin:([a-f0-9]{64})$")
HISTORY_ID = re.compile(r"^[0-9]{1,20}$")
KINDS = {"TEXT", "IMAGE", "BINARY"}


def store():
    """Return the directory reserved for explicitly saved items."""
    base = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")
    return base / "desktop-shell" / "clipboard-pins"


def location():
    """Create the pin directory with restricted permissions."""
    folder = store()
    if folder.is_symlink():
        raise ValueError("Clipboard pin location cannot be a symlink")
    folder.mkdir(parents=True, mode=0o700, exist_ok=True)
    folder.chmod(0o700)
    return folder


def valid_pin(value):
    """Reject identities that could escape the private directory."""
    match = PIN_ID.fullmatch(value)
    if not match:
        raise ValueError("Invalid pin identity")
    return match.group(1)


def valid_history(value):
    """Accept only decimal cliphist row identifiers."""
    if not HISTORY_ID.fullmatch(value):
        raise ValueError("Invalid clipboard history identity")
    return value


def safe_preview(raw):
    """Generate a bounded single-line label from copied text."""
    return " ".join(raw.decode("utf-8", "replace").split())[:180] or "[empty text]"


def path_for(folder, key, ext):
    """Resolve the pinned file belonging to a validated digest."""
    return folder / (key + ext)


def read_pin(value):
    """Load and verify the payload and metadata."""
    key = valid_pin(value)
    folder = store()
    metadata = json.loads(path_for(folder, key, ".json").read_text())
    data = path_for(folder, key, ".bin").read_bytes()
    if not isinstance(metadata, dict) or metadata.get("kind") not in KINDS:
        raise ValueError("Invalid pinned item")
    if hashlib.sha256(data).hexdigest() != key or len(data) > LIMIT_BYTES:
        raise ValueError("Pinned item is corrupt")
    return metadata, data


def atomic_write(folder, name, data):
    """Publish a private file without exposing partial contents."""
    fd, tmp = tempfile.mkstemp(prefix=".writing-", dir=folder)
    try:
        with os.fdopen(fd, "wb") as out:
            out.write(data)
        os.replace(tmp, folder / name)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def pins():
    """Enumerate valid pinned records in newest-first order."""
    folder = store()
    if not folder.is_dir() or folder.is_symlink():
        return []
    found = []
    for item in folder.glob("*.json"):
        if not re.fullmatch(r"[a-f0-9]{64}\.json", item.name):
            continue
        try:
            metadata, _data = read_pin("pin:" + item.stem)
            found.append((item.stat().st_mtime_ns, item.stem, metadata))
        except (ValueError, OSError, json.JSONDecodeError):
            continue
    return sorted(found, reverse=True)[:LIMIT_ITEMS]


def list_items():
    """List retained items ahead of current cliphist history."""
    for _, key, metadata in pins():
        kind = metadata["kind"]
        preview = str(metadata.get("preview", "")).replace("\t", " ").replace("\n", " ")
        print(f"pin:{key}\t{kind}\t{preview}")
    history = subprocess.run(["cliphist", "list"], check=True, capture_output=True)
    sys.stdout.write(history.stdout.decode("utf-8", "replace"))


def pin_history(ident, kind):
    """Save a bounded copy of an explicitly selected history entry."""
    valid_history(ident)
    if kind not in KINDS:
        raise ValueError("Unsupported item type")
    data = subprocess.run(["cliphist", "decode", ident], check=True, capture_output=True).stdout
    if len(data) > LIMIT_BYTES:
        raise ValueError("Clipboard item exceeds the pin size limit")
    folder = location()
    key = hashlib.sha256(data).hexdigest()
    if not path_for(folder, key, ".json").exists() and len(pins()) >= LIMIT_ITEMS:
        raise ValueError("Clipboard pin limit reached")
    detected = kind
    if kind == "IMAGE" and not data.startswith((b"\x89PNG\r\n\x1a\n", b"\xff\xd8\xff", b"RIFF", b"GIF8")):
        raise ValueError("Unsupported image clipboard encoding")
    metadata = {"kind": detected, "preview": safe_preview(data) if kind == "TEXT" else "Pinned " + kind.lower()}
    atomic_write(folder, key + ".bin", data)
    atomic_write(folder, key + ".json", json.dumps(metadata).encode("utf-8"))


def remove_pin(ident):
    """Remove payload and metadata belonging to an explicit pin."""
    key = valid_pin(ident)
    folder = store()
    # Pins are only deleted by explicit user action. Ignore a missing record.
    for ext in (".json", ".bin"):
        path_for(folder, key, ext).unlink(missing_ok=True)


def copy_pin(ident):
    """Restore a pinned item with its supported content type."""
    metadata, data = read_pin(ident)
    kind = metadata["kind"]
    if kind == "BINARY":
        raise ValueError("Cannot restore an unsupported binary item")
    if kind == "TEXT":
        mime = "text/plain;charset=utf-8"
    elif data.startswith(b"\x89PNG\r\n\x1a\n"):
        mime = "image/png"
    elif data.startswith(b"\xff\xd8\xff"):
        mime = "image/jpeg"
    elif data.startswith(b"RIFF"):
        mime = "image/webp"
    elif data.startswith(b"GIF8"):
        mime = "image/gif"
    else:
        raise ValueError("Cannot identify the pinned image format")
    subprocess.run(["wl-copy", "--type", mime], input=data, check=True)


def main(args):
    """Dispatch the clipboard operations exposed to the shell."""
    if not args:
        raise ValueError("Operation required")
    action, *params = args
    if action == "list" and not params:
        list_items()
    elif action == "pin" and len(params) == 2:
        pin_history(params[0], params[1])
    elif action == "unpin" and len(params) == 1:
        remove_pin(params[0])
    elif action == "delete" and len(params) == 1:
        ident = params[0]
        if PIN_ID.fullmatch(ident):
            remove_pin(ident)
        else:
            subprocess.run(["cliphist", "delete"], input=(valid_history(ident) + "\n").encode("ascii"), check=True)
    elif action == "copy" and len(params) == 1:
        copy_pin(params[0])
    elif action == "read" and len(params) == 1:
        _, data = read_pin(params[0])
        sys.stdout.buffer.write(data)
    else:
        raise ValueError("Unknown clipboard operation")


if __name__ == "__main__":
    os.umask(0o077)
    try:
        main(sys.argv[1:])
    except (ValueError, OSError, subprocess.CalledProcessError, json.JSONDecodeError) as exc:
        print(f"clipboard operation failed: {exc}", file=sys.stderr)
        sys.exit(1)

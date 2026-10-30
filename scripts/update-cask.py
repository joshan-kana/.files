#!/usr/bin/env python3
"""Refresh package-owned macOS release pins from upstream cask metadata."""

import base64
import json
import re
import subprocess
import sys
from pathlib import Path
from urllib.request import urlopen

if len(sys.argv) not in (2, 3) or any(not re.fullmatch(r"[a-z][a-z0-9-]*", arg) for arg in sys.argv[1:]):
    sys.exit("Usage: update-cask TOKEN [OVERLAY_DIR]")
token = sys.argv[1]
update_dir = sys.argv[2] if len(sys.argv) == 3 else token
root = Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip())
target = root / "overlays" / update_dir / "default.nix"
if not target.is_file():
    sys.exit(f"Missing package: {token}")
with urlopen(f"https://formulae.brew.sh/api/cask/{token}.json", timeout=30) as response:
    release = json.load(response)
version, digest = release["version"], release["sha256"]
if not isinstance(version, str) or not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
    sys.exit(f"Missing version or verified archive hash for {token}")
hash_value = "sha256-" + base64.b64encode(bytes.fromhex(digest)).decode()
source = target.read_text()
pattern = r'(release = \{\s*version = ")[^"]+(";\s*hash = ")[^"]+(";\s*\};)'
updated, count = re.subn(pattern, lambda m: m[1] + version + m[2] + hash_value + m[3], source, count=1)
if count != 1:
    sys.exit(f"Missing pinned release metadata in {target}")
target.write_text(updated)
print(f"{token}: {version}")

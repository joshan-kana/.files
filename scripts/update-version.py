#!/usr/bin/env python3
"""Match a version in passthru.updateUrl using passthru.updateRegex, then run nix-update."""

import json
import re
import subprocess
import sys
from urllib.request import Request, urlopen

if len(sys.argv) != 3:
    sys.exit("Usage: update-version PACKAGE SYSTEM")
package, system = sys.argv[1:]
expression = (
    "let p = builtins.getAttr "
    + json.dumps(package)
    + " (builtins.getAttr "
    + json.dumps(system)
    + " (builtins.getFlake (toString ./. )).packages); in "
    + "{ url = p.passthru.updateUrl; regex = p.passthru.updateRegex; filename = p.passthru.updateFilename; }"
)
metadata = json.loads(subprocess.check_output(["nix", "eval", "--impure", "--json", "--expr", expression]))
with urlopen(Request(metadata["url"], headers={"User-Agent": "nix-update"}), timeout=30) as response:
    match = re.search(metadata["regex"], response.read().decode())
if match is None or match.lastindex != 1 or not re.fullmatch(r"[0-9][A-Za-z0-9.+_-]*", match[1]):
    sys.exit("No valid release version found")

subprocess.run(
    ["nix-update", "--flake", "--system", system, "--override-filename", metadata["filename"], "--version", match[1], package],
    check=True,
)

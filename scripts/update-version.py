#!/usr/bin/env python3
"""Discover a vendor version using the existing package update metadata."""

import json
import re
import subprocess
import sys
from urllib.request import Request, urlopen

if len(sys.argv) != 3:
    sys.exit("Usage: update-version FILENAME SYSTEM")

filename, system = sys.argv[1:]
expression = (
    "let f = builtins.getFlake (toString ./.); "
    + "packages = builtins.getAttr "
    + json.dumps(system)
    + " f.packages; names = builtins.getAttr "
    + json.dumps(system)
    + " f.lib.updateablePackages; in "
    + "map (name: { inherit name; inherit (packages.${name}.passthru) updateUrl updateRegex; }) "
    + "(builtins.filter (name: (packages.${name}.passthru.updateFilename or null) == "
    + json.dumps(filename)
    + ") names)"
)
matches = json.loads(subprocess.check_output(["nix", "eval", "--impure", "--json", "--expr", expression]))
if len(matches) != 1:
    sys.exit(f"Expected one package for {filename} on {system}; found {len(matches)}")

package = matches[0]
with urlopen(Request(package["updateUrl"], headers={"User-Agent": "nix-update"}), timeout=30) as response:
    match = re.search(package["updateRegex"], response.read().decode())
if match is None or match.lastindex != 1 or not re.fullmatch(r"[0-9][A-Za-z0-9.+_-]*", match[1]):
    sys.exit("No valid release version found")

subprocess.run(
    [
        "nix-update",
        "--flake",
        "--system",
        system,
        "--override-filename",
        filename,
        "--version",
        match[1],
        package["name"],
    ],
    check=True,
)

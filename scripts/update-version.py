#!/usr/bin/env python3
"""Resolve a release version and let nix-update update its source and hash."""

import re
import subprocess
import sys
from urllib.request import Request, urlopen

if len(sys.argv) != 6:
    sys.exit("Usage: update-version URL REGEX PACKAGE SYSTEM FILE")

url, pattern, package, system, filename = sys.argv[1:]
with urlopen(Request(url, headers={"User-Agent": "nix-update"}), timeout=30) as response:
    match = re.search(pattern, response.read().decode())
if match is None or not re.fullmatch(r"[0-9][A-Za-z0-9.+_-]*", match[1]):
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
        package,
    ],
    check=True,
)

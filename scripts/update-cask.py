#!/usr/bin/env python3
"""Manually refresh a pinned upstream release from optional Homebrew cask metadata."""

import argparse
import base64
import json
import re
import subprocess
import sys
from pathlib import Path
from urllib.request import urlopen

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("cask", help="Homebrew cask token")
parser.add_argument("file", help="Package overlay to update")
parser.add_argument("--arch-hashes", action="store_true", help="Refresh declared Linux and Apple Silicon hashes")
args = parser.parse_args()
if not re.fullmatch(r"[a-z][a-z0-9-]*", args.cask):
    parser.error("Cask token must be lowercase")
root = Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip())
target = (root / args.file).resolve()
if not target.is_relative_to(root / "overlays") or target.name != "default.nix":
    parser.error("Update file must be a package overlay")
if not target.is_file():
    sys.exit(f"Missing package: {args.cask}")
with urlopen(f"https://formulae.brew.sh/api/cask/{args.cask}.json", timeout=30) as response:
    release = json.load(response)
version, digest = release["version"], release["sha256"]
if not isinstance(version, str) or not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
    sys.exit(f"Missing version or verified archive hash for {args.cask}")


def sri(value):
    if not re.fullmatch(r"[0-9a-f]{64}", value):
        raise ValueError(f"Invalid SHA-256 digest for {args.cask}")
    return "sha256-" + base64.b64encode(bytes.fromhex(value)).decode()


source = target.read_text()
if args.arch_hashes:
    block_pattern = r"(hashes = \{)([^{}]*)(\};)"
    blocks = list(re.finditer(block_pattern, source, re.S))
    if len(blocks) != 1:
        sys.exit("Expected one platform hash map")
    block = blocks[0]
    body = block[2]
    hashes = {"aarch64-darwin": sri(digest)}
    for system, variation in (("x86_64-linux", "x86_64_linux"), ("aarch64-linux", "arm64_linux")):
        if re.search(r"\b" + re.escape(system) + r"\s*=", body):
            variant = release.get("variations", {}).get(variation, {})
            if variant.get("version", version) != version or not isinstance(variant.get("sha256"), str):
                sys.exit(f"No matching verified archive for {system}")
            hashes[system] = sri(variant["sha256"])
    for system, hash_value in hashes.items():
        body, count = re.subn(
            r"(\b" + re.escape(system) + r'\s*=\s*")[^"]+(";)',
            lambda m, hash_value=hash_value: m[1] + hash_value + m[2],
            body,
            count=1,
        )
        if count != 1:
            sys.exit(f"Missing hash for {system}")
    updated = source[: block.start(2)] + body + source[block.end(2) :]
    updated, count = re.subn(
        r'(\brelease\s*=\s*\{\s*version\s*=\s*")[^"]+(";)',
        lambda m: m[1] + version + m[2],
        updated,
        count=1,
    )
    if count == 0:
        updated, count = re.subn(
            r'(?m)^(\s*version\s*=\s*")[^"]+(";)',
            lambda m: m[1] + version + m[2],
            updated,
            count=1,
        )
else:
    release_version, _, release_build = version.partition(",")
    pattern = r'(release = \{\s*version = ")[^"]+(";)(\s*build = ")[^"]+(";)?(\s*hash = ")[^"]+(";\s*\};)'
    if release_build:
        updated, count = re.subn(
            pattern,
            lambda m: m[1] + release_version + m[2] + m[3] + release_build + m[4] + m[5] + sri(digest) + m[6],
            source,
            count=1,
        )
    else:
        pattern = r'(release = \{\s*version = ")[^"]+(";\s*hash = ")[^"]+(";\s*\};)'
        updated, count = re.subn(pattern, lambda m: m[1] + version + m[2] + sri(digest) + m[3], source, count=1)
if count != 1:
    sys.exit(f"Missing pinned release metadata in {target}")
if updated != source:
    target.write_text(updated)
print(f"{args.cask}: {version}")

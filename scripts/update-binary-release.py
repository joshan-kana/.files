#!/usr/bin/env python3
"""Refresh locked vendor assets using checksums published with a GitHub release."""

import base64
import json
import re
import subprocess
import sys
from pathlib import Path
from urllib.request import Request, urlopen


def fetch(url):
    with urlopen(Request(url, headers={"User-Agent": "nix-package-update"}), timeout=30) as response:
        return response.read()


def sri(digest):
    if not re.fullmatch(r"[a-f0-9]{64}", digest):
        raise ValueError(f"Invalid SHA-256: {digest!r}")
    return "sha256-" + base64.b64encode(bytes.fromhex(digest)).decode()


if len(sys.argv) != 2 or sys.argv[1] not in ("agentgateway", "openai-tunnel-client"):
    sys.exit("Usage: update-binary-release PACKAGE")
name = sys.argv[1]
root = Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip())
source_path = root / "overlays" / name / "default.nix"
source = source_path.read_text()
repositories = {
    "agentgateway": "agentgateway/agentgateway",
    "openai-tunnel-client": "openai/tunnel-client",
}
release = json.loads(fetch(f"https://api.github.com/repos/{repositories[name]}/releases/latest"))
tag = release["tag_name"]
if not re.fullmatch(r"v[0-9][0-9A-Za-z.+-]*", tag):
    sys.exit(f"Unexpected release tag: {tag}")
version = tag[1:]
download = f"https://github.com/{repositories[name]}/releases/download/{tag}/"
# Package-owned assets define the platforms; adding Darwin does not change the updater.
asset_block = re.search(r"asset =\s*\{([^}]+)\}", source)
if asset_block is None:
    sys.exit(f"Missing platform asset map in {source_path}")
platform_assets = dict(re.findall(r'([a-z0-9_-]+)\s*=\s*"([^"]+)"\s*;', asset_block[1]))
if not platform_assets:
    sys.exit(f"No platform assets in {source_path}")
digests = {}
if name == "agentgateway":
    for system, asset in platform_assets.items():
        checksum = fetch(download + "agentgateway-" + asset + ".sha256").decode().strip().splitlines()[0]
        digests[system] = sri(checksum.split()[0])
else:
    checksums = fetch(download + "SHA256SUMS.txt").decode()
    for system, asset in platform_assets.items():
        filename = f"tunnel-client-runtime-v{version}-{asset}.zip"
        matches = re.findall(r"^([a-f0-9]{64})\s+" + re.escape(filename) + r"$", checksums, re.M)
        if len(matches) != 1:
            sys.exit(f"No unique upstream checksum for {filename}")
        digests[system] = sri(matches[0])

updated, n = re.subn(r'(version = ")[^"]+(";)', lambda m: m[1] + version + m[2], source, count=1)
if n != 1:
    sys.exit(f"No version pin in {source_path}")
for system, digest in digests.items():
    updated, n = re.subn(
        r"(" + system + r' = ")[^"]+(";)',
        lambda m: m[1] + digest + m[2],
        updated,
        count=1,
    )
    if n != 1:
        sys.exit(f"No {system} hash in {source_path}")
source_path.write_text(updated)
print(f"{name}: {version} ({len(digests)} verified SHA-256 pins)")

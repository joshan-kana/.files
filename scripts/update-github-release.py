#!/usr/bin/env python3
"""Update a GitHub release's version and verified platform hashes in an overlay."""

import argparse
import base64
import json
import re
import subprocess
from pathlib import Path
from urllib.request import Request, urlopen


def fetch(url):
    with urlopen(Request(url, headers={"User-Agent": "nix-package-update"}), timeout=30) as response:
        return response.read()


def sri(digest):
    if not re.fullmatch(r"[a-f0-9]{64}", digest):
        raise ValueError(f"Invalid SHA-256: {digest!r}")
    return "sha256-" + base64.b64encode(bytes.fromhex(digest)).decode()


def block(source, name):
    matches = list(re.finditer(r"\b" + re.escape(name) + r"\s*=\s*\{([^{}]*)\};", source, re.S))
    if len(matches) != 1:
        raise ValueError(f"Expected one {name} attribute set")
    return matches[0]


def platform_values(source, name):
    content = block(source, name)[1]
    values = dict(re.findall(r'^\s*([a-z0-9_-]+)\s*=\s*"([^"]+)"\s*;', content, re.M))
    if not values:
        raise ValueError(f"Missing {name} platform values")
    return values


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", help="Overlay directory containing default.nix")
    parser.add_argument("--repository", required=True, help="GitHub owner/repository")
    parser.add_argument("--asset-pattern", required=True, help="Release asset name with {asset} and optional {version}")
    checksums = parser.add_mutually_exclusive_group(required=True)
    checksums.add_argument("--checksums", help="Release-wide checksum filename")
    checksums.add_argument("--checksum-suffix", help="Suffix for a per-asset checksum file")
    args = parser.parse_args(argv)

    if not re.fullmatch(r"[a-z][a-z0-9-]*", args.package):
        parser.error("package must be a lowercase overlay directory")
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", args.repository):
        parser.error("repository must be a GitHub owner/repository")
    if "{asset}" not in args.asset_pattern:
        parser.error("asset pattern must contain {asset}")

    root = Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip())
    path = root / "overlays" / args.package / "default.nix"
    source = path.read_text()
    assets = platform_values(source, "asset")
    hashes = platform_values(source, "hashes")
    if assets.keys() != hashes.keys():
        raise ValueError("Platform asset and hash keys must match")

    release = json.loads(fetch(f"https://api.github.com/repos/{args.repository}/releases/latest"))
    tag = release["tag_name"]
    if not re.fullmatch(r"v[0-9][0-9A-Za-z.+-]*", tag):
        raise ValueError(f"Unexpected release tag: {tag}")
    version = tag[1:]
    download = f"https://github.com/{args.repository}/releases/download/{tag}/"

    checksum_lines = fetch(download + args.checksums).decode().splitlines() if args.checksums else []
    digests = {}
    for system, asset in assets.items():
        filename = args.asset_pattern.format(asset=asset, version=version)
        if args.checksum_suffix:
            checksum = fetch(download + filename + args.checksum_suffix).decode().strip().splitlines()[0]
            digest = checksum.split()[0]
        else:
            matches = re.findall(r"^([a-f0-9]{64})\s+\*?" + re.escape(filename) + r"$", "\n".join(checksum_lines), re.M)
            if len(matches) != 1:
                raise ValueError(f"No unique checksum for {filename}")
            digest = matches[0]
        digests[system] = sri(digest)

    updated, count = re.subn(r'(\bversion\s*=\s*")[^"]+(";)', lambda m: m[1] + version + m[2], source, count=1)
    if count != 1:
        raise ValueError("Expected one version pin")
    hash_block = block(updated, "hashes")
    body = hash_block[1]
    for system, digest in digests.items():
        body, count = re.subn(
            r"(^\s*" + re.escape(system) + r'\s*=\s*")[^"]+(";)',
            lambda m: m[1] + digest + m[2],
            body,
            count=1,
            flags=re.M,
        )
        if count != 1:
            raise ValueError(f"No unique {system} hash")
    updated = updated[: hash_block.start(1)] + body + updated[hash_block.end(1) :]
    path.write_text(updated)
    print(f"{args.package}: {version} ({len(digests)} verified platform hashes)")


if __name__ == "__main__":
    main()

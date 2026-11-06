#!/usr/bin/env python3
"""Refresh a pinned release from verified Homebrew cask metadata."""

import argparse
import base64
import json
import re
import subprocess
import sys
from pathlib import Path
from urllib.request import urlopen

SHA256 = re.compile(r"[0-9a-f]{64}\Z")
SRI = re.compile(r"sha256-[A-Za-z0-9+/]{43}=\Z")
SYSTEM = re.compile(r"[A-Za-z0-9_+.-]+-[A-Za-z0-9_+.-]+\Z")
RELEASE = re.compile(r"release\s*=\s*\{\s*version\s*=\s*\"([^\"]+)\"\s*;", re.S)
HASHES = re.compile(
    r"(release\s*=\s*\{\s*version\s*=\s*\"[^\"]+\"\s*;\s*hashes\s*=\s*\{)"
    r"(?P<body>[^{}]*)"
    r"(\}\s*;\s*\}\s*;)",
    re.S,
)


def sha256_sri(digest):
    if not isinstance(digest, str) or not SHA256.fullmatch(digest):
        raise ValueError("Missing or invalid SHA-256 checksum in cask metadata")
    return "sha256-" + base64.b64encode(bytes.fromhex(digest)).decode()


def replace_one(source, pattern, replacement, description):
    updated, count = re.subn(pattern, replacement, source, count=1, flags=re.S)
    if count != 1:
        raise ValueError(f"Expected one {description} in pinned release")
    return updated


def package_url(system, name):
    expression = (
        "let flake = builtins.getFlake (toString ./.); "
        f"in (builtins.getAttr {json.dumps(name)} "
        f"(builtins.getAttr {json.dumps(system)} flake.packages)).src.url"
    )
    return subprocess.check_output(
        ["nix", "eval", "--raw", "--impure", "--expr", expression], text=True
    ).strip()


def updated_url(system, name, old_version, version, old_build=None, build=None):
    url = package_url(system, name)
    if old_version != version and old_version not in url:
        raise ValueError(f"{system}/{name} source URL does not contain the pinned version")
    url = url.replace(old_version, version)
    if old_build is not None and old_build != build:
        if old_build not in url:
            raise ValueError(f"{system}/{name} source URL does not contain the pinned build")
        url = url.replace(old_build, build)
    return url


def prefetch(url):
    result = json.loads(subprocess.check_output(
        ["nix", "store", "prefetch-file", "--json", "--hash-type", "sha256", url],
        text=True,
    ))
    digest = result.get("hash")
    if not isinstance(digest, str) or not SRI.fullmatch(digest):
        raise ValueError(f"No SHA-256 returned for {url}")
    return digest


def update_single(source, version, build, digest):
    match = RELEASE.search(source)
    if not match:
        raise ValueError("Expected a release.version declaration")
    old_version = match.group(1)
    if build is not None:
        source = replace_one(
            source,
            r'(release\s*=\s*\{\s*version\s*=\s*")[^"]+("\s*;\s*build\s*=\s*")[^"]+("\s*;\s*hash\s*=\s*")[^"]+(")',
            lambda m: m[1] + version + m[2] + build + m[3] + digest + m[4],
            "release with build and hash",
        )
    else:
        source = replace_one(
            source,
            r'(release\s*=\s*\{\s*version\s*=\s*")[^"]+("\s*;\s*hash\s*=\s*")[^"]+(")',
            lambda m: m[1] + version + m[2] + digest + m[3],
            "release with hash",
        )
    return source, old_version


def update_platform_hashes(source, package, release_version, release_url, mac_digest):
    match = HASHES.search(source)
    if not match:
        raise ValueError("Expected a release.hashes map keyed by Nix system")
    old_version_match = RELEASE.search(source)
    if not old_version_match:
        raise ValueError("Expected a release.version declaration")
    old_version = old_version_match.group(1)
    entries = re.findall(r'"([^"]+)"\s*=\s*"([^"]+)"\s*;', match["body"])
    if not entries or len(entries) != len(set(key for key, _ in entries)):
        raise ValueError("Empty or duplicate platform hashes")
    urls = {}
    for system, old_hash in entries:
        if not SYSTEM.fullmatch(system) or not SRI.fullmatch(old_hash):
            raise ValueError(f"Invalid platform hash: {system}")
        urls[system] = updated_url(system, package, old_version, release_version)
    if release_url not in urls.values():
        raise ValueError(f"{package} has no archive matching the cask metadata")
    hashes = {
        system: (
            mac_digest
            if urls[system] == release_url
            else old_hash if release_version == old_version else prefetch(urls[system])
        )
        for system, old_hash in entries
    }
    body = match["body"]
    for system, _ in entries:
        body = replace_one(
            body,
            r'("' + re.escape(system) + r'"\s*=\s*")[^"]+(")',
            lambda m, s=system: m[1] + hashes[s] + m[2],
            f"{system} checksum",
        )
    updated = source[:match.start("body")] + body + source[match.end("body"):]
    updated = replace_one(
        updated,
        r'(release\s*=\s*\{\s*version\s*=\s*")[^"]+(")',
        lambda m: m[1] + release_version + m[2],
        "shared release version",
    )
    return updated


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cask", help="Homebrew cask token")
    parser.add_argument("file", help="Package overlay to update")
    parser.add_argument("--package", help="Flake package name for verifying source URLs")
    parser.add_argument("--arch-hashes", action="store_true", help="Update all declared OS/architecture checksums")
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z][a-z0-9-]*", args.cask):
        parser.error("Invalid cask token")
    if args.arch_hashes and not args.package:
        parser.error("--arch-hashes requires --package")

    root = Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip())
    target = (root / args.file).resolve()
    if not target.is_relative_to(root / "overlays") or target.name != "default.nix" or not target.is_file():
        parser.error("Expected an existing package overlay under overlays/")

    with urlopen(f"https://formulae.brew.sh/api/cask/{args.cask}.json", timeout=30) as response:
        metadata = json.load(response)
    upstream_version = metadata.get("version")
    upstream_url = metadata.get("url")
    if not isinstance(upstream_version, str) or not isinstance(upstream_url, str):
        raise ValueError("Cask must provide a version and artifact URL")
    version, comma, build = upstream_version.partition(",")
    digest = sha256_sri(metadata.get("sha256"))
    original = target.read_text()

    if args.arch_hashes:
        if comma:
            raise ValueError("Platform hash updater does not support separate release build numbers")
        updated = update_platform_hashes(original, args.package, version, upstream_url, digest)
    else:
        match = RELEASE.search(original)
        if not match:
            raise ValueError("Expected a release.version declaration")
        updated, _ = update_single(original, version, build if comma else None, digest)

    if original != updated:
        target.write_text(updated)
    print(f"{args.cask}: {upstream_version}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, subprocess.CalledProcessError, OSError) as error:
        sys.exit(str(error))

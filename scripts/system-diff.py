#!/usr/bin/env python3
"""Report differences in evaluated NixOS, nix-darwin and Home Manager packages."""

import argparse
import json
import os
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

EXPRESSION = """
let
  flake = builtins.getFlake (builtins.getEnv "SYSTEM_DIFF_FLAKE");
  describe = package:
    let
      parsed = builtins.parseDrvName package.name;
      pname = package.pname or null;
      version = package.version or null;
    in {
      name = if pname == null || pname == "" then parsed.name else pname;
      version = if version == null || version == "" then parsed.version else version;
      derivation = package.drvPath;
    };
  describeHost = host:
    let
      config = host.config;
      homeUsers = builtins.attrValues (config.home-manager.users or {});
      homePackages = builtins.concatLists (map (user: user.home.packages or []) homeUsers);
    in {
      system = host.pkgs.stdenv.hostPlatform.system;
      packages = map describe ((config.environment.systemPackages or []) ++ homePackages);
    };
in {
  nixos = builtins.mapAttrs (_: describeHost) flake.nixosConfigurations;
  darwin = builtins.mapAttrs (_: describeHost) flake.darwinConfigurations;
}
"""


def command(*args):
    return subprocess.check_output(args, text=True).strip()


def revision(repo, ref):
    return command("git", "-C", str(repo), "rev-parse", "--verify", f"{ref}^{{commit}}")


def evaluate(reference):
    return json.loads(
        subprocess.check_output(
            ["nix", "eval", "--impure", "--json", "--expr", EXPRESSION],
            text=True,
            env={**os.environ, "SYSTEM_DIFF_FLAKE": reference},
        )
    )


def inventory(host):
    packages = defaultdict(lambda: defaultdict(set))
    for package in host.get("packages", []):
        name = package.get("name")
        if not name:
            continue
        version = package.get("version") or "unknown"
        packages[name][version].add(package["derivation"])
    return packages


def compare(before, after, base, head):
    result = {"base": base, "head": head, "hosts": []}
    for kind in ("nixos", "darwin"):
        previous = before[kind]
        current = after[kind]
        for name in sorted(previous.keys() | current.keys()):
            old_host = previous.get(name, {})
            new_host = current.get(name, {})
            old = inventory(old_host)
            new = inventory(new_host)
            changes = []
            counts = dict.fromkeys(("added", "removed", "updated", "modified"), 0)
            for package in sorted(old.keys() | new.keys()):
                old_versions = sorted(old.get(package, {}))
                new_versions = sorted(new.get(package, {}))
                if package not in old:
                    status = "added"
                elif package not in new:
                    status = "removed"
                elif old_versions != new_versions:
                    status = "updated"
                elif old[package] != new[package]:
                    status = "modified"
                else:
                    continue
                counts[status] += 1
                changes.append(
                    {
                        "status": status,
                        "name": package,
                        "before": old_versions,
                        "after": new_versions,
                    }
                )
            result["hosts"].append(
                {
                    "name": name,
                    "kind": kind,
                    "system": new_host.get("system", old_host.get("system")),
                    "status": "added" if not old_host else "removed" if not new_host else "present",
                    "summary": counts,
                    "changes": changes,
                }
            )
    return result


def markdown(report):
    lines = [
        "## Package changes",
        "",
        "| Configuration | Added | Removed | Updated | Modified |",
        "| --- | ---: | ---: | ---: | ---: |",
    ]
    changes = defaultdict(list)
    for host in report["hosts"]:
        counts = host["summary"]
        lines.append(f"| `{host['name']}` | {counts['added']} | {counts['removed']} | {counts['updated']} | {counts['modified']} |")
        for item in host["changes"]:
            key = (item["status"], item["name"], tuple(item["before"]), tuple(item["after"]))
            changes[key].append(host["name"])

    if not changes:
        return "\n".join(lines + ["", "No package changes."])

    lines.extend(
        [
            "",
            "| Change | Package | Version | Configurations |",
            "| --- | --- | --- | --- |",
        ]
    )
    order = {"updated": 0, "added": 1, "removed": 2, "modified": 3}
    for (status, name, before, after), hosts in sorted(
        changes.items(), key=lambda item: (order[item[0][0]], item[0][1], item[0][2], item[0][3])
    ):
        old = ", ".join(before)
        new = ", ".join(after)
        version = f"`{old}` → `{new}`" if status == "updated" else f"`{new if status == 'added' else old}`"
        configurations = ", ".join(f"`{host}`" for host in hosts)
        lines.append(f"| {status.capitalize()} | `{name}` | {version} | {configurations} |")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", help="Git revision to compare against (default: origin/HEAD)")
    parser.add_argument("--head", help="Git revision to compare (default: current working tree)")
    parser.add_argument("--json", action="store_true", help="Print all changes as JSON")
    args = parser.parse_args()

    repo = Path(command("git", "rev-parse", "--show-toplevel")).resolve()
    try:
        base = revision(repo, args.base or "origin/HEAD")
    except subprocess.CalledProcessError:
        parser.error(f"unknown base revision: {args.base or 'origin/HEAD'}")
    head = revision(repo, args.head) if args.head else "working tree"
    prefix = "git+" + repo.as_uri()
    before = evaluate(f"{prefix}?rev={base}")
    after = evaluate(f"{prefix}?rev={head}" if args.head else prefix)
    report = compare(before, after, base[:12], head[:12] if args.head else head)
    print(json.dumps(report, indent=2, sort_keys=True) if args.json else markdown(report))


if __name__ == "__main__":
    try:
        main()
    except (subprocess.CalledProcessError, json.JSONDecodeError) as error:
        print(f"system-diff: {error}", file=sys.stderr)
        sys.exit(1)

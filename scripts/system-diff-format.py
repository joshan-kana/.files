#!/usr/bin/env python3
"""Render package changes as Markdown."""

import json
import sys
from collections import defaultdict


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


if __name__ == "__main__":
    print(markdown(json.load(sys.stdin)))

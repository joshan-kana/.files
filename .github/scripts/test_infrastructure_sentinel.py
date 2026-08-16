#!/usr/bin/env python3
"""Unit tests for the first-party GitHub relationship handling."""

from __future__ import annotations

import importlib.util
import os
import pathlib
import unittest
from unittest import mock


SCRIPT = pathlib.Path(__file__).with_name("infrastructure-sentinel.py")
SPEC = importlib.util.spec_from_file_location("infrastructure_sentinel", SCRIPT)
assert SPEC and SPEC.loader
bridge = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(bridge)


class FakeClient:
    def __init__(self) -> None:
        self.parents: dict[int, int] = {}
        self.calls: list[tuple[str, str, object]] = []

    def request(self, method: str, path: str, payload=None, **kwargs):
        self.calls.append((method, path, payload))
        if path.endswith("/parent"):
            child = int(path.split("/")[-2])
            parent = self.parents.get(child)
            return {"number": parent, "state": "open"} if parent else None
        if "/sub_issues?" in path:
            parent = int(path.split("/")[-2])
            children = [child for child, candidate in self.parents.items() if candidate == parent]
            return [{"number": child, "state": "open"} for child in children]
        if method == "POST" and path.endswith("/sub_issues"):
            parent = int(path.split("/")[-2])
            self.parents[payload["sub_issue_id"]] = parent
            return {"number": payload["sub_issue_id"]}
        if method == "DELETE" and path.endswith("/sub_issue"):
            self.parents.pop(payload["sub_issue_id"], None)
            return {"number": payload["sub_issue_id"]}
        raise AssertionError(f"unexpected request: {method} {path}")


class PullRequestProjectTests(unittest.TestCase):
    def test_pull_request_can_target_project_membership_and_fields(self) -> None:
        project = {
            "fields": {
                "Status": {
                    "type": "SINGLE_SELECT",
                    "options": [{"id": "review", "name": "Review", "description": ""}],
                }
            }
        }
        command = {
            "version": 1,
            "request_id": "pr-project",
            "operations": [{"issue": 80, "ensure_project": True, "fields": {"Status": "Review"}}],
        }
        with (
            __import__('unittest').mock.patch.object(bridge, "project_data", return_value=(project, {})),
            __import__('unittest').mock.patch.object(bridge, "issue_list", return_value=[]),
            __import__('unittest').mock.patch.object(
                bridge,
                "issue_metadata",
                return_value={"id": 80, "node_id": "pr-node", "pull_request": {"url": "example"}},
            ),
            __import__('unittest').mock.patch.dict(os.environ, {"INFRASTRUCTURE_SENTINEL_PROJECT_TOKEN": "test-token"}),
        ):
            normalized = bridge.normalize_command(command, FakeClient())
        self.assertEqual(normalized[0]["content_type"], "PullRequest")
        self.assertTrue(normalized[0]["ensure_project"])
        self.assertEqual(normalized[0]["fields"], {"Status": "Review"})

    def test_pull_request_relationship_operations_are_rejected(self) -> None:
        command = {
            "version": 1,
            "request_id": "pr-relationship",
            "operations": [{"issue": 80, "blocked_by": []}],
        }
        with (
            __import__('unittest').mock.patch.object(bridge, "project_data", return_value=({"fields": {}}, {})),
            __import__('unittest').mock.patch.object(
                bridge,
                "issue_metadata",
                return_value={"id": 80, "node_id": "pr-node", "pull_request": {"url": "example"}},
            ),
            __import__('unittest').mock.patch.dict(os.environ, {"INFRASTRUCTURE_SENTINEL_PROJECT_TOKEN": "test-token"}),
        ):
            with self.assertRaisesRegex(bridge.BridgeError, "only supports project membership/field operations"):
                bridge.normalize_command(command, FakeClient())

    def test_snapshot_exposes_pull_request_project_fields(self) -> None:
        project = {"title": "infrastructure", "fields": {}}
        project_items = {
            80: {"id": "project-item-80", "fields": {"Status": "Review"}, "content_type": "PullRequest"}
        }
        open_items = [{
            "number": 80,
            "title": "docs: update infrastructure docs submodule",
            "state": "open",
            "pull_request": {"url": "example"},
        }]
        with (
            __import__('unittest').mock.patch.object(bridge, "project_data", return_value=(project, project_items)),
            __import__('unittest').mock.patch.object(bridge, "issue_list", return_value=open_items),
        ):
            state = bridge.build_snapshot(FakeClient(), FakeClient(), {})
        self.assertEqual(state["pull_requests"]["80"]["project_item_id"], "project-item-80")
        self.assertEqual(state["pull_requests"]["80"]["fields"]["Status"], "Review")


class RelationshipTests(unittest.TestCase):
    def test_parent_and_sub_issue_reads_use_first_party_endpoints(self) -> None:
        client = FakeClient()
        client.parents[12] = 7

        self.assertEqual(bridge.parent_issue(client, 12, {}), {"number": 7, "state": "open"})
        self.assertEqual(bridge.sub_issues(client, 7, {}), [{"number": 12, "state": "open"}])
        self.assertEqual([call[1] for call in client.calls], [
            "/repos/joshan-kana/.files/issues/12/parent",
            "/repos/joshan-kana/.files/issues/7/sub_issues?per_page=100&page=1",
        ])

    def test_parent_apply_is_idempotent_and_read_back_verified(self) -> None:
        client = FakeClient()
        operation = {
            "issue": 12,
            "ensure_project": False,
            "fields": None,
            "blocked_by": None,
            "parent_requested": True,
            "parent": 7,
            "relates_to_requested": False,
            "relates_to": None,
        }
        with (
            mock.patch.object(bridge, "normalize_command", return_value=[operation]),
            mock.patch.object(bridge, "refresh_project", return_value=(
                {"id": "project", "fields": {}}, {}
            )),
            mock.patch.object(bridge, "issue_metadata", return_value={"id": 12, "pull_request": None}),
            mock.patch.dict(os.environ, {"INFRASTRUCTURE_SENTINEL_PROJECT_TOKEN": "test-token"}),
        ):
            applied, unchanged = bridge.apply_command({"version": 1}, client)

        self.assertEqual(applied, ["issue #12: parent set to 7"])
        self.assertEqual(unchanged, [])
        self.assertEqual(client.parents, {12: 7})
        self.assertEqual(sum(path.endswith("/sub_issues") for _, path, _ in client.calls), 1)

    def test_parent_cycle_is_rejected_before_mutation(self) -> None:
        issues = [{"number": 1}, {"number": 2}]

        def metadata(_client, number, _cache):
            return {"id": number, "node_id": f"node-{number}", "pull_request": None}

        def live_parent(_client, number, _cache):
            return {"number": 2} if number == 1 else None

        command = {"version": 1, "request_id": "cycle", "operations": [{"issue": 2, "parent": 1}]}
        with (
            mock.patch.object(bridge, "project_data", return_value=({"fields": {}}, {})),
            mock.patch.object(bridge, "issue_list", return_value=issues),
            mock.patch.object(bridge, "dependencies", return_value=[]),
            mock.patch.object(bridge, "issue_metadata", side_effect=metadata),
            mock.patch.object(bridge, "parent_issue", side_effect=live_parent),
            mock.patch.dict(os.environ, {"INFRASTRUCTURE_SENTINEL_PROJECT_TOKEN": "test-token"}),
        ):
            with self.assertRaisesRegex(bridge.BridgeError, "parent cycle"):
                bridge.normalize_command(command, FakeClient())

    def test_relates_to_fails_closed_without_becoming_blocked_by(self) -> None:
        command = {"version": 1, "request_id": "related", "operations": [{"issue": 12, "relates_to": [7]}]}

        def metadata(_client, number, _cache):
            return {"id": number, "node_id": f"node-{number}", "pull_request": None}

        with (
            mock.patch.object(bridge, "project_data", return_value=({"fields": {}}, {})),
            mock.patch.object(bridge, "issue_list", return_value=[]),
            mock.patch.object(bridge, "dependencies", return_value=[]),
            mock.patch.object(bridge, "issue_metadata", side_effect=metadata),
            mock.patch.dict(os.environ, {"INFRASTRUCTURE_SENTINEL_PROJECT_TOKEN": "test-token"}),
        ):
            with self.assertRaisesRegex(bridge.BridgeError, "UNSUPPORTED_CAPABILITY"):
                bridge.normalize_command(command, FakeClient())

    def test_state_marker_is_upgraded_without_losing_command(self) -> None:
        old = "before\n\n<!-- infrastructure-sentinel-state:v1\n{}\n-->\n\n<!-- infrastructure-sentinel-command:v1\n{\"request_id\": \"x\"}\n-->"
        updated = bridge.replace_state(old, {"version": 2})
        self.assertIn("infrastructure-sentinel-state:v2", updated)
        self.assertIn("infrastructure-sentinel-command:v1", updated)


if __name__ == "__main__":
    unittest.main()

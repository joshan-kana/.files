#!/usr/bin/env python3
"""Small, policy-free GitHub Project v2 bridge for Infrastructure Sentinel."""

from __future__ import annotations

import datetime as dt
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Any


OWNER = "joshan-kana"
REPOSITORY = ".files"
PROJECT_NUMBER = 1
BRIDGE_ISSUE_NUMBER = 71
COMMAND_VERSION = 1
STATE_VERSION = 2
REST_API_VERSION = "2026-03-10"
GRAPHQL_ENDPOINT = "https://api.github.com/graphql"
REST_ENDPOINT = "https://api.github.com"
SUPPORTED_VALUE_TYPES = {"TEXT", "NUMBER", "DATE", "SINGLE_SELECT", "ITERATION", "MULTI_SELECT"}

STATE_RE = re.compile(r"<!--\s*infrastructure-sentinel-state:v[12]\s*\n(.*?)\n\s*-->", re.DOTALL)
COMMAND_RE = re.compile(r"<!--\s*infrastructure-sentinel-command:v1\s*\n(.*?)\n\s*-->", re.DOTALL)


class BridgeError(Exception):
    def __init__(self, message: str, *, applied: list[str] | None = None):
        super().__init__(message)
        self.applied = applied or []


def now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def fail(message: str) -> None:
    raise BridgeError(message)


class GitHub:
    def __init__(self, token: str, *, project: bool = False):
        if not token:
            fail("required GitHub credential is missing")
        self.token = token
        self.project = project

    def request(
        self,
        method: str,
        path: str,
        payload: Any = None,
        *,
        dependency: bool = False,
        allow_statuses: set[int] | None = None,
    ) -> Any:
        headers = {
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {self.token}",
            "User-Agent": "infrastructure-sentinel-bridge",
            "X-GitHub-Api-Version": REST_API_VERSION if dependency else "2022-11-28",
        }
        body = None
        if payload is not None:
            headers["Content-Type"] = "application/json"
            body = json.dumps(payload, separators=(",", ":")).encode()
        request = urllib.request.Request(REST_ENDPOINT + path, data=body, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                raw = response.read()
        except urllib.error.HTTPError as error:
            raw = error.read()
            if allow_statuses and error.code in allow_statuses:
                return None
            try:
                details = json.loads(raw.decode() or "{}")
            except json.JSONDecodeError:
                details = raw.decode(errors="replace")
            raise BridgeError(f"GitHub REST {method} {path} failed ({error.code}): {details}") from error
        if not raw:
            return None
        try:
            return json.loads(raw.decode())
        except json.JSONDecodeError as error:
            raise BridgeError(f"GitHub REST {method} {path} returned invalid JSON") from error

    def graphql(self, query: str, variables: dict[str, Any]) -> dict[str, Any]:
        headers = {
            "Accept": "application/json",
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
            "User-Agent": "infrastructure-sentinel-bridge",
        }
        request = urllib.request.Request(
            GRAPHQL_ENDPOINT,
            data=json.dumps({"query": query, "variables": variables}, separators=(",", ":")).encode(),
            headers=headers,
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                result = json.loads(response.read().decode())
        except urllib.error.HTTPError as error:
            details = error.read().decode(errors="replace")
            raise BridgeError(f"GitHub GraphQL request failed ({error.code}): {details}") from error
        errors = result.get("errors")
        if errors:
            message = "; ".join(str(item.get("message", item)) for item in errors)
            raise BridgeError(f"GitHub GraphQL request failed: {message}")
        return result.get("data", {})


def page_info(connection: dict[str, Any]) -> tuple[bool, str | None]:
    info = connection.get("pageInfo", {})
    return bool(info.get("hasNextPage")), info.get("endCursor")


PROJECT_QUERY = """
query($owner:String!,$number:Int!,$cursor:String){
  user(login:$owner){ projectV2(number:$number){
    id number title
    fields(first:100,after:$cursor){
      nodes{
        __typename
        ... on ProjectV2Field { id name dataType }
        ... on ProjectV2SingleSelectField { id name dataType options { id name description } }
        ... on ProjectV2IterationField {
          id name dataType
          configuration {
            iterations { id title startDate duration }
            completedIterations { id title startDate duration }
          }
        }
        ... on ProjectV2MultiSelectField {
          id name dataType multiSelectOptions { id name description }
        }
      }
      pageInfo { hasNextPage endCursor }
    }
  }}
}
"""

ITEMS_QUERY = """
query($owner:String!,$number:Int!,$cursor:String){
  user(login:$owner){ projectV2(number:$number){
    items(first:100,after:$cursor){
      nodes{
        id
        content {
          __typename
          ... on Issue { number title state repository { nameWithOwner } id }
          ... on PullRequest { number title state repository { nameWithOwner } id }
        }
        fieldValues(first:100){
          nodes{
            __typename
            ... on ProjectV2ItemFieldTextValue {
              field { ... on ProjectV2Field { name } ... on ProjectV2SingleSelectField { name } ... on ProjectV2IterationField { name } ... on ProjectV2MultiSelectField { name } }
              text
            }
            ... on ProjectV2ItemFieldNumberValue {
              field { ... on ProjectV2Field { name } ... on ProjectV2SingleSelectField { name } ... on ProjectV2IterationField { name } ... on ProjectV2MultiSelectField { name } }
              number
            }
            ... on ProjectV2ItemFieldDateValue {
              field { ... on ProjectV2Field { name } ... on ProjectV2SingleSelectField { name } ... on ProjectV2IterationField { name } ... on ProjectV2MultiSelectField { name } }
              date
            }
            ... on ProjectV2ItemFieldSingleSelectValue {
              field { ... on ProjectV2Field { name } ... on ProjectV2SingleSelectField { name } ... on ProjectV2IterationField { name } ... on ProjectV2MultiSelectField { name } }
              name optionId
            }
            ... on ProjectV2ItemFieldIterationValue {
              field { ... on ProjectV2Field { name } ... on ProjectV2SingleSelectField { name } ... on ProjectV2IterationField { name } ... on ProjectV2MultiSelectField { name } }
              title iterationId
            }
            ... on ProjectV2ItemFieldMultiSelectValue {
              field { ... on ProjectV2Field { name } ... on ProjectV2SingleSelectField { name } ... on ProjectV2IterationField { name } ... on ProjectV2MultiSelectField { name } }
              options { id name }
            }
          }
        }
      }
      pageInfo { hasNextPage endCursor }
    }
  }}
}
"""

ADD_ITEM_MUTATION = """
mutation($projectId:ID!,$contentId:ID!){
  addProjectV2ItemById(input:{projectId:$projectId,contentId:$contentId}) { item { id } }
}
"""

UPDATE_FIELD_MUTATION = """
mutation($projectId:ID!,$itemId:ID!,$fieldId:ID!,$value:ProjectV2FieldValue!){
  updateProjectV2ItemFieldValue(input:{projectId:$projectId,itemId:$itemId,fieldId:$fieldId,value:$value}) {
    projectV2Item { id }
  }
}
"""

CLEAR_FIELD_MUTATION = """
mutation($projectId:ID!,$itemId:ID!,$fieldId:ID!){
  clearProjectV2ItemFieldValue(input:{projectId:$projectId,itemId:$itemId,fieldId:$fieldId}) {
    projectV2Item { id }
  }
}
"""

DELETE_ITEM_MUTATION = """
mutation($projectId:ID!,$itemId:ID!){
  deleteProjectV2Item(input:{projectId:$projectId,itemId:$itemId}) { deletedItemId }
}
"""


def project_data(client: GitHub) -> tuple[dict[str, Any], dict[int, dict[str, Any]]]:
    project: dict[str, Any] | None = None
    fields: list[dict[str, Any]] = []
    cursor = None
    while True:
        data = client.graphql(PROJECT_QUERY, {"owner": OWNER, "number": PROJECT_NUMBER, "cursor": cursor})
        current = data.get("user", {}).get("projectV2")
        if not current:
            fail(f"user-owned Project v2 number {PROJECT_NUMBER} does not exist")
        if project is None:
            project = {key: current[key] for key in ("id", "number", "title")}
        fields.extend(current["fields"]["nodes"])
        has_next, cursor = page_info(current["fields"])
        if not has_next:
            break

    items: dict[int, dict[str, Any]] = {}
    cursor = None
    while True:
        data = client.graphql(ITEMS_QUERY, {"owner": OWNER, "number": PROJECT_NUMBER, "cursor": cursor})
        current = data["user"]["projectV2"]
        for item in current["items"]["nodes"]:
            content = item.get("content") or {}
            if content.get("__typename") not in {"Issue", "PullRequest"} or content.get("repository", {}).get("nameWithOwner") != f"{OWNER}/{REPOSITORY}":
                continue
            values: dict[str, Any] = {}
            for value in item.get("fieldValues", {}).get("nodes", []):
                field_name = (value.get("field") or {}).get("name")
                if not field_name:
                    continue
                kind = value.get("__typename")
                if kind == "ProjectV2ItemFieldTextValue":
                    values[field_name] = value.get("text")
                elif kind == "ProjectV2ItemFieldNumberValue":
                    values[field_name] = value.get("number")
                elif kind == "ProjectV2ItemFieldDateValue":
                    values[field_name] = value.get("date")
                elif kind == "ProjectV2ItemFieldSingleSelectValue":
                    values[field_name] = value.get("name")
                elif kind == "ProjectV2ItemFieldIterationValue":
                    values[field_name] = value.get("title")
                elif kind == "ProjectV2ItemFieldMultiSelectValue":
                    values[field_name] = [option.get("name") for option in value.get("options", [])]
            items[content["number"]] = {
                "id": item["id"],
                "fields": values,
                "content_type": content["__typename"],
            }
        has_next, cursor = page_info(current["items"])
        if not has_next:
            break

    normalized_fields: dict[str, dict[str, Any]] = {}
    for field in fields:
        entry: dict[str, Any] = {"id": field["id"], "name": field["name"], "type": field["dataType"]}
        if field["__typename"] in {"ProjectV2SingleSelectField", "ProjectV2MultiSelectField"}:
            raw_options = field.get("options", field.get("multiSelectOptions", []))
            entry["options"] = [
                {"id": option["id"], "name": option["name"], "description": option.get("description", "")}
                for option in raw_options
            ]
        elif field["__typename"] == "ProjectV2IterationField":
            configuration = field.get("configuration") or {}
            entry["iterations"] = [
                {"id": iteration["id"], "title": iteration["title"]}
                for iteration in configuration.get("iterations", []) + configuration.get("completedIterations", [])
            ]
        normalized_fields[field["name"]] = entry
    assert project is not None
    return {**project, "fields": normalized_fields}, items


def issue_list(client: GitHub, state: str) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    page = 1
    while True:
        batch = client.request(
            "GET",
            f"/repos/{OWNER}/{REPOSITORY}/issues?state={state}&per_page=100&page={page}&sort=created&direction=asc",
        )
        if not batch:
            break
        result.extend(batch)
        if len(batch) < 100:
            break
        page += 1
    return result


def issue_metadata(client: GitHub, number: int, cache: dict[int, dict[str, Any]]) -> dict[str, Any]:
    if number not in cache:
        issue = client.request("GET", f"/repos/{OWNER}/{REPOSITORY}/issues/{number}")
        cache[number] = issue
    return cache[number]


def dependencies(client: GitHub, number: int, cache: dict[int, list[dict[str, Any]]]) -> list[dict[str, Any]]:
    if number not in cache:
        cache[number] = client.request(
            "GET", f"/repos/{OWNER}/{REPOSITORY}/issues/{number}/dependencies/blocked_by", dependency=True
        )
    return cache[number]


def parent_issue(client: GitHub, number: int, cache: dict[int, dict[str, Any] | None]) -> dict[str, Any] | None:
    if number not in cache:
        cache[number] = client.request(
            "GET",
            f"/repos/{OWNER}/{REPOSITORY}/issues/{number}/parent",
            dependency=True,
            allow_statuses={404, 410},
        )
    return cache[number]


def sub_issues(client: GitHub, number: int, cache: dict[int, list[dict[str, Any]]]) -> list[dict[str, Any]]:
    if number not in cache:
        result: list[dict[str, Any]] = []
        page = 1
        while True:
            batch = client.request(
                "GET",
                f"/repos/{OWNER}/{REPOSITORY}/issues/{number}/sub_issues?per_page=100&page={page}",
                dependency=True,
            )
            if not batch:
                break
            result.extend(batch)
            if len(batch) < 100:
                break
            page += 1
        cache[number] = result
    return cache[number]


def relationship_ref(issue: dict[str, Any]) -> dict[str, Any]:
    return {"number": issue["number"], "state": issue.get("state", "UNKNOWN")}


def parse_block(body: str, pattern: re.Pattern[str], label: str) -> dict[str, Any] | None:
    match = pattern.search(body)
    if not match:
        return None
    try:
        value = json.loads(match.group(1).strip())
    except json.JSONDecodeError as error:
        raise BridgeError(f"{label} block is not valid JSON: {error}") from error
    if not isinstance(value, dict):
        raise BridgeError(f"{label} block must contain a JSON object")
    return value


def bridge_issue(client: GitHub) -> dict[str, Any]:
    issue = client.request("GET", f"/repos/{OWNER}/{REPOSITORY}/issues/{BRIDGE_ISSUE_NUMBER}")
    if issue.get("state") != "closed":
        fail(f"bridge issue #{BRIDGE_ISSUE_NUMBER} must remain closed")
    if issue.get("pull_request"):
        fail("bridge issue unexpectedly identifies as a pull request")
    return issue


def normalize_command(command: dict[str, Any], client: GitHub) -> list[dict[str, Any]]:
    allowed_root = {"version", "request_id", "operations"}
    extras = set(command) - allowed_root
    if extras:
        fail(f"command has unsupported top-level keys: {sorted(extras)}")
    if command.get("version") != COMMAND_VERSION:
        fail(f"unsupported command version: {command.get('version')!r}")
    request_id = command.get("request_id")
    if not isinstance(request_id, str) or not request_id.strip():
        fail("command request_id is required")
    operations = command.get("operations")
    if not isinstance(operations, list):
        fail("command operations must be an array")

    project_client = GitHub(os.environ.get("INFRASTRUCTURE_SENTINEL_PROJECT_TOKEN", ""), project=True)
    project, project_items = project_data(project_client)
    fields = project["fields"]
    issue_cache: dict[int, dict[str, Any]] = {}
    seen: set[int] = set()
    normalized: list[dict[str, Any]] = []
    for index, operation in enumerate(operations):
        if not isinstance(operation, dict):
            fail(f"operation {index} must be an object")
        allowed = {"issue", "ensure_project", "fields", "blocked_by", "parent", "relates_to"}
        extras = set(operation) - allowed
        if extras:
            fail(f"operation {index} has unsupported keys: {sorted(extras)}")
        number = operation.get("issue")
        if isinstance(number, bool) or not isinstance(number, int):
            fail(f"operation {index} issue must be an integer")
        if number in seen:
            fail(f"duplicate operations target issue #{number}")
        seen.add(number)
        issue = issue_metadata(client, number, issue_cache)
        target_is_pull_request = bool(issue.get("pull_request"))
        relationship_keys = sorted({"blocked_by", "parent", "relates_to"} & set(operation))
        if target_is_pull_request and relationship_keys:
            fail(
                f"pull request #{number} only supports project membership/field operations; "
                f"relationship keys are not allowed: {relationship_keys}"
            )
        ensure_project = operation.get("ensure_project", False)
        if not isinstance(ensure_project, bool):
            fail(f"operation for #{number} ensure_project must be boolean")
        requested_fields = operation.get("fields")
        if requested_fields is not None and not isinstance(requested_fields, dict):
            fail(f"operation for #{number} fields must be an object")
        if requested_fields is not None:
            for name, value in requested_fields.items():
                if name not in fields:
                    fail(f"operation for #{number} requests unknown project field {name!r}")
                field = fields[name]
                if field["type"] not in SUPPORTED_VALUE_TYPES:
                    fail(f"project field {name!r} has unsupported type {field['type']}")
                if value is not None:
                    if field["type"] == "MULTI_SELECT":
                        if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
                            fail(f"field {name!r} on #{number} requires a string array")
                        if len(value) != len(set(value)):
                            fail(f"field {name!r} on #{number} contains duplicate options")
                        valid = {option["name"] for option in field.get("options", [])}
                        unknown = set(value) - valid
                        if unknown:
                            fail(f"field {name!r} on #{number} has unknown options: {sorted(unknown)}")
                    elif field["type"] == "NUMBER":
                        if isinstance(value, bool) or not isinstance(value, (int, float)):
                            fail(f"field {name!r} on #{number} requires a number")
                    elif field["type"] == "DATE":
                        if not isinstance(value, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
                            fail(f"field {name!r} on #{number} requires YYYY-MM-DD")
                    else:
                        if not isinstance(value, str):
                            fail(f"field {name!r} on #{number} requires a string")
                        if field["type"] in {"SINGLE_SELECT", "ITERATION"}:
                            choices = field.get("options", []) if field["type"] == "SINGLE_SELECT" else field.get("iterations", [])
                            choice_names = {choice.get("name", choice.get("title")) for choice in choices}
                            if value not in choice_names:
                                fail(f"field {name!r} on #{number} has no live option {value!r}")
        blockers = operation.get("blocked_by", None)
        if blockers is not None:
            if not isinstance(blockers, list) or any(isinstance(item, bool) or not isinstance(item, int) for item in blockers):
                fail(f"operation for #{number} blocked_by must be an integer array")
            if len(blockers) != len(set(blockers)):
                fail(f"operation for #{number} blocked_by contains duplicates")
            if number in blockers:
                fail(f"issue #{number} cannot block itself")
            for blocker in blockers:
                blocker_issue = issue_metadata(client, blocker, issue_cache)
                if blocker_issue.get("pull_request"):
                    fail(f"blocker #{blocker} is a pull request, not an issue")

        parent_requested = "parent" in operation
        desired_parent = operation.get("parent")
        if parent_requested:
            if desired_parent is not None:
                if isinstance(desired_parent, bool) or not isinstance(desired_parent, int):
                    fail(f"operation for #{number} parent must be an integer or null")
                if desired_parent == number:
                    fail(f"issue #{number} cannot be its own parent")
                parent = issue_metadata(client, desired_parent, issue_cache)
                if parent.get("pull_request"):
                    fail(f"parent #{desired_parent} is a pull request, not an issue")

        relates_to_requested = "relates_to" in operation
        related = operation.get("relates_to")
        if relates_to_requested:
            if not isinstance(related, list) or any(isinstance(item, bool) or not isinstance(item, int) for item in related):
                fail(f"operation for #{number} relates_to must be an integer array")
            if len(related) != len(set(related)):
                fail(f"operation for #{number} relates_to contains duplicates")
            if number in related:
                fail(f"issue #{number} cannot relate to itself")
            for related_number in related:
                related_issue = issue_metadata(client, related_number, issue_cache)
                if related_issue.get("pull_request"):
                    fail(f"related issue #{related_number} is a pull request, not an issue")
            fail(
                "UNSUPPORTED_CAPABILITY: native relates-to relationships are not exposed by GitHub's current first-party REST or GraphQL APIs; "
                "refusing to approximate relates_to with blocked_by"
            )
        normalized.append(
            {
                "issue": number,
                "content_type": "PullRequest" if target_is_pull_request else "Issue",
                "ensure_project": ensure_project,
                "fields": requested_fields,
                "blocked_by": blockers,
                "parent_requested": parent_requested,
                "parent": desired_parent,
                "relates_to_requested": relates_to_requested,
                "relates_to": related,
            }
        )

    # The operation set is applied as a desired-state overlay on the live graph.
    graph: dict[int, set[int]] = {}
    for raw in issue_list(client, "all"):
        if raw.get("pull_request"):
            continue
        graph[raw["number"]] = {item["number"] for item in dependencies(client, raw["number"], {})}
    for operation in normalized:
        if operation["blocked_by"] is not None:
            graph[operation["issue"]] = set(operation["blocked_by"])
    for start in graph:
        stack: list[int] = []
        visiting: set[int] = set()
        visited: set[int] = set()

        def visit(node: int) -> None:
            if node in visiting:
                cycle = " -> ".join(map(str, stack + [node]))
                fail(f"dependency cycle would result: {cycle}")
            if node in visited:
                return
            visiting.add(node)
            stack.append(node)
            for dependency in graph.get(node, set()):
                visit(dependency)
            stack.pop()
            visiting.remove(node)
            visited.add(node)

        visit(start)

    parent_graph: dict[int, int] = {}
    parent_cache: dict[int, dict[str, Any] | None] = {}
    for raw in issue_list(client, "all"):
        if raw.get("pull_request"):
            continue
        current_parent = parent_issue(client, raw["number"], parent_cache)
        if current_parent:
            parent_graph[raw["number"]] = current_parent["number"]
    for operation in normalized:
        if operation["parent_requested"]:
            if operation["parent"] is None:
                parent_graph.pop(operation["issue"], None)
            else:
                parent_graph[operation["issue"]] = operation["parent"]
    for start in parent_graph:
        chain: list[int] = []
        seen_parents: set[int] = set()
        current = start
        while current in parent_graph:
            if current in seen_parents:
                cycle = " -> ".join(map(str, chain + [current]))
                fail(f"parent cycle would result: {cycle}")
            seen_parents.add(current)
            chain.append(current)
            current = parent_graph[current]
    return normalized


def current_value(item: dict[str, Any] | None, field: dict[str, Any]) -> Any:
    if not item:
        return None
    return item.get("fields", {}).get(field["name"])


def value_equal(field_type: str, current: Any, desired: Any) -> bool:
    if field_type == "MULTI_SELECT":
        return current is not None and set(current) == set(desired or [])
    return current == desired


def field_payload(field_type: str, value: Any) -> dict[str, Any]:
    if field_type == "TEXT":
        return {"text": value}
    if field_type == "NUMBER":
        return {"number": value}
    if field_type == "DATE":
        return {"date": value}
    if field_type == "SINGLE_SELECT":
        return {"singleSelectOptionId": value}
    if field_type == "ITERATION":
        return {"iterationId": value}
    if field_type == "MULTI_SELECT":
        return {"multiSelectOptionIds": value}
    fail(f"unsupported project field type {field_type}")


def refresh_project(project_client: GitHub) -> tuple[dict[str, Any], dict[int, dict[str, Any]]]:
    return project_data(project_client)


def apply_command(command: dict[str, Any], github: GitHub) -> tuple[list[str], list[str]]:
    operations = normalize_command(command, github)
    project_client = GitHub(os.environ.get("INFRASTRUCTURE_SENTINEL_PROJECT_TOKEN", ""), project=True)
    project, project_items = refresh_project(project_client)
    applied: list[str] = []
    unchanged: list[str] = []
    issue_cache: dict[int, dict[str, Any]] = {}
    dependency_cache: dict[int, list[dict[str, Any]]] = {}
    parent_cache: dict[int, dict[str, Any] | None] = {}
    for operation in operations:
        number = operation["issue"]
        item = project_items.get(number)
        operation_changed = False
        if operation["ensure_project"] and item is None:
            issue = issue_metadata(github, number, issue_cache)
            try:
                result = project_client.graphql(ADD_ITEM_MUTATION, {"projectId": project["id"], "contentId": issue["node_id"]})
            except BridgeError as error:
                raise BridgeError(f"issue #{number}: adding to project failed: {error}", applied=applied) from error
            if not result.get("addProjectV2ItemById", {}).get("item", {}).get("id"):
                raise BridgeError(f"failed to add issue #{number} to the Infrastructure project", applied=applied)
            project, project_items = refresh_project(project_client)
            item = project_items.get(number)
            if item is None:
                raise BridgeError(f"issue #{number} was not present after adding it to the Infrastructure project", applied=applied)
            applied.append(f"issue #{number}: added to project")
            operation_changed = True
        elif operation["fields"] and item is None:
            raise BridgeError(f"issue #{number} is not in the project; set ensure_project=true before writing fields", applied=applied)

        if operation["fields"]:
            for name, desired in operation["fields"].items():
                field = project["fields"][name]
                current = current_value(item, field)
                if value_equal(field["type"], current, desired):
                    unchanged.append(f"issue #{number}: field {name} already {desired!r}")
                    continue
                try:
                    if desired is None:
                        try:
                            project_client.graphql(
                                CLEAR_FIELD_MUTATION,
                                {"projectId": project["id"], "itemId": item["id"], "fieldId": field["id"]},
                            )
                        except BridgeError:
                            if field["type"] != "MULTI_SELECT":
                                raise
                            project_client.graphql(
                                UPDATE_FIELD_MUTATION,
                                {
                                    "projectId": project["id"],
                                    "itemId": item["id"],
                                    "fieldId": field["id"],
                                    "value": field_payload(field["type"], []),
                                },
                            )
                    else:
                        option_id = desired
                        if field["type"] == "SINGLE_SELECT":
                            option_id = next(option["id"] for option in field["options"] if option["name"] == desired)
                        elif field["type"] == "ITERATION":
                            option_id = next(iteration["id"] for iteration in field["iterations"] if iteration["title"] == desired)
                        elif field["type"] == "MULTI_SELECT":
                            option_id = [option["id"] for option in field["options"] if option["name"] in desired]
                        project_client.graphql(
                            UPDATE_FIELD_MUTATION,
                            {
                                "projectId": project["id"],
                                "itemId": item["id"],
                                "fieldId": field["id"],
                                "value": field_payload(field["type"], option_id),
                            },
                        )
                except BridgeError as error:
                    raise BridgeError(f"issue #{number}: field {name} mutation failed: {error}", applied=applied) from error
                project, project_items = refresh_project(project_client)
                item = project_items.get(number)
                actual = current_value(item, field)
                if not value_equal(field["type"], actual, desired):
                    raise BridgeError(
                        f"issue #{number}: field {name} read-back was {actual!r}, expected {desired!r}", applied=applied
                    )
                applied.append(f"issue #{number}: field {name} set to {desired!r}")
                operation_changed = True

        if operation["parent_requested"]:
            current_parent = parent_issue(github, number, parent_cache)
            current_parent_number = current_parent.get("number") if current_parent else None
            desired_parent = operation["parent"]
            if current_parent_number == desired_parent:
                unchanged.append(f"issue #{number}: parent already {desired_parent!r}")
            else:
                issue = issue_metadata(github, number, issue_cache)
                try:
                    if desired_parent is None:
                        if current_parent is None:
                            raise BridgeError(f"issue #{number}: parent disappeared during reconciliation")
                        github.request(
                            "DELETE",
                            f"/repos/{OWNER}/{REPOSITORY}/issues/{current_parent_number}/sub_issue",
                            {"sub_issue_id": issue["id"]},
                            dependency=True,
                        )
                    else:
                        github.request(
                            "POST",
                            f"/repos/{OWNER}/{REPOSITORY}/issues/{desired_parent}/sub_issues",
                            {"sub_issue_id": issue["id"], "replace_parent": True},
                            dependency=True,
                        )
                except BridgeError as error:
                    raise BridgeError(f"issue #{number}: parent mutation failed: {error}", applied=applied) from error
                actual_parent = parent_issue(github, number, {})
                actual_parent_number = actual_parent.get("number") if actual_parent else None
                if actual_parent_number != desired_parent:
                    raise BridgeError(
                        f"issue #{number}: parent read-back was {actual_parent_number!r}, expected {desired_parent!r}",
                        applied=applied,
                    )
                applied.append(f"issue #{number}: parent set to {desired_parent!r}")
                operation_changed = True

        if operation["blocked_by"] is not None:
            existing = {dependency["number"]: dependency for dependency in dependencies(github, number, dependency_cache)}
            desired_set = set(operation["blocked_by"])
            stale = sorted(set(existing) - desired_set)
            missing = sorted(desired_set - set(existing))
            for blocker in stale:
                blocker_id = existing[blocker].get("id")
                if blocker_id is None:
                    raise BridgeError(f"issue #{number}: existing blocker #{blocker} has no database id", applied=applied)
                try:
                    github.request(
                        "DELETE",
                        f"/repos/{OWNER}/{REPOSITORY}/issues/{number}/dependencies/blocked_by/{blocker_id}",
                        dependency=True,
                    )
                except BridgeError as error:
                    raise BridgeError(f"issue #{number}: removing blocker #{blocker} failed: {error}", applied=applied) from error
                applied.append(f"issue #{number}: removed blocker #{blocker}")
                operation_changed = True
            for blocker in missing:
                blocker_issue = issue_metadata(github, blocker, issue_cache)
                try:
                    github.request(
                        "POST",
                        f"/repos/{OWNER}/{REPOSITORY}/issues/{number}/dependencies/blocked_by",
                        {"issue_id": blocker_issue["id"]},
                        dependency=True,
                    )
                except BridgeError as error:
                    raise BridgeError(f"issue #{number}: adding blocker #{blocker} failed: {error}", applied=applied) from error
                applied.append(f"issue #{number}: added blocker #{blocker}")
                operation_changed = True
            actual = {dependency["number"] for dependency in dependencies(github, number, {})}
            if actual != desired_set:
                raise BridgeError(
                    f"issue #{number}: dependency read-back was {sorted(actual)}, expected {sorted(desired_set)}", applied=applied
                )
            if not stale and not missing:
                unchanged.append(f"issue #{number}: blocked_by already {sorted(desired_set)}")
        if (
            not operation_changed
            and operation["fields"] is None
            and operation["blocked_by"] is None
            and not operation["parent_requested"]
            and not operation["relates_to_requested"]
        ):
            unchanged.append(f"issue #{number}: already in desired state")
    return applied, unchanged


def build_snapshot(github: GitHub, project_client: GitHub, last_result: dict[str, Any]) -> dict[str, Any]:
    project, project_items = project_data(project_client)
    open_items = issue_list(github, "open")
    open_issues = [issue for issue in open_items if not issue.get("pull_request")]
    open_pull_requests = [issue for issue in open_items if issue.get("pull_request")]
    dependency_cache: dict[int, list[dict[str, Any]]] = {}
    parent_cache: dict[int, dict[str, Any] | None] = {}
    sub_issue_cache: dict[int, list[dict[str, Any]]] = {}
    issues: dict[str, Any] = {}
    for issue in open_issues:
        number = issue["number"]
        blocked = [
            {"number": item["number"], "state": item.get("state", "UNKNOWN")}
            for item in dependencies(github, number, dependency_cache)
        ]
        parent = parent_issue(github, number, parent_cache)
        children = sub_issues(github, number, sub_issue_cache)
        item = project_items.get(number)
        issues[str(number)] = {
            "title": issue["title"],
            "state": issue["state"],
            "project_item_id": item["id"] if item else None,
            "fields": item["fields"] if item else {},
            "blocked_by": sorted(blocked, key=lambda value: value["number"]),
            "parent": relationship_ref(parent) if parent else None,
            "sub_issues": sorted(
                [relationship_ref(child) for child in children], key=lambda value: value["number"]
            ),
            "relates_to": None,
        }
    pull_requests: dict[str, Any] = {}
    for pull_request in open_pull_requests:
        number = pull_request["number"]
        item = project_items.get(number)
        pull_requests[str(number)] = {
            "title": pull_request["title"],
            "state": pull_request["state"],
            "project_item_id": item["id"] if item else None,
            "fields": item["fields"] if item else {},
        }
    schema: dict[str, Any] = {}
    for name, field in project["fields"].items():
        entry = {"type": field["type"]}
        if "options" in field:
            entry["options"] = [
                {"name": option["name"], "description": option.get("description", "")}
                for option in field["options"]
            ]
        if "iterations" in field:
            entry["iterations"] = [iteration["title"] for iteration in field["iterations"]]
        schema[name] = entry
    return {
        "version": STATE_VERSION,
        "refreshed_at": now(),
        "project": {"owner": OWNER, "number": PROJECT_NUMBER, "title": project["title"]},
        "fields": schema,
        "relationship_capabilities": {
            "blocked_by": {"read": True, "write": True},
            "parent": {"read": True, "write": True},
            "sub_issues": {"read": True, "write": True},
            "relates_to": {
                "read": False,
                "write": False,
                "status": "unsupported",
                "issues": None,
                "reason": (
                    "GitHub's current first-party REST and GraphQL APIs do not expose native relates-to "
                    "issue relationships"
                ),
            },
        },
        "issues": issues,
        "pull_requests": pull_requests,
        "last_result": last_result,
    }


def replace_state(body: str, state: dict[str, Any], *, remove_request_id: str | None = None) -> str:
    state_block = f"<!-- infrastructure-sentinel-state:v2\n{json.dumps(state, indent=2, sort_keys=True)}\n-->"
    if STATE_RE.search(body):
        body = STATE_RE.sub(state_block, body, count=1)
    else:
        insertion = body.find("<!-- infrastructure-sentinel-command:v1")
        if insertion < 0:
            body = body.rstrip() + "\n\n" + state_block
        else:
            body = body[:insertion].rstrip() + "\n\n" + state_block + "\n\n" + body[insertion:]
    if remove_request_id is not None:
        command_match = COMMAND_RE.search(body)
        if command_match:
            try:
                command = json.loads(command_match.group(1).strip())
            except json.JSONDecodeError:
                command = None
            if isinstance(command, dict) and command.get("request_id") == remove_request_id:
                body = body[: command_match.start()].rstrip() + body[command_match.end() :]
    return body.strip() + "\n"


def write_bridge_body(github: GitHub, state: dict[str, Any], *, remove_request_id: str | None = None) -> None:
    latest = bridge_issue(github)
    body = replace_state(latest.get("body") or "", state, remove_request_id=remove_request_id)
    github.request("PATCH", f"/repos/{OWNER}/{REPOSITORY}/issues/{BRIDGE_ISSUE_NUMBER}", {"body": body})
    project_client = GitHub(os.environ.get("INFRASTRUCTURE_SENTINEL_PROJECT_TOKEN", ""), project=True)
    project, project_items = project_data(project_client)
    bridge_item = project_items.get(BRIDGE_ISSUE_NUMBER)
    if bridge_item:
        project_client.graphql(
            DELETE_ITEM_MUTATION,
            {"projectId": project["id"], "itemId": bridge_item["id"]},
        )
        _, project_items = project_data(project_client)
        if BRIDGE_ISSUE_NUMBER in project_items:
            raise BridgeError(f"bridge issue #{BRIDGE_ISSUE_NUMBER} remained in the Infrastructure project")


def main() -> int:
    try:
        github = GitHub(os.environ.get("GITHUB_TOKEN", ""))
        project_client = GitHub(os.environ.get("INFRASTRUCTURE_SENTINEL_PROJECT_TOKEN", ""), project=True)
        issue = bridge_issue(github)
        previous_state = parse_block(issue.get("body") or "", STATE_RE, "state") or {}
        mode = os.environ.get("RUN_MODE", "snapshot")
        last_result = previous_state.get("last_result") if isinstance(previous_state.get("last_result"), dict) else {
            "request_id": None,
            "status": None,
            "applied": [],
            "unchanged": [],
            "errors": [],
        }
        command = parse_block(issue.get("body") or "", COMMAND_RE, "command") if mode == "command" else None
        if mode == "command" and command is None:
            raise BridgeError("bridge issue edit did not contain a command block")
        if mode not in {"command", "snapshot"}:
            raise BridgeError(f"unsupported RUN_MODE {mode!r}")

        remove_request_id = None
        if command is not None:
            request_id = command.get("request_id")
            if isinstance(last_result, dict) and last_result.get("status") == "ok" and last_result.get("request_id") == request_id:
                raise BridgeError(f"successful request_id {request_id!r} was replayed")
            try:
                applied, unchanged = apply_command(command, github)
            except BridgeError as error:
                failure = {
                    "request_id": request_id if isinstance(request_id, str) else None,
                    "status": "error",
                    "applied": error.applied,
                    "unchanged": [],
                    "errors": [str(error)],
                }
                try:
                    state = build_snapshot(github, project_client, failure)
                    write_bridge_body(github, state)
                except Exception as refresh_error:  # keep the original validation/mutation failure visible in the run
                    print(f"snapshot refresh after failure also failed: {refresh_error}", file=sys.stderr)
                raise
            last_result = {"request_id": command["request_id"], "status": "ok", "applied": applied, "unchanged": unchanged, "errors": []}
            remove_request_id = command["request_id"]

        state = build_snapshot(github, project_client, last_result)
        write_bridge_body(github, state, remove_request_id=remove_request_id)
        return 0
    except BridgeError as error:
        print(f"infrastructure-sentinel bridge failed: {error}", file=sys.stderr)
        return 1
    except Exception as error:
        print(f"infrastructure-sentinel bridge failed unexpectedly: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

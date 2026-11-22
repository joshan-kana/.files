"""Host-scoped execution policy and trusted operator approval records."""

import argparse
import asyncio
import hashlib
import json
import os
import tempfile
import time
from pathlib import Path

APPROVAL_DIR = Path(os.environ.get("CHATGPT_SHELL_APPROVAL_DIR", "/run/chatgpt-shell-access/approvals"))
STATE_DIR = Path(os.environ.get("CHATGPT_SHELL_STATE_DIR", "/var/lib/chatgpt-shell-access"))
DEFAULTS_FILE = Path(os.environ.get("CHATGPT_SHELL_POLICIES_FILE", "/etc/chatgpt-shell-policies.json"))
APPROVAL_TIMEOUT = 300
MAX_REVIEW_STDIN_BYTES = 16 * 1024
MODES = {"automatic", "ask", "deny"}
KINDS = {"commands", "elevation"}


def _defaults() -> dict[str, dict[str, str]]:
    """Read the declarative host defaults, which do not contain secrets."""
    return json.loads(DEFAULTS_FILE.read_text())


def _read_json(path: Path, default: dict | None = None) -> dict:
    """Read an optional private JSON record."""
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        if default is None:
            raise
        return default


def _write_exclusive(path: Path, value: dict) -> None:
    """Create a private, immutable decision record once."""
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as output:
        json.dump(value, output, sort_keys=True)
        output.write("\n")


def _write_atomic(path: Path, value: dict) -> None:
    """Replace a private policy file without exposing partially written content."""
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, temporary = tempfile.mkstemp(dir=path.parent)
    try:
        with os.fdopen(fd, "w") as output:
            json.dump(value, output, sort_keys=True)
            output.write("\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def _digest(request: dict) -> str:
    """Bind a human decision to the precise, unmodified submitted operation."""
    payload = json.dumps(request, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(payload).hexdigest()


def _override(host: str, kind: str) -> str | None:
    """Read a non-expired operator policy override."""
    entry = _read_json(STATE_DIR / "policies.json", {}).get(host, {}).get(kind, {})
    if entry and entry.get("expires_at") is not None and entry["expires_at"] <= time.time():
        return None
    return entry.get("mode")


def effective(host: str, kind: str) -> str:
    """Resolve operator overrides above the declarative host defaults."""
    defaults = _defaults()
    if host not in defaults or kind not in KINDS:
        raise ValueError("unknown host or permission category")
    mode = _override(host, kind) or defaults[host][kind]
    if mode not in MODES:
        raise ValueError("invalid permission mode")
    return mode


def _prepare() -> None:
    """Create approval directories restricted to the trusted controller identity."""
    (APPROVAL_DIR / "pending").mkdir(parents=True, exist_ok=True, mode=0o700)
    (APPROVAL_DIR / "decisions").mkdir(parents=True, exist_ok=True, mode=0o700)


def audit(event: str, details: dict) -> None:
    """Append an operator-readable private event without granting approval."""
    STATE_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd = os.open(STATE_DIR / "events.jsonl", os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
    with os.fdopen(fd, "a") as output:
        output.write(json.dumps({"at": time.time(), "event": event, **details}, sort_keys=True) + "\n")


async def authorize(
    request_id: str,
    host: str,
    kind: str,
    command: str,
    cwd: str | None,
    stdin: str | None = None,
) -> None:
    """Wait for a one-time human decision where the effective policy requires it."""
    mode = effective(host, kind)
    if mode == "deny":
        audit("denied-by-policy", {"request": request_id, "host": host, "kind": kind})
        raise PermissionError(f"{kind} denied on {host}")
    if mode == "automatic":
        audit("allowed-by-policy", {"request": request_id, "host": host, "kind": kind})
        return

    if stdin is not None and len(stdin.encode()) > MAX_REVIEW_STDIN_BYTES:
        raise PermissionError("stdin exceeds the maximum size for an operator-reviewed command")

    _prepare()
    request = {
        "id": request_id,
        "host": host,
        "kind": kind,
        "command": command,
        "cwd": cwd,
        "stdin": stdin,
        "expires_at": time.time() + APPROVAL_TIMEOUT,
    }
    digest = _digest(request)
    pending = APPROVAL_DIR / "pending" / f"{request_id}.json"
    decision_file = APPROVAL_DIR / "decisions" / f"{request_id}.json"
    _write_exclusive(pending, {**request, "digest": digest})
    audit("approval-requested", {"request": request_id, "host": host, "kind": kind})

    try:
        while time.time() < request["expires_at"]:
            try:
                decision = _read_json(decision_file)
                decision_file.unlink()
            except FileNotFoundError:
                await asyncio.sleep(0.2)
                continue
            if decision.get("digest") != digest or decision.get("decision") not in ("approve", "deny"):
                raise PermissionError("approval record does not match the requested operation")
            if effective(host, kind) == "deny":
                raise PermissionError("policy changed to deny while awaiting approval")
            if decision["decision"] == "approve":
                audit("approval-granted", {"request": request_id, "host": host, "kind": kind})
                return
            raise PermissionError("operator denied the execution")
        raise PermissionError("approval timed out")
    finally:
        pending.unlink(missing_ok=True)
        decision_file.unlink(missing_ok=True)


def _valid_id(value: str) -> str:
    """Accept only hexadecimal request IDs for filesystem lookups."""
    if len(value) != 32 or any(char not in "0123456789abcdef" for char in value):
        raise ValueError("invalid request ID")
    return value


def _list() -> None:
    """Show approvals without requiring a custom user interface."""
    _prepare()
    for path in sorted((APPROVAL_DIR / "pending").glob("*.json")):
        request = _read_json(path)
        if request["expires_at"] <= time.time():
            continue
        print(f"{request['id']}  {request['host']}  {request['kind']}")
        print(f"  cwd: {json.dumps(request['cwd'], ensure_ascii=True)}")
        print(f"  command: {json.dumps(request['command'], ensure_ascii=True)}")
        if request.get("stdin") is not None:
            print(f"  stdin: {json.dumps(request['stdin'], ensure_ascii=True)}")


def _decide(request_id: str, decision: str) -> None:
    """Record one human decision against the original request digest."""
    request_id = _valid_id(request_id)
    request = _read_json(APPROVAL_DIR / "pending" / f"{request_id}.json")
    if request["expires_at"] <= time.time():
        raise ValueError("approval expired")
    _write_exclusive(
        APPROVAL_DIR / "decisions" / f"{request_id}.json",
        {"decision": decision, "digest": request["digest"]},
    )
    print(f"{decision} {request_id}")


def _set_policy(host: str, kind: str, mode: str, ttl: int | None) -> None:
    """Set an explicit operator policy with mandatory expiry for automatic elevation."""
    if host not in _defaults() or kind not in KINDS or mode not in MODES:
        raise ValueError("unknown host, permission category or mode")
    if ttl is not None and not 1 <= ttl <= 3600:
        raise ValueError("TTL must be between 1 and 3600 seconds")
    if kind == "elevation" and mode == "automatic" and ttl is None:
        raise ValueError("automatic elevation requires a TTL")
    policy_file = STATE_DIR / "policies.json"
    policies = _read_json(policy_file, {})
    policies.setdefault(host, {})[kind] = {
        "mode": mode,
        "expires_at": time.time() + ttl if ttl is not None else None,
    }
    _write_atomic(policy_file, policies)
    audit("policy-changed", {"host": host, "kind": kind, "mode": mode, "ttl": ttl})
    print(f"{host} {kind}: {effective(host, kind)}")


def main() -> None:
    """Run the operator-only approval and policy command interface."""
    parser = argparse.ArgumentParser(description="Inspect and authorize ChatGPT shell commands")
    subcommands = parser.add_subparsers(dest="action", required=True)
    subcommands.add_parser("list")
    for action in ("approve", "deny"):
        subcommands.add_parser(action).add_argument("request_id")
    get_policy = subcommands.add_parser("policy")
    get_policy.add_argument("host")
    get_policy.add_argument("kind", choices=sorted(KINDS))
    set_policy = subcommands.add_parser("set-policy")
    set_policy.add_argument("host")
    set_policy.add_argument("kind", choices=sorted(KINDS))
    set_policy.add_argument("mode", choices=sorted(MODES))
    set_policy.add_argument("--ttl", type=int)
    arguments = parser.parse_args()

    try:
        if arguments.action == "list":
            _list()
        elif arguments.action in ("approve", "deny"):
            _decide(arguments.request_id, arguments.action)
        elif arguments.action == "policy":
            print(effective(arguments.host, arguments.kind))
        elif arguments.action == "set-policy":
            _set_policy(arguments.host, arguments.kind, arguments.mode, arguments.ttl)
    except (OSError, ValueError, PermissionError) as exc:
        parser.error(str(exc))


if __name__ == "__main__":
    main()

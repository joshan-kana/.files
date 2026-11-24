"""Host-scoped execution policy and trusted operator approval records."""

import argparse
import asyncio
import hashlib
import json
import os
import tempfile
import time
import uuid
from pathlib import Path

APPROVAL_DIR = Path(os.environ["CHATGPT_SHELL_APPROVAL_DIR"])
STATE_DIR = Path(os.environ["CHATGPT_SHELL_STATE_DIR"])
OPERATOR_STATE_DIR = Path(os.environ["CHATGPT_SHELL_OPERATOR_STATE_DIR"])
POLICY_FILE = OPERATOR_STATE_DIR / "policies.json"
DEFAULTS_FILE = Path(os.environ["CHATGPT_SHELL_POLICIES_FILE"])
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


def _write_exclusive(path: Path, value: dict, mode: int = 0o600) -> None:
    """Create a private, immutable decision record once."""
    fd, temporary = tempfile.mkstemp(dir=path.parent)
    try:
        os.fchmod(fd, mode)
        with os.fdopen(fd, "w") as output:
            json.dump(value, output, sort_keys=True)
            output.write("\n")
        os.link(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def _write_atomic(path: Path, value: dict) -> None:
    """Replace a private policy file without exposing partially written content."""
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, temporary = tempfile.mkstemp(dir=path.parent)
    os.fchmod(fd, 0o640 if path == POLICY_FILE else 0o600)
    try:
        with os.fdopen(fd, "w") as output:
            json.dump(value, output, sort_keys=True)
            output.write("\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def register_terminal(address: str, name: str, metadata: dict) -> None:
    """Bind agent-owned terminal control to private controller state, not labels."""
    if (
        not isinstance(address, str)
        or not isinstance(name, str)
        or not name.startswith("chatgpt-")
        or metadata.get("address") != address
        or metadata.get("name") != name
        or not isinstance(metadata.get("created_ms"), int)
    ):
        raise ValueError("Herdr returned invalid terminal identity")
    path = STATE_DIR / "managed-terminals.json"
    records = _read_json(path, {})
    if address in records:
        raise ValueError("terminal address already registered")
    records[address] = {"name": name, "created_ms": metadata["created_ms"]}
    _write_atomic(path, records)


def owns_terminal(address: str, metadata: dict) -> bool:
    """Only the controller can claim a session; client-provided labels are ignored."""
    record = _read_json(STATE_DIR / "managed-terminals.json", {}).get(address)
    return (
        record is not None
        and record
        == {
            "name": metadata.get("name"),
            "created_ms": metadata.get("created_ms"),
        }
        and metadata.get("address") == address
    )


def release_terminal(address: str) -> None:
    """Drop controller mutation authority when a managed terminal is killed."""
    path = STATE_DIR / "managed-terminals.json"
    records = _read_json(path, {})
    if address in records:
        del records[address]
        _write_atomic(path, records)


def _require_operator() -> None:
    """Only an authenticated run0 operator may change a decision or grant."""
    if os.geteuid() != 0:
        raise PermissionError("operator decisions require run0")


def _digest(request: dict) -> str:
    """Bind a human decision to the precise, unmodified submitted operation."""
    payload = json.dumps(request, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(payload).hexdigest()


def _policy_revision(host: str, kind: str, session: str | None) -> str:
    """Bind a pending approval to the relevant root-owned policy records."""
    policies = _read_json(POLICY_FILE, {}).get(host, {})
    return _digest(
        {
            "default": _defaults()[host][kind],
            "host": policies.get(kind),
            "session": policies.get("sessions", {}).get(session, {}).get(kind) if session is not None else None,
        }
    )


def _valid_session(session: str) -> str:
    """Keep session policy keys bounded and unambiguous."""
    if not session or len(session) > 64 or not all(c.isascii() and (c.isalnum() or c in "-_") for c in session):
        raise ValueError("invalid session")
    return session


def _override(host: str, kind: str, session: str | None = None) -> str | None:
    """Read an unexpired host or individual-session operator grant."""
    policies = _read_json(POLICY_FILE, {}).get(host, {})
    if session is not None:
        policies = policies.get("sessions", {}).get(_valid_session(session), {})
    entry = policies.get(kind, {})
    if entry and entry.get("expires_at") is not None and entry["expires_at"] <= time.time():
        return None
    return entry.get("mode")


def effective(host: str, kind: str, session: str | None = None) -> str:
    """Apply explicit host denies before scoped operator grants."""
    defaults = _defaults()
    if host not in defaults or kind not in KINDS:
        raise ValueError("unknown host or permission category")
    if defaults[host][kind] == "deny":
        return "deny"
    mode = _override(host, kind) or defaults[host][kind]
    if mode == "deny":
        return "deny"
    if session is not None:
        mode = _override(host, kind, session) or mode
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
    session: str | None = None,
    target_identity: str | None = None,
) -> None:
    """Wait for a one-time human decision where the effective policy requires it."""
    mode = effective(host, kind, session)
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
        "target_identity": target_identity,
        "command": command,
        "cwd": cwd,
        "stdin": stdin,
        "session": session,
        "policy_revision": _policy_revision(host, kind, session),
        "expires_at": time.time() + APPROVAL_TIMEOUT,
    }
    digest = _digest(request)
    pending = APPROVAL_DIR / "pending" / f"{request_id}.json"
    decision_file = APPROVAL_DIR / "decisions" / f"{request_id}.json"
    _write_exclusive(pending, {**request, "digest": digest})
    audit("approval-requested", {"request": request_id, "host": host, "kind": kind})

    try:
        while time.time() < request["expires_at"]:
            if effective(host, kind, session) == "deny":
                raise PermissionError("policy changed to deny while awaiting approval")
            if effective(host, kind, session) != "ask" or _policy_revision(host, kind, session) != request["policy_revision"]:
                raise PermissionError("policy changed while awaiting approval")
            try:
                decision = _read_json(decision_file)
                # The decision directory is root-owned and deliberately not writable
                # by the gateway. Request IDs are unique, preventing replay.
            except FileNotFoundError:
                await asyncio.sleep(0.2)
                continue
            if decision.get("digest") != digest or decision.get("decision") not in ("approve", "deny"):
                raise PermissionError("approval record does not match the requested operation")
            if decision["decision"] == "approve":
                audit("approval-granted", {"request": request_id, "host": host, "kind": kind})
                return
            raise PermissionError("operator denied the execution")
        raise PermissionError("approval timed out")
    finally:
        pending.unlink(missing_ok=True)
        # Root-owned decisions stay immutable to the gateway until runtime cleanup.


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
        print(f"  target: {json.dumps(request.get('target_identity'), ensure_ascii=True)}")
        print(f"  expires: {time.strftime('%Y-%m-%d %H:%M:%S %Z', time.localtime(request['expires_at']))}")
        print("  scope: one operation")
        print(f"  cwd: {json.dumps(request['cwd'], ensure_ascii=True)}")
        if request.get("session") is not None:
            print(f"  session: {json.dumps(request['session'], ensure_ascii=True)}")
        print(f"  command: {json.dumps(request['command'], ensure_ascii=True)}")
        if request.get("stdin") is not None:
            print(f"  stdin: {json.dumps(request['stdin'], ensure_ascii=True)}")


def _decide(request_id: str, decision: str) -> None:
    """Record one human decision against the original request digest."""
    _require_operator()
    request_id = _valid_id(request_id)
    request = _read_json(APPROVAL_DIR / "pending" / f"{request_id}.json")
    if request["expires_at"] <= time.time():
        raise ValueError("approval expired")
    _write_exclusive(
        APPROVAL_DIR / "decisions" / f"{request_id}.json",
        {"decision": decision, "digest": request["digest"]},
        mode=0o640,
    )
    print(f"{decision} {request_id}")


def _set_policy(host: str, kind: str, mode: str, ttl: int | None, session: str | None = None) -> None:
    """Set a host or session grant; automatic overrides always expire."""
    _require_operator()
    defaults = _defaults()
    if host not in defaults or kind not in KINDS or mode not in MODES:
        raise ValueError("unknown host, permission category or mode")
    if defaults[host][kind] == "deny" and mode != "deny":
        raise PermissionError("declarative policy denies this permission")
    if session is not None:
        _valid_session(session)
    if ttl is not None and not 1 <= ttl <= 3600:
        raise ValueError("TTL must be between 1 and 3600 seconds")
    if mode == "automatic" and ttl is None:
        raise ValueError("automatic grants require a TTL")
    policy_file = POLICY_FILE
    policies = _read_json(policy_file, {})
    host_policies = policies.setdefault(host, {})
    target = host_policies.setdefault("sessions", {}).setdefault(session, {}) if session else host_policies
    target[kind] = {
        "mode": mode,
        "expires_at": time.time() + ttl if ttl is not None else None,
        # An unchanged or reverted value is still a new operator decision.
        "revision": uuid.uuid4().hex,
    }
    _write_atomic(policy_file, policies)
    audit("policy-changed", {"host": host, "kind": kind, "mode": mode, "ttl": ttl, "session": session})
    print(f"{host} {kind}: {effective(host, kind, session)}")


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
    get_policy.add_argument("--session")
    set_policy = subcommands.add_parser("set-policy")
    set_policy.add_argument("host")
    set_policy.add_argument("kind", choices=sorted(KINDS))
    set_policy.add_argument("mode", choices=sorted(MODES))
    set_policy.add_argument("--ttl", type=int)
    set_policy.add_argument("--session")
    arguments = parser.parse_args()

    try:
        if arguments.action == "list":
            _list()
        elif arguments.action in ("approve", "deny"):
            _decide(arguments.request_id, arguments.action)
        elif arguments.action == "policy":
            print(effective(arguments.host, arguments.kind, arguments.session))
        elif arguments.action == "set-policy":
            _set_policy(arguments.host, arguments.kind, arguments.mode, arguments.ttl, arguments.session)
    except (OSError, ValueError, PermissionError) as exc:
        parser.error(str(exc))


if __name__ == "__main__":
    main()

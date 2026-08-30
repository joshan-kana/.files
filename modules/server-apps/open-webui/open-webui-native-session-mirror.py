#!/usr/bin/env python3
"""Optional SessionWiki -> Open WebUI native-session mirror.

This is deliberately a leaf feature: SessionWiki/Computer/native resume do not
need it. `push` runs on a machine that owns native sessions; `ingest` runs on the
Open WebUI server and is normally reached over SSH.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import socket
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

SCHEMA = "dotfiles.native-session-mirror/1"
DEFAULT_SERVER = "joshan@192.168.1.3"
DEFAULT_OPEN_WEBUI_URL = "http://192.168.1.3:8081"
DEFAULT_OPEN_WEBUI_ENV = "/root/secrets/open-webui.env"
DEFAULT_STATE = "/var/lib/apps/open-webui/native-session-mirror.json"


def run_json(argv: list[str]) -> Any:
    proc = subprocess.run(argv, check=True, text=True, stdout=subprocess.PIPE)
    return json.loads(proc.stdout)


def which(name: str) -> str | None:
    for directory in os.environ.get("PATH", "").split(os.pathsep):
        candidate = Path(directory) / name
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


def sessionwiki_rows(limit: int) -> list[dict[str, Any]]:
    subprocess.run(["sessionwiki", "sync"], check=True, stdout=subprocess.DEVNULL)
    rows = run_json(["sessionwiki", "list", "-n", str(limit), "--json", "--no-sync"])
    if not isinstance(rows, list):
        raise RuntimeError("sessionwiki list --json did not return an array")
    return [row for row in rows if isinstance(row, dict)]


def session_envelope(host: str, row: dict[str, Any]) -> dict[str, Any]:
    session_id = str(row.get("id") or "")
    if not session_id:
        raise RuntimeError("SessionWiki row is missing id")
    session = run_json(["sessionwiki", "show", session_id, "--json", "--no-sync"])
    if not isinstance(session, dict):
        raise RuntimeError(f"sessionwiki show {session_id} --json did not return an object")

    # Send only what the mirror needs. In particular, keep SessionWiki's
    # absolute source path local to the machine that owns the native session.
    clean_session = {
        "id": session.get("id"),
        "tool": session.get("tool"),
        "project": session.get("project"),
        "started": session.get("started"),
        "ended": session.get("ended"),
        "title": session.get("title"),
        "subagent": bool(session.get("subagent", False)),
        "messages": session.get("messages") if isinstance(session.get("messages"), list) else [],
    }
    return {
        "schema": SCHEMA,
        "host": host,
        "native_id": row.get("native_id"),
        "session": clean_session,
    }


def cmd_push(args: argparse.Namespace) -> int:
    if not which("sessionwiki"):
        raise SystemExit("sessionwiki is not installed on this machine")

    host = args.host or socket.gethostname().split(".")[0]
    rows = sessionwiki_rows(args.limit)
    remote = [
        "ssh",
        "-A",
        "-o",
        "BatchMode=yes",
        args.server,
        "sudo",
        "open-webui-native-session-mirror",
        "ingest",
    ]
    proc = subprocess.Popen(remote, stdin=subprocess.PIPE, text=True)
    assert proc.stdin is not None
    sent = 0
    try:
        for row in rows:
            if row.get("kind") not in (None, "main"):
                continue
            try:
                envelope = session_envelope(host, row)
            except Exception as exc:
                # One corrupt/pruned session should not block all other mirrors.
                print(f"skip {row.get('id', '?')}: {exc}", file=sys.stderr)
                continue
            proc.stdin.write(json.dumps(envelope, separators=(",", ":")) + "\n")
            proc.stdin.flush()
            sent += 1
    finally:
        proc.stdin.close()

    rc = proc.wait()
    if rc != 0:
        raise SystemExit(rc)
    print(f"Sent {sent} native session(s) from {host} for Open WebUI mirroring.")
    return 0


def read_env(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        result[key] = value
    return result


def api_json(base: str, path: str, *, token: str | None = None, payload: Any | None = None) -> Any:
    data = None if payload is None else json.dumps(payload, separators=(",", ":")).encode()
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(
        base.rstrip("/") + path,
        data=data,
        headers=headers,
        method="POST" if data is not None else "GET",
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        body = response.read()
    return json.loads(body) if body else None


def signin(base: str, env_path: Path) -> str:
    env = read_env(env_path)
    email = env.get("WEBUI_ADMIN_EMAIL")
    password = env.get("WEBUI_ADMIN_PASSWORD")
    if not email or not password:
        raise RuntimeError(f"{env_path} must contain WEBUI_ADMIN_EMAIL and WEBUI_ADMIN_PASSWORD")
    result = api_json(
        base,
        "/api/v1/auths/signin",
        payload={"email": email, "password": password},
    )
    token = result.get("token") if isinstance(result, dict) else None
    if not token:
        raise RuntimeError("Open WebUI signin did not return a token")
    return str(token)


def parse_time(value: Any, fallback: int) -> int:
    if not isinstance(value, str) or not value:
        return fallback
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
        return int(parsed.timestamp())
    except ValueError:
        return fallback


def stable_message_id(key: str, index: int) -> str:
    return hashlib.sha256(f"{key}:{index}".encode()).hexdigest()[:32]


def mirror_chat(
    envelope: dict[str, Any],
) -> tuple[str, dict[str, Any], dict[str, Any], int, int, str]:
    host = str(envelope.get("host") or "unknown")
    session = envelope.get("session")
    if not isinstance(session, dict):
        raise ValueError("envelope session must be an object")
    sid = str(session.get("id") or "")
    tool = str(session.get("tool") or "native")
    if not sid:
        raise ValueError("session id is missing")

    key = f"{host}:{sid}"
    title_raw = str(session.get("title") or "Native session").strip() or "Native session"
    title = f"[{tool} · {host}] {title_raw}"
    native_id = envelope.get("native_id")
    project = str(session.get("project") or "")

    source_note = (
        "This chat is an optional read-through mirror of a native coding-agent session. "
        f"Source host: {host}. Tool: {tool}. SessionWiki id: {sid}. "
        + (f"Native session id: {native_id}. " if native_id else "")
        + "Use SessionWiki/Computer on the source host to resume the native session. "
        "The mirror is convenience history; native session files remain the resume source."
    )

    source_messages = session.get("messages") if isinstance(session.get("messages"), list) else []
    messages: list[dict[str, Any]] = []
    history: dict[str, dict[str, Any]] = {}
    parent: str | None = None
    base_ts = parse_time(
        session.get("started"),
        int(dt.datetime.now(dt.timezone.utc).timestamp()),
    )

    normalized = [{"role": "system", "text": source_note, "ts": session.get("started")}] + source_messages
    for index, item in enumerate(normalized):
        if not isinstance(item, dict):
            continue
        role = str(item.get("role") or "assistant")
        text = str(item.get("text") or "")
        if role == "tool":
            role = "assistant"
            text = "[native tool output]\n\n" + text
        if role not in {"system", "user", "assistant"}:
            role = "assistant"

        message_id = stable_message_id(key, index)
        timestamp = parse_time(item.get("ts"), base_ts + index)
        message = {
            "id": message_id,
            "parentId": parent,
            "childrenIds": [],
            "role": role,
            "content": text,
            "timestamp": timestamp,
        }
        if parent is not None and parent in history:
            history[parent]["childrenIds"].append(message_id)
        history[message_id] = message
        messages.append(message)
        parent = message_id

    chat = {
        "title": title,
        "models": [],
        "messages": messages,
        "history": {"messages": history, "currentId": parent},
    }
    meta = {
        "native_session_mirror": {
            "schema": SCHEMA,
            "key": key,
            "host": host,
            "tool": tool,
            "sessionwiki_id": sid,
            "native_id": native_id,
            "project": project,
        }
    }
    created_at = parse_time(session.get("started"), base_ts)
    updated_at = parse_time(
        session.get("ended"),
        messages[-1]["timestamp"] if messages else created_at,
    )
    digest = hashlib.sha256(
        json.dumps(
            {"chat": chat, "meta": meta},
            sort_keys=True,
            separators=(",", ":"),
        ).encode()
    ).hexdigest()
    return key, chat, meta, created_at, updated_at, digest


def load_state(path: Path) -> dict[str, dict[str, str]]:
    if not path.exists():
        return {}
    try:
        raw = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError):
        return {}
    return raw if isinstance(raw, dict) else {}


def save_state(path: Path, state: dict[str, dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=path.name + ".", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as handle:
            json.dump(state, handle, indent=2, sort_keys=True)
            handle.write("\n")
        os.chmod(temp_name, 0o600)
        os.replace(temp_name, path)
    finally:
        if os.path.exists(temp_name):
            os.unlink(temp_name)


def import_chat(
    base: str,
    token: str,
    chat: dict[str, Any],
    meta: dict[str, Any],
    created_at: int,
    updated_at: int,
) -> str:
    current_id = chat.get("history", {}).get("currentId")
    payload = {
        "chats": [
            {
                "chat": chat,
                "meta": meta,
                "current_message_id": current_id,
                "created_at": created_at,
                "updated_at": updated_at,
            }
        ]
    }
    result = api_json(base, "/api/v1/chats/import", token=token, payload=payload)
    if not isinstance(result, list) or not result or not isinstance(result[0], dict) or not result[0].get("id"):
        raise RuntimeError("Open WebUI chat import returned an unexpected response")
    return str(result[0]["id"])


def cmd_ingest(args: argparse.Namespace) -> int:
    del args
    if os.geteuid() != 0:
        raise SystemExit("ingest must run as root on the Open WebUI server")

    base = os.environ.get("OPEN_WEBUI_URL", DEFAULT_OPEN_WEBUI_URL)
    env_path = Path(os.environ.get("OPEN_WEBUI_ENV", DEFAULT_OPEN_WEBUI_ENV))
    state_path = Path(os.environ.get("OPEN_WEBUI_NATIVE_MIRROR_STATE", DEFAULT_STATE))
    token = signin(base, env_path)
    state = load_state(state_path)
    imported = updated = skipped = 0

    for line in sys.stdin:
        if not line.strip():
            continue
        envelope = json.loads(line)
        if not isinstance(envelope, dict) or envelope.get("schema") != SCHEMA:
            raise RuntimeError("unsupported native-session mirror payload")

        key, chat, meta, created_at, updated_at, digest = mirror_chat(envelope)
        current = state.get(key) if isinstance(state.get(key), dict) else None
        if current and current.get("digest") == digest:
            skipped += 1
            continue

        chat_id = current.get("chat_id") if current else None
        if chat_id:
            try:
                api_json(
                    base,
                    f"/api/v1/chats/{chat_id}",
                    token=token,
                    payload={"chat": chat},
                )
                updated += 1
            except urllib.error.HTTPError as exc:
                if exc.code not in {401, 404}:
                    raise
                chat_id = import_chat(base, token, chat, meta, created_at, updated_at)
                imported += 1
        else:
            chat_id = import_chat(base, token, chat, meta, created_at, updated_at)
            imported += 1

        state[key] = {"chat_id": chat_id, "digest": digest}

    save_state(state_path, state)
    print(f"Native-session mirrors: {imported} imported, {updated} updated, {skipped} unchanged.")
    return 0


def parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    push = sub.add_parser(
        "push",
        help="push this machine's recent SessionWiki sessions to Open WebUI",
    )
    push.add_argument(
        "--server",
        default=DEFAULT_SERVER,
        help="SSH target for the Open WebUI server",
    )
    push.add_argument(
        "--host",
        help="stable source-host label (defaults to short hostname)",
    )
    push.add_argument(
        "--limit",
        type=int,
        default=100,
        help="number of recent top-level sessions to mirror",
    )
    push.set_defaults(func=cmd_push)

    ingest = sub.add_parser(
        "ingest",
        help="ingest newline-delimited mirror payloads on the Open WebUI server",
    )
    ingest.set_defaults(func=cmd_ingest)
    return parser


def main() -> int:
    args = parser().parse_args()
    if getattr(args, "limit", 1) < 1:
        raise SystemExit("--limit must be at least 1")
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())

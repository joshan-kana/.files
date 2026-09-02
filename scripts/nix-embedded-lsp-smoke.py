#!/usr/bin/env python3
"""Protocol smoke test for the editor-facing nix-embedded-lsp."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path
from typing import Any


class LspClient:
    def __init__(self, command: str, cwd: Path) -> None:
        self.proc = subprocess.Popen(
            [command],
            cwd=cwd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        assert self.proc.stdin is not None
        assert self.proc.stdout is not None
        assert self.proc.stderr is not None
        self.stdin = self.proc.stdin
        self.stdout = self.proc.stdout
        self.next_id = 1
        self.responses: dict[int, dict[str, Any]] = {}
        self.notifications: list[dict[str, Any]] = []
        self.condition = threading.Condition()
        self.write_lock = threading.Lock()
        self.workspace_folders = [{"uri": cwd.resolve().as_uri(), "name": cwd.name}]
        self.server_requests: list[str] = []
        self.stderr: list[str] = []
        threading.Thread(target=self._read_stdout, daemon=True).start()
        threading.Thread(target=self._read_stderr, daemon=True).start()

    def _read_frame(self) -> dict[str, Any] | None:
        headers: dict[str, str] = {}
        while True:
            line = self.stdout.readline()
            if not line:
                return None
            if line in (b"\r\n", b"\n"):
                break
            key, value = line.decode("ascii").split(":", 1)
            headers[key.lower()] = value.strip()
        length = int(headers.get("content-length", "0"))
        if length <= 0:
            return None
        return json.loads(self.stdout.read(length))

    def _read_stdout(self) -> None:
        while (message := self._read_frame()) is not None:
            if "id" in message and "method" in message:
                self._respond_to_server_request(message)
                continue
            with self.condition:
                if "id" in message:
                    self.responses[int(message["id"])] = message
                else:
                    self.notifications.append(message)
                self.condition.notify_all()

    def _respond_to_server_request(self, message: dict[str, Any]) -> None:
        method = str(message["method"])
        params = message.get("params") or {}
        self.server_requests.append(method)
        if method == "workspace/configuration":
            result: Any = [None for _ in params.get("items", [])]
        elif method == "workspace/workspaceFolders":
            result = self.workspace_folders
        elif method == "workspace/applyEdit":
            result = {"applied": False}
        else:
            # Registration, refresh and progress-creation requests all use a
            # null result. Recording the method keeps unexpected requests visible
            # in timeout diagnostics without deadlocking the downstream server.
            result = None
        self.send({"jsonrpc": "2.0", "id": message["id"], "result": result})

    def _read_stderr(self) -> None:
        assert self.proc.stderr is not None
        for line in self.proc.stderr:
            self.stderr.append(line.decode(errors="replace").rstrip())

    def send(self, message: dict[str, Any]) -> None:
        payload = json.dumps(message, separators=(",", ":")).encode()
        frame = f"Content-Length: {len(payload)}\r\n\r\n".encode() + payload
        with self.write_lock:
            self.stdin.write(frame)
            self.stdin.flush()

    def notify(self, method: str, params: dict[str, Any] | None = None) -> None:
        message: dict[str, Any] = {"jsonrpc": "2.0", "method": method}
        if params is not None:
            message["params"] = params
        self.send(message)

    def request(self, method: str, params: dict[str, Any] | None = None, timeout: float = 30) -> Any:
        request_id = self.next_id
        self.next_id += 1
        message: dict[str, Any] = {"jsonrpc": "2.0", "id": request_id, "method": method}
        if params is not None:
            message["params"] = params
        self.send(message)
        deadline = time.monotonic() + timeout
        with self.condition:
            while request_id not in self.responses:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    tail = "\n".join(self.stderr[-30:])
                    requests = ", ".join(self.server_requests[-20:])
                    raise RuntimeError(f"timed out waiting for {method}; server requests=[{requests}]\n{tail}")
                self.condition.wait(remaining)
            response = self.responses.pop(request_id)
        if "error" in response:
            raise RuntimeError(f"{method}: {response['error']}")
        return response.get("result")

    def close(self) -> None:
        try:
            self.request("shutdown", timeout=5)
            self.notify("exit")
        finally:
            try:
                self.proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait()
        if self.proc.returncode not in (0, None):
            tail = "\n".join(self.stderr[-30:])
            raise RuntimeError(f"LSP exited {self.proc.returncode}\n{tail}")


def position(
    lines: list[str],
    needle: str,
    *,
    after: bool = False,
    offset: int = 0,
    occurrence: int = 1,
) -> dict[str, int]:
    remaining = occurrence
    for line, text in enumerate(lines):
        start = 0
        while (column := text.find(needle, start)) >= 0:
            remaining -= 1
            if remaining == 0:
                if after:
                    column += len(needle)
                column += offset
                return {"line": line, "character": column}
            start = column + len(needle)
    raise RuntimeError(f"fixture is missing occurrence {occurrence} of {needle!r}")


def decode_semantic_tokens(data: list[int], token_types: list[str]) -> list[tuple[int, int, int, str]]:
    decoded: list[tuple[int, int, int, str]] = []
    line = 0
    column = 0
    for offset in range(0, len(data), 5):
        delta_line, delta_column, length, token_type, _modifiers = data[offset : offset + 5]
        if delta_line:
            line += delta_line
            column = delta_column
        else:
            column += delta_column
        name = token_types[token_type] if token_type < len(token_types) else str(token_type)
        decoded.append((line, column, length, name))
    return decoded


def completion_labels(result: Any) -> set[str]:
    if isinstance(result, dict):
        items = result.get("items") or []
    else:
        items = result or []
    return {str(item.get("label")) for item in items if isinstance(item, dict)}


def wait_for_completion(
    client: LspClient,
    params: dict[str, Any],
    expected: set[str],
    description: str,
    timeout: float = 15.0,
) -> set[str]:
    deadline = time.monotonic() + timeout
    labels: set[str] = set()
    while time.monotonic() < deadline:
        labels = completion_labels(client.request("textDocument/completion", params))
        if expected & labels or any(label.startswith(f"{candidate}(") for label in labels for candidate in expected):
            return labels
        time.sleep(0.05)
    sample = sorted(labels)[:25]
    stderr_tail = "\n".join(client.stderr[-30:])
    raise RuntimeError(f"{description}; sample={sample}\n{stderr_tail}")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: nix-embedded-lsp-smoke.py /path/to/nix-embedded-lsp")
    command = os.path.abspath(sys.argv[1])
    fixture = """{
  ordinary = let nixdCompletionTarget = 1; in nixdCompletionTar;
  python = /* python */ ''
    import pathlib
    path = pathlib.Path("/tmp")
    path.
    interpolated = ${
      let interpolationCompletionTarget = 1;
      in interpolationCompletionTar
    }
  '';
  bash = /* bash */ ''
    smoke_bash_target=1
    echo "$smoke_bash_tar"
    echo "''${HOME}"
  '';
  lua = /* lua */ ''
    local text = "hello"
    string.
  '';
  javascript = /* js */ ''
    Math.
  '';
}
"""
    lines = fixture.splitlines()

    with tempfile.TemporaryDirectory(prefix="nix-embedded-kakehashi-") as temp:
        root = Path(temp)
        path = root / "fixture.nix"
        path.write_text(fixture)
        uri = path.resolve().as_uri()
        client = LspClient(command, root)
        try:
            init = client.request(
                "initialize",
                {
                    "processId": os.getpid(),
                    "rootUri": root.resolve().as_uri(),
                    "workspaceFolders": [{"uri": root.resolve().as_uri(), "name": root.name}],
                    "capabilities": {
                        "general": {"positionEncodings": ["utf-16"]},
                        "workspace": {"configuration": True, "workspaceFolders": True},
                        "textDocument": {
                            "completion": {"completionItem": {"snippetSupport": True}},
                            "hover": {"contentFormat": ["markdown", "plaintext"]},
                            "semanticTokens": {
                                "requests": {"full": True},
                                "tokenTypes": [
                                    "namespace",
                                    "type",
                                    "class",
                                    "enum",
                                    "interface",
                                    "struct",
                                    "typeParameter",
                                    "parameter",
                                    "variable",
                                    "property",
                                    "enumMember",
                                    "event",
                                    "function",
                                    "method",
                                    "macro",
                                    "keyword",
                                    "modifier",
                                    "comment",
                                    "string",
                                    "number",
                                    "regexp",
                                    "operator",
                                    "decorator",
                                ],
                                "tokenModifiers": [],
                                "formats": ["relative"],
                            },
                        },
                    },
                    "clientInfo": {"name": "nix-embedded-smoke", "version": "1"},
                },
            )
            capabilities = (init or {}).get("capabilities") or {}
            semantic_provider = capabilities.get("semanticTokensProvider")
            if not isinstance(semantic_provider, dict):
                raise RuntimeError("kakehashi did not advertise semantic tokens")
            semantic_types = list((semantic_provider.get("legend") or {}).get("tokenTypes") or [])
            client.notify("initialized", {})
            client.notify(
                "textDocument/didOpen",
                {
                    "textDocument": {
                        "uri": uri,
                        "languageId": "nix",
                        "version": 1,
                        "text": fixture,
                    }
                },
            )

            captures = client.request(
                "kakehashi/captures/full",
                {"textDocument": {"uri": uri}, "kind": "injections"},
            )
            injected_languages = {
                str((match.get("metadata") or {}).get("injection.language"))
                for match in (captures or {}).get("matches", [])
                if isinstance(match, dict)
            }
            expected_injections = {"python", "bash", "lua", "javascript"}
            if not expected_injections <= injected_languages:
                raise RuntimeError(
                    f"generated injection query missed languages: expected={sorted(expected_injections)} got={sorted(injected_languages)}"
                )

            wait_for_completion(
                client,
                {
                    "textDocument": {"uri": uri},
                    "position": position(lines, "nixdCompletionTar", after=True, occurrence=2),
                    "context": {"triggerKind": 1},
                },
                {"nixdCompletionTarget"},
                "normal Nix completion did not fall through to nixd",
            )

            wait_for_completion(
                client,
                {
                    "textDocument": {"uri": uri},
                    "position": position(lines, "path.", after=True),
                    "context": {"triggerKind": 1},
                },
                {"exists", "read_text", "write_text"},
                "embedded Python completion did not reach basedpyright",
            )

            wait_for_completion(
                client,
                {
                    "textDocument": {"uri": uri},
                    "position": position(lines, "interpolationCompletionTar", after=True, occurrence=2),
                    "context": {"triggerKind": 1},
                },
                {"interpolationCompletionTarget"},
                "multiline Nix interpolation inside Python did not fall through to nixd",
            )

            wait_for_completion(
                client,
                {
                    "textDocument": {"uri": uri},
                    "position": position(lines, "$smoke_bash_tar", after=True),
                    "context": {"triggerKind": 1},
                },
                {"smoke_bash_target"},
                "embedded Bash completion did not reach bash-language-server",
            )

            wait_for_completion(
                client,
                {
                    "textDocument": {"uri": uri},
                    "position": position(lines, "string.", after=True),
                    "context": {"triggerKind": 1},
                },
                {"len", "upper", "lower", "sub"},
                "embedded Lua completion did not reach lua-language-server",
            )

            wait_for_completion(
                client,
                {
                    "textDocument": {"uri": uri},
                    "position": position(lines, "Math.", after=True),
                    "context": {"triggerKind": 1},
                },
                {"abs", "floor", "max", "round"},
                "embedded JavaScript completion did not reach typescript-language-server",
            )

            tokens = client.request("textDocument/semanticTokens/full", {"textDocument": {"uri": uri}})
            if not isinstance(tokens, dict) or not tokens.get("data"):
                raise RuntimeError("Tree-sitter semantic-token smoke test returned no tokens")
            decoded = decode_semantic_tokens(tokens["data"], semantic_types)
            lua_line = position(lines, "string.")["line"]
            javascript_line = position(lines, "Math.")["line"]
            if not any(
                line == lua_line and column >= 4 and kind in {"keyword", "variable", "function", "method"}
                for line, column, _length, kind in decoded
            ):
                raise RuntimeError("semantic-token smoke test did not highlight embedded Lua")
            if not any(
                line == javascript_line and column >= 4 and kind in {"variable", "property", "function", "method"}
                for line, column, _length, kind in decoded
            ):
                raise RuntimeError("semantic-token smoke test did not highlight embedded JavaScript")
        finally:
            client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

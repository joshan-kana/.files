#!/usr/bin/env python3
"""Editor-agnostic LSP bridge for languages embedded in annotated Nix strings."""

from __future__ import annotations

import argparse
import asyncio
import importlib.util
import json
import os
import sys
import tempfile
import urllib.parse
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Awaitable, Callable, Mapping

CORE_PATH = Path(__file__).with_name("nix-embedded.py")
_spec = importlib.util.spec_from_file_location("nix_embedded_core", CORE_PATH)
if _spec is None or _spec.loader is None:
    raise RuntimeError(f"cannot load {CORE_PATH}")
core = importlib.util.module_from_spec(_spec)
sys.modules[_spec.name] = core
_spec.loader.exec_module(core)

AST_GREP = os.environ.get("NIX_EMBEDDED_AST_GREP", "ast-grep")
NIXFMT = os.environ.get("NIX_EMBEDDED_NIXFMT", "nixfmt")

Json = dict[str, Any]


def log(message: str) -> None:
    print(f"nix-embedded-lsp: {message}", file=sys.stderr, flush=True)


def utf16_len(text: str) -> int:
    return len(text.encode("utf-16-le")) // 2


def utf16_to_char(text: str, column: int) -> int:
    if column <= 0:
        return 0
    units = 0
    for index, char in enumerate(text):
        width = utf16_len(char)
        if units + width > column:
            return index
        units += width
        if units == column:
            return index + 1
    return len(text)


def position_to_char(text: str, position: Mapping[str, int]) -> int:
    line = int(position["line"])
    column = int(position["character"])
    lines = text.splitlines(keepends=True)
    if line >= len(lines):
        return len(text)
    prefix = sum(len(item) for item in lines[:line])
    body = lines[line].rstrip("\r\n")
    return prefix + utf16_to_char(body, column)


def position_to_byte(text: str, position: Mapping[str, int]) -> int:
    return len(text[: position_to_char(text, position)].encode("utf-8"))


def byte_to_position(data: bytes, offset: int) -> Json:
    prefix = data[:offset].decode("utf-8")
    line_text = prefix.rsplit("\n", 1)[-1]
    return {"line": prefix.count("\n"), "character": utf16_len(line_text)}


def file_uri(path: Path) -> str:
    return path.resolve().as_uri()


def uri_path(uri: str) -> Path | None:
    parsed = urllib.parse.urlparse(uri)
    if parsed.scheme != "file":
        return None
    return Path(urllib.parse.unquote(parsed.path))


def read_frame_sync(stream: Any) -> Json | None:
    headers: dict[str, str] = {}
    while True:
        line = stream.readline()
        if not line:
            return None
        if line in (b"\r\n", b"\n"):
            break
        key, value = line.decode("ascii").split(":", 1)
        headers[key.lower()] = value.strip()
    length = int(headers.get("content-length", "0"))
    if length <= 0:
        return None
    payload = stream.read(length)
    if len(payload) != length:
        return None
    return json.loads(payload)


def encode_frame(message: Mapping[str, Any]) -> bytes:
    payload = json.dumps(message, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    return f"Content-Length: {len(payload)}\r\n\r\n".encode("ascii") + payload


async def read_async_frame(stream: asyncio.StreamReader) -> Json | None:
    headers: dict[str, str] = {}
    while True:
        line = await stream.readline()
        if not line:
            return None
        if line in (b"\r\n", b"\n"):
            break
        key, value = line.decode("ascii").split(":", 1)
        headers[key.lower()] = value.strip()
    length = int(headers.get("content-length", "0"))
    if length <= 0:
        return None
    payload = await stream.readexactly(length)
    return json.loads(payload)


@dataclass(frozen=True)
class BackendSpec:
    name: str
    command: tuple[str, ...]
    features: frozenset[str]


SEMANTIC_FEATURES = frozenset(
    {
        "textDocument/completion",
        "textDocument/hover",
        "textDocument/signatureHelp",
        "textDocument/definition",
        "textDocument/declaration",
        "textDocument/typeDefinition",
        "textDocument/implementation",
        "textDocument/references",
        "textDocument/documentHighlight",
        "textDocument/prepareRename",
        "textDocument/rename",
        "textDocument/documentSymbol",
        "textDocument/inlayHint",
    }
)

FEATURE_GROUPS: dict[str, frozenset[str]] = {
    "semantic": SEMANTIC_FEATURES,
    "hover": frozenset({"textDocument/hover"}),
    "codeAction": frozenset({"textDocument/codeAction"}),
}


def backend_features(groups: object) -> frozenset[str]:
    if not isinstance(groups, list):
        return frozenset()
    features: set[str] = set()
    for group in groups:
        if not isinstance(group, str) or group not in FEATURE_GROUPS:
            raise RuntimeError(f"unknown embedded LSP feature group {group!r}")
        features.update(FEATURE_GROUPS[group])
    return frozenset(features)


def language_backends(spec: Mapping[str, Any]) -> tuple[BackendSpec, ...]:
    raw = spec.get("lsp")
    if not isinstance(raw, list):
        return ()
    result: list[BackendSpec] = []
    for backend in raw:
        if not isinstance(backend, dict):
            raise RuntimeError("invalid embedded LSP backend entry")
        command = backend.get("command")
        name = backend.get("name")
        if not isinstance(name, str) or not isinstance(command, list) or not all(isinstance(item, str) for item in command):
            raise RuntimeError(f"invalid embedded LSP backend {backend!r}")
        result.append(BackendSpec(name, tuple(command), backend_features(backend.get("features"))))
    return tuple(result)


BACKEND_SPECS: dict[str, tuple[BackendSpec, ...]] = {
    language: backends for language, spec in core.LANGUAGES.items() if (backends := language_backends(spec))
}
LANGUAGE_IDS = {language: str(core.LANGUAGES[language]["languageId"]) for language in BACKEND_SPECS}
EXTENSIONS = {language: str(core.LANGUAGES[language]["extension"]) for language in BACKEND_SPECS}


def ast_nodes_text(text: str) -> list[Any]:
    nodes: list[Any] = []
    for kind in core.AST_KINDS:
        proc = core.run(
            [
                AST_GREP,
                "run",
                "--stdin",
                "--lang",
                "Nix",
                "--kind",
                kind,
                "--json=compact",
            ],
            stdin=text,
            ok=(0, 1),
        )
        if not proc.stdout.strip():
            continue
        rows = json.loads(proc.stdout)
        for row in rows:
            range_ = row["range"]
            byte_range = range_["byteOffset"]
            nodes.append(
                core.Node(
                    start=int(byte_range["start"]),
                    end=int(byte_range["end"]),
                    line=int(range_["start"]["line"]),
                    column=int(range_["start"]["column"]),
                    text=row["text"],
                )
            )
    nodes.sort(key=lambda node: (node.start, node.end))
    return nodes


@dataclass
class VirtualDocument:
    host_uri: str
    uri: str
    language: str
    index: int
    block: Any
    text: str
    prefix_lines: int
    content_start: Json
    content_end: Json
    version: int

    def contains(self, host_text: str, position: Mapping[str, int]) -> bool:
        offset = position_to_byte(host_text, position)
        return self.block.content_start <= offset <= self.block.content_end

    def host_to_virtual(self, position: Mapping[str, int]) -> Json | None:
        line = int(position["line"])
        col = int(position["character"])
        start_line = int(self.content_start["line"])
        end_line = int(self.content_end["line"])
        if line < start_line or line > end_line:
            return None
        rel = line - start_line
        if rel == 0:
            col -= int(self.content_start["character"])
        if col < 0:
            return None
        return {"line": rel + self.prefix_lines, "character": col}

    def virtual_to_host(self, position: Mapping[str, int]) -> Json | None:
        line = int(position["line"]) - self.prefix_lines
        col = int(position["character"])
        if line < 0:
            return None
        host_line = int(self.content_start["line"]) + line
        if host_line > int(self.content_end["line"]):
            return None
        if line == 0:
            col += int(self.content_start["character"])
        return {"line": host_line, "character": col}

    def host_range_to_virtual(self, range_: Mapping[str, Any]) -> Json | None:
        start = self.host_to_virtual(range_["start"])
        end = self.host_to_virtual(range_["end"])
        if start is None or end is None:
            return None
        return {"start": start, "end": end}

    def virtual_range_to_host(self, range_: Mapping[str, Any]) -> Json | None:
        start = self.virtual_to_host(range_["start"])
        end = self.virtual_to_host(range_["end"])
        if start is None or end is None:
            return None
        return {"start": start, "end": end}


def virtual_uri(host_uri: str, language: str, index: int) -> str:
    path = uri_path(host_uri)
    extension = EXTENSIONS[language]
    if path is not None:
        return file_uri(path.with_name(f".{path.name}.nix-embedded-{index}.{extension}"))
    escaped = urllib.parse.quote(host_uri, safe="")
    return f"file:///tmp/nix-embedded/{escaped}-{index}.{extension}"


def build_virtuals(host_uri: str, text: str, version: int) -> list[VirtualDocument]:
    del host_uri, text, version
    raise core.ToolError("evaluated Nix source-map layer is not installed")


class Backend:
    def __init__(
        self,
        spec: BackendSpec,
        root_uri: str | None,
        workspace_folders: list[Json],
        diagnostics: Callable[[str, str, Json], Awaitable[None]],
    ) -> None:
        self.spec = spec
        self.root_uri = root_uri
        self.workspace_folders = workspace_folders
        self.diagnostics = diagnostics
        self.process: asyncio.subprocess.Process | None = None
        self.pending: dict[int, asyncio.Future[Any]] = {}
        self.next_id = 1
        self.write_lock = asyncio.Lock()
        self.reader_task: asyncio.Task[None] | None = None
        self.stderr_task: asyncio.Task[None] | None = None
        self.capabilities: Json = {}
        self.commands: set[str] = set()
        # Virtual documents are opened lazily. Starting every language server
        # during the host document's didOpen scales terribly as the registry grows.
        self.documents: dict[str, int] = {}

    async def start(self) -> None:
        if self.process is not None:
            return
        self.process = await asyncio.create_subprocess_exec(
            *self.spec.command,
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        self.reader_task = asyncio.create_task(self._reader())
        self.stderr_task = asyncio.create_task(self._stderr())
        result = await self.request(
            "initialize",
            {
                "processId": os.getpid(),
                "rootUri": self.root_uri,
                "workspaceFolders": self.workspace_folders or None,
                "capabilities": {
                    "workspace": {
                        "configuration": True,
                        "workspaceFolders": True,
                        "didChangeWatchedFiles": {"dynamicRegistration": True},
                    },
                    "textDocument": {
                        "completion": {
                            "completionItem": {
                                "snippetSupport": True,
                                "documentationFormat": ["markdown", "plaintext"],
                                "resolveSupport": {
                                    "properties": [
                                        "documentation",
                                        "detail",
                                        "additionalTextEdits",
                                    ]
                                },
                            }
                        },
                        "hover": {"contentFormat": ["markdown", "plaintext"]},
                        "signatureHelp": {
                            "signatureInformation": {
                                "documentationFormat": ["markdown", "plaintext"],
                                "parameterInformation": {"labelOffsetSupport": True},
                            }
                        },
                        "definition": {"linkSupport": True},
                        "declaration": {"linkSupport": True},
                        "typeDefinition": {"linkSupport": True},
                        "implementation": {"linkSupport": True},
                        "codeAction": {
                            "codeActionLiteralSupport": {
                                "codeActionKind": {
                                    "valueSet": [
                                        "",
                                        "quickfix",
                                        "refactor",
                                        "refactor.extract",
                                        "refactor.inline",
                                        "refactor.rewrite",
                                        "source",
                                        "source.organizeImports",
                                        "source.fixAll",
                                    ]
                                }
                            },
                            "resolveSupport": {"properties": ["edit"]},
                        },
                        "rename": {"prepareSupport": True},
                        "inlayHint": {"dynamicRegistration": False},
                    },
                },
                "initializationOptions": {},
                "clientInfo": {"name": "nix-embedded-lsp", "version": "0.1"},
            },
        )
        if isinstance(result, dict):
            self.capabilities = result.get("capabilities") or {}
            execute = self.capabilities.get("executeCommandProvider") or {}
            self.commands = set(execute.get("commands") or [])
        await self.notify("initialized", {})

    async def _stderr(self) -> None:
        assert self.process is not None and self.process.stderr is not None
        while True:
            line = await self.process.stderr.readline()
            if not line:
                return
            log(f"[{self.spec.name}] {line.decode(errors='replace').rstrip()}")

    async def _reader(self) -> None:
        assert self.process is not None and self.process.stdout is not None
        try:
            while True:
                message = await read_async_frame(self.process.stdout)
                if message is None:
                    return
                if "id" in message and "method" not in message:
                    future = self.pending.pop(int(message["id"]), None)
                    if future is not None and not future.done():
                        if "error" in message:
                            future.set_exception(core.ToolError(f"{self.spec.name}: {message['error']}"))
                        else:
                            future.set_result(message.get("result"))
                    continue
                method = message.get("method")
                if method == "textDocument/publishDiagnostics":
                    params = message.get("params") or {}
                    await self.diagnostics(self.spec.name, params.get("uri", ""), params)
                    continue
                if "id" in message and method:
                    await self._answer_server_request(message)
        except (asyncio.IncompleteReadError, BrokenPipeError):
            return
        except Exception as exc:
            log(f"{self.spec.name} reader failed: {exc}")
            for future in self.pending.values():
                if not future.done():
                    future.set_exception(exc)
            self.pending.clear()

    async def _answer_server_request(self, message: Json) -> None:
        method = message["method"]
        params = message.get("params") or {}
        result: Any = None
        if method == "workspace/configuration":
            result = [{} for _ in params.get("items", [])]
        elif method == "workspace/workspaceFolders":
            result = self.workspace_folders or None
        elif method == "workspace/applyEdit":
            result = {
                "applied": False,
                "failureReason": "edits must flow through nix-embedded-lsp",
            }
        await self._write({"jsonrpc": "2.0", "id": message["id"], "result": result})

    async def _write(self, message: Json) -> None:
        assert self.process is not None and self.process.stdin is not None
        async with self.write_lock:
            self.process.stdin.write(encode_frame(message))
            await self.process.stdin.drain()

    async def request(self, method: str, params: Json | None = None, timeout: float = 15.0) -> Any:
        if self.process is None and method != "initialize":
            await self.start()
        request_id = self.next_id
        self.next_id += 1
        future: asyncio.Future[Any] = asyncio.get_running_loop().create_future()
        self.pending[request_id] = future
        message: Json = {"jsonrpc": "2.0", "id": request_id, "method": method}
        if params is not None:
            message["params"] = params
        await self._write(message)
        try:
            return await asyncio.wait_for(future, timeout)
        finally:
            self.pending.pop(request_id, None)

    async def notify(self, method: str, params: Json | None = None) -> None:
        if self.process is None:
            await self.start()
        message: Json = {"jsonrpc": "2.0", "method": method}
        if params is not None:
            message["params"] = params
        await self._write(message)

    async def stop(self) -> None:
        if self.process is None:
            return
        try:
            await self.request("shutdown", timeout=3)
            await self.notify("exit")
        except Exception:
            pass
        if self.process.returncode is None:
            self.process.terminate()
            try:
                await asyncio.wait_for(self.process.wait(), 2)
            except asyncio.TimeoutError:
                self.process.kill()
        self.process = None


@dataclass
class HostDocument:
    uri: str
    text: str
    version: int
    virtuals: list[VirtualDocument] = field(default_factory=list)
    diagnostics: dict[tuple[str, str], list[Json]] = field(default_factory=dict)

    def virtual_at(self, position: Mapping[str, int]) -> VirtualDocument | None:
        for virtual in self.virtuals:
            if virtual.contains(self.text, position):
                return virtual
        return None

    def by_uri(self, uri: str) -> VirtualDocument | None:
        return next((item for item in self.virtuals if item.uri == uri), None)


def map_range_to_host(virtual: VirtualDocument, range_: Mapping[str, Any]) -> Json | None:
    return virtual.virtual_range_to_host(range_)


def map_diagnostic_to_host(virtual: VirtualDocument, diagnostic: Mapping[str, Any], backend: str) -> Json | None:
    range_ = map_range_to_host(virtual, diagnostic["range"])
    if range_ is None:
        return None
    result = dict(diagnostic)
    result["range"] = range_
    source = result.get("source") or backend
    result["source"] = f"{source} · embedded {virtual.language}"
    return result


def map_location_to_host(virtual: VirtualDocument, value: Mapping[str, Any]) -> Json | None:
    uri = value.get("uri")
    if uri != virtual.uri:
        return dict(value)
    range_ = map_range_to_host(virtual, value["range"])
    if range_ is None:
        return None
    result = dict(value)
    result["uri"] = virtual.host_uri
    result["range"] = range_
    return result


def map_location_link_to_host(virtual: VirtualDocument, value: Mapping[str, Any]) -> Json | None:
    result = dict(value)
    if "originSelectionRange" in result:
        mapped = map_range_to_host(virtual, result["originSelectionRange"])
        if mapped is None:
            return None
        result["originSelectionRange"] = mapped
    if result.get("targetUri") == virtual.uri:
        result["targetUri"] = virtual.host_uri
        for key in ("targetRange", "targetSelectionRange"):
            mapped = map_range_to_host(virtual, result[key])
            if mapped is None:
                return None
            result[key] = mapped
    return result


def map_text_edit_to_host(virtual: VirtualDocument, edit: Mapping[str, Any]) -> Json | None:
    result = dict(edit)
    if "range" in result:
        mapped = map_range_to_host(virtual, result["range"])
        if mapped is None:
            return None
        result["range"] = mapped
    else:
        for key in ("insert", "replace"):
            if key in result:
                mapped = map_range_to_host(virtual, result[key])
                if mapped is None:
                    return None
                result[key] = mapped
    return result


def map_workspace_edit_to_host(virtual: VirtualDocument, edit: Mapping[str, Any]) -> Json:
    result = dict(edit)
    if "changes" in result:
        changes: dict[str, list[Json]] = {}
        for uri, edits in (result.get("changes") or {}).items():
            if uri == virtual.uri:
                mapped = [item for raw in edits if (item := map_text_edit_to_host(virtual, raw)) is not None]
                changes.setdefault(virtual.host_uri, []).extend(mapped)
            else:
                changes[uri] = list(edits)
        result["changes"] = changes
    if "documentChanges" in result:
        changes: list[Json] = []
        for raw in result.get("documentChanges") or []:
            if "textDocument" not in raw:
                if raw.get("uri") == virtual.uri or raw.get("oldUri") == virtual.uri:
                    continue
                changes.append(dict(raw))
                continue
            item = dict(raw)
            document = dict(item["textDocument"])
            if document.get("uri") == virtual.uri:
                document["uri"] = virtual.host_uri
                item["textDocument"] = document
                item["edits"] = [
                    mapped for edit_ in item.get("edits") or [] if (mapped := map_text_edit_to_host(virtual, edit_)) is not None
                ]
            changes.append(item)
        result["documentChanges"] = changes
    return result


def map_result_to_host(method: str, virtual: VirtualDocument, result: Any, backend: str) -> Any:
    if result is None:
        return None
    if method in {
        "textDocument/definition",
        "textDocument/declaration",
        "textDocument/typeDefinition",
        "textDocument/implementation",
        "textDocument/references",
    }:
        values = result if isinstance(result, list) else [result]
        mapped: list[Json] = []
        for value in values:
            if "targetUri" in value:
                item = map_location_link_to_host(virtual, value)
            else:
                item = map_location_to_host(virtual, value)
            if item is not None:
                mapped.append(item)
        return mapped if isinstance(result, list) else (mapped[0] if mapped else None)

    if method == "textDocument/hover":
        value = dict(result)
        if value.get("range") is not None:
            value["range"] = map_range_to_host(virtual, value["range"])
        return value

    if method == "textDocument/documentHighlight":
        mapped = []
        for value in result or []:
            item = dict(value)
            range_ = map_range_to_host(virtual, item["range"])
            if range_ is not None:
                item["range"] = range_
                mapped.append(item)
        return mapped

    if method == "textDocument/rename":
        return map_workspace_edit_to_host(virtual, result)

    if method == "textDocument/prepareRename":
        if isinstance(result, dict) and "range" in result:
            value = dict(result)
            value["range"] = map_range_to_host(virtual, value["range"])
            return value
        return result

    if method == "textDocument/completion":
        container = dict(result) if isinstance(result, dict) else None
        items = container.get("items", []) if container is not None else list(result or [])
        mapped_items: list[Json] = []
        for raw in items:
            item = dict(raw)
            if item.get("textEdit") is not None:
                item["textEdit"] = map_text_edit_to_host(virtual, item["textEdit"])
            item["additionalTextEdits"] = [
                edit_ for value in item.get("additionalTextEdits") or [] if (edit_ := map_text_edit_to_host(virtual, value)) is not None
            ]
            item["data"] = {
                "__nixEmbedded": {
                    "backend": backend,
                    "virtualUri": virtual.uri,
                    "original": item.get("data"),
                }
            }
            mapped_items.append(item)
        if container is not None:
            container["items"] = mapped_items
            return container
        return mapped_items

    if method == "textDocument/codeAction":
        mapped: list[Json] = []
        for raw in result or []:
            item = dict(raw)
            if item.get("edit") is not None:
                item["edit"] = map_workspace_edit_to_host(virtual, item["edit"])
            item["diagnostics"] = [
                diag for value in item.get("diagnostics") or [] if (diag := map_diagnostic_to_host(virtual, value, backend)) is not None
            ]
            item["data"] = {
                "__nixEmbedded": {
                    "backend": backend,
                    "virtualUri": virtual.uri,
                    "original": item.get("data"),
                }
            }
            mapped.append(item)
        return mapped

    if method == "textDocument/inlayHint":
        mapped = []
        for raw in result or []:
            item = dict(raw)
            position = virtual.virtual_to_host(item["position"])
            if position is None:
                continue
            item["position"] = position
            if item.get("textEdits"):
                item["textEdits"] = [edit_ for value in item["textEdits"] if (edit_ := map_text_edit_to_host(virtual, value)) is not None]
            mapped.append(item)
        return mapped

    if method == "textDocument/documentSymbol":

        def convert(symbol: Mapping[str, Any]) -> Json | None:
            item = dict(symbol)
            for key in ("range", "selectionRange"):
                if key in item:
                    mapped_range = map_range_to_host(virtual, item[key])
                    if mapped_range is None:
                        return None
                    item[key] = mapped_range
            if "location" in item:
                location = map_location_to_host(virtual, item["location"])
                if location is None:
                    return None
                item["location"] = location
            if item.get("children"):
                item["children"] = [child for value in item["children"] if (child := convert(value)) is not None]
            return item

        return [item for value in result or [] if (item := convert(value)) is not None]

    return result


def request_params_for_virtual(method: str, virtual: VirtualDocument, params: Mapping[str, Any]) -> Json | None:
    result = dict(params)
    result["textDocument"] = {"uri": virtual.uri}
    if "position" in result:
        position = virtual.host_to_virtual(result["position"])
        if position is None:
            return None
        result["position"] = position
    if "range" in result:
        range_ = virtual.host_range_to_virtual(result["range"])
        if range_ is None:
            return None
        result["range"] = range_
    if method == "textDocument/codeAction":
        context = dict(result.get("context") or {})
        diagnostics = []
        for raw in context.get("diagnostics") or []:
            diag = dict(raw)
            mapped = virtual.host_range_to_virtual(diag["range"])
            if mapped is not None:
                diag["range"] = mapped
                diagnostics.append(diag)
        context["diagnostics"] = diagnostics
        result["context"] = context
    return result


class Bridge:
    def __init__(self) -> None:
        self.documents: dict[str, HostDocument] = {}
        self.backends: dict[str, Backend] = {}
        self.root_uri: str | None = None
        self.workspace_folders: list[Json] = []
        self.shutdown = False
        self.output_lock = asyncio.Lock()

    async def write(self, message: Json) -> None:
        payload = encode_frame(message)
        async with self.output_lock:
            await asyncio.to_thread(sys.stdout.buffer.write, payload)
            await asyncio.to_thread(sys.stdout.buffer.flush)

    async def respond(self, request_id: Any, result: Any = None, error: Json | None = None) -> None:
        message: Json = {"jsonrpc": "2.0", "id": request_id}
        if error is not None:
            message["error"] = error
        else:
            message["result"] = result
        await self.write(message)

    async def notify(self, method: str, params: Json) -> None:
        await self.write({"jsonrpc": "2.0", "method": method, "params": params})

    async def backend(self, spec: BackendSpec) -> Backend:
        backend = self.backends.get(spec.name)
        if backend is None:
            backend = Backend(
                spec,
                self.root_uri,
                self.workspace_folders,
                self.on_backend_diagnostics,
            )
            self.backends[spec.name] = backend
            await backend.start()
        return backend

    async def ensure_backend_document(
        self,
        spec: BackendSpec,
        virtual: VirtualDocument,
    ) -> Backend:
        backend = await self.backend(spec)
        previous_version = backend.documents.get(virtual.uri)
        if previous_version is None:
            await backend.notify(
                "textDocument/didOpen",
                {
                    "textDocument": {
                        "uri": virtual.uri,
                        "languageId": LANGUAGE_IDS[virtual.language],
                        "version": virtual.version,
                        "text": virtual.text,
                    }
                },
            )
            backend.documents[virtual.uri] = virtual.version
        elif previous_version != virtual.version:
            await backend.notify(
                "textDocument/didChange",
                {
                    "textDocument": {"uri": virtual.uri, "version": virtual.version},
                    "contentChanges": [{"text": virtual.text}],
                },
            )
            backend.documents[virtual.uri] = virtual.version
        return backend

    async def on_backend_diagnostics(self, backend: str, virtual_uri_: str, params: Json) -> None:
        for document in self.documents.values():
            virtual = document.by_uri(virtual_uri_)
            if virtual is None:
                continue
            mapped = [
                diag for value in params.get("diagnostics") or [] if (diag := map_diagnostic_to_host(virtual, value, backend)) is not None
            ]
            document.diagnostics[(backend, virtual_uri_)] = mapped
            await self.notify(
                "textDocument/publishDiagnostics",
                {
                    "uri": document.uri,
                    "version": document.version,
                    "diagnostics": [value for values in document.diagnostics.values() for value in values],
                },
            )
            return

    async def sync_document(self, document: HostDocument, old: list[VirtualDocument]) -> None:
        old_by_uri = {item.uri: item for item in old}
        new_by_uri = {item.uri: item for item in document.virtuals}

        # Only synchronize backends that were already demanded by an editor
        # request. Merely discovering a Lua/Rust/Go/etc block must not spawn its
        # language server during textDocument/didOpen.
        for uri, virtual in old_by_uri.items():
            if uri in new_by_uri:
                continue
            for spec in BACKEND_SPECS[virtual.language]:
                backend = self.backends.get(spec.name)
                if backend is not None and uri in backend.documents:
                    await backend.notify("textDocument/didClose", {"textDocument": {"uri": uri}})
                    backend.documents.pop(uri, None)
            for key in list(document.diagnostics):
                if key[1] == uri:
                    del document.diagnostics[key]

        for uri, virtual in new_by_uri.items():
            previous = old_by_uri.get(uri)
            for spec in BACKEND_SPECS[virtual.language]:
                backend = self.backends.get(spec.name)
                if backend is None or uri not in backend.documents:
                    continue
                if previous is not None and previous.language == virtual.language:
                    await backend.notify(
                        "textDocument/didChange",
                        {
                            "textDocument": {"uri": uri, "version": virtual.version},
                            "contentChanges": [{"text": virtual.text}],
                        },
                    )
                    backend.documents[uri] = virtual.version
                else:
                    await backend.notify("textDocument/didClose", {"textDocument": {"uri": uri}})
                    backend.documents.pop(uri, None)
                    await self.ensure_backend_document(spec, virtual)

        await self.notify(
            "textDocument/publishDiagnostics",
            {
                "uri": document.uri,
                "version": document.version,
                "diagnostics": [value for values in document.diagnostics.values() for value in values],
            },
        )

    async def did_open(self, params: Json) -> None:
        item = params["textDocument"]
        document = HostDocument(item["uri"], item["text"], int(item.get("version", 0)))
        try:
            document.virtuals = build_virtuals(document.uri, document.text, document.version)
        except Exception as exc:
            log(f"parse failed for {document.uri}: {exc}")
            document.virtuals = []
        self.documents[document.uri] = document
        await self.sync_document(document, [])

    async def did_change(self, params: Json) -> None:
        uri = params["textDocument"]["uri"]
        document = self.documents.get(uri)
        if document is None:
            return
        changes = params.get("contentChanges") or []
        if not changes:
            return
        text = changes[-1].get("text")
        if text is None:
            return
        old = document.virtuals
        document.text = text
        document.version = int(params["textDocument"].get("version", document.version + 1))
        try:
            document.virtuals = build_virtuals(uri, text, document.version)
        except Exception as exc:
            log(f"parse failed for {uri}: {exc}")
            document.virtuals = []
        await self.sync_document(document, old)

    async def did_close(self, params: Json) -> None:
        uri = params["textDocument"]["uri"]
        document = self.documents.pop(uri, None)
        if document is None:
            return
        for virtual in document.virtuals:
            for spec in BACKEND_SPECS[virtual.language]:
                backend = self.backends.get(spec.name)
                if backend is not None and virtual.uri in backend.documents:
                    await backend.notify("textDocument/didClose", {"textDocument": {"uri": virtual.uri}})
                    backend.documents.pop(virtual.uri, None)
        await self.notify("textDocument/publishDiagnostics", {"uri": uri, "diagnostics": []})

    async def request_feature(self, method: str, params: Json) -> Any:
        uri = params.get("textDocument", {}).get("uri")
        document = self.documents.get(uri)
        if document is None:
            return None

        virtual: VirtualDocument | None = None
        if params.get("position") is not None:
            virtual = document.virtual_at(params["position"])
        elif params.get("range") is not None:
            virtual = document.virtual_at(params["range"]["start"])
        if virtual is None:
            return None

        request_params = request_params_for_virtual(method, virtual, params)
        if request_params is None:
            return None

        combined: list[Any] = []
        for spec in BACKEND_SPECS[virtual.language]:
            if method not in spec.features:
                continue
            backend = await self.ensure_backend_document(spec, virtual)
            try:
                raw = await backend.request(method, request_params)
            except Exception as exc:
                log(f"{spec.name} {method} failed: {exc}")
                continue
            mapped = map_result_to_host(method, virtual, raw, spec.name)
            if method == "textDocument/codeAction":
                if isinstance(mapped, list):
                    combined.extend(mapped)
                continue
            if mapped not in (None, [], {"items": []}):
                return mapped
        if method == "textDocument/codeAction":
            return combined
        if method in {
            "textDocument/completion",
            "textDocument/references",
            "textDocument/documentHighlight",
            "textDocument/inlayHint",
        }:
            return []
        return None

    async def document_symbols(self, params: Json) -> list[Json]:
        uri = params.get("textDocument", {}).get("uri")
        document = self.documents.get(uri)
        if document is None:
            return []
        result: list[Json] = []
        for virtual in document.virtuals:
            for spec in BACKEND_SPECS[virtual.language]:
                if "textDocument/documentSymbol" not in spec.features:
                    continue
                backend = await self.ensure_backend_document(spec, virtual)
                raw = await backend.request("textDocument/documentSymbol", {"textDocument": {"uri": virtual.uri}})
                mapped = map_result_to_host("textDocument/documentSymbol", virtual, raw, spec.name)
                if mapped:
                    result.extend(mapped)
                break
        return result

    async def formatting(self, params: Json) -> list[Json]:
        uri = params.get("textDocument", {}).get("uri")
        document = self.documents.get(uri)
        path = uri_path(uri or "")
        if document is None or path is None:
            return []
        original = document.text
        with tempfile.NamedTemporaryFile(
            mode="w",
            suffix=".nix",
            prefix=f".{path.stem}.nix-embedded-",
            dir=path.parent,
            delete=False,
        ) as handle:
            temp_path = Path(handle.name)
            handle.write(original)
        try:
            core.run([NIXFMT, str(temp_path)], cwd=path.parent)
            core.format_files([temp_path])
            core.run([NIXFMT, str(temp_path)], cwd=path.parent)
            formatted = temp_path.read_text()
        finally:
            temp_path.unlink(missing_ok=True)
        if formatted == original:
            return []
        lines = original.split("\n")
        end = {"line": len(lines) - 1, "character": utf16_len(lines[-1])}
        return [
            {
                "range": {"start": {"line": 0, "character": 0}, "end": end},
                "newText": formatted,
            }
        ]

    async def resolve_item(self, method: str, item: Json) -> Any:
        marker = (item.get("data") or {}).get("__nixEmbedded")
        if not marker:
            return item
        backend = self.backends.get(marker["backend"])
        if backend is None:
            return item
        virtual: VirtualDocument | None = None
        for document in self.documents.values():
            virtual = document.by_uri(marker["virtualUri"])
            if virtual is not None:
                break
        if virtual is None:
            return item
        document = next((doc for doc in self.documents.values() if doc.by_uri(virtual.uri) is virtual), None)
        if document is not None:
            await self.ensure_backend_document(backend.spec, virtual)
        forwarded = dict(item)
        forwarded["data"] = marker.get("original")
        raw = await backend.request(method, forwarded)
        parent_method = "textDocument/completion" if method == "completionItem/resolve" else "textDocument/codeAction"
        mapped = map_result_to_host(parent_method, virtual, [raw], backend.spec.name)
        return mapped[0] if mapped else item

    async def execute_command(self, params: Json) -> Any:
        command = params.get("command")
        for backend in self.backends.values():
            if command in backend.commands:
                return await backend.request("workspace/executeCommand", params)
        return None

    async def handle_request(self, message: Json) -> None:
        request_id = message["id"]
        method = message.get("method", "")
        params = message.get("params") or {}
        try:
            if method == "initialize":
                self.root_uri = params.get("rootUri")
                self.workspace_folders = params.get("workspaceFolders") or []
                result = {
                    "capabilities": {
                        "textDocumentSync": 1,
                        "completionProvider": {
                            "resolveProvider": True,
                            "triggerCharacters": [".", "/", "$", "{", "(", "[", '"', "'"],
                        },
                        "hoverProvider": True,
                        "signatureHelpProvider": {"triggerCharacters": ["(", ","]},
                        "definitionProvider": True,
                        "declarationProvider": True,
                        "typeDefinitionProvider": True,
                        "implementationProvider": True,
                        "referencesProvider": True,
                        "documentHighlightProvider": True,
                        "renameProvider": {"prepareProvider": True},
                        "documentSymbolProvider": True,
                        "codeActionProvider": {"resolveProvider": True},
                        "inlayHintProvider": True,
                        "documentFormattingProvider": True,
                        "executeCommandProvider": {"commands": []},
                    },
                    "serverInfo": {"name": "nix-embedded-lsp", "version": "0.1"},
                }
            elif method == "shutdown":
                self.shutdown = True
                result = None
            elif method == "textDocument/formatting":
                result = await self.formatting(params)
            elif method == "textDocument/documentSymbol":
                result = await self.document_symbols(params)
            elif method == "completionItem/resolve":
                result = await self.resolve_item(method, params)
            elif method == "codeAction/resolve":
                result = await self.resolve_item(method, params)
            elif method == "workspace/executeCommand":
                result = await self.execute_command(params)
            elif method.startswith("textDocument/"):
                result = await self.request_feature(method, params)
            else:
                result = None
            await self.respond(request_id, result)
        except Exception as exc:
            log(f"{method} failed: {exc}")
            await self.respond(request_id, error={"code": -32603, "message": str(exc)})

    async def handle_notification(self, message: Json) -> None:
        method = message.get("method", "")
        params = message.get("params") or {}
        if method == "initialized":
            return
        if method == "textDocument/didOpen":
            await self.did_open(params)
        elif method == "textDocument/didChange":
            await self.did_change(params)
        elif method == "textDocument/didClose":
            await self.did_close(params)
        elif method == "exit":
            self.shutdown = True

    async def run(self) -> None:
        tasks: set[asyncio.Task[None]] = set()
        while not self.shutdown:
            message = await asyncio.to_thread(read_frame_sync, sys.stdin.buffer)
            if message is None:
                break
            if "id" in message:
                task = asyncio.create_task(self.handle_request(message))
                tasks.add(task)
                task.add_done_callback(tasks.discard)
            else:
                await self.handle_notification(message)
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)
        await asyncio.gather(
            *(backend.stop() for backend in self.backends.values()),
            return_exceptions=True,
        )


async def self_test() -> None:
    fixture = """{
  python = /* python */ ''
    import pathlib
    import os

    path = pathlib.Path("/tmp")
    path.
  '';
  bash = /* bash */ ''
    echo "$HOME"
  '';
}
"""
    with tempfile.TemporaryDirectory(prefix="nix-embedded-lsp-") as temp:
        root = Path(temp)
        host = root / "fixture.nix"
        host.write_text(fixture)
        virtuals = build_virtuals(file_uri(host), fixture, 1)
        if [item.language for item in virtuals] != ["python", "bash"]:
            raise core.ToolError("LSP self-test did not discover Python and Bash blocks")
        if "lua" not in BACKEND_SPECS:
            raise core.ToolError("LSP self-test registry is missing Lua support")

        python_virtual = virtuals[0]
        cursor_line = fixture.splitlines().index("    path.")
        host_position = {"line": cursor_line, "character": utf16_len("    path.")}
        virtual_position = python_virtual.host_to_virtual(host_position)
        if virtual_position is None:
            raise core.ToolError("LSP self-test position mapping failed")

        diagnostics_seen = asyncio.Event()

        async def diagnostics(backend: str, uri: str, params: Json) -> None:
            if backend == "ruff" and uri == python_virtual.uri and params.get("diagnostics"):
                diagnostics_seen.set()

        folders = [{"uri": file_uri(root), "name": root.name}]
        pyright = Backend(BACKEND_SPECS["python"][0], file_uri(root), folders, diagnostics)
        ruff = Backend(BACKEND_SPECS["python"][1], file_uri(root), folders, diagnostics)
        bash = Backend(BACKEND_SPECS["bash"][0], file_uri(root), folders, diagnostics)
        try:
            for backend in (pyright, ruff, bash):
                await backend.start()

            for backend in (pyright, ruff):
                await backend.notify(
                    "textDocument/didOpen",
                    {
                        "textDocument": {
                            "uri": python_virtual.uri,
                            "languageId": "python",
                            "version": 1,
                            "text": python_virtual.text,
                        }
                    },
                )
            bash_virtual = virtuals[1]
            await bash.notify(
                "textDocument/didOpen",
                {
                    "textDocument": {
                        "uri": bash_virtual.uri,
                        "languageId": "shellscript",
                        "version": 1,
                        "text": bash_virtual.text,
                    }
                },
            )

            completion = await pyright.request(
                "textDocument/completion",
                {
                    "textDocument": {"uri": python_virtual.uri},
                    "position": virtual_position,
                    "context": {"triggerKind": 1},
                },
            )
            items = completion.get("items", []) if isinstance(completion, dict) else completion or []
            labels = {item.get("label") for item in items}
            if not ({"exists", "read_text", "write_text"} & labels):
                raise core.ToolError(f"basedpyright completion smoke test failed; labels sample={list(labels)[:20]!r}")
            await asyncio.wait_for(diagnostics_seen.wait(), timeout=10)
        finally:
            await asyncio.gather(pyright.stop(), ruff.stop(), bash.stop(), return_exceptions=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    try:
        if args.self_test:
            asyncio.run(self_test())
        else:
            asyncio.run(Bridge().run())
    except (core.ToolError, OSError, asyncio.TimeoutError) as exc:
        log(str(exc))
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

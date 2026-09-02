#!/usr/bin/env python3
"""Native formatting and linting for explicitly annotated Nix indented strings."""

from __future__ import annotations

import argparse
import bisect
import difflib
import fnmatch
import json
import os
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Sequence

AST_GREP = os.environ.get("NIX_EMBEDDED_AST_GREP", "ast-grep")
NIX_INSTANTIATE = os.environ.get("NIX_EMBEDDED_NIX_INSTANTIATE", "nix-instantiate")
RUFF = os.environ.get("NIX_EMBEDDED_RUFF", "ruff")
SHELLCHECK = os.environ.get("NIX_EMBEDDED_SHELLCHECK", "shellcheck")

ANNOTATION = re.compile(r"^/\*\s*([A-Za-z0-9_+.-]+)\s*\*/$")
REGISTRY_PATH = Path(
    os.environ.get(
        "NIX_EMBEDDED_LANGUAGE_REGISTRY",
        Path(__file__).with_name("nix-embedded-languages.json"),
    )
)
try:
    LANGUAGES: dict[str, dict[str, object]] = json.loads(REGISTRY_PATH.read_text())
except (OSError, json.JSONDecodeError) as exc:
    raise RuntimeError(f"cannot load embedded-language registry {REGISTRY_PATH}: {exc}") from exc
LANGUAGE_ALIASES = {alias.lower(): language for language, spec in LANGUAGES.items() for alias in spec.get("aliases", [])}
AST_KINDS = ("comment", "indented_string_expression", "interpolation")


class ToolError(RuntimeError):
    pass


def boundary_maps(source: str, target: str) -> tuple[list[int], list[int]]:
    """Map every character boundary between raw and transformed text."""
    source_to_target: list[int | None] = [None] * (len(source) + 1)
    target_to_source: list[int | None] = [None] * (len(target) + 1)
    matcher = difflib.SequenceMatcher(a=source, b=target, autojunk=False)

    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        source_len = i2 - i1
        target_len = j2 - j1
        if tag == "equal":
            for offset in range(source_len + 1):
                source_to_target[i1 + offset] = j1 + offset
                target_to_source[j1 + offset] = i1 + offset
            continue

        for offset in range(source_len + 1):
            ratio = 0.0 if source_len == 0 else offset / source_len
            source_to_target[i1 + offset] = j1 + round(ratio * target_len)
        for offset in range(target_len + 1):
            ratio = 0.0 if target_len == 0 else offset / target_len
            target_to_source[j1 + offset] = i1 + round(ratio * source_len)

    def finish(values: list[int | None]) -> list[int]:
        previous = 0
        for index, value in enumerate(values):
            if value is None:
                values[index] = previous
            else:
                previous = value
        return [int(value or 0) for value in values]

    return finish(source_to_target), finish(target_to_source)


@dataclass(frozen=True)
class Node:
    start: int
    end: int
    line: int
    column: int
    text: str


@dataclass(frozen=True)
class Block:
    language: str
    start: int
    end: int
    content_start: int
    content_end: int
    line: int
    column: int
    interpolations: tuple[Node, ...]


@dataclass(frozen=True)
class Prepared:
    code: str
    placeholders: tuple[tuple[str, str], ...]
    placeholder_ranges: tuple[tuple[int, int], ...]
    raw_content: str
    evaluated_to_raw: tuple[int, ...]


def run(
    argv: Sequence[str],
    *,
    stdin: str | None = None,
    cwd: Path | None = None,
    ok: tuple[int, ...] = (0,),
) -> subprocess.CompletedProcess[str]:
    proc = subprocess.run(
        list(argv),
        input=stdin,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        cwd=cwd,
        check=False,
    )
    if proc.returncode not in ok:
        detail = proc.stderr.strip() or proc.stdout.strip() or f"exit status {proc.returncode}"
        raise ToolError(f"{' '.join(argv)}: {detail}")
    return proc


def ast_nodes(files: Sequence[Path]) -> dict[Path, list[Node]]:
    """Parse Nix with ast-grep once per batch and return the three node kinds we need."""
    result: dict[Path, list[Node]] = {path.resolve(): [] for path in files}
    for offset in range(0, len(files), 128):
        batch = [path.resolve() for path in files[offset : offset + 128]]
        for kind in AST_KINDS:
            proc = run(
                [AST_GREP, "run", "--lang", "Nix", "--kind", kind, "--json=compact", *map(str, batch)],
                ok=(0, 1),
            )
            if not proc.stdout.strip():
                continue
            try:
                rows = json.loads(proc.stdout)
            except json.JSONDecodeError as exc:
                raise ToolError(f"invalid ast-grep JSON for {kind}: {exc}") from exc
            for row in rows:
                path = Path(row["file"]).resolve()
                range_ = row["range"]
                byte_range = range_["byteOffset"]
                result.setdefault(path, []).append(
                    Node(
                        start=int(byte_range["start"]),
                        end=int(byte_range["end"]),
                        line=int(range_["start"]["line"]),
                        column=int(range_["start"]["column"]),
                        text=row["text"],
                    )
                )
    for nodes in result.values():
        nodes.sort(key=lambda node: (node.start, node.end))
    return result


def blocks_for(path: Path, data: bytes, nodes: Sequence[Node]) -> list[Block]:
    comments = [node for node in nodes if node.text.startswith(("#", "/*"))]
    strings = [node for node in nodes if node.text.startswith("''")]
    interpolations = [node for node in nodes if node.text.startswith("${")]
    starts = [node.start for node in strings]
    blocks: list[Block] = []
    used: set[tuple[int, int]] = set()

    for comment in comments:
        annotation = ANNOTATION.fullmatch(comment.text.strip())
        if not annotation:
            continue
        language = LANGUAGE_ALIASES.get(annotation.group(1).lower())
        if language is None:
            continue
        index = bisect.bisect_left(starts, comment.end)
        if index == len(strings):
            continue
        string = strings[index]
        if data[comment.end : string.start].strip() or (string.start, string.end) in used:
            continue
        raw = data[string.start : string.end]
        if not (raw.startswith(b"''") and raw.endswith(b"''")):
            raise ToolError(f"{path}:{string.line + 1}: unexpected Nix indented-string AST range")
        content_start, content_end = string.start + 2, string.end - 2
        blocks.append(
            Block(
                language=language,
                start=string.start,
                end=string.end,
                content_start=content_start,
                content_end=content_end,
                line=string.line,
                column=string.column,
                interpolations=tuple(node for node in interpolations if content_start <= node.start and node.end <= content_end),
            )
        )
        used.add((string.start, string.end))
    return blocks


def unique_placeholder(index: int, occupied: str) -> str:
    stem = f"__NIX_EMBEDDED_INTERP_{index}__"
    candidate = stem
    suffix = 0
    while candidate in occupied:
        suffix += 1
        candidate = f"{stem}_{suffix}"
    return candidate


def prepare(block: Block, data: bytes) -> Prepared:
    """Replace Nix interpolations, then let Nix itself decode indentation and escapes."""
    expression = data[block.start : block.end]
    occupied = expression.decode("utf-8")
    replacements: list[tuple[int, int, str, str]] = []
    for index, interpolation in enumerate(block.interpolations):
        placeholder = unique_placeholder(index, occupied)
        raw = data[interpolation.start : interpolation.end].decode("utf-8")
        replacements.append((interpolation.start - block.start, interpolation.end - block.start, placeholder, raw))
        occupied += placeholder

    masked = expression
    for start, end, placeholder, _ in sorted(replacements, reverse=True):
        masked = masked[:start] + placeholder.encode() + masked[end:]

    evaluated = run(
        [NIX_INSTANTIATE, "--eval", "--strict", "--json", "--expr", masked.decode()],
    ).stdout
    try:
        code = json.loads(evaluated)
    except json.JSONDecodeError as exc:
        raise ToolError(f"nix-instantiate returned invalid JSON: {exc}") from exc
    if not isinstance(code, str):
        raise ToolError("nix-instantiate did not evaluate the embedded string to a string")

    placeholders = tuple((placeholder, raw) for _, _, placeholder, raw in replacements)
    placeholder_ranges: list[tuple[int, int]] = []
    for placeholder, _ in placeholders:
        start = code.find(placeholder)
        if start < 0 or code.find(placeholder, start + 1) >= 0:
            raise ToolError(f"Nix evaluation lost or duplicated interpolation placeholder {placeholder}")
        placeholder_ranges.append((start, start + len(placeholder)))

    raw_content = data[block.content_start : block.content_end].decode("utf-8")
    masked_content = masked[2:-2].decode("utf-8")
    _, masked_to_raw = boundary_maps(raw_content, masked_content)
    _, evaluated_to_masked = boundary_maps(masked_content, code)
    evaluated_to_raw = tuple(masked_to_raw[index] for index in evaluated_to_masked)
    return Prepared(
        code=code,
        placeholders=placeholders,
        placeholder_ranges=tuple(placeholder_ranges),
        raw_content=raw_content,
        evaluated_to_raw=evaluated_to_raw,
    )


def encode_indented_string(code: str) -> str:
    """Encode literal ${ and '' while leaving ordinary shell/Python syntax untouched."""
    out: list[str] = []
    index = 0
    while index < len(code):
        if code.startswith("''", index):
            out.append("'''")
            index += 2
        elif code.startswith("${", index):
            out.append("''${")
            index += 2
        else:
            out.append(code[index])
            index += 1
    return "".join(out)


def closing_indent(block: Block, data: bytes) -> str:
    line_start = data.rfind(b"\n", 0, block.content_end) + 1
    prefix = data[line_start : block.content_end].decode("utf-8")
    if not prefix.strip():
        return prefix
    return " " * block.column


def render(block: Block, prepared: Prepared, formatted: str, data: bytes) -> bytes:
    encoded = encode_indented_string(formatted)
    for placeholder, interpolation in prepared.placeholders:
        if encoded.count(placeholder) != 1:
            raise ToolError(f"native formatter changed interpolation placeholder {placeholder}")
        encoded = encoded.replace(placeholder, interpolation)

    indent = closing_indent(block, data)
    body_indent = indent + "  "
    lines = encoded.rstrip("\n").split("\n") if encoded else []
    body = "\n".join(body_indent + line if line else "" for line in lines)
    rendered = "\n" + body
    if body:
        rendered += "\n"
    rendered += indent
    return rendered.encode("utf-8")


def ruff_builtins(placeholders: Iterable[tuple[str, str]]) -> str | None:
    names = [name for name, _ in placeholders]
    if not names:
        return None
    return "builtins = [" + ", ".join(json.dumps(name) for name in names) + "]"


def format_code(language: str, prepared: Prepared, path: Path) -> str:
    spec = LANGUAGES[language]
    formatter = spec.get("formatter")
    if not isinstance(formatter, dict):
        return prepared.code

    kind = formatter.get("kind")
    extension = str(spec["extension"])
    filename = f"{path.name}.embedded.{extension}"

    if kind == "ruff":
        argv = [RUFF, "format", "--stdin-filename", filename]
        if builtins := ruff_builtins(prepared.placeholders):
            argv += ["--config", builtins]
        return run([*argv, "-"], stdin=prepared.code, cwd=path.parent).stdout

    if kind == "prettier":
        return run(["prettier", "--stdin-filepath", filename], stdin=prepared.code, cwd=path.parent).stdout

    if kind == "clang-format":
        return run(["clang-format", "--assume-filename", filename], stdin=prepared.code, cwd=path.parent).stdout

    if kind == "command":
        command = formatter.get("command")
        if not isinstance(command, list) or not all(isinstance(item, str) for item in command):
            raise ToolError(f"invalid formatter command for {language}")
        return run(command, stdin=prepared.code, cwd=path.parent).stdout

    raise ToolError(f"unsupported formatter kind {kind!r} for {language}")


def line_column_to_char(text: str, row: int, column: int) -> int:
    """Convert 1-based tool coordinates to a character boundary."""
    lines = text.splitlines(keepends=True)
    if row <= 0:
        return 0
    if row > len(lines):
        return len(text)
    prefix = sum(len(line) for line in lines[: row - 1])
    body = lines[row - 1].rstrip("\r\n")
    return prefix + max(0, min(column - 1, len(body)))


def source_position(block: Block, prepared: Prepared, data: bytes, row: int, column: int) -> tuple[int, int]:
    evaluated_index = line_column_to_char(prepared.code, row, column)
    evaluated_index = min(evaluated_index, len(prepared.evaluated_to_raw) - 1)
    raw_index = prepared.evaluated_to_raw[evaluated_index]
    host_prefix = data[: block.content_start].decode("utf-8") + prepared.raw_content[:raw_index]
    line_text = host_prefix.rsplit("\n", 1)[-1]
    return host_prefix.count("\n") + 1, len(line_text) + 1


def diagnostic_hits_placeholder(
    prepared: Prepared,
    row: int,
    column: int,
    end_row: int | None = None,
    end_column: int | None = None,
) -> bool:
    start = line_column_to_char(prepared.code, row, column)
    end = line_column_to_char(prepared.code, end_row, end_column) if end_row is not None and end_column is not None else start + 1
    if start == end:
        return any(left <= start < right for left, right in prepared.placeholder_ranges)
    return any(start < right and end > left for left, right in prepared.placeholder_ranges)


def lint_code(language: str, prepared: Prepared, path: Path, block: Block, data: bytes) -> list[str]:
    linter = LANGUAGES[language].get("linter")
    if linter is None:
        return []

    if linter == "shellcheck":
        proc = run(
            [SHELLCHECK, "--format=json", "--shell=bash", "-"],
            stdin=prepared.code,
            cwd=path.parent,
            ok=(0, 1),
        )
        rows = json.loads(proc.stdout or "[]")
        diagnostics = []
        for row in rows:
            native_line = int(row["line"])
            native_column = int(row["column"])
            end_line = int(row.get("endLine", native_line))
            end_column = int(row.get("endColumn", native_column + 1))
            if diagnostic_hits_placeholder(prepared, native_line, native_column, end_line, end_column):
                continue
            line, column = source_position(block, prepared, data, native_line, native_column)
            diagnostics.append(f"{path}:{line}:{column}: {row.get('level', 'warning')} SC{row['code']}: {row['message']}")
        return diagnostics

    if linter == "ruff":
        extension = str(LANGUAGES[language]["extension"])
        argv = [RUFF, "check", "--output-format", "json", "--stdin-filename", f"{path.name}.embedded.{extension}"]
        if builtins := ruff_builtins(prepared.placeholders):
            argv += ["--config", builtins]
        proc = run([*argv, "-"], stdin=prepared.code, cwd=path.parent, ok=(0, 1))
        rows = json.loads(proc.stdout or "[]")
        diagnostics = []
        for row in rows:
            location = row["location"]
            end_location = row.get("end_location") or location
            native_line = int(location["row"])
            native_column = int(location["column"])
            if diagnostic_hits_placeholder(
                prepared,
                native_line,
                native_column,
                int(end_location["row"]),
                int(end_location["column"]),
            ):
                continue
            line, column = source_position(block, prepared, data, native_line, native_column)
            diagnostics.append(f"{path}:{line}:{column}: {row.get('code') or 'Ruff'}: {row['message']}")
        return diagnostics

    raise ToolError(f"unsupported linter {linter!r} for {language}")


def validate_nix(path: Path) -> None:
    run([NIX_INSTANTIATE, "--parse", str(path)], cwd=path.parent)


def format_files(files: Sequence[Path]) -> None:
    parsed = ast_nodes(files)
    for path in files:
        original = path.read_bytes()
        replacements: list[tuple[int, int, bytes]] = []
        for block in blocks_for(path, original, parsed.get(path.resolve(), [])):
            if not isinstance(LANGUAGES[block.language].get("formatter"), dict):
                continue
            try:
                prepared = prepare(block, original)
                formatted = format_code(block.language, prepared, path)
                replacements.append((block.content_start, block.content_end, render(block, prepared, formatted, original)))
            except ToolError as exc:
                raise ToolError(f"{path}:{block.line + 1}: {block.language}: {exc}") from exc

        updated = original
        for start, end, replacement in sorted(replacements, reverse=True):
            updated = updated[:start] + replacement + updated[end:]
        if updated == original:
            continue
        path.write_bytes(updated)
        try:
            validate_nix(path)
        except Exception:
            path.write_bytes(original)
            raise


def lint_files(files: Sequence[Path]) -> list[str]:
    parsed = ast_nodes(files)
    diagnostics: list[str] = []
    for path in files:
        data = path.read_bytes()
        for block in blocks_for(path, data, parsed.get(path.resolve(), [])):
            if LANGUAGES[block.language].get("linter") is None:
                continue
            try:
                prepared = prepare(block, data)
                diagnostics.extend(lint_code(block.language, prepared, path, block, data))
            except (ToolError, json.JSONDecodeError) as exc:
                diagnostics.append(f"{path}:{block.line + 1}: error: {block.language}: {exc}")
    return diagnostics


def excluded(relative: Path, patterns: Sequence[str]) -> bool:
    value = relative.as_posix()
    return any(
        value == pattern.rstrip("/") or value.startswith(pattern.rstrip("/") + "/") or fnmatch.fnmatch(value, pattern)
        for pattern in patterns
    )


def collect(paths: Sequence[str], excludes: Sequence[str]) -> list[Path]:
    files: set[Path] = set()
    for raw in paths:
        path = Path(raw).resolve()
        if path.is_file():
            if path.suffix == ".nix":
                files.add(path)
            continue
        if not path.is_dir():
            raise ToolError(f"path does not exist: {raw}")
        for root, dirs, names in os.walk(path):
            root_path = Path(root)
            relative_root = root_path.relative_to(path)
            dirs[:] = [name for name in dirs if not excluded(relative_root / name, excludes)]
            for name in names:
                relative = relative_root / name
                if name.endswith(".nix") and not excluded(relative, excludes):
                    files.add(root_path / name)
    return sorted(files)


def self_test() -> None:
    fixture = """{\n  bash = /* bash */ ''\n    if [ \"$x\" = x ];then echo \"''${x}\";fi\n  '';\n  python = /* python */ ''\n    import os,sys\n    print(  ${builtins.toString 1} )\n  '';\n  lua = /* lua */ ''\n    local  x=1\n    print(x)\n  '';\n  ruby = /* ruby */ ''\n    puts \"hello\"\n\n\n  '';\n}\n"""
    with tempfile.TemporaryDirectory(prefix="nix-embedded-") as temp:
        path = Path(temp) / "fixture.nix"
        path.write_text(fixture)
        ruby_block = "  ruby = /* ruby */ ''\n    puts \"hello\"\n\n\n  '';"
        format_files([path])
        result = path.read_text()
        if ruby_block not in result:
            raise ToolError("self-test formatter changed a language without formatter support")
        expected = [
            'if [ "$x" = x ]; then',
            "import os, sys",
            "${builtins.toString 1}",
            "''${x}",
            "local x = 1",
        ]
        missing = [text for text in expected if text not in result]
        if missing:
            raise ToolError(f"self-test formatter failed; missing {missing!r}\n{result}")
        if not any("F401" in item for item in lint_files([path])):
            raise ToolError("self-test linter failed to report Ruff F401")

        lint_path = Path(temp) / "lint-map.nix"
        lint_path.write_text(
            "{\n  python = /* python */ ''\n    import os\n    ${\n      builtins.toString 1\n    }\n    import pathlib\n  '';\n}\n"
        )
        lint_diagnostics = lint_files([lint_path])
        mapped = [item for item in lint_diagnostics if "`pathlib` imported but unused" in item]
        if not mapped or f"{lint_path}:7:12:" not in mapped[0]:
            raise ToolError(f"self-test linter source mapping failed: {mapped!r}")
        if any("B018" in item for item in lint_diagnostics):
            raise ToolError(f"self-test linter leaked an interpolation placeholder diagnostic: {lint_diagnostics!r}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    fmt = commands.add_parser("format")
    fmt.add_argument("files", nargs="+")
    lint = commands.add_parser("lint")
    lint.add_argument("--exclude", action="append", default=[])
    lint.add_argument("paths", nargs="+")
    commands.add_parser("self-test")
    args = parser.parse_args()

    try:
        if args.command == "format":
            format_files([Path(item).resolve() for item in args.files if item.endswith(".nix")])
        elif args.command == "lint":
            diagnostics = lint_files(collect(args.paths, args.exclude))
            if diagnostics:
                print("\n".join(diagnostics), file=sys.stderr)
                return 1
        else:
            self_test()
    except ToolError as exc:
        print(f"nix-embedded: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

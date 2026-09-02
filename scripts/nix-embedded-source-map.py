#!/usr/bin/env python3
"""Exact-ish source maps between raw Nix indented strings and evaluated code."""

from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any, Mapping


def char_to_position(lsp: Any, text: str, index: int) -> dict[str, int]:
    prefix = text[: max(0, min(index, len(text)))]
    line_text = prefix.rsplit("\n", 1)[-1]
    return {"line": prefix.count("\n"), "character": lsp.utf16_len(line_text)}


def evaluate_masked(lsp: Any, block: Any, data: bytes) -> tuple[str, str, tuple[str, ...], str]:
    expression = data[block.start : block.end]
    original = data[block.content_start : block.content_end].decode("utf-8")
    occupied = expression.decode("utf-8")
    replacements: list[tuple[int, int, str]] = []
    placeholders: list[str] = []

    for index, interpolation in enumerate(block.interpolations):
        placeholder = lsp.core.unique_placeholder(index, occupied)
        occupied += placeholder
        placeholders.append(placeholder)
        replacements.append(
            (
                interpolation.start - block.start,
                interpolation.end - block.start,
                placeholder,
            )
        )

    masked_expression = expression
    for start, end, placeholder in sorted(replacements, reverse=True):
        masked_expression = masked_expression[:start] + placeholder.encode() + masked_expression[end:]

    masked = masked_expression[2:-2].decode("utf-8")
    evaluated = lsp.core.run(
        [
            lsp.core.NIX_INSTANTIATE,
            "--eval",
            "--strict",
            "--json",
            "--expr",
            masked_expression.decode("utf-8"),
        ]
    ).stdout
    try:
        code = json.loads(evaluated)
    except json.JSONDecodeError as exc:
        raise lsp.core.ToolError(f"nix-instantiate returned invalid JSON: {exc}") from exc
    if not isinstance(code, str):
        raise lsp.core.ToolError("Nix did not evaluate the embedded block to a string")
    return original, masked, tuple(placeholders), code


@dataclass
class MapData:
    host_text: str
    content_start_char: int
    raw_to_evaluated: list[int]
    evaluated_to_raw: list[int]
    raw_interpolation_ranges: tuple[tuple[int, int], ...]
    placeholder_ranges: tuple[tuple[int, int], ...]


def install(lsp: Any) -> None:
    base_virtual = lsp.VirtualDocument
    original_map_diagnostic = lsp.map_diagnostic_to_host
    original_map_text_edit = lsp.map_text_edit_to_host

    @dataclass
    class MappedVirtualDocument(base_virtual):
        source_map: MapData | None = None

        def host_to_virtual(self, position: Mapping[str, int]) -> dict[str, int] | None:
            if self.source_map is None:
                return super().host_to_virtual(position)
            host_index = lsp.position_to_char(self.source_map.host_text, position)
            raw_index = host_index - self.source_map.content_start_char
            if raw_index < 0 or raw_index >= len(self.source_map.raw_to_evaluated):
                return None
            if any(start <= raw_index < end for start, end in self.source_map.raw_interpolation_ranges):
                return None
            evaluated_index = self.source_map.raw_to_evaluated[raw_index]
            if self.in_placeholder(evaluated_index):
                return None
            return char_to_position(lsp, self.text, evaluated_index)

        def virtual_to_host(self, position: Mapping[str, int]) -> dict[str, int] | None:
            if self.source_map is None:
                return super().virtual_to_host(position)
            evaluated_index = lsp.position_to_char(self.text, position)
            if self.in_placeholder(evaluated_index):
                return None
            if evaluated_index < 0 or evaluated_index >= len(self.source_map.evaluated_to_raw):
                return None
            raw_index = self.source_map.evaluated_to_raw[evaluated_index]
            return char_to_position(
                lsp,
                self.source_map.host_text,
                self.source_map.content_start_char + raw_index,
            )

        def in_placeholder(self, index: int) -> bool:
            if self.source_map is None:
                return False
            return any(start <= index < end for start, end in self.source_map.placeholder_ranges)

        def range_hits_placeholder(self, range_: Mapping[str, Any]) -> bool:
            if self.source_map is None:
                return False
            start = lsp.position_to_char(self.text, range_["start"])
            end = lsp.position_to_char(self.text, range_["end"])
            if start == end:
                return any(left <= start < right for left, right in self.source_map.placeholder_ranges)
            return any(start < right and end > left for left, right in self.source_map.placeholder_ranges)

    def build_virtuals(host_uri: str, text: str, version: int) -> list[Any]:
        data = text.encode("utf-8")
        path = lsp.uri_path(host_uri) or lsp.Path("buffer.nix")
        blocks = lsp.core.blocks_for(path, data, lsp.ast_nodes_text(text))
        result: list[Any] = []

        for index, block in enumerate(blocks):
            language = block.language
            if language not in lsp.BACKEND_SPECS:
                continue
            original, masked, placeholders, evaluated = evaluate_masked(lsp, block, data)
            raw_to_masked, masked_to_raw = lsp.core.boundary_maps(original, masked)
            masked_to_evaluated, evaluated_to_masked = lsp.core.boundary_maps(masked, evaluated)
            raw_to_evaluated = [masked_to_evaluated[item] for item in raw_to_masked]
            evaluated_to_raw = [masked_to_raw[item] for item in evaluated_to_masked]

            placeholder_ranges: list[tuple[int, int]] = []
            for placeholder in placeholders:
                start = evaluated.find(placeholder)
                if start < 0 or evaluated.find(placeholder, start + 1) >= 0:
                    raise lsp.core.ToolError(f"embedded LSP lost or duplicated interpolation placeholder {placeholder}")
                placeholder_ranges.append((start, start + len(placeholder)))

            content_start_char = len(data[: block.content_start].decode("utf-8"))
            raw_interpolation_ranges = tuple(
                (
                    len(data[block.content_start : interpolation.start].decode("utf-8")),
                    len(data[block.content_start : interpolation.end].decode("utf-8")),
                )
                for interpolation in block.interpolations
            )
            result.append(
                MappedVirtualDocument(
                    host_uri=host_uri,
                    uri=lsp.virtual_uri(host_uri, language, index),
                    language=language,
                    index=index,
                    block=block,
                    text=evaluated,
                    prefix_lines=0,
                    content_start=lsp.byte_to_position(data, block.content_start),
                    content_end=lsp.byte_to_position(data, block.content_end),
                    version=version,
                    source_map=MapData(
                        host_text=text,
                        content_start_char=content_start_char,
                        raw_to_evaluated=raw_to_evaluated,
                        evaluated_to_raw=evaluated_to_raw,
                        raw_interpolation_ranges=raw_interpolation_ranges,
                        placeholder_ranges=tuple(placeholder_ranges),
                    ),
                )
            )
        return result

    def map_diagnostic(virtual: Any, diagnostic: Mapping[str, Any], backend: str) -> Any:
        if isinstance(virtual, MappedVirtualDocument) and virtual.range_hits_placeholder(diagnostic["range"]):
            return None
        return original_map_diagnostic(virtual, diagnostic, backend)

    def map_text_edit(virtual: Any, edit: Mapping[str, Any]) -> Any:
        ranges = []
        if "range" in edit:
            ranges.append(edit["range"])
        else:
            ranges.extend(edit[key] for key in ("insert", "replace") if key in edit)
        if isinstance(virtual, MappedVirtualDocument) and any(virtual.range_hits_placeholder(range_) for range_ in ranges):
            return None
        return original_map_text_edit(virtual, edit)

    lsp.VirtualDocument = MappedVirtualDocument
    lsp.build_virtuals = build_virtuals
    lsp.map_diagnostic_to_host = map_diagnostic
    lsp.map_text_edit_to_host = map_text_edit

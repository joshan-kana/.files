#!/usr/bin/env python3
"""Install evaluated-source mapping, then run the embedded-language specialist LSP."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path


def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


here = Path(__file__).parent
lsp = load("nix_embedded_lsp", here / "nix-embedded-lsp.py")
source_map = load("nix_embedded_source_map", here / "nix-embedded-source-map.py")
source_map.install(lsp)

raise SystemExit(lsp.main())

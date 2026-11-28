#!/usr/bin/env python3
"""Compile every fullscreen effect combination against the shared compositor."""

import importlib.util
import itertools
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHELL = ROOT / "modules/desktop/hyprland/shell"
MODULE = SHELL / "scripts/compose-screen-effects.py"
SPEC = importlib.util.spec_from_file_location("screen_compositor", MODULE)
compositor = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(compositor)

SCREEN_VALUES = {"intensity": 0.6, "shape": 0.5, "color": 0.5, "texture": 0.5, "lines": 0.5, "speed": 1, "artifacts": 0.2}
VHS_VALUES = {"vhsIntensity": 0.45, "vhsTracking": 1, "vhsChroma": 1, "vhsNoise": 1, "vhsScanlines": 1, "vhsSpeed": 1, "vhsDropouts": 0}
DEFAULTS = {
    "screen": {effect: SCREEN_VALUES for effect in compositor.ORDER if effect != "vhs"},
    "vhs": VHS_VALUES,
}
BOUNDS = {
    "screenEffectTuning": {key: {"min": 0.25 if key == "speed" else 0, "max": 2.5 if key == "speed" else 1} for key in SCREEN_VALUES},
    "vhs": {key: {"min": 0.25 if key == "vhsSpeed" else 0, "max": 2.5 if key == "vhsSpeed" else 1} for key in VHS_VALUES},
}
SOURCES = {name: SHELL / "shaders" / (name + ".frag") for name in compositor.ORDER}


def main():
    """Confirm all subsets generate valid shader code without dropping stages."""
    compiler = sys.argv[1] if len(sys.argv) > 1 else "glslangValidator"
    with tempfile.TemporaryDirectory() as folder:
        shader_file = Path(folder) / "combined.frag"
        for flags in itertools.product((False, True), repeat=len(compositor.ORDER)):
            enabled = dict(zip(compositor.ORDER, flags, strict=True))
            content, animation, count = compositor.generate({"enabled": enabled, "tuning": {}}, SOURCES, DEFAULTS, BOUNDS)
            assert count == sum(flags)
            assert animation == any(value and key != "monochrome" for key, value in enabled.items())
            for effect in compositor.ORDER:
                assert (f"stage_{effect}(v_texcoord, colour);" in content) == enabled[effect]
            shader_file.write_text(content)
            result = subprocess.run([compiler, "-S", "frag", str(shader_file)], capture_output=True, text=True, check=False)
            if result.returncode:
                raise AssertionError(f"{enabled}\n{result.stdout}\n{result.stderr}")
    print("PASS: all 64 shader combinations compile, with correct stages and animation policy")


if __name__ == "__main__":
    main()

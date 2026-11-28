#!/usr/bin/env python3
"""Build one fullscreen fragment shader from the enabled desktop effects."""

import hashlib
import json
import os
import re
import sys
import tempfile
from pathlib import Path

ORDER = ("crt", "hologram", "glitch", "film", "monochrome", "vhs")
PARAMS = ("intensity", "shape", "color", "texture", "lines", "speed", "artifacts")
VHS = ("vhsIntensity", "vhsTracking", "vhsChroma", "vhsNoise", "vhsScanlines", "vhsSpeed", "vhsDropouts")
VHS_NAMES = ("INTENSITY", "TRACKING", "CHROMA", "NOISE", "SCANLINES", "SPEED", "DROPOUTS")


def checked_values(effect, chosen, defaults, bounds):
    """Validate and normalize one effect's declared parameters."""
    names = VHS if effect == "vhs" else PARAMS
    original = defaults if effect == "vhs" else defaults[effect]
    limits = bounds if effect == "vhs" else bounds["screenEffectTuning"]
    if not isinstance(chosen, dict) or set(chosen) - set(names):
        raise ValueError(f"invalid {effect} parameter names")
    result = {}
    for name in names:
        number = chosen.get(name, original[name])
        rule = limits[name]
        if isinstance(number, bool) or not isinstance(number, (int, float)) or not (rule["min"] <= number <= rule["max"]):
            raise ValueError(f"invalid {effect}.{name}")
        result[name] = round(number * 100) / 100
    return result


def stage(effect, source, values):
    """Adapt a standalone fragment shader into a composable colour stage."""
    start = source.index("const float ")
    program = source[start:]
    names = VHS_NAMES if effect == "vhs" else tuple(p.upper() for p in PARAMS)
    for name, value in zip(names, values.values(), strict=True):
        prefix = "VHS_" if effect == "vhs" else "FX_"
        keyword = prefix + name
        replacement = f"const float {effect.upper()}_{keyword} = {value:.2f};"
        program, count = re.subn(r"const float " + keyword + r" = [^;]+;", replacement, program)
        if count != 1:
            raise ValueError(f"missing shader parameter {effect}.{keyword}")
        program = re.sub(r"\b" + keyword + r"\b", f"{effect.upper()}_{keyword}", program)
    for helper in ("hash", "tapeHash"):
        program = re.sub(r"\b" + helper + r"\b", effect + "_" + helper, program)
    program, count = re.subn(r"void main\(\)", f"vec4 stage_{effect}(vec2 stageUv, vec4 stageInput)", program)
    if count != 1:
        raise ValueError(f"invalid {effect} shader entrypoint")
    program = re.sub(r"\bv_texcoord\b", "stageUv", program)
    program = re.sub(r"\btexture\s*\(\s*tex\s*,", "sampleStage(stageUv, stageInput,", program)
    return re.sub(r"\bfragColor\s*=", "return", program)


def generate(payload, sources, defaults, constraints):
    """Create one GLSL program from enabled independent effects."""
    enabled = payload.get("enabled")
    tuning = payload.get("tuning")
    if not isinstance(enabled, dict) or set(enabled) != set(ORDER) or any(type(value) is not bool for value in enabled.values()):
        raise ValueError("enabled effects must contain exactly six boolean entries")
    if not isinstance(tuning, dict) or set(tuning) - set(ORDER):
        raise ValueError("unexpected effect tuning")
    pieces = [
        """#version 300 es
precision highp float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;
uniform vec2 screenSize;
uniform float time;

// A single source sample shared by every stage. Offset samples use the source
// image's spatial difference and preserve the colour of preceding stages.
// Single-effect output is identical to its standalone shader sampling path.
vec4 sampleStage(vec2 uv, vec4 previous, vec2 offsetUv) {
    return texture(tex, offsetUv) + previous - texture(tex, uv);
}
"""
    ]
    included = []
    for effect in ORDER:
        if not enabled[effect]:
            continue
        values = checked_values(
            effect,
            tuning.get(effect, {}),
            defaults["vhs"] if effect == "vhs" else defaults["screen"],
            constraints["vhs"] if effect == "vhs" else constraints,
        )
        if values["vhsIntensity" if effect == "vhs" else "intensity"] == 0:
            continue
        pieces.append(stage(effect, sources[effect].read_text(), values))
        included.append(effect)
    pieces.append("void main() {\n    vec4 colour = texture(tex, v_texcoord);\n")
    pieces.extend(f"    colour = stage_{effect}(v_texcoord, colour);\n" for effect in included)
    pieces.append("    fragColor = colour;\n}\n")
    return "".join(pieces), any(effect != "monochrome" for effect in included), len(included)


def main():
    """Produce an immutable cached shader for one requested effect set."""
    if len(sys.argv) != 2:
        raise ValueError("expected a single JSON effect configuration")
    payload = json.loads(sys.argv[1])
    defaults = {
        "vhs": json.loads(os.environ["DESKTOP_VHS_DEFAULTS"]),
        "screen": json.loads(os.environ["SCREEN_EFFECT_DEFAULTS"]),
    }
    constraints = {
        "vhs": json.loads(os.environ["DESKTOP_VHS_CONSTRAINTS"]),
        "screenEffectTuning": json.loads(os.environ["SCREEN_EFFECT_CONSTRAINTS"]),
    }
    sources = {key: Path(os.environ[f"SCREEN_{key.upper()}_SOURCE"]) for key in ORDER}
    shader, animated, count = generate(payload, sources, defaults, constraints)
    if not count:
        print("off")
        return
    cache = Path(os.environ["SCREEN_COMPOSITE_CACHE"])
    cache.mkdir(mode=0o700, parents=True, exist_ok=True)
    digest = hashlib.sha256(shader.encode()).hexdigest()
    target = cache / (digest + ".frag")
    if not target.exists():
        fd, temporary = tempfile.mkstemp(dir=cache, suffix=".frag")
        try:
            with os.fdopen(fd, "w") as output:
                output.write(shader)
            os.chmod(temporary, 0o600)
            os.replace(temporary, target)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
    print(str(target) + " " + ("animated" if animated else "static"))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, json.JSONDecodeError, OSError) as error:
        print(f"screen composition: {error}", file=sys.stderr)
        sys.exit(2)

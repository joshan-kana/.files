// The native compositor owns one screen-wide pass. These semantic parameter
// descriptions are consumed by the shared detail view, not by a second renderer.
const keys = [
  "intensity",
  "shape",
  "color",
  "texture",
  "lines",
  "speed",
  "artifacts",
];
const definitions = {
  crt: {
    title: "CRT",
    glyph: "󰍹",
    description: "Phosphor display, curvature and persistence",
    labels: [
      "Strength",
      "Tube curvature",
      "Phosphor mask",
      "Bloom",
      "Scanlines",
      "Pulse speed",
      "Flicker",
    ],
    descriptions: [
      "Overall processing",
      "Screen-edge distortion",
      "RGB subpixel pattern",
      "Phosphor halo",
      "Horizontal tube lines",
      "Rate of subtle luminance modulation",
      "Luminance instability",
    ],
  },
  hologram: {
    title: "Holographic",
    glyph: "󰌌",
    description: "Digital interference, spectral edges and light",
    labels: [
      "Strength",
      "Interference shift",
      "Cyan tint",
      "Signal texture",
      "Scan layers",
      "Beam speed",
      "Energy beams",
    ],
    descriptions: [
      "Overall processing",
      "Time-varying horizontal refraction",
      "Spectral hue",
      "Pixel-level interference",
      "Moving scan pattern",
      "Temporal response",
      "Soft digital light streaks",
    ],
  },
  glitch: {
    title: "Digital glitch",
    glyph: "󰜊",
    description: "Pixel breakup, chroma displacement and data faults",
    labels: [
      "Strength",
      "Block size",
      "Chroma split",
      "Pixelation",
      "Dropout strips",
      "Glitch rate",
      "Data faults",
    ],
    descriptions: [
      "Overall processing",
      "Coarseness of the distortion",
      "RGB offset",
      "Sampling resolution",
      "Corrupted horizontal sections",
      "Temporal glitch rate",
      "Random signal breaks",
    ],
  },
  film: {
    title: "Film",
    glyph: "󰕧",
    description: "Grain, gate movement and analog warmth",
    labels: [
      "Strength",
      "Gate weave",
      "Warm tint",
      "Grain",
      "Scratches",
      "Film speed",
      "Exposure flicker",
    ],
    descriptions: [
      "Overall processing",
      "Subtle image movement",
      "Photographic colour grading",
      "Organic temporal texture",
      "Film damage",
      "Grain animation speed",
      "Exposure fluctuation",
    ],
  },
  monochrome: {
    title: "Monochrome",
    glyph: "󰟏",
    description: "Static grayscale and tinted phosphor",
    labels: [
      "Strength",
      "Contrast",
      "Phosphor tint",
      "Dither",
      "Scanlines",
      "Static",
      "Vignette",
    ],
    descriptions: [
      "Overall processing",
      "Tonal separation",
      "Grayscale to green monochrome",
      "Static fine texture",
      "Horizontal shading",
      "No motion: compositor keeps normal redraw policy",
      "Darkened edges",
    ],
  },
};
const modes = Object.keys(definitions);

function descriptor(mode) {
  return definitions[mode] || null;
}
function parameters(mode, bounds) {
  const d = descriptor(mode);
  if (!d) return [];
  return keys
    .filter((key) => mode !== "monochrome" || key !== "speed")
    .map((key) => {
      const i = keys.indexOf(key);
      const limits = bounds[key];
      return {
        key: "screen." + mode + "." + key,
        name: key,
        title: d.labels[i],
        description: d.descriptions[i],
        minimum: limits.min * 100,
        maximum: limits.max * 100,
        step: 5,
        suffix: key === "speed" ? "%" : "%",
      };
    });
}

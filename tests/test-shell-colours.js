const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const root = path.join(__dirname, "..");
const qml = (name) =>
  fs.readFileSync(
    path.join(root, "modules/desktop/hyprland/shell/qml", name + ".qml"),
    "utf8",
  );
const theme = qml("Theme");
const adapter = fs.readFileSync(
  path.join(root, "modules/theme/desktop-shell-theme.nix"),
  "utf8",
);
const roles = {
  command: "0D",
  choice: "0E",
  adjustment: "0C",
  readback: "09",
  utility: "0F",
  search: "0A",
  toggle: "0B",
  progress: "0C",
  focus: "0D",
  critical: "08",
  positive: "0B",
  warning: "0A",
};

test("functional roles and all tonal slots derive from the single Base16 adapter", () => {
  for (const [role, token] of Object.entries(roles))
    assert.match(adapter, new RegExp("\\b" + role + " = colors.base" + token));
  for (let i = 0; i < 16; i++)
    assert.match(
      adapter,
      new RegExp("colors.base" + i.toString(16).toUpperCase().padStart(2, "0")),
    );
  assert.match(theme, /return chosen \? chosen : text;/);
  const declared = new Set(
    [...adapter.matchAll(/\b(\w+) = colors\.base[0-9A-F]+;/g)].map((m) => m[1]),
  );
  const dir = path.join(root, "modules/desktop/hyprland/shell/qml");
  for (const name of fs.readdirSync(dir).filter((n) => n.endsWith(".qml"))) {
    for (const match of fs
      .readFileSync(path.join(dir, name), "utf8")
      .matchAll(/(?:readableRoleColor|roleColor)\("([^"]+)"\)/g))
      assert.ok(
        declared.has(match[1]),
        name + ": unknown colour role " + match[1],
      );
  }
});

test("shared controls own their function colours without panel-specific overrides", () => {
  assert.match(qml("ShellSlider"), /accentColor: theme.sliderColor/);
  assert.match(qml("ShellChoice"), /activeColor: theme.choiceColor/);
  assert.match(
    qml("ShellValueSelector"),
    /activeColor: selector.theme.choiceColor/,
  );
  assert.match(
    qml("ShellAction"),
    /activeColor: switchControl \? theme.toggleColor : theme.commandColor/,
  );
  assert.match(qml("ShellUtilityAction"), /activeColor: theme.utilityColor/);
  assert.match(qml("ShellStepper"), /activeColor: stepper.theme.valueColor/);
  assert.match(
    qml("QuickSettingChip"),
    /identityColor: theme.commandColor[\s\S]*?activeColor: theme.toggleColor/,
  );
  assert.match(theme, /expressiveSurface: groupBase/);
  assert.match(theme, /expressiveSurfaceStrong: controlBase/);
  assert.match(theme, /selectionFill: surfaceRaised/);
  assert.match(
    qml("ShellExpansionHost"),
    /loadingOperationColor: theme.progressColor/,
  );
  for (const name of [
    "DisplaySettings",
    "AudioHardwareSettings",
    "WallpaperPanel",
    "ResourceDashboard",
    "SettingsDetail",
    "VhsPanel",
    "ScreenshotPicker",
  ])
    assert.doesNotMatch(
      qml(name),
      /(?:accentColor|activeColor): \w+\.theme\.(?:readableRoleColor|roleColor)\("/,
    );
});

// Exercise the actual QML math, as in the reactive visual regression tests.
// Nix evaluates every registered palette through the production adapter.
test("all registered palettes preserve semantic hue where possible and readable controls", () => {
  const palettes = JSON.parse(
    execFileSync(
      "nix-instantiate",
      [
        "--eval",
        "--strict",
        "--json",
        "--expr",
        `let r = import ./modules/theme/registry.nix { lib = null; }; a = import ./modules/theme/desktop-shell-theme.nix; ns = builtins.filter (n: r.variants.\${n} ? colors) (builtins.attrNames r.variants); in builtins.listToAttrs (map (n: { name = n; value = a { colors = builtins.mapAttrs (_: v: "#\${v}") r.variants.\${n}.colors; }; }) ns)`,
      ],
      { cwd: root, encoding: "utf8" },
    ),
  );
  const rgb = (hex) => ({
    r: parseInt(hex.slice(1, 3), 16) / 255,
    g: parseInt(hex.slice(3, 5), 16) / 255,
    b: parseInt(hex.slice(5, 7), 16) / 255,
  });
  const bodies = [
    "luminance",
    "blend",
    "contrastRatio",
    "onColor",
    "contrastColor",
    "readableColor",
    "solidFill",
    "choiceFill",
    "choiceForeground",
  ]
    .map((name) => {
      const source = theme.match(
        new RegExp(
          "    function " +
            name +
            "\\(([^)]*)\\): \\w+ \\{([\\s\\S]*?)\\n    \\}",
        ),
      );
      assert.ok(source, name);
      return (
        "function " +
        name +
        "(" +
        source[1].replace(/: \w+/g, "") +
        ") {" +
        source[2].replace(
          /function channel\(value: real\): real/,
          "function channel(value)",
        ) +
        "\n}"
      );
    })
    .join("\n");
  const evaluate = new Function(
    "palette",
    "roles",
    "Qt",
    `
    const {background, surface, surfaceRaised, outline, textMuted, text, textStrong, textBright} = palette;
    ${bodies}
    const dark = luminance(background) < luminance(textStrong);
    const panelBase = blend(background, surface, dark ? 0.33 : 0.22);
    const paneBase = blend(background, surface, dark ? 0.68 : 0.55);
    const controlBase = blend(paneBase, surfaceRaised, dark ? 0.35 : 0.24);
    const track = blend(surfaceRaised, outline, dark ? 0.35 : 0.25);
    return { contrastRatio, readableColor, solidFill, onColor, choiceFill, choiceForeground, contrastColor, panelBase, controlBase, track };
  `,
  );
  assert.ok(Object.keys(palettes).length >= 2);
  for (const [name, data] of Object.entries(palettes)) {
    const palette = Object.fromEntries(
      Object.entries(data.theme).map(([k, v]) => [k, rgb(v)]),
    );
    const resolved = Object.fromEntries(
      Object.entries(data.roles).map(([k, v]) => [k, rgb(v)]),
    );
    const f = evaluate(palette, resolved, { rgba: (r, g, b) => ({ r, g, b }) });
    for (const [role, colour] of Object.entries(resolved)) {
      const label = name + ":" + role;
      for (const surface of [f.panelBase, f.controlBase]) {
        const readable = f.readableColor(colour, surface);
        assert.ok(
          f.contrastRatio(readable, surface) >= 4.5,
          label + " text contrast",
        );
        if (f.contrastRatio(colour, surface) >= 4.5)
          assert.deepEqual(readable, colour, label + " preserve hue");
      }
      assert.ok(
        f.contrastRatio(f.choiceForeground(colour), f.choiceFill(colour)) >=
          4.5,
        label + " selected contrast",
      );
      const solid = f.solidFill(colour);
      assert.ok(
        f.contrastRatio(f.onColor(solid), solid) >= 4.5,
        label + " solid command contrast",
      );
    }
    assert.ok(
      f.contrastRatio(
        f.contrastColor(resolved.adjustment, f.track, 3),
        f.track,
      ) >= 3,
      name + " slider track contrast",
    );
  }
});

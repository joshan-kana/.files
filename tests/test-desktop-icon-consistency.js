import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import vm from "node:vm";

const root = path.join(
  import.meta.dirname,
  "../modules/desktop/hyprland/shell/qml",
);
const qml = (name) => fs.readFileSync(path.join(root, name), "utf8");
const context = vm.createContext({});
vm.runInContext(qml("DesktopIcons.js"), context);

const surfaces = {
  theme: ["SystemContent.qml", "ThemePanel.qml", "shell.qml"],
  wallpaper: ["SystemContent.qml", "WallpaperPanel.qml", "shell.qml"],
  session: ["SystemContent.qml", "SessionPanel.qml", "shell.qml"],
  resources: ["SystemContent.qml", "ResourceDashboard.qml", "shell.qml"],
  captures: ["SystemContent.qml", "RecordingLibrary.qml", "shell.qml"],
  clipboard: ["ClipboardPanel.qml", "shell.qml"],
  shortcuts: ["ShortcutCheatsheet.qml", "shell.qml"],
  audioMixer: ["SystemContent.qml", "AudioMixerContent.qml", "shell.qml"],
};

test("semantic destination icons are centralized and reused in every entry point", () => {
  const icons = Object.values(surfaces).map((_, i) =>
    context.glyphFor(Object.keys(surfaces)[i]),
  );
  assert.equal(new Set(icons).size, icons.length);
  for (const [destination, files] of Object.entries(surfaces)) {
    assert.ok(
      context.glyphFor(destination).length > 0,
      `missing ${destination} icon`,
    );
    for (const file of files) {
      assert.ok(
        qml(file).includes(`DesktopIcons.glyphFor("${destination}")`),
        `${file} must use the shared icon for ${destination}`,
      );
    }
  }
  assert.equal(context.glyphFor("nonexistent"), "");
});

test("detail headers use the existing Nerd Font optical box and no competing glyph", () => {
  for (const file of [
    "ThemePanel.qml",
    "WallpaperPanel.qml",
    "SessionPanel.qml",
    "ResourceDashboard.qml",
    "RecordingLibrary.qml",
    "ClipboardPanel.qml",
    "ShortcutCheatsheet.qml",
  ]) {
    assert.match(qml(file), /glyphFont: "Symbols Nerd Font"/);
    assert.match(
      qml(file),
      /glyph: (?:panel\.armedAction\.length > 0 \? "!" : )?DesktopIcons\.glyphFor/,
    );
  }
});

test("built-in palette actions retain shared glyphs while applications keep their icons", () => {
  const palette = qml("CommandPalette.qml");
  const shell = qml("shell.qml");
  assert.match(palette, /glyph: command\.glyph \|\| ""/);
  assert.match(
    palette,
    /glyphFont: command\.glyph \? "Symbols Nerd Font" : ""/,
  );
  assert.match(
    palette,
    /glyph: command\.glyph \|\| ""[\s\S]*?kind: "application"/,
  );
  assert.match(palette, /visible: !modelData\.glyph/);
  assert.match(palette, /font\.family: modelData\.glyphFont \|\| ""/);
  for (const [id, key] of [
    ["theme.toggle", "theme"],
    ["wallpaper.toggle", "wallpaper"],
    ["captures.library", "captures"],
    ["session.toggle", "session"],
    ["resources.toggle", "resources"],
    ["clipboard.toggle", "clipboard"],
    ["shortcuts.toggle", "shortcuts"],
    ["audio.mixer", "audioMixer"],
  ]) {
    const at = shell.indexOf(`id: "${id}"`);
    assert.ok(at >= 0, `${id} command missing`);
    assert.ok(
      shell
        .slice(at, at + 270)
        .includes(`glyph: DesktopIcons.glyphFor("${key}")`),
      `${id} icon mismatch`,
    );
  }
});

test("gallery and capture palette commands delegate to the existing action owners", () => {
  const actions = qml("Actions.qml");
  assert.match(
    actions,
    /commandId === "wallpaper\.toggle"\)\s*showWallpaper\(\)/,
  );
  assert.match(
    actions,
    /commandId === "captures\.library"\)\s*showCaptures\(\)/,
  );
});

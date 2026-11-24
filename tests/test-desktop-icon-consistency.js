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
  theme: ["SystemContent.qml", "ThemePanel.qml", "ActionCatalog.js"],
  wallpaper: ["SystemContent.qml", "WallpaperPanel.qml", "ActionCatalog.js"],
  session: ["SystemContent.qml", "SessionPanel.qml", "ActionCatalog.js"],
  resources: ["SystemContent.qml", "ResourceDashboard.qml", "ActionCatalog.js"],
  captures: ["SystemContent.qml", "RecordingLibrary.qml", "ActionCatalog.js"],
  clipboard: ["ClipboardPanel.qml", "ActionCatalog.js"],
  shortcuts: ["ShortcutCheatsheet.qml", "ActionCatalog.js"],
  audioMixer: [
    "SystemContent.qml",
    "AudioMixerContent.qml",
    "ActionCatalog.js",
  ],
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
        qml(file).includes(
          `${file === "ActionCatalog.js" ? "options" : "DesktopIcons"}.glyphFor("${destination}")`,
        ),
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
  const catalog = qml("ActionCatalog.js");
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
    const at = catalog.indexOf(`id: "${id}"`);
    assert.ok(at >= 0, `${id} command missing`);
    assert.ok(
      catalog.slice(at, at + 300).includes(`glyph: options.glyphFor("${key}")`),
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

test("capability headers and tiles share dynamic state and canonical static icons", () => {
  const tile = qml("SystemContent.qml");
  const detail = qml("SettingsDetail.qml");
  assert.match(detail, /DesktopIcons\.capabilityGlyph\(kind,/);
  assert.match(detail, /text: panel\.capabilityIcon/);
  for (const kind of [
    "windows",
    "glass",
    "bar",
    "spectrum",
    "displays",
    "vhs",
    "status",
  ])
    assert.ok(tile.includes('DesktopIcons.glyphFor("' + kind + '")'));
  for (const kind of [
    "alerts",
    "stay",
    "frame",
    "motion",
    "nightLight",
    "bluetooth",
  ]) {
    assert.ok(tile.includes('DesktopIcons.capabilityGlyph("' + kind + '"'));
    assert.notEqual(
      context.capabilityGlyph(kind, { active: true }),
      context.capabilityGlyph(kind, { active: false }),
    );
  }
  assert.equal(
    context.capabilityGlyph("power", {
      batteryAvailable: true,
      batteryLevelIcon: "battery",
    }),
    "battery",
  );
  assert.equal(
    context.capabilityGlyph("reactive", {}),
    context.glyphFor("audioMixer"),
  );
  assert.match(
    qml("NetworkPanel.qml"),
    /glyph: DesktopIcons\.capabilityGlyph\("network"/,
  );
  assert.match(
    qml("BluetoothPanel.qml"),
    /glyph: DesktopIcons\.capabilityGlyph\("bluetooth"/,
  );
  assert.match(qml("VhsPanel.qml"), /text: DesktopIcons\.glyphFor\("vhs"\)/);
  assert.match(
    qml("StatusContent.qml"),
    /text: DesktopIcons\.glyphFor\("status"\)/,
  );
});

test("capability enable/disable actions share recognizable state glyphs", () => {
  assert.notEqual(context.toggleGlyph(true), context.toggleGlyph(false));
  assert.equal(context.toggleGlyph(true).codePointAt(0), 0xf0521);
  assert.equal(context.toggleGlyph(false).codePointAt(0), 0xf0522);
  assert.match(
    qml("SettingsDetail.qml"),
    /switchControl: true[\s\S]*?active: panel.masterState/,
  );
});

test("Controls header destination glyphs use their detail semantic colours without selecting the action", () => {
  const controls = qml("SystemContent.qml");
  const action = qml("ShellAction.qml");
  for (const [destination, role, detail] of [
    ["theme", "display", "ThemePanel.qml"],
    ["wallpaper", "wallpaper", "WallpaperPanel.qml"],
    ["session", "resources", "SessionPanel.qml"],
  ]) {
    assert.ok(
      controls.includes(
        `icon: DesktopIcons.glyphFor("${destination}")\n                    iconColor: root.theme.roleColor("${role}")`,
      ),
    );
    assert.ok(qml(detail).includes(`panel.theme.roleColor("${role}")`));
  }
  assert.match(
    action,
    /property color iconColor: prominentAction \? theme.onColor\(activeColor\) : active \? activeColor : theme.textStrong/,
  );
  assert.equal(
    [...action.matchAll(/text: root.icon\s+color: root.iconColor/g)].length,
    4,
  );
  assert.match(
    action,
    /text: root.title[\s\S]*?color: root.prominentAction \? root.theme.onColor\(root.activeColor\) : root.active \? root.activeColor :/,
  );
  assert.match(action, /selected: root.active/);
});

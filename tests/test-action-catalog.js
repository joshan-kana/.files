const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { test } = require("node:test");

const root = path.join(__dirname, "../modules/desktop/hyprland/shell/qml");
const load = (name) => fs.readFileSync(path.join(root, name), "utf8");
const catalog = vm.runInNewContext(load("ActionCatalog.js") + "\ncommands;");
const actions = load("Actions.qml");
const shell = load("shell.qml");
const palette = load("CommandPalette.qml");

function descriptors(overrides = {}) {
  return catalog({
    wallpaperSpectrumEnabled: false,
    musicReactiveEnabled: false,
    seekSeconds: 10,
    rememberRecents: false,
    terminal: "kitty",
    audioAvailable: true,
    brightnessAvailable: true,
    glyphFor: () => "",
    ...overrides,
  });
}

test("action descriptors have unique stable IDs and reachable handlers", () => {
  const entries = descriptors();
  assert.ok(entries.length > 45);
  const ids = entries.map((entry) => entry.id);
  assert.equal(new Set(ids).size, ids.length);
  for (const entry of entries) {
    assert.match(entry.id, /^[a-z][a-zA-Z]*(?:\.[a-zA-Z]+)+$/);
    assert.ok(entry.name && entry.description && entry.icon);
    assert.ok(Array.isArray(entry.keywords) && entry.keywords.length > 0);
    const internal = /^(?:launcher\.|audio\.setVolume$|brightness\.set$)/.test(
      entry.id,
    );
    const delegated =
      palette.includes(`entry.commandId === "${entry.id}"`) ||
      shell.includes(`commandId === "${entry.id}"`);
    const dispatched = actions.includes(`commandId === "${entry.id}"`);
    assert.ok(
      internal ? delegated : dispatched,
      `Missing handler for ${entry.id}`,
    );
  }
  assert.match(shell, /commands: actions\.paletteCommands/);
  assert.match(
    shell,
    /onCommandTriggered: commandId => actions\.invokeCommand\(commandId\)/,
  );
});

test("hardware capabilities, dynamic labels and settings search stay authoritative", () => {
  const full = descriptors();
  const limited = descriptors({
    audioAvailable: false,
    brightnessAvailable: false,
    wallpaperSpectrumEnabled: true,
    musicReactiveEnabled: true,
    rememberRecents: true,
    seekSeconds: 30,
  });
  const ids = limited.map((entry) => entry.id);
  for (const id of [
    "audio.volumeUp",
    "audio.volumeDown",
    "audio.toggleMute",
    "audio.setVolume",
    "brightness.set",
    "brightness.up",
    "brightness.down",
  ])
    assert.ok(!ids.includes(id), `${id} available without hardware`);
  assert.match(
    limited.find((entry) => entry.id === "media.reactiveShell").name,
    /Disable/,
  );
  assert.match(
    limited.find((entry) => entry.id === "media.seekForward").name,
    /30 Seconds/,
  );
  assert.match(
    limited.find((entry) => entry.id === "launcher.toggleHistory").name,
    /Disable/,
  );
  assert.ok(
    full.some(
      (entry) =>
        entry.id === "controls.network" && entry.keywords.includes("dns"),
    ),
  );
  assert.ok(
    full.some(
      (entry) =>
        entry.id === "controls.bluetooth" && entry.keywords.includes("pair"),
    ),
  );
});

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { test } = require("node:test");

const root = path.join(__dirname, "../modules/desktop/hyprland/shell/qml");
const read = (name) => fs.readFileSync(path.join(root, name), "utf8");
const context = vm.runInNewContext(
  read("ContextActions.js") +
    "\n({ filtered, clipboardActions, historyFilter, safeWebUrl });",
);
const palette = read("CommandPalette.qml");
const clipboard = read("ClipboardPanel.qml");

test("context action search ranks and filters, preserving source order and selection identity", () => {
  const actions = [
    { name: "Open With…", genericName: "Desktop app" },
    { name: "Copy Path", genericName: "File pathname" },
    { name: "Open Folder", genericName: "Containment" },
  ];
  assert.deepEqual(
    Array.from(context.filtered(actions, "open")).map((a) => a.name),
    ["Open With…", "Open Folder"],
  );
  assert.deepEqual(
    Array.from(context.filtered(actions, "desktop app")).map((a) => a.name),
    ["Open With…"],
  );
  assert.deepEqual(
    Array.from(context.filtered(actions, "")).map((a) => a.name),
    actions.map((a) => a.name),
  );
  assert.equal(context.filtered(actions, "do not match").length, 0);
  assert.match(palette, /ContextActionModel \{/);
  assert.match(palette, /actionQuery = text;/);
  assert.match(palette, /search\.text = priorQuery;/);
  assert.match(palette, /selectionIdentity = identity\(target\);/);
});

test("clipboard actions reflect capabilities and never offer executable URL schemes", () => {
  const text = { kind: "TEXT", pinned: false };
  const pinned = { kind: "TEXT", pinned: true };
  const image = { kind: "IMAGE", pinned: false };
  const binary = { kind: "BINARY", pinned: false };
  assert.deepEqual(
    Array.from(context.clipboardActions(text, true)).map((a) => a.action),
    ["copy", "openLink", "pin", "delete"],
  );
  assert.deepEqual(
    Array.from(context.clipboardActions(pinned, false)).map((a) => a.action),
    ["copy", "unpin", "delete"],
  );
  assert.deepEqual(
    Array.from(context.clipboardActions(image, false)).map((a) => a.action),
    ["copy", "pin", "delete"],
  );
  assert.deepEqual(
    Array.from(context.clipboardActions(binary, false)).map((a) => a.action),
    ["copy", "delete"],
  );
  assert.equal(
    context.safeWebUrl("https://example.com/path?q=1"),
    "https://example.com/path?q=1",
  );
  for (const bad of [
    "javascript:alert(1)",
    "file:///etc/shadow",
    "https://evil.test\nexec",
    "http://",
    "https://host name",
    "https://@example.org",
  ])
    assert.equal(context.safeWebUrl(bad), "", bad);
});

test("clipboard search combines persistent pins, type filtering and list focus", () => {
  const items = [
    { kind: "TEXT", preview: "Hello", pinned: false },
    { kind: "IMAGE", preview: "Photo", pinned: false },
    { kind: "TEXT", preview: "Pinned command", pinned: true },
  ];
  assert.equal(context.historyFilter(items, "", "all").length, 3);
  assert.deepEqual(
    Array.from(context.historyFilter(items, "", "pinned")).map(
      (x) => x.preview,
    ),
    ["Pinned command"],
  );
  assert.deepEqual(
    Array.from(context.historyFilter(items, "pinned", "TEXT")).map(
      (x) => x.preview,
    ),
    ["Pinned command"],
  );
  assert.equal(context.historyFilter(items, "", "IMAGE").length, 1);
  assert.match(clipboard, /ContextActionModel \{/);
  assert.match(
    clipboard,
    /if\s*\(panel\.actionMode\)\s*panel\.leaveActions\(\)/,
  );
  assert.match(clipboard, /deleteArmed = true;/);
  assert.match(clipboard, /panel\.kindFilter === modelData\.id/);
  assert.match(clipboard, /clipboardOperations/);
});

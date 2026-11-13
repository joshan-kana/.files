const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { test } = require("node:test");

const context = vm.createContext({ Math, Number });
vm.runInContext(
  fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml/ToastQueue.js"),
    "utf8",
  ),
  context,
);
const layout = (items, limit = 3, now = 1000) =>
  Array.from(context.layout(items, limit, now, 220));

const sample = (slot, phase = "visible", removeAt = 0) => ({
  phase,
  slot,
  removeAt,
});

test("three live notifications occupy stable slots without an exit layer", () => {
  const next = layout([sample(0), sample(0), sample(0)]);
  assert.deepEqual(
    next.map((entry) => [entry.phase, entry.slot]),
    [
      ["visible", 0],
      ["visible", 1],
      ["visible", 2],
    ],
  );
});

test("fourth arrival keeps the displaced card behind the third visible slot", () => {
  const next = layout([sample(0), sample(0), sample(1), sample(2)]);
  assert.deepEqual(
    next.map((entry) => [entry.phase, entry.slot]),
    [
      ["visible", 0],
      ["visible", 1],
      ["visible", 2],
      ["closing", 2],
    ],
  );
  assert.equal(next[3].removeAt, 1220);
  assert.equal(next[3].evicted, true);
});

test("expiration preserves the outgoing card while reflowing its successors", () => {
  const next = layout([sample(0, "closing", 1220), sample(1), sample(2)]);
  assert.deepEqual(
    next.map((entry) => [entry.phase, entry.slot]),
    [
      ["closing", 0],
      ["visible", 0],
      ["visible", 1],
    ],
  );
  assert.equal(next[0].removeAt, 1220);
  assert.equal(next[0].evicted, false);
});

test("bursts retain previous exits and do not reactivate them", () => {
  const next = layout([
    sample(0),
    sample(0),
    sample(0),
    sample(2, "closing", 1140),
    sample(2, "closing", 1180),
  ]);
  assert.deepEqual(
    next.map((entry) => entry.phase),
    ["visible", "visible", "visible", "closing", "closing"],
  );
  assert.deepEqual(
    next.slice(3).map((entry) => entry.removeAt),
    [1140, 1180],
  );
});

test("burst eviction never draws a partially clipped fourth card", () => {
  const items = [
    sample(0),
    sample(0),
    sample(0),
    { ...sample(2, "closing", 1140), evicted: true },
  ];
  const next = layout(items, 3);
  assert.ok(next.every((entry) => entry.slot >= 0 && entry.slot < 3));
  assert.equal(next[3].slot, next[2].slot);
  assert.equal(next[3].phase, "closing");
  assert.equal(next[3].evicted, true);
});

test("reduced visible capacity preserves an outgoing slot without overlap", () => {
  const next = layout([sample(0), sample(1), sample(2)], 2);
  assert.deepEqual(
    next.map((entry) => [entry.phase, entry.slot]),
    [
      ["visible", 0],
      ["visible", 1],
      ["closing", 1],
    ],
  );
  assert.equal(next[2].evicted, true);
});

const byOutput = (items, capacities = {}, limit = 3, now = 1000) =>
  Array.from(context.layoutByOutput(items, capacities, limit, now, 220));

test("two outputs keep independent full toast stacks without teleporting or duplicating", () => {
  const items = [
    { ...sample(0), outputName: "HEADLESS-1" },
    { ...sample(0), outputName: "Virtual-1" },
    { ...sample(0), outputName: "HEADLESS-1" },
    { ...sample(0), outputName: "Virtual-1" },
    { ...sample(0), outputName: "Virtual-1" },
  ];
  const result = byOutput(items);
  assert.deepEqual(
    result.map((x) => [x.phase, x.slot]),
    [
      ["visible", 0],
      ["visible", 0],
      ["visible", 1],
      ["visible", 1],
      ["visible", 2],
    ],
  );
  const eviction = byOutput([
    { ...sample(0), outputName: "HEADLESS-1" },
    ...items,
  ]);
  assert.equal(eviction[0].slot, 0);
  assert.equal(eviction[3].slot, 2);
  assert.equal(eviction[5].phase, "visible");
});

test("constrained secondary output capacity does not reduce primary capacity", () => {
  const items = [
    { ...sample(0), outputName: "HEADLESS-1" },
    { ...sample(0), outputName: "HEADLESS-1" },
    { ...sample(0), outputName: "HEADLESS-1" },
    { ...sample(0), outputName: "Virtual-1" },
    { ...sample(0), outputName: "Virtual-1" },
    { ...sample(0), outputName: "Virtual-1" },
  ];
  const result = byOutput(items, { "HEADLESS-1": 2, "Virtual-1": 3 });
  assert.deepEqual(
    result.slice(0, 3).map((x) => x.phase),
    ["visible", "visible", "closing"],
  );
  assert.deepEqual(
    result.slice(3).map((x) => x.phase),
    ["visible", "visible", "visible"],
  );
});

test("newest popup is displayed at the first and highest visible slot", () => {
  const queue = ["first", "second"];
  queue.unshift("third");
  const next = layout(queue.map((name) => ({ ...sample(0), name })));
  assert.deepEqual(queue, ["third", "first", "second"]);
  assert.deepEqual(
    next.map((entry) => entry.slot),
    [0, 1, 2],
  );
  const popupSource = fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/qml/NotificationPopup.qml",
    ),
    "utf8",
  );
  const stateSource = fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/qml/NotificationState.qml",
    ),
    "utf8",
  );
  const centerSource = fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/qml/NotificationContent.qml",
    ),
    "utf8",
  );
  assert.match(stateSource, /popups\.insert\(0, \{/);
  assert.match(
    popupSource,
    /y: slot \* \(popup\.cardHeight \+ popup\.cardGap\)/,
  );
  assert.match(
    centerSource,
    /readonly property var items: \[\.\.\.\(notificationState\.history \|\| \[\]\)\]\.reverse\(\)/,
  );
});

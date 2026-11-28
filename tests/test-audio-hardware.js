const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const root = path.join(__dirname, "../modules/desktop/hyprland/shell/qml");
const f = vm.runInNewContext(
  fs.readFileSync(path.join(root, "AudioHardware.js"), "utf8") +
    "\n({ hardwareSnapshot, pendingChoice, choiceGroups })",
);
const card = {
  id: 10,
  type: "PipeWire:Interface:Device",
  info: {
    props: {
      "media.class": "Audio/Device",
      "object.serial": 20,
      "device.name": "card",
    },
    params: {
      EnumProfile: [
        { index: 0, name: "off", available: "yes" },
        { index: 1, name: "duplex", available: "yes" },
        { index: 2, name: "unsupported", available: "no" },
      ],
      Profile: [{ index: 1, name: "duplex" }],
      EnumRoute: [
        {
          index: 0,
          direction: "Output",
          devices: [3],
          profiles: [1],
          name: "speaker",
          available: "yes",
        },
        {
          index: 1,
          direction: "Output",
          devices: [4],
          profiles: [1],
          name: "other",
          available: "yes",
        },
        {
          index: 2,
          direction: "Input",
          devices: [3],
          profiles: [1],
          name: "microphone",
          available: "yes",
        },
      ],
      Route: [{ index: 0, direction: "Output", device: 3 }],
    },
  },
};
const sink = {
  id: 11,
  type: "PipeWire:Interface:Node",
  info: {
    props: {
      "media.class": "Audio/Sink",
      "object.serial": 21,
      "device.id": 10,
      "card.profile.device": 3,
      "node.name": "sink",
    },
  },
};
test("native profiles and routes follow the actual hardware graph", () => {
  const devices = f.hardwareSnapshot(JSON.stringify([card, sink]));
  assert.equal(devices.length, 1);
  const choices = devices[0].choices;
  assert.equal(choices.length, 4);
  assert.equal(choices[0].label, "off");
  assert.equal(choices[1].active, true);
  assert.equal(choices[2].available, false);
  assert.equal(choices[3].target, 11);
  assert.equal(choices[3].active, true);
  assert.equal(f.hardwareSnapshot("invalid"), null);
});
test("off-profile cards remain configurable without any audio nodes", () => {
  const devices = f.hardwareSnapshot(JSON.stringify([card]));
  assert.equal(devices[0].choices.length, 3);
});
test("reused PipeWire ids cannot authorize a stale choice", () => {
  const devices = f.hardwareSnapshot(JSON.stringify([card, sink]));
  const request = {
    device: "card",
    deviceSerial: 20,
    key: "route:sink:0",
    serial: 21,
  };
  assert.equal(f.pendingChoice(devices, request).target, 11);
  assert.equal(f.pendingChoice(devices, { ...request, serial: 22 }), null);
  assert.equal(
    f.pendingChoice(devices, { ...request, deviceSerial: 22 }),
    null,
  );
});

test("grouped hardware controls retain exclusive native profile and per-node route choices", () => {
  const choices = f.hardwareSnapshot(JSON.stringify([card, sink]))[0].choices;
  const groups = f.choiceGroups(choices);
  assert.equal(groups.length, 2);
  assert.equal(groups[0].title, "Profile");
  assert.equal(groups[0].choices.length, 3);
  assert.equal(groups[0].choices[1].active, true);
  assert.equal(groups[0].choices[2].available, false);
  assert.equal(groups[1].title, "Output · sink");
  assert.equal(groups[1].choices[0].routeName, "speaker");
  assert.equal(
    f.choiceGroups([...choices, { ...choices[3], serial: 22 }]).length,
    3,
  );
});

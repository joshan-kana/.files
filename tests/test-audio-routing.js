const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const root = path.join(__dirname, "../modules/desktop/hyprland/shell/qml");
const f = vm.runInNewContext(fs.readFileSync(path.join(root, "AudioRouting.js"), "utf8") + "\n({stereoIndices, balance, balancedVolumes, linkedDevice})");
test("balance preserves maximum channel gain and only supports genuine stereo", () => {
  const indices = f.stereoIndices([2, 1], 1, 2);
  assert.deepEqual(Array.from(indices), [1, 0]);
  assert.equal(f.stereoIndices([1], 1, 2), null);
  assert.equal(f.stereoIndices([1, 2, 3], 1, 2), null);
  assert.deepEqual(Array.from(f.balancedVolumes([0.8, 0.8], indices, 0.5)), [0.8, 0.4]);
  assert.equal(f.balance([0.8, 0.4], indices), 0.5);
  assert.deepEqual(Array.from(f.balancedVolumes([0, 0], indices, 1)), [0, 0]);
});
test("routing readback uses real directed links and never the default device", () => {
  const source = {id: 1, audio: true};
  const sink = {id: 2, audio: true};
  const stream = {id: 3, isStream: true};
  const groups = [{source, target: stream}, {source: stream, target: sink}];
  assert.equal(f.linkedDevice(groups, stream, true), source);
  assert.equal(f.linkedDevice(groups, stream, false), sink);
  assert.equal(f.linkedDevice([], stream, false), null);
  const mixer = fs.readFileSync(path.join(root, "AudioMixerContent.qml"), "utf8");
  assert.match(mixer, /"target.object", target.name, "Spa:String"/);
  assert.match(mixer, /Routing was not confirmed by PipeWire/);
});

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const shell = path.join(__dirname, "../modules/desktop/hyprland/shell/qml");
const library = fs.readFileSync(
  path.join(shell, "RecordingLibrary.qml"),
  "utf8",
);
const controls = fs.readFileSync(path.join(shell, "SystemContent.qml"), "utf8");

function method(name) {
  const start = library.indexOf(`    function ${name}(): void {`);
  assert.ok(start >= 0, `${name} must be defined`);
  const end = library.indexOf("\n    }", start);
  assert.ok(end > start, `${name} must have an ending`);
  return library.slice(start, end + 6).replace("(): void", "()");
}

function fixture() {
  const operations = [];
  const state = {
    selectedEntry: { name: "Recording-example.mkv" },
    deletePending: "",
    open: true,
    isBusy: false,
    statusText: "",
    statusError: false,
    deletingName: "",
    runtime: { recordingLibrary: "recording-helper" },
    actionProcess: {
      running: false,
      exec(args) {
        operations.push(args);
        state.actionProcess.running = true;
        state.isBusy = true;
      },
    },
    Quickshell: {
      execDetached(args) {
        operations.push(args);
      },
    },
    deleteConfirmation: {
      request(name) {
        if (state.deletePending !== name) state.deletePending = name;
      },
      cancel() {
        state.deletePending = "";
      },
    },
  };
  vm.createContext(state);
  vm.runInContext(
    [
      "requestDelete",
      "activateSelected",
      "confirmDelete",
      "openSelected",
      "cancelDelete",
    ]
      .map(method)
      .join("\n"),
    state,
  );
  return { state, operations };
}

test("recording delete key and pointer button arm one warning; only Enter confirms", () => {
  const { state, operations } = fixture();
  // The key binding and pointer surface both dispatch requestDelete().
  assert.match(library, /onActivated: library\.requestDelete\(\)/);
  assert.match(
    controls,
    /shellMatchesHint\("RecordingLibrary\.delete", event\.key, event\.modifiers\)\)[\s\S]*?if \(!event\.isAutoRepeat\)\s*recordingsPanel\.invoke\("requestDelete"\)/,
  );
  assert.match(
    controls,
    /shellKeyCode\("controls", "Enter"\)\)[\s\S]*?if \(!event\.isAutoRepeat\)\s*recordingsPanel\.invoke\("activateSelected"\)/,
  );
  state.requestDelete(); // Key-down or pointer click.
  assert.equal(state.deletePending, "Recording-example.mkv");
  assert.equal(state.statusError, false);
  assert.match(state.statusText, /Press Enter/);
  state.requestDelete(); // Another Delete key-down or another pointer click.
  assert.equal(state.deletePending, "Recording-example.mkv");
  state.openSelected(); // The pointer Open button must not confirm.
  assert.equal(operations.length, 0);
  state.activateSelected(); // Enter.
  assert.deepEqual(Array.from(operations[0]), [
    "recording-helper",
    "trash",
    "Recording-example.mkv",
  ]);
  assert.equal(operations.length, 1);
  assert.equal(state.deletePending, "");
  state.activateSelected(); // Repeated/double Enter cannot open while processing.
  assert.equal(operations.length, 1);
});

test("cancel and expiry return Enter to normal Open without trashing", () => {
  for (const cancel of ["cancelDelete", "expiry"]) {
    const { state, operations } = fixture();
    state.requestDelete();
    if (cancel === "expiry") state.deleteConfirmation.cancel();
    else state.cancelDelete();
    assert.equal(state.deletePending, "");
    state.activateSelected();
    assert.deepEqual(Array.from(operations[0]), [
      "recording-helper",
      "open",
      "Recording-example.mkv",
    ]);
  }
});

test("the pending Trash button shows the Enter instruction and cannot be reactivated", () => {
  assert.match(
    library,
    /title: library\.selectedEntry && library\.deletePending === library\.selectedEntry\.name \? "Press Enter to confirm" : "Trash"/,
  );
  assert.match(
    library,
    /enabled: !!library\.selectedEntry && !library\.isBusy && library\.deletePending\.length === 0\s*activeColor: library\.theme\.critical/,
  );
  assert.doesNotMatch(library, /Press D or Enter again/);
});

const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const qml = (name) =>
  fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
    "utf8",
  );

test("shared buttons activate on first key-down and use key-up only to release feedback", () => {
  const state = qml("StateLayer.qml");
  const press = state
    .split("Keys.onPressed: event => {")[1]
    .split("Keys.onReleased: event => {")[0];
  const release = state
    .split("Keys.onReleased: event => {")[1]
    .split("onActiveFocusChanged:")[0];

  assert.match(press, /!event\.isAutoRepeat/);
  assert.match(
    press,
    /keyboardHeld = true;\s*playPressFeedback\(width \/ 2, height \/ 2\);\s*activated\(event\)/,
  );
  assert.match(press, /event\.accepted = true/);
  assert.doesNotMatch(release, /activated\(/);
  assert.match(release, /keyboardHeld = false/);
  assert.match(release, /!event\.isAutoRepeat/);
  assert.match(state, /onClicked: event => activated\(event\)/);
});

test("pointer and keyboard share a bounded press effect and reset safely", () => {
  const state = qml("StateLayer.qml");
  assert.match(
    state,
    /visualPressed: pressed \|\| manualPress \|\| heldPress \|\| keyboardHeld/,
  );
  assert.match(state, /function playPressFeedback\(x: real, y: real\): void/);
  assert.match(state, /pressFeedback\.restart\(\);\s*startRipple\(x, y\)/);
  assert.match(
    state,
    /onPressed: event => playPressFeedback\(event\.x, event\.y\)/,
  );
  assert.match(
    state,
    /onActiveFocusChanged: \{\s*if \(!activeFocus && keyboardHeld\) \{\s*keyboardHeld = false;\s*fadeRipple\.restart\(\)/,
  );
  assert.match(
    state,
    /onDisabledChanged: \{\s*if \(disabled\)\s*resetPressFeedback\(\)/,
  );
  assert.match(state, /if \(!animationsEnabled \|\| !showHover\)/);
});

test("shared motion tokens drive compact, normal and split-button deformation", () => {
  const motion = qml("Motion.qml");
  for (const token of [
    "pressScaleSmall",
    "pressScaleNormal",
    "pressSpring",
    "pressDamping",
    "pressEpsilon",
  ])
    assert.match(motion, new RegExp("readonly property real " + token + ":"));

  for (const [name, scale] of [
    ["ShellAction.qml", "pressScaleNormal"],
    ["TileCornerAction.qml", "pressScaleSmall"],
  ]) {
    const src = qml(name);
    assert.match(src, /interaction\.visualPressed|press\.visualPressed/);
    assert.match(src, new RegExp("motion\\." + scale));
    assert.match(
      src,
      name === "ShellAction.qml"
        ? /Behavior on animatedScaleX \{/
        : /Behavior on scale \{/,
    );
    assert.match(src, /SpringAnimation \{/);
    assert.match(src, /enabled: (root|chip|action)\.motion\.enabled/);
    assert.match(src, /motion\.pressEpsilon/);
  }
});

test("selected state, hit target size and shortcut ownership remain independent of press scale", () => {
  const action = qml("ShellAction.qml");
  assert.match(
    action,
    /Accessible\.role: switchControl \? Accessible\.CheckBox : Accessible\.Button/,
  );
  assert.match(action, /active: false/);
  assert.match(action, /cornerRadius: buttonSurface\.cornerRadius/);
  for (const name of ["TileCornerAction.qml", "TileQuickAction.qml"]) {
    const src = qml(name);
    assert.match(src, /Math\.max\(36, hint\.implicitWidth/);
    assert.match(src, /Math\.max\(36, hint\.implicitHeight/);
    assert.match(
      src,
      /(?:shortcut: action\.shortcut|required property Item hint)/,
    );
  }
});

test("visual transforms do not resize pointer or keyboard targets", () => {
  const action = qml("ShellAction.qml");
  const state = qml("StateLayer.qml");
  assert.match(
    action,
    /Item \{\s*id: visualBody\s*anchors.fill: parent\s*transform: Scale/,
  );
  assert.match(action, /effectScaleX: root.bodyScaleX/);
  assert.match(
    state,
    /Item \{\s*parent: root.feedbackParent \|\| root\s*visible: root.visible\s*anchors.fill: parent\s*transform: Scale/,
  );
  assert.match(
    state,
    /function resetPressFeedback\(\): void \{[\s\S]*?rippleOpacity = 0/,
  );
  assert.match(
    state,
    /if \(!root.pressed && !root.keyboardHeld\)\s*fadeRipple.restart\(\)/,
  );
  assert.match(
    qml("SessionActionButton.qml"),
    /id: pointer\s*anchors.fill: surface/,
  );
  assert.match(qml("HubTabs.qml"), /id: backPress\s*anchors.fill: backButton/);
});

test("lightweight state layers share the default press spring and preserve fixed hit geometry", () => {
  const state = qml("StateLayer.qml");
  assert.match(
    state,
    /defaultEffectScale: motion.enabled && showHover && visualPressed/,
  );
  assert.match(state, /effectScaleX: feedbackParent \? 1 : defaultEffectScale/);
  assert.match(state, /effectScaleY: feedbackParent \? 1 : defaultEffectScale/);
  assert.match(state, /Behavior on defaultEffectScale/);
});

test("whole tile visuals share one press geometry and fixed action owners", () => {
  for (const [name, hit] of [
    ["QuickSettingChip.qml", "press"],
    ["ConnectivityTile.qml", "interaction"],
    ["ControlsMediaCard.qml", "cardHit"],
    ["AudioMixerContent.qml", "mixerHit"],
    ["WeatherSummary.qml", "forecastHit"],
  ]) {
    const src = qml(name);
    assert.ok(src.includes(hit + ".defaultEffectScale"), name);
    if (["QuickSettingChip.qml", "ConnectivityTile.qml"].includes(name)) {
      assert.doesNotMatch(src, /TileCornerAction \{/);
      assert.match(src, /manualPress: quickAction/);
    } else {
      assert.match(src, /feedbackParent: visualBody/);
    }
  }
});

test("secondary tile hit feedback stays local and follows the owning tile without a second press transform", () => {
  const action = qml("TileQuickAction.qml");
  assert.match(
    action,
    /id: localFeedback\s*parent: action\.hint\.parent\s*x: action\.x\s*y: action\.y\s*width: action\.width\s*height: action\.height/,
  );
  assert.match(action, /visible: action\.visible && action\.available/);
  assert.match(action, /id: interaction\s*feedbackParent: localFeedback/);
  assert.doesNotMatch(action, /showHover: false|Behavior on scale|KeyHint \{/);
  assert.match(action, /hoverOpacity: 0\.22/);
  assert.match(action, /pressOpacity: 0\.32/);
});

test("direct shortcuts and accessibility use the shared feedback dispatch", () => {
  const state = qml("StateLayer.qml");
  assert.match(
    state,
    /function trigger\(\): void \{\s*if \(!enabled\)\s*return;\s*playPressFeedback\(width \/ 2, height \/ 2\);\s*activated\(null\)/,
  );
  assert.match(qml("ShellAction.qml"), /interaction\.trigger\(\)/);
  assert.match(qml("AudioDeviceControl.qml"), /muteHit\.trigger\(\)/);
  assert.match(qml("AudioStreamControl.qml"), /muteButton\.trigger\(\)/);
  const mixer = qml("AudioMixerContent.qml");
  assert.match(mixer, /outputDevice\.triggerMute\(\)/);
  assert.match(mixer, /inputDevice\.triggerMute\(\)/);
  assert.match(mixer, /row\.control\.triggerMute\(\)/);
});

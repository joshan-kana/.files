const assert = require("node:assert/strict");
const { test } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const shell = path.join(__dirname, "../modules/desktop/hyprland/shell");
const read = (file) => fs.readFileSync(path.join(shell, file), "utf8");
const readScript = (file) =>
  fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/scripts", file),
    "utf8",
  );
const utilities = vm.runInNewContext(
  read("qml/PaletteUtilities.js") +
    "\n({ parseQuicklinks, quicklinkResult, linkUrl, parseSnippets })",
);

test("Quicklinks are declared in Nix, not duplicated inside QML or JavaScript", () => {
  const nix = read("default.nix");
  const qml = read("qml/CommandPalette.qml");
  const runtime = read("qml/RuntimeConfig.qml");
  const aliases = [...nix.matchAll(/alias = "([a-z0-9_-]+)"/g)].map(
    (match) => match[1],
  );
  assert.equal(aliases.length, 29);
  assert.equal(new Set(aliases).size, 29);
  assert.ok(aliases.includes("gl"));
  assert.ok(aliases.includes("gh"));
  assert.ok(aliases.includes("np"));
  for (const prohibited of ["steam", "pcgw", "proton", "ozb", "amazon", "ebay"])
    assert.ok(!aliases.includes(prohibited), prohibited);
  assert.match(nix, /inherit \(scopeConfig\) quicklinks;/);
  assert.match(
    runtime,
    /paletteQuicklinks: root\.configData\.palette\.quicklinks/,
  );
  assert.match(
    qml,
    /quicklinks = PaletteUtilities\.parseQuicklinks\(JSON\.stringify\(runtime\.paletteQuicklinks/,
  );
  assert.match(
    qml,
    /function onLoaded\(\): void \{\s*palette\.refreshDeclaredProviders\(\)/,
  );
  assert.match(
    qml,
    /Component\.onCompleted:\s*\{\s*refreshDeclaredProviders\(\)/,
  );
  assert.doesNotMatch(qml, /quicklinks\.json/);
  assert.doesNotMatch(read("qml/PaletteUtilities.js"), /DEFAULT_QUICKLINKS/);
});

test("Nix Quicklinks with an empty browser setting remain valid", () => {
  const providers = [
    {
      name: "GitLab",
      alias: "gl",
      url: "https://gitlab.com/search?search={query}",
      browser: "",
    },
    {
      name: "GitHub",
      alias: "gh",
      url: "https://github.com/search?q={query}",
      keywords: ["code"],
    },
  ];
  const parsed = utilities.parseQuicklinks(JSON.stringify(providers));
  assert.equal(parsed.length, 2);
  assert.equal(
    utilities.quicklinkResult(parsed[0], "gl nixpkgs").url,
    "https://gitlab.com/search?search=nixpkgs",
  );
  assert.equal(
    utilities.quicklinkResult(parsed[1], "gh nix 2").url,
    "https://github.com/search?q=nix%202",
  );
});

test("Safe URL schemes, aliases and clipboard consent remain enforced", () => {
  const parsed = utilities.parseQuicklinks(
    JSON.stringify([
      { name: "Valid", alias: "ok", url: "https://search.example/?q={query}" },
      {
        name: "Duplicate",
        alias: "ok",
        url: "https://other.example/?q={query}",
      },
      { name: "Unsafe", alias: "js", url: "javascript:alert({query})" },
      {
        name: "Clipboard",
        alias: "clip",
        url: "https://search.example/?q={clipboard}",
      },
    ]),
  );
  assert.equal(parsed.length, 2);
  assert.equal(parsed[1].needsClipboard, true);
  assert.equal(utilities.linkUrl(parsed[1].urlTemplate, ""), "");
  assert.equal(
    utilities.linkUrl(parsed[1].urlTemplate, "", "private text"),
    "https://search.example/?q=private%20text",
  );
});

test("Clipboard quicklink authorization expires when the interaction is dismissed", () => {
  const palette = read("qml/CommandPalette.qml");
  assert.match(
    palette,
    /function invalidateInteraction\(\): void \{\s*interactionGeneration\+\+;\s*pendingClipboardLink = null;/,
  );
  assert.match(
    palette,
    /function hide\(\): void \{[\s\S]*?invalidateInteraction\(\);/,
  );
  assert.match(
    palette,
    /if \(parameterTarget\) \{\s*invalidateInteraction\(\);/,
  );
  assert.match(palette, /palette\.parameterTarget === link/);
  assert.match(
    palette,
    /palette\.clipboardGeneration === palette\.interactionGeneration/,
  );
  assert.match(
    palette,
    /palette\.browserGeneration === palette\.interactionGeneration/,
  );
  assert.match(
    palette,
    /if \(quicklinkClipboardRead\.running \|\| clipboardPending\)/,
  );
  assert.match(
    palette,
    /if \(quicklinkBrowserProcess\.running \|\| browserPending\)/,
  );
  assert.match(
    palette,
    /palette\.fileOpenWithGeneration !== palette\.interactionGeneration/,
  );
  assert.match(
    palette,
    /palette\.calculationGeneration !== palette\.interactionGeneration/,
  );
});

test("Indexer and desktop defaults use the generated runtime configuration", () => {
  const nix = read("default.nix");
  const indexer = readScript("palette-search.py");
  const runtime = read("qml/RuntimeConfig.qml");
  assert.match(nix, /fileRoots = scopeConfig\.fileSearchRoots/);
  assert.match(indexer, /\["palette"\]\["fileRoots"\]/);
  assert.doesNotMatch(indexer, /files\.json/);
  assert.match(runtime, /appearanceDefaults: root\.configData\.appearance/);
  assert.match(nix, /weather\.location = scopeConfig\.weatherLocation/);
  assert.match(
    nix,
    /capture\.freezeEnabled = scopeConfig\.captureFreezeEnabled/,
  );
  assert.match(nix, /silent = scopeConfig\.notificationsSilent/);
  assert.match(nix, /presentation = scopeConfig\.notificationsPresentation/);
  assert.match(
    nix,
    /historyEnabled = scopeConfig\.notificationsHistoryEnabled/,
  );
});

test("User-owned snippets remain higher precedence than Nix defaults", () => {
  const palette = read("qml/CommandPalette.qml");
  assert.match(
    palette,
    /userSnippets === null \? defaultSnippets : userSnippets/,
  );
  assert.match(palette, /snippets\.json/);
  assert.match(
    palette,
    /onLoaded: palette\.userSnippets = PaletteUtilities\.parseSnippets\(text\(\)\)/,
  );
});

test("Preference reset returns control to Nix instead of freezing the old default", () => {
  const store = read("qml/PreferenceStore.qml");
  assert.match(
    store,
    /return has\(key\) \? overrides\[key\] : defaults\[key\]/,
  );
  assert.match(store, /delete next\[key\]/);
  for (const component of [
    "AppearancePreferences",
    "Motion",
    "SessionPanel",
    "ScreenshotPicker",
    "NotificationState",
    "ResourceState",
    "WeatherState",
  ]) {
    assert.match(read("qml/" + component + ".qml"), /PreferenceStore \{/);
  }
});

test("Theme-owned shell presentation is applied through the theme app scope", () => {
  const shellNix = read("default.nix");
  const themeNix = fs.readFileSync(
    path.join(__dirname, "../modules/theme/default.nix"),
    "utf8",
  );
  const runtime = read("qml/RuntimeConfig.qml");

  assert.match(
    themeNix,
    /scopeEdits = \{[\s\S]*?desktop =[\s\S]*?hyprland = \{[\s\S]*?shell = \{[\s\S]*?home =/,
  );
  assert.match(
    themeNix,
    /xdg\.configFile\."desktop-shell\/theme\.json"\.source =[\s\S]*?visual = \{/,
  );
  for (const [name, value] of [
    ["panelOpacity", "1.0"],
    ["focusOpacity", "0.96"],
    ["scrimOpacity", "0.50"],
    ["squircleExponent", "4.5"],
  ]) {
    assert.match(
      themeNix,
      new RegExp(name + " = " + value.replace(".", "\\.")),
    );
    assert.match(
      runtime,
      new RegExp(
        "readonly property real " +
          name +
          ": root\\.themeAdapter\\.visual\\." +
          name,
      ),
    );
  }
  assert.doesNotMatch(shellNix, /shellVisual\s*=/);
  assert.doesNotMatch(shellNix, /visual = shellVisual/);
  assert.doesNotMatch(shellNix, /config\.stylix\.fonts\.monospace\.name/);
  const hyprlandNix = fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/default.nix"),
    "utf8",
  );
  assert.match(
    themeNix,
    /scopeEdits = \{[\s\S]*?desktop =[\s\S]*?hyprland = \{[\s\S]*?stylix\.targets\.hyprland\.hyprpaper\.enable = false/,
  );
  assert.match(
    themeNix,
    /wayland\.windowManager\.hyprland\.settings\.config\.decoration\.shadow = \{/,
  );
  assert.doesNotMatch(hyprlandNix, /stylix\.|lib\.stylix/);
  assert.match(readScript("markup.sh"), /--font-family monospace/);
  assert.equal(
    (runtime.match(/property JsonObject visual: JsonObject/g) || []).length,
    1,
  );
});

test("QML consumes evaluated runtime values without its own default adapter", () => {
  const nix = read("default.nix");
  const qml = read("qml/RuntimeConfig.qml");
  assert.match(qml, /configData: parseConfig\(configFile.text\(\)\)/);
  assert.doesNotMatch(
    qml,
    /property JsonObject appearance:|property JsonObject capture:|property JsonObject motion:/,
  );
  assert.match(nix, /appearance = scopeConfig\.appearance \/\//);
  assert.match(
    nix,
    /blurEnabled = config\.wayland\.windowManager\.hyprland\.settings\.config\.decoration\.blur\.enabled/,
  );
  assert.match(
    nix,
    /blurSize = config\.wayland\.windowManager\.hyprland\.settings\.config\.decoration\.blur\.size/,
  );
  const body = qml
    .split("function parseConfig(text: string): var {")[1]
    .split("\n    }")[0];
  const parseConfig = new Function("text", "Qt", "console", body);
  const groups = [
    "constraints",
    "accessibility",
    "defaults",
    "motion",
    "resourceSampling",
    "session",
    "palette",
    "appearance",
    "capture",
    "notifications",
    "weather",
    "tools",
    "shortcuts",
    "shortcutHints",
    "shellBindings",
    "nightLight",
    "wallpaperRotation",
  ];
  const fixture = Object.fromEntries(groups.map((key) => [key, {}]));
  fixture.keybindings = [];
  const qt = { exit: () => assert.fail("Valid configuration must load") };
  const store = read("qml/PreferenceStore.qml");
  const effectiveBody = store
    .split("function value(key: string): var {")[1]
    .split("\n    }")[0];
  const effective = new Function(
    "key",
    "has",
    "overrides",
    "defaults",
    effectiveBody,
  );
  for (const mode of ["fit", "crop"]) {
    fixture.appearance = {
      wallpaperResizeMode: mode,
      wallpaperSpectrumEnabled: false,
      windowOpacity: 0.63,
    };
    const config = parseConfig(JSON.stringify(fixture), qt, console);
    assert.deepEqual(config, fixture);
    const other = mode === "fit" ? "crop" : "fit";
    const overrides = { wallpaperResizeMode: other };
    assert.equal(
      effective(
        "wallpaperResizeMode",
        () => false,
        overrides,
        config.appearance,
      ),
      mode,
    );
    assert.equal(
      effective(
        "wallpaperResizeMode",
        () => true,
        overrides,
        config.appearance,
      ),
      other,
    );
  }
  let exitCode = 0;
  const badQt = {
    exit: (code) => {
      exitCode = code;
    },
  };
  assert.throws(
    () => parseConfig("{}", badQt, { error() {} }),
    /Missing runtime configuration/,
  );
  assert.equal(exitCode, 1);
  assert.throws(() => parseConfig("not json", badQt, { error() {} }));
});

test("parameter confirmation text follows the palette shortcut registry", () => {
  const palette = read("qml/CommandPalette.qml");
  assert.match(
    palette,
    /"Press " \+ palette\.runtime\.shellHint\("CommandPalette\.confirm"\)/,
  );
  assert.doesNotMatch(
    palette,
    /Press Enter again to confirm|Enter confirms clipboard sharing/,
  );
});

test("runtime bounds follow the supplied configuration instead of fixed literals", () => {
  const qml = read("qml/RuntimeConfig.qml");
  const body = qml
    .split(
      "function bounded(group: string, key: string, value: real): real {",
    )[1]
    .split("\n    }")[0];
  const bounded = new Function("group", "key", "value", "constraints", body);
  for (const max of [2, 4]) {
    const constraints = {
      appearance: { musicReactiveSensitivity: { min: 0.4, max } },
    };
    assert.equal(
      bounded("appearance", "musicReactiveSensitivity", 5, constraints),
      max,
    );
    assert.equal(
      bounded("appearance", "musicReactiveSensitivity", 0, constraints),
      0.4,
    );
  }
});

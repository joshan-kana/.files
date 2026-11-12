const assert = require("node:assert/strict");
const { test } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const shell = path.join(__dirname, "../modules/desktop/hyprland/shell");
const read = (file) => fs.readFileSync(path.join(shell, file), "utf8");
const readScript = (file) =>
  fs.readFileSync(
    path.join(__dirname, "../scripts/linux-desktop", file),
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
  assert.match(qml, /Component\.onCompleted: refreshDeclaredProviders\(\)/);
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
  const appearance = read("qml/AppearancePreferences.qml");
  assert.match(
    appearance,
    /overrideKeys\.includes\(key\) \? saved\[key\] : runtime\.appearanceDefaults\[key\]/,
  );
  assert.match(appearance, /saved\.userOverrides = "\[\]"/);
  for (const component of [
    "Motion",
    "SessionPanel",
    "ScreenshotPicker",
    "NotificationState",
  ]) {
    const source = read("qml/" + component + ".qml");
    assert.match(source, /preferenceSource = "default"/);
    assert.match(source, /preferenceSource = "user"/);
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
    /xdg\.configFile\."linux-desktop\/theme\.json"\.source =[\s\S]*?visual = \{/,
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

test("QML runtime defaults match the native Nix shell option declarations", () => {
  const nix = read("default.nix");
  const qml = read("qml/RuntimeConfig.qml");
  const appearanceNix = nix
    .split("  scopeOptions.appearance = lib.mkOption {")[1]
    .split("  scopeOptions.captureFreezeEnabled")[0];
  const appearanceQml = qml
    .split("            property JsonObject appearance: JsonObject {")[1]
    .split("            property JsonObject capture: JsonObject {")[0];

  const declared = [
    ...appearanceNix.matchAll(
      /^ {8}(\w+) = lib\.mkOption \{\n([\s\S]*?)^ {8}\};/gm,
    ),
  ];
  const adapted = new Map(
    [
      ...appearanceQml.matchAll(
        /^ {16}property (bool|string|real|int) (\w+): ([^\n]+)$/gm,
      ),
    ].map((match) => [match[2], { type: match[1], value: match[3].trim() }]),
  );

  assert.equal(declared.length, 13);
  assert.deepEqual(
    [...adapted.keys()].sort(),
    declared.map((match) => match[1]).sort(),
    "Every appearance field must have exactly one matching QML adapter property",
  );

  for (const [, name, definition] of declared) {
    const type = definition.match(/type = lib\.types\.(bool|str|enum|numbers)/);
    const defaultValue = definition.match(
      /default = (true|false|"[^"]*"|[0-9.]+);/,
    );
    assert.ok(type, name + " must use a recognized native Nix type");
    assert.ok(defaultValue, name + " must declare a Nix default");
    assert.match(
      definition,
      /description = "[^"]+/,
      name + " needs a nixd description",
    );

    const expectedType = {
      bool: "bool",
      str: "string",
      enum: typeof JSON.parse(defaultValue[1]) === "string" ? "string" : "int",
      numbers: "real",
    }[type[1]];
    assert.equal(adapted.get(name).type, expectedType, name + " QML type");
    assert.deepEqual(
      JSON.parse(adapted.get(name).value),
      JSON.parse(defaultValue[1]),
      name + " QML fallback must match the Nix default",
    );
    if (name === "windowOpacity" || name === "glassOpacity") {
      assert.match(
        definition,
        /type = lib\.types\.numbers\.between 0\.2 1\.0;/,
        name + " must use the same inclusive limits as the UI slider",
      );
    }
  }

  // The non-appearance defaults are also repeated in the runtime adapter.
  for (const [option, object, key, qmlType] of [
    ["textScale", "accessibility", "textScale", "real"],
    ["animationsEnabled", "motion", "animationsEnabled", "bool"],
    ["restoreWindowsOnExit", "session", "restoreWindowsOnExit", "bool"],
    ["captureFreezeEnabled", "capture", "freezeEnabled", "bool"],
    ["notificationsSilent", "notifications", "silent", "bool"],
    ["weatherLocation", "weather", "location", "string"],
  ]) {
    const native = nix.match(
      new RegExp(
        "scopeOptions\\." +
          option +
          ' = lib\\.mkOption \\{[\\s\\S]*?default = (true|false|"[^"]*"|[0-9.]+);',
      ),
    );
    const runtime = qml.match(
      new RegExp(
        "property JsonObject " +
          object +
          ": JsonObject \\{\\s*property " +
          qmlType +
          " " +
          key +
          ": ([^\\n]+)",
      ),
    );
    assert.ok(native, option + " Nix declaration");
    assert.ok(runtime, object + "." + key + " QML declaration");
    assert.deepEqual(
      JSON.parse(runtime[1].trim()),
      JSON.parse(native[1]),
      object + "." + key + " default must match native Nix",
    );
  }
});

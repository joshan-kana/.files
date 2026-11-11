const assert = require("node:assert/strict");
const { test } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const shell = path.join(__dirname, "../modules/desktop/hyprland/shell");
const read = (file) => fs.readFileSync(path.join(shell, file), "utf8");
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
    /PaletteUtilities\.parseQuicklinks\(JSON\.stringify\(runtime\.paletteQuicklinks/,
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

test("Indexer and desktop defaults use the generated runtime configuration", () => {
  const nix = read("default.nix");
  const indexer = read("scripts/palette-search.py");
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
  assert.match(nix, /notifications\.silent = scopeConfig\.notificationsSilent/);
});

test("User-owned snippets remain higher precedence than Nix defaults", () => {
  const palette = read("qml/CommandPalette.qml");
  assert.match(
    palette,
    /userSnippets === null \? PaletteUtilities\.parseSnippets\(JSON\.stringify\(runtime\.paletteSnippets/,
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

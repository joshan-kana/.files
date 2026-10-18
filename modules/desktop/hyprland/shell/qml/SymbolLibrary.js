// Small local index; symbols are only searched when the user selects this mode.
const entries = [
  ["😀", "grinning", "smile happy face"],
  ["😂", "laughing", "tears joy funny"],
  ["🥰", "loving", "heart smile affectionate"],
  ["😎", "cool", "sunglasses"],
  ["🥲", "smiling tear", "sad relieved"],
  ["😭", "crying", "tears sad"],
  ["🙃", "upside down", "sarcasm"],
  ["😴", "sleeping", "tired zzz"],
  ["🤔", "thinking", "ponder question"],
  ["🤯", "mind blown", "surprised"],
  ["💀", "skull", "dead"],
  ["👀", "eyes", "look watching"],
  ["👍", "thumbs up", "yes approve"],
  ["👎", "thumbs down", "no disapprove"],
  ["👏", "clapping", "applause"],
  ["🙏", "thanks", "please prayer"],
  ["🤝", "handshake", "agreement"],
  ["🫡", "saluting", "respect"],
  ["💡", "light bulb", "idea"],
  ["✨", "sparkles", "glitter"],
  ["🔥", "fire", "hot"],
  ["❤️", "heart", "love red"],
  ["💛", "yellow heart", "love"],
  ["💚", "green heart", "love"],
  ["⚡", "lightning", "electric fast"],
  ["🌈", "rainbow", "colour"],
  ["🌙", "crescent moon", "night"],
  ["☀️", "sun", "bright day"],
  ["☁️", "cloud", "weather"],
  ["🌧️", "rain", "weather"],
  ["🎵", "music note", "audio song"],
  ["🎧", "headphones", "audio"],
  ["🎮", "gamepad", "gaming"],
  ["🚀", "rocket", "launch"],
  ["🛠️", "tools", "settings engineering"],
  ["📋", "clipboard", "paste"],
  ["📁", "folder", "files"],
  ["💻", "laptop", "computer"],
  ["✔", "check mark", "tick done success"],
  ["✓", "check", "tick"],
  ["✕", "cross", "close x"],
  ["✗", "cross mark", "no error"],
  ["→", "right arrow", "next forward"],
  ["←", "left arrow", "back previous"],
  ["↑", "up arrow", "above"],
  ["↓", "down arrow", "below"],
  ["↗", "up right arrow", "diagonal external"],
  ["↔", "left right arrow", "horizontal"],
  ["↕", "up down arrow", "vertical"],
  ["∞", "infinity", "endless"],
  ["≈", "approximately", "math about"],
  ["≠", "not equal", "math"],
  ["≤", "less equal", "math"],
  ["≥", "greater equal", "math"],
  ["±", "plus minus", "math"],
  ["×", "multiply", "math"],
  ["÷", "divide", "math"],
  ["°", "degree", "angle temperature"],
  ["©", "copyright", "legal"],
  ["®", "registered", "legal"],
  ["™", "trademark", "legal"],
  ["•", "bullet", "list dot"],
  ["…", "ellipsis", "dots"],
  ["—", "em dash", "punctuation"],
  ["✦", "star", "hyper modifier"],
  ["✣", "flower star", "meh modifier"],
  ["⌘", "command", "mac modifier"],
  ["⌥", "option", "alt modifier"],
  ["⇧", "shift", "modifier"],
  ["⌃", "control", "modifier"],
  ["⏎", "return", "enter key"],
];

// Unicode's CLDR-ordered, fully-qualified emoji data comes from Nixpkgs.
// Only parse on source-load, never on each keystroke.
function parseUnicode(content) {
  const result = [];
  const seen = new Set();
  let category = "";
  for (const line of content.split("\n")) {
    if (line.startsWith("# group: ")) {
      category = line.slice(9);
      continue;
    }
    if (!line.includes("fully-qualified")) continue;
    const match = line.match(
      /;\s*fully-qualified\s*#\s*(\S+)\s+E[0-9.]+\s+(.+)$/,
    );
    if (!match || seen.has(match[1])) continue;
    seen.add(match[1]);
    const name = match[2].trim();
    result.push({
      kind: "symbol",
      name: match[1] + "  " + name,
      genericName: category,
      glyph: match[1],
      result: match[1],
      searchName: name.toLowerCase(),
      searchKeys: category.toLowerCase(),
      icon: "",
      key: "COPY",
    });
  }
  return result;
}

const curated = entries.map((entry) => ({
  kind: "symbol",
  name: entry[0] + "  " + entry[1],
  genericName: entry[2],
  glyph: entry[0],
  result: entry[0],
  searchName: entry[1].toLowerCase(),
  searchKeys: entry[2].toLowerCase(),
  icon: "",
  key: "COPY",
}));

function matches(term, entry, allowFuzzy) {
  const name = entry.searchName;
  const keys = entry.searchKeys;
  if (name === term || entry.glyph === term) return 0;
  if (name.startsWith(term)) return 10;
  if (name.includes(" " + term) || name.includes(": " + term)) return 15;
  if (name.includes(term)) return 20;
  if (keys.startsWith(term) || keys.includes(" " + term)) return 30;
  if (keys.includes(term)) return 35;
  if (!allowFuzzy) return Infinity;

  let cursor = 0;
  let penalty = 0;
  for (const character of term) {
    const found = name.indexOf(character, cursor);
    if (found < 0) return Infinity;
    penalty += found - cursor;
    cursor = found + 1;
  }
  return 70 + penalty;
}

// A bounded results model is essential: ScriptModel synchronously diffs all
// entries whenever TextInput changes. Deduplicate only when the data changes.
const maxResults = 64;
let indexedUnicode = null;
let prepared = [];
let previousQuery = "";
let previousResults = [];

function prepare(unicodeEntries) {
  if (indexedUnicode === unicodeEntries) return;
  indexedUnicode = unicodeEntries;
  const seen = new Set();
  prepared = [];
  for (const entry of curated.concat(unicodeEntries || [])) {
    if (seen.has(entry.glyph)) continue;
    seen.add(entry.glyph);
    prepared.push(entry);
  }
  previousQuery = "";
  previousResults = [];
}

function search(term, unicodeEntries) {
  const query = (term || "").trim().toLowerCase();
  prepare(unicodeEntries);
  if (!query) return prepared.slice(0, maxResults);
  if (query === previousQuery) return previousResults;

  function ranked(fuzzy) {
    const results = [];
    for (const entry of prepared) {
      const rank = matches(query, entry, fuzzy);
      if (Number.isFinite(rank) && (fuzzy ? rank < 83 : rank < 70))
        results.push({ entry, rank });
    }
    results.sort(
      (a, b) =>
        a.rank - b.rank || a.entry.searchName.localeCompare(b.entry.searchName),
    );
    return results.slice(0, maxResults).map((item) => item.entry);
  }

  const exact = ranked(false);
  previousQuery = query;
  previousResults =
    exact.length === 0 && query.length >= 3 ? ranked(true) : exact;
  return previousResults;
}

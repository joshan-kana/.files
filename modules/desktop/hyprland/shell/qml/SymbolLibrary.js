// Small local index; symbols are only searched when the user selects this mode.
const entries = [
    ["😀", "grinning", "smile happy face"], ["😂", "laughing", "tears joy funny"],
    ["🥰", "loving", "heart smile affectionate"], ["😎", "cool", "sunglasses"],
    ["🥲", "smiling tear", "sad relieved"], ["😭", "crying", "tears sad"],
    ["🙃", "upside down", "sarcasm"], ["😴", "sleeping", "tired zzz"],
    ["🤔", "thinking", "ponder question"], ["🤯", "mind blown", "surprised"],
    ["💀", "skull", "dead"], ["👀", "eyes", "look watching"],
    ["👍", "thumbs up", "yes approve"], ["👎", "thumbs down", "no disapprove"],
    ["👏", "clapping", "applause"], ["🙏", "thanks", "please prayer"],
    ["🤝", "handshake", "agreement"], ["🫡", "saluting", "respect"],
    ["💡", "light bulb", "idea"], ["✨", "sparkles", "glitter"],
    ["🔥", "fire", "hot"], ["❤️", "heart", "love red"],
    ["💛", "yellow heart", "love"], ["💚", "green heart", "love"],
    ["⚡", "lightning", "electric fast"], ["🌈", "rainbow", "colour"],
    ["🌙", "crescent moon", "night"], ["☀️", "sun", "bright day"],
    ["☁️", "cloud", "weather"], ["🌧️", "rain", "weather"],
    ["🎵", "music note", "audio song"], ["🎧", "headphones", "audio"],
    ["🎮", "gamepad", "gaming"], ["🚀", "rocket", "launch"],
    ["🛠️", "tools", "settings engineering"], ["📋", "clipboard", "paste"],
    ["📁", "folder", "files"], ["💻", "laptop", "computer"],
    ["✔", "check mark", "tick done success"], ["✓", "check", "tick"],
    ["✕", "cross", "close x"], ["✗", "cross mark", "no error"],
    ["→", "right arrow", "next forward"], ["←", "left arrow", "back previous"],
    ["↑", "up arrow", "above"], ["↓", "down arrow", "below"],
    ["↗", "up right arrow", "diagonal external"], ["↔", "left right arrow", "horizontal"],
    ["↕", "up down arrow", "vertical"], ["∞", "infinity", "endless"],
    ["≈", "approximately", "math about"], ["≠", "not equal", "math"],
    ["≤", "less equal", "math"], ["≥", "greater equal", "math"],
    ["±", "plus minus", "math"], ["×", "multiply", "math"],
    ["÷", "divide", "math"], ["°", "degree", "angle temperature"],
    ["©", "copyright", "legal"], ["®", "registered", "legal"],
    ["™", "trademark", "legal"], ["•", "bullet", "list dot"],
    ["…", "ellipsis", "dots"], ["—", "em dash", "punctuation"],
    ["✦", "star", "hyper modifier"],
    ["✣", "flower star", "meh modifier"], ["⌘", "command", "mac modifier"],
    ["⌥", "option", "alt modifier"], ["⇧", "shift", "modifier"],
    ["⌃", "control", "modifier"], ["⏎", "return", "enter key"]
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
        if (!line.includes("fully-qualified"))
            continue;
        const match = line.match(/;\s*fully-qualified\s*#\s*(\S+)\s+E[0-9.]+\s+(.+)$/);
        if (!match || seen.has(match[1]))
            continue;
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
            key: "COPY"
        });
    }
    return result;
}

const curated = entries.map(entry => ({
    kind: "symbol",
    name: entry[0] + "  " + entry[1],
    genericName: entry[2],
    glyph: entry[0],
    result: entry[0],
    searchName: entry[1].toLowerCase(),
    searchKeys: entry[2].toLowerCase(),
    icon: "",
    key: "COPY"
}));

function matches(term, entry, allowFuzzy) {
    const name = entry.searchName;
    const keys = entry.searchKeys;
    if (name === term || entry.glyph === term)
        return 0;
    if (name.startsWith(term))
        return 10;
    if (name.includes(" " + term) || name.includes(": " + term))
        return 15;
    if (name.includes(term))
        return 20;
    if (keys.startsWith(term) || keys.includes(" " + term))
        return 30;
    if (keys.includes(term))
        return 35;
    if (!allowFuzzy)
        return Infinity;

    let cursor = 0;
    let penalty = 0;
    for (const character of term) {
        const found = name.indexOf(character, cursor);
        if (found < 0)
            return Infinity;
        penalty += found - cursor;
        cursor = found + 1;
    }
    return 70 + penalty;
}

function search(term, unicodeEntries) {
    const query = (term || "").trim().toLowerCase();
    if (!query)
        return curated.slice(0, 9);

    // Keep a bounded top nine; repeated full sorts would steal animation frames.
    const extra = unicodeEntries || [];
    const best = [];
    const seen = new Set();
    function insert(entry, score) {
        let at = best.findIndex(previous => previous.score > score);
        if (at === -1)
            at = best.length;
        if (at < 9) {
            best.splice(at, 0, { entry, score });
            if (best.length > 9)
                best.pop();
        }
    }
    function collect(fuzzy) {
        best.length = 0;
        seen.clear();
        for (const entries of [curated, extra]) {
            for (const entry of entries) {
                if (seen.has(entry.glyph))
                    continue;
                seen.add(entry.glyph);
                const score = matches(query, entry, fuzzy);
                if (Number.isFinite(score) && (fuzzy ? score < 83 : score < 70))
                    insert(entry, score);
            }
        }
    }
    collect(false);
    // Fuzzy results are fallback, not padding beneath a strong match.
    if (best.length === 0 && query.length >= 3)
        collect(true);
    const threshold = best.length > 0 && best[0].score >= 70 ? best[0].score + 2 : Infinity;
    return best.filter(item => item.score <= threshold).map(item => item.entry);
}

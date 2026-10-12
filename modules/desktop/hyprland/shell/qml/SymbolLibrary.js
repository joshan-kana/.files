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

function search(term) {
    const query = (term || "").toLowerCase();
    return entries.filter(entry => !query || (entry[1] + " " + entry[2] + " " + entry[0]).toLowerCase().includes(query)).slice(0, 9).map(entry => ({
        kind: "symbol", name: entry[0] + "  " + entry[1], genericName: entry[2], glyph: entry[0], result: entry[0], icon: "", key: "COPY"
    }));
}

// Present modifiers compactly without changing shortcut registration or search data.
function display(value) {
    return String(value || "")
        .replace(/\bCTRL\s*\+\s*ALT\s*\+\s*SHIFT\s*\+\s*/gi, "✣")
        .replace(/\bSUPER\s*\+\s*/gi, "✦")
        .replace(/\bCTRL\s*\+\s*/gi, "∧")
        .replace(/\bALT\s*\+\s*/gi, "⌥")
        .replace(/\bSHIFT\s*\+\s*/gi, "⬆")
        .replace(/([✦✣∧⌥⬆]+)(?=\S)/g, "$1 ");
}

// Preserve the exact registered shortcut for search/dispatch, but allow the
// glyphs and final key to have independent optical sizes in compact keycaps.
function parts(value) {
    const raw = String(value || "");
    const matched = raw.match(/^((?:(?:SUPER|CTRL|ALT|SHIFT)\s*\+\s*)+)(.*)$/i);
    if (!matched)
        return { modifiers: "", key: display(raw) };
    return {
        modifiers: display(matched[1]).replace(/\s+/g, ""),
        key: display(matched[2]).trim()
    };
}

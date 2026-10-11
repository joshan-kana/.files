// Present modifiers compactly without changing shortcut registration or search data.
function display(value) {
    return String(value || "")
        .replace(/\bSUPER\s*\+\s*/gi, "⊞")
        .replace(/\bCTRL\s*\+\s*/gi, "⌃")
        .replace(/\bALT\s*\+\s*/gi, "⌥")
        .replace(/\bSHIFT\s*\+\s*/gi, "⇧");
}

// Keyboard translation only. Physical assignments and action hints live in
// shell/keybindings.nix, and are generated into the shell runtime config.
function assigned(registry, scope, slot) {
  const overrides = registry?.overrides?.[scope];
  return String(overrides?.[slot] ?? registry?.base?.[slot] ?? "");
}

function codeFor(value, qt) {
  const spec = value.toUpperCase();
  if (spec.length === 1 && /[A-Z0-9]/.test(spec)) return spec.charCodeAt(0);
  const names = {
    ESC: qt.Key_Escape,
    ENTER: qt.Key_Return,
    NUMENTER: qt.Key_Enter,
    TAB: qt.Key_Tab,
    "SHIFT+TAB": qt.Key_Backtab,
    BACKSPACE: qt.Key_Backspace,
    SPACE: qt.Key_Space,
    DEL: qt.Key_Delete,
    UP: qt.Key_Up,
    DOWN: qt.Key_Down,
    LEFT: qt.Key_Left,
    RIGHT: qt.Key_Right,
    PGUP: qt.Key_PageUp,
    PGDN: qt.Key_PageDown,
    SHIFT: qt.Key_Shift,
    ALT: qt.Key_Alt,
    CTRL: qt.Key_Control,
    SUPER: qt.Key_Meta,
    ALTGR: qt.Key_AltGr,
    "/": qt.Key_Slash,
    "?": qt.Key_Question,
    "-": qt.Key_Minus,
    _: qt.Key_Underscore,
    "+": qt.Key_Plus,
    "=": qt.Key_Equal,
    "[": qt.Key_BracketLeft,
    "]": qt.Key_BracketRight,
    ",": qt.Key_Comma,
    ".": qt.Key_Period,
  };
  return names[spec] ?? -1;
}

function keyCode(registry, scope, slot, qt) {
  return codeFor(assigned(registry, scope, slot), qt);
}

function modifier(registry, scope, slot, mask, qt) {
  const spec = assigned(registry, scope, slot).toUpperCase();
  const bits = {
    SHIFT: qt.ShiftModifier,
    ALT: qt.AltModifier,
    CTRL: qt.ControlModifier,
    SUPER: qt.MetaModifier,
  };
  return !!(mask & (bits[spec] ?? 0));
}

function hint(registry, action) {
  const entry = registry?.hints?.[action];
  if (!entry) return "";
  const scope = entry.scope;
  if (entry.literal === true) return entry.template;
  const render = (name) => assigned(registry, scope, name);
  const single = {
    "/": "Slash",
    "?": "Question",
    "-": "Minus",
    "+": "Plus",
    "=": "Equal",
    "[": "BracketLeft",
    "]": "BracketRight",
  };
  if (entry.template in single) return render(single[entry.template]);
  if (entry.template === "[ / ]")
    return `${render("BracketLeft")} / ${render("BracketRight")}`;
  if (entry.template === "1–0") {
    const workspaceKeys = [
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      "0",
    ].map(render);
    return workspaceKeys.join("") === "1234567890"
      ? "1–0"
      : workspaceKeys.join("/");
  }
  const arrows = ["Left", "Up", "Down", "Right"].map(render);
  const renderGroup = (group) => {
    const keys = group.split("").map(render);
    return keys.every((key) => key.length === 1)
      ? keys.join("")
      : keys.join("/");
  };
  // Long special-key names and action descriptions must never be split into
  // independently remappable letters. Only registered key tokens are resolved.
  const text = entry.template.replace(/[↑↓←→⇧]/g, (glyph) => {
    const slot = {
      "↑": "Up",
      "↓": "Down",
      "←": "Left",
      "→": "Right",
      "⇧": "Shift",
    }[glyph];
    const value = render(slot);
    const original = {
      Up: "UP",
      Down: "DOWN",
      Left: "LEFT",
      Right: "RIGHT",
      Shift: "SHIFT",
    }[slot];
    return value === original ? glyph : value;
  });
  return text.replace(
    /BACKSPACE|ARROWS|HJKL|PGUP|PGDN|SHIFT|CTRL|ALT|ESC|ENTER|SPACE|TAB|DEL|[A-Z0-9]/g,
    (token) => {
      if (token === "ARROWS")
        return arrows.join("/") === "LEFT/UP/DOWN/RIGHT"
          ? "ARROWS"
          : arrows.join("/");
      if (token === "HJKL") return renderGroup(token);
      const alias = {
        PGUP: "PageUp",
        PGDN: "PageDown",
        ESC: "Escape",
        ENTER: "Return",
        SPACE: "Space",
        TAB: "Tab",
        SHIFT: "Shift",
        CTRL: "Control",
        ALT: "Alt",
        BACKSPACE: "Backspace",
        DEL: "Delete",
      };
      return render(alias[token] ?? token) || token;
    },
  );
}

function sequence(registry, action) {
  return hint(registry, action)
    .replace(/\bESC\b/g, "Esc")
    .replace(/\bPGUP\b/g, "PgUp")
    .replace(/\bPGDN\b/g, "PgDown")
    .replace(/\bCTRL\b/g, "Ctrl")
    .replace(/\bSHIFT\b/g, "Shift")
    .replace(/\bALT\b/g, "Alt")
    .replace(/\bSUPER\b/g, "Meta")
    .replace(/\bSPACE\b/g, "Space")
    .replace(/\bNUMENTER\b/g, "Enter");
}

function matchesHint(registry, action, key, modifiers, qt) {
  const entry = registry?.hints?.[action];
  if (!entry || !/^(?:SHIFT\+|ALT\+|CTRL\+)?[A-Z0-9]$/.test(entry.template))
    return false;
  const parts = entry.template.split("+");
  const slot = parts.pop();
  if (key !== keyCode(registry, entry.scope, slot, qt)) return false;
  const expected = parts.reduce(
    (mask, name) =>
      mask |
      ({
        SHIFT: qt.ShiftModifier,
        ALT: qt.AltModifier,
        CTRL: qt.ControlModifier,
        SUPER: qt.MetaModifier,
      }[
        assigned(
          registry,
          entry.scope,
          { SHIFT: "Shift", ALT: "Alt", CTRL: "Control" }[name],
        ).toUpperCase()
      ] ?? 0),
    0,
  );
  return (
    (modifiers &
      (qt.ShiftModifier |
        qt.AltModifier |
        qt.ControlModifier |
        qt.MetaModifier)) ===
    expected
  );
}

// Numbered actions can be rearranged without requiring contiguous Qt keycodes.
function numberIndex(registry, scope, key, count, qt) {
  for (let index = 0; index < count; ++index)
    if (key === keyCode(registry, scope, String(index + 1), qt)) return index;
  return -1;
}

function numberHint(registry, scope, index) {
  return assigned(registry, scope, String(index + 1));
}

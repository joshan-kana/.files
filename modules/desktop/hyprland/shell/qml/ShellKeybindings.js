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

// Direction slots are declared once in Hyprland keybindings.nix. Text input can opt
// into arrow-only handling so letters remain available for typing.
function navigates(registry, scope, direction, key, qt, mode = "all") {
  const slots = registry?.navigation?.[direction] ?? [];
  const selected =
    mode === "arrows"
      ? slots.slice(1)
      : mode === "primary"
        ? slots.slice(0, 1)
        : slots;
  return selected.some((slot) => keyCode(registry, scope, slot, qt) === key);
}

const navigationDirections = {
  HORIZONTAL: ["left", "right"],
  VERTICAL: ["down", "up"],
  ALL: ["left", "down", "up", "right"],
};

function navigationHint(registry, scope, token) {
  const shifted = token.endsWith("_SHIFT");
  const primaryOnly = token.includes("_PRIMARY");
  const arrowsOnly = token.includes("_ARROWS");
  const axis = token
    .replace(/^NAV_/, "")
    .replace(/_(?:PRIMARY|ARROWS|SHIFT)/g, "");
  const directions = navigationDirections[axis] ?? [];
  const groups = arrowsOnly ? [1] : primaryOnly ? [0] : [0, 1];
  return groups
    .map((index) => {
      const names = directions.map(
        (direction) => registry.navigation[direction][index],
      );
      const keys = names.map((name) => {
        const value = assigned(registry, scope, name);
        return (
          { LEFT: "←", RIGHT: "→", UP: "↑", DOWN: "↓" }[value.toUpperCase()] ??
          value
        );
      });
      return (
        (shifted ? assigned(registry, scope, "Shift") + "+" : "") +
        keys.join("/")
      );
    })
    .join(" · ");
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

function actionAssignment(registry, action) {
  const explicit = registry?.actions?.[action];
  return typeof explicit === "string" ? explicit.toUpperCase() : "";
}

function hint(registry, action) {
  const explicit = actionAssignment(registry, action);
  if (explicit) return explicit;
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
  // Resolve every original token once. Replacing an arrow glyph before
  // positional keys could remap its replacement a second time.
  return entry.template.replace(
    /NAV_KEY_(?:UP|DOWN|LEFT|RIGHT)_(?:PRIMARY(?:_SHIFT)?|ARROW)|NAV_(?:HORIZONTAL|VERTICAL|ALL)(?:_PRIMARY)?(?:_ARROWS)?(?:_SHIFT)?|BACKSPACE|PGUP|PGDN|SHIFT|CTRL|ALT|ESC|ENTER|SPACE|TAB|DEL|[↑↓←→⇧]|[A-Z0-9]/g,
    (token) => {
      if (token.startsWith("NAV_KEY_")) {
        const [, , direction, variant] = token.split("_");
        const index = variant === "PRIMARY" ? 0 : 1;
        const slot = registry.navigation[direction.toLowerCase()][index];
        const value = render(slot);
        const label =
          { UP: "Up", DOWN: "Down", LEFT: "Left", RIGHT: "Right" }[
            value.toUpperCase()
          ] ?? value;
        return token.endsWith("_SHIFT") ? render("Shift") + "+" + label : label;
      }
      if (token.startsWith("NAV_"))
        return navigationHint(registry, scope, token);
      const direction = {
        "↑": "Up",
        "↓": "Down",
        "←": "Left",
        "→": "Right",
        "⇧": "Shift",
      }[token];
      if (direction) {
        const rendered = render(direction);
        const original = {
          Up: "UP",
          Down: "DOWN",
          Left: "LEFT",
          Right: "RIGHT",
          Shift: "SHIFT",
        }[direction];
        return rendered === original ? token : rendered;
      }
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
  const explicit = actionAssignment(registry, action);
  if (explicit) {
    const parts = explicit.split("+");
    const assignedKey = parts.pop();
    const modifiersByName = {
      SHIFT: qt.ShiftModifier,
      ALT: qt.AltModifier,
      CTRL: qt.ControlModifier,
      SUPER: qt.MetaModifier,
    };
    const bits =
      qt.ShiftModifier | qt.AltModifier | qt.ControlModifier | qt.MetaModifier;
    if (
      codeFor(assignedKey, qt) !== key ||
      parts.some((name) => !(name in modifiersByName))
    )
      return false;
    const expected = parts.reduce(
      (mask, name) => mask | modifiersByName[name],
      0,
    );
    return (modifiers & bits) === expected;
  }
  const entry = registry?.hints?.[action];
  // A single action may use a named key or a directional slot as well as
  // a letter. Multi-action legends are display-only.
  if (
    !entry ||
    !/^(?:(?:SHIFT|ALT|CTRL|SUPER)\+)*(?:[A-Z0-9]|ENTER|NUMENTER|ESC|BACKSPACE|SPACE|TAB|DEL|PGUP|PGDN|NAV_KEY_(?:UP|DOWN|LEFT|RIGHT)_(?:PRIMARY(?:_SHIFT)?|ARROW))$/.test(
      entry.template,
    )
  )
    return false;
  const parts = hint(registry, action).toUpperCase().split("+");
  const assignedKey = parts.pop();
  const modifiersByName = {
    SHIFT: qt.ShiftModifier,
    ALT: qt.AltModifier,
    CTRL: qt.ControlModifier,
    SUPER: qt.MetaModifier,
  };
  if (
    codeFor(assignedKey, qt) !== key ||
    parts.some((name) => !(name in modifiersByName))
  )
    return false;
  const expected = parts.reduce(
    (mask, name) => mask | modifiersByName[name],
    0,
  );
  const bits =
    qt.ShiftModifier | qt.AltModifier | qt.ControlModifier | qt.MetaModifier;
  return (modifiers & bits) === expected;
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

function widgetChoiceHint(registry, index) {
  return registry?.widgetChoices?.[index] || "";
}

function widgetChoiceIndex(registry, key, modifiers, count, qt) {
  const bits = qt.ShiftModifier | qt.ControlModifier | qt.AltModifier | qt.MetaModifier;
  for (let index = 0; index < count; ++index) {
    const slot = widgetChoiceHint(registry, index);
    if (!/^(?:SHIFT\+)?[A-Z]$/.test(slot)) continue;
    const expected = slot.startsWith("SHIFT+") ? qt.ShiftModifier : 0;
    if ((modifiers & bits) === expected && key === codeFor(slot.split("+").pop(), qt)) return index;
  }
  return -1;
}

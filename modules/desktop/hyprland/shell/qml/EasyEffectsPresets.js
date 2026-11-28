// EasyEffects CLI emits numbered local preset names in separate pipeline sections.
function parsePresets(text) {
  const byName = new Map();
  const seen = new Set();
  let pipeline = "";
  for (const line of text.split(/\r?\n/)) {
    if (/^(Output|Input) presets:\s*$/i.test(line)) {
      pipeline = line.split(" ")[0].toLowerCase();
      seen.add(pipeline);
      continue;
    }
    const empty = /^No (output|input) presets\.\s*$/i.exec(line);
    if (empty) {
      seen.add(empty[1].toLowerCase());
      pipeline = "";
      continue;
    }
    const entry = /^\d+\t(.+)$/.exec(line);
    if (!entry || !pipeline) continue;
    const name = entry[1].trim();
    if (!name) continue;
    const preset = byName.get(name) || { name, input: false, output: false };
    preset[pipeline] = true;
    byName.set(name, preset);
  }
  return seen.size === 2
    ? Array.from(byName.values()).sort((a, b) => a.name.localeCompare(b.name))
    : null;
}

function parseActive(text) {
  const result = {};
  for (const line of text.split(/\r?\n/)) {
    const match = /^(input|output):\s*(.*)$/i.exec(line);
    if (match) result[match[1].toLowerCase()] = match[2].trim();
  }
  return Object.prototype.hasOwnProperty.call(result, "input") &&
    Object.prototype.hasOwnProperty.call(result, "output")
    ? result
    : null;
}

function confirmed(preset, active) {
  return (
    !!active &&
    (!preset.input || active.input === preset.name) &&
    (!preset.output || active.output === preset.name)
  );
}

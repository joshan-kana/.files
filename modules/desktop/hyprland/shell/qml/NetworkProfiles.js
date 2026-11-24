// Saved profile changes are staged, allow-listed, and never reactivate a link.
function editableFields(kind) {
  const fields = [
    {
      key: "connection.autoconnect",
      label: "Auto-connect",
      choices: ["yes", "no"],
    },
    {
      key: "connection.autoconnect-priority",
      label: "Connection priority",
      minimum: -999,
      maximum: 999,
    },
    {
      key: "connection.metered",
      label: "Metered",
      choices: ["unknown", "yes", "no"],
    },
  ];
  if (kind === "802-11-wireless" || kind === "802-3-ethernet") {
    for (const family of ["ipv4", "ipv6"]) {
      fields.push({
        key: family + ".ignore-auto-dns",
        label: family.toUpperCase() + " ignore automatic DNS",
        choices: ["yes", "no"],
      });
      fields.push({
        key: family + ".dns",
        label: family.toUpperCase() + " DNS servers",
      });
    }
  }
  return fields;
}
function splitLine(line) {
  const result = [];
  let field = "",
    escaped = false;
  for (const ch of line) {
    if (escaped) {
      field += ch;
      escaped = false;
    } else if (ch === "\\") escaped = true;
    else if (ch === ":") {
      result.push(field);
      field = "";
    } else field += ch;
  }
  result.push(field);
  return result;
}
function parseProfile(output, fields) {
  const values = {};
  for (const line of output.split("\n")) {
    const parts = splitLine(line);
    if (fields.some((field) => field.key === parts[0])) {
      let value = parts.slice(1).join(":").trim();
      if (value === "--") value = "";
      if (parts[0] === "connection.metered")
        value =
          { 0: "unknown", 1: "yes", 2: "no" }[value.split(" ")[0]] || value;
      values[parts[0]] = value;
    }
  }
  return values;
}
function modification(uuid, fields, original, draft) {
  if (
    !/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(
      uuid,
    )
  )
    throw new Error("Invalid profile UUID");
  const args = ["connection", "modify", "uuid", uuid];
  for (const field of fields) {
    const value = String(draft[field.key] ?? "");
    if (value === String(original[field.key] ?? "")) continue;
    if (field.choices && !field.choices.includes(value))
      throw new Error("Invalid " + field.label);
    if (
      field.minimum !== undefined &&
      (!/^-?\d+$/.test(value) ||
        Number(value) < field.minimum ||
        Number(value) > field.maximum)
    )
      throw new Error("Invalid " + field.label);
    if (value.length > 512 || /[\r\n\x00]/.test(value))
      throw new Error("Invalid " + field.label);
    args.push(field.key, value);
  }
  return args;
}

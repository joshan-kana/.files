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

// NetworkManager owns the probe URI, policy and connectivity classification.
// A cached/full connectivity state is not proof that a probe was enabled.
function connectivityPolicy(output) {
  try {
    const rows = output
      .trim()
      .split("\n")
      .map((row) => JSON.parse(row));
    if (
      rows.length !== 2 ||
      !rows.every((row) => row.type === "b" && typeof row.data === "boolean")
    )
      return null;
    return { available: rows[0].data, enabled: rows[1].data };
  } catch (_) {
    return null;
  }
}
function connectivityResult(output) {
  try {
    const reply = JSON.parse(output);
    if (
      reply.type !== "u" ||
      !Array.isArray(reply.data) ||
      reply.data.length !== 1
    )
      return null;
    return (
      {
        0: "Unknown connectivity",
        1: "No network connectivity",
        2: "Captive portal detected",
        3: "Limited connectivity",
        4: "Full connectivity",
      }[reply.data[0]] || null
    );
  } catch (_) {
    return null;
  }
}

// A filesystem's capacity and the backing block device's I/O are distinct.
function filesystems(raw) {
  try {
    const rows = JSON.parse(raw).filesystems;
    if (!Array.isArray(rows)) return [];
    const seen = new Set();
    return rows
      .filter(
        (row) =>
          typeof row.target === "string" &&
          typeof row.source === "string" &&
          row.source.startsWith("/dev/"),
      )
      .sort((a, b) =>
        a.target === "/"
          ? -1
          : b.target === "/"
            ? 1
            : a.target.localeCompare(b.target),
      )
      .filter((row) => {
        const source = row.source.split("[")[0];
        if (seen.has(source)) return false;
        seen.add(source);
        return true;
      })
      .map((row) => ({
        target: row.target,
        source: row.source.split("[")[0],
        device: row["maj:min"],
        fstype: row.fstype,
      }));
  } catch (_) {
    return [];
  }
}

function counters(raw, filesystem) {
  if (!filesystem) return null;
  const rows = raw
    .trim()
    .split("\n")
    .map((line) => line.trim().split(/\s+/));
  // A virtual filesystem device number is not necessarily a block device.
  // An explicit kernel device path from findmnt (e.g. /dev/sda2 on Btrfs)
  // identifies that device's I/O, not an aggregate for the filesystem.
  const direct = /^\/dev\/([^/]+)$/.exec(filesystem.source || "");
  const row =
    rows.find((fields) => fields[0] + ":" + fields[1] === filesystem.device) ||
    (direct ? rows.find((fields) => fields[2] === direct[1]) : null);
  if (!row || row.length < 14) return null;
  const read = Number(row[5]),
    write = Number(row[9]);
  if (!Number.isFinite(read) || !Number.isFinite(write)) return null;
  return { read: read * 512, write: write * 512 };
}

function rates(previous, current, elapsed) {
  if (
    !previous ||
    !current ||
    elapsed <= 0 ||
    current.read < previous.read ||
    current.write < previous.write
  )
    return null;
  return {
    read: (current.read - previous.read) / elapsed,
    write: (current.write - previous.write) / elapsed,
  };
}

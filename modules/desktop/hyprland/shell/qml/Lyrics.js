// Minimal deterministic LRC parser. No provider, network traffic or text export.
function parse(source) {
  const rows = [];
  if (typeof source !== "string" || source.length > 262144) return rows;
  for (const line of source.split(/\r?\n/)) {
    const marks = [];
    const pattern = /\[(\d{1,3}):(\d{2})(?:\.(\d{1,3}))?\]/g;
    let match;
    while ((match = pattern.exec(line)) !== null) marks.push(match);
    if (marks.length === 0) continue;
    const words = line
      .replace(/\[(\d{1,3}):(\d{2})(?:\.(\d{1,3}))?\]/g, "")
      .trim();
    if (!words) continue;
    for (const mark of marks) {
      const minutes = Number(mark[1]);
      const seconds = Number(mark[2]);
      const fraction = mark[3] ? Number("0." + mark[3]) : 0;
      if (seconds >= 60 || minutes > 999) continue;
      rows.push({ at: minutes * 60 + seconds + fraction, words });
      if (rows.length >= 4096) break;
    }
    if (rows.length >= 4096) break;
  }
  rows.sort((a, b) => a.at - b.at);
  return rows;
}

function currentIndex(rows, seconds) {
  if (!rows || rows.length === 0 || !isFinite(seconds)) return -1;
  let lo = 0;
  let hi = rows.length;
  while (lo < hi) {
    const middle = (lo + hi) >> 1;
    if (rows[middle].at <= seconds) lo = middle + 1;
    else hi = middle;
  }
  return lo - 1;
}

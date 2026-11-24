function activeAt(date, startMinute, endMinute, days) {
  const minute = date.getHours() * 60 + date.getMinutes();
  const day = date.getDay();
  const selected = d => (days & (1 << d)) !== 0;
  if (startMinute === endMinute || days === 0) return false;
  if (startMinute < endMinute)
    return selected(day) && minute >= startMinute && minute < endMinute;
  return (selected(day) && minute >= startMinute) ||
    (selected((day + 6) % 7) && minute < endMinute);
}

function nextTransition(date, startMinute, endMinute, days) {
  const current = activeAt(date, startMinute, endMinute, days);
  if (!days || startMinute === endMinute) return 0;
  // Walk local day boundaries rather than adding fixed 24-hour durations:
  // dates may cross daylight-saving changes.
  const candidates = [];
  for (let offset = -1; offset <= 8; ++offset) {
    const start = new Date(date.getFullYear(), date.getMonth(), date.getDate() + offset,
      Math.floor(startMinute / 60), startMinute % 60);
    if (!(days & (1 << start.getDay()))) continue;
    const end = new Date(start.getFullYear(), start.getMonth(),
      start.getDate() + (endMinute < startMinute ? 1 : 0),
      Math.floor(endMinute / 60), endMinute % 60);
    candidates.push(start, end);
  }
  candidates.sort((a, b) => a - b);
  for (const boundary of candidates) {
    if (boundary > date && activeAt(boundary, startMinute, endMinute, days) !== current)
      return boundary.getTime();
  }
  return 0;
}

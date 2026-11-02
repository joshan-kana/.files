// Geometry-only helpers for the shared busy indicator. Track the actual
// native squircle vertices so a moving highlight stays visible at every corner.
function contour(width, height, inset, surface) {
  const points = [];
  const left = inset;
  const top = inset;
  const right = width - inset;
  const bottom = height - inset;
  const radius = Math.min(
    Math.max(0, surface.cornerRadius - inset),
    (right - left) / 2,
    (bottom - top) / 2,
  );
  if (radius <= 0) return points;

  function add(x, y) {
    const previous = points.length > 0 ? points[points.length - 1] : null;
    const at = previous
      ? previous.at + Math.hypot(x - previous.x, y - previous.y)
      : 0;
    points.push({ x: x, y: y, at: at });
  }
  function corner(cx, cy, start, end) {
    for (let i = 1; i <= surface.cornerSamples; ++i) {
      const t =
        start +
        (end - start) * surface.cornerProgress(i / surface.cornerSamples);
      add(
        cx +
          radius *
            Math.sign(Math.cos(t)) *
            Math.abs(Math.cos(t)) ** (2 / surface.exponent),
        cy +
          radius *
            Math.sign(Math.sin(t)) *
            Math.abs(Math.sin(t)) ** (2 / surface.exponent),
      );
    }
  }

  add(left + radius, top);
  add(right - radius, top);
  corner(right - radius, top + radius, -Math.PI / 2, 0);
  add(right, bottom - radius);
  corner(right - radius, bottom - radius, 0, Math.PI / 2);
  add(left + radius, bottom);
  corner(left + radius, bottom - radius, Math.PI / 2, Math.PI);
  add(left, top + radius);
  corner(left + radius, top + radius, Math.PI, Math.PI * 1.5);
  return points;
}

function atDistance(points, length, distance) {
  const offset = ((distance % length) + length) % length;
  // Cumulative path positions are sorted: binary search avoids scanning the
  // complete monitor frame for each sample at every animation tick.
  let lo = 1;
  let hi = points.length - 1;
  while (lo <= hi) {
    const mid = (lo + hi) >> 1;
    if (points[mid].at < offset) lo = mid + 1;
    else hi = mid - 1;
  }
  if (lo < points.length) {
    const next = points[lo];
    const prev = points[lo - 1];
    const t = (offset - prev.at) / Math.max(0.00001, next.at - prev.at);
    return {
      x: prev.x + (next.x - prev.x) * t,
      y: prev.y + (next.y - prev.y) * t,
    };
  }
  // Frame geometry closes with a final segment from the last vertex to the
  // first. Interpolate it instead of teleporting the trace through the corner.
  const last = points[points.length - 1];
  const first = points[0];
  const closing = Math.max(0.00001, length - last.at);
  const t = Math.max(0, Math.min(1, (offset - last.at) / closing));
  return {
    x: last.x + (first.x - last.x) * t,
    y: last.y + (first.y - last.y) * t,
  };
}

// A tapered head is built from short strokes along the actual squircle path.
// Two passes share these samples: a wide translucent halo and a crisp core.
// The tail falls away smoothly instead of ending in a blunt dash.
function paint(
  ctx,
  points,
  length,
  circuit,
  fraction,
  color,
  lineWidth,
  width,
  height,
) {
  ctx.clearRect(0, 0, width, height);
  if (points.length < 2 || length <= 0) return;

  const head = length * (((circuit % 1) + 1) % 1);
  const span = length * fraction;
  // Preserve each actual contour vertex (particularly the small concave
  // shoulders), then subdivide long straights. Uniform sparse sampling draws
  // diagonal shortcuts through tight corners as the highlight travels.
  const tail = head - span;
  const positions = [tail, head];
  const maxStep = 7;
  for (let at = tail + maxStep; at < head; at += maxStep) positions.push(at);
  for (
    let lap = Math.floor(tail / length);
    lap <= Math.ceil(head / length);
    lap++
  ) {
    for (const point of points) {
      const at = lap * length + point.at;
      if (at > tail && at < head) positions.push(at);
    }
  }
  positions.sort((a, b) => a - b);
  const samples = [];
  for (const at of positions) {
    if (samples.length && at - samples[samples.length - 1].at < 0.0001)
      continue;
    const point = atDistance(points, length, at);
    samples.push({ x: point.x, y: point.y, at });
  }

  const rgb = `${Math.round(color.r * 255)}, ${Math.round(color.g * 255)}, ${Math.round(color.b * 255)}`;
  for (const layer of [
    { scale: 7, alpha: 0.025 },
    { scale: 4.5, alpha: 0.045 },
    { scale: 2.5, alpha: 0.075 },
    { scale: 1, alpha: 0.88 },
  ]) {
    for (let i = 0; i < samples.length - 1; i++) {
      const strength = ((samples[i].at + samples[i + 1].at) / 2 - tail) / span;
      const taper = 0.1 + 0.9 * strength * strength;
      const alpha = layer.alpha * strength * strength;
      ctx.beginPath();
      ctx.moveTo(samples[i].x, samples[i].y);
      ctx.lineTo(samples[i + 1].x, samples[i + 1].y);
      ctx.strokeStyle = `rgba(${rgb}, ${alpha})`;
      ctx.lineWidth = lineWidth * taper * layer.scale;
      // Short contour segments should not accumulate luminous blobs where
      // their ends meet. Only the crisp foreground has rounded endpoints.
      ctx.lineCap = layer.scale === 1 ? "round" : "butt";
      ctx.lineJoin = "round";
      ctx.stroke();
    }
  }
}

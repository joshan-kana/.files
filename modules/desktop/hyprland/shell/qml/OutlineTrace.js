// Geometry-only helpers for the shared busy indicator. Track the actual
// owner's painted cubic path so the highlight stays on the actual outline.
function contour(path) {
  const tokens = path.match(/[MLCZ]|[-+]?(?:\d*\.)?\d+(?:e[-+]?\d+)?/gi) || [];
  const points = [];
  let i = 0;
  function add(x, y) {
    const previous = points[points.length - 1];
    points.push({
      x,
      y,
      at: previous
        ? previous.at + Math.hypot(x - previous.x, y - previous.y)
        : 0,
    });
  }
  while (i < tokens.length) {
    const command = tokens[i++];
    if (command === "M" || command === "L") {
      add(Number(tokens[i++]), Number(tokens[i++]));
    } else if (command === "C" && points.length) {
      const start = points[points.length - 1];
      const x1 = Number(tokens[i++]),
        y1 = Number(tokens[i++]);
      const x2 = Number(tokens[i++]),
        y2 = Number(tokens[i++]);
      const x3 = Number(tokens[i++]),
        y3 = Number(tokens[i++]);
      const length =
        Math.hypot(x1 - start.x, y1 - start.y) +
        Math.hypot(x2 - x1, y2 - y1) +
        Math.hypot(x3 - x2, y3 - y2);
      const steps = Math.max(12, Math.ceil(length / 2));
      for (let step = 1; step <= steps; step++) {
        const t = step / steps,
          u = 1 - t;
        add(
          u * u * u * start.x +
            3 * u * u * t * x1 +
            3 * u * t * t * x2 +
            t * t * t * x3,
          u * u * u * start.y +
            3 * u * u * t * y1 +
            3 * u * t * t * y2 +
            t * t * t * y3,
        );
      }
    } else if (command === "Z" && points.length) {
      add(points[0].x, points[0].y);
    } else {
      return [];
    }
  }
  return points.every((p) => Number.isFinite(p.at)) ? points : [];
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
// The frame uses a bounded Canvas around the current highlight, avoiding a
// full-screen texture upload on every animation tick. The original vertices
// and fine subdivisions are retained for the exact same contour.
function traceSamples(points, length, circuit, fraction) {
  if (points.length < 2 || length <= 0)
    return { samples: [], tail: 0, span: 0 };
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

  return { samples, tail, span };
}

// Reduced-motion operations must remain visibly active. Show an accent
// segment that follows the same contour without a running animation or
// full-screen Canvas texture; a solid full perimeter is just another border.
function traceBounds(
  points,
  length,
  circuit,
  fraction,
  padding,
  width,
  height,
) {
  const geometry = traceSamples(points, length, circuit, fraction);
  if (!geometry.samples.length)
    return { x: 0, y: 0, width: 1, height: 1, samples: [], tail: 0, span: 0 };
  let minX = Infinity,
    minY = Infinity,
    maxX = -Infinity,
    maxY = -Infinity;
  for (const point of geometry.samples) {
    minX = Math.min(minX, point.x);
    minY = Math.min(minY, point.y);
    maxX = Math.max(maxX, point.x);
    maxY = Math.max(maxY, point.y);
  }
  // Quantization prevents reallocating the Canvas backing texture for every
  // single pixel of motion. The clip still always includes the whole halo.
  const tile = 64;
  const x = Math.max(0, Math.floor((minX - padding) / tile) * tile);
  const y = Math.max(0, Math.floor((minY - padding) / tile) * tile);
  const right = Math.min(width, Math.ceil((maxX + padding) / tile) * tile);
  const bottom = Math.min(height, Math.ceil((maxY + padding) / tile) * tile);
  return {
    x,
    y,
    width: Math.max(1, right - x),
    height: Math.max(1, bottom - y),
    samples: geometry.samples,
    tail: geometry.tail,
    span: geometry.span,
  };
}

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
  offsetX = 0,
  offsetY = 0,
  cached = null,
) {
  ctx.clearRect(0, 0, width, height);
  if (points.length < 2 || length <= 0) return;

  const { samples, tail, span } =
    cached || traceSamples(points, length, circuit, fraction);
  if (samples.length < 2 || span <= 0) return;

  const rgb = `${Math.round(color.r * 255)}, ${Math.round(color.g * 255)}, ${Math.round(color.b * 255)}`;
  // Batch adjacent contour segments into a handful of tapered bands. A
  // stroke() per 7px segment forces hundreds of software Canvas raster passes
  // per frame, particularly on full-monitor progress outlines. The geometry
  // vertices are retained, so batching never shortcuts a corner.
  const bands = 24;
  for (const layer of [
    { scale: 7, alpha: 0.025 },
    { scale: 4.5, alpha: 0.045 },
    { scale: 2.5, alpha: 0.075 },
    { scale: 1, alpha: 0.88 },
  ]) {
    let currentBand = -1;
    function finishBand() {
      if (currentBand < 0) return;
      ctx.stroke();
    }
    for (let i = 0; i < samples.length - 1; i++) {
      const strength = ((samples[i].at + samples[i + 1].at) / 2 - tail) / span;
      const band = Math.max(
        0,
        Math.min(bands - 1, Math.floor(strength * bands)),
      );
      if (band !== currentBand) {
        finishBand();
        currentBand = band;
        const level = (band + 0.5) / bands;
        const taper = 0.1 + 0.9 * level * level;
        ctx.beginPath();
        ctx.strokeStyle = `rgba(${rgb}, ${layer.alpha * level * level})`;
        ctx.lineWidth = lineWidth * taper * layer.scale;
        ctx.lineCap = "butt";
        ctx.lineJoin = "round";
        ctx.moveTo(samples[i].x - offsetX, samples[i].y - offsetY);
      }
      ctx.lineTo(samples[i + 1].x - offsetX, samples[i + 1].y - offsetY);
    }
    finishBand();
  }
  // A single rounded tip avoids the bright overlapping caps of hundreds of
  // separate line segments while keeping the highlight's leading edge soft.
  if (ctx.arc) {
    const tip = samples[samples.length - 1];
    ctx.beginPath();
    ctx.arc(tip.x - offsetX, tip.y - offsetY, lineWidth / 2, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(${rgb}, 0.88)`;
    ctx.fill();
  }
}

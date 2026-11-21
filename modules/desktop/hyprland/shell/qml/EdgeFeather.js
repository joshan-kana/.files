// One-dimensional smoothstep feather, in logical pixels. The two axes
// multiply when the mask is composited, including at all four corners.
function gradientStops(extent, feather) {
  const fraction = Math.min(0.5, Math.max(0, feather / Math.max(1, extent)));
  const stops = [];
  const steps = 8;
  for (let i = 0; i <= steps; i++) {
    const t = i / steps;
    stops.push([t * fraction, t * t * (3 - 2 * t)]);
  }
  for (let i = steps; i >= 0; i--) {
    const t = i / steps;
    const position = 1 - t * fraction;
    if (position > stops[stops.length - 1][0])
      stops.push([position, t * t * (3 - 2 * t)]);
  }
  return stops;
}

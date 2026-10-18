// Geometry-only helpers for the shared busy indicator. Track the actual
// native squircle vertices so a moving highlight stays visible at every corner.
function contour(width, height, inset, surface) {
    const points = [];
    const left = inset;
    const top = inset;
    const right = width - inset;
    const bottom = height - inset;
    const radius = Math.min(Math.max(0, surface.cornerRadius - inset), (right - left) / 2, (bottom - top) / 2);
    if (radius <= 0)
        return points;

    function add(x, y) {
        const previous = points.length > 0 ? points[points.length - 1] : null;
        const at = previous ? previous.at + Math.hypot(x - previous.x, y - previous.y) : 0;
        points.push({ x: x, y: y, at: at });
    }
    function corner(cx, cy, start, end) {
        for (let i = 1; i <= surface.cornerSamples; ++i) {
            const t = start + (end - start) * surface.cornerProgress(i / surface.cornerSamples);
            add(cx + radius * Math.sign(Math.cos(t)) * Math.pow(Math.abs(Math.cos(t)), 2 / surface.exponent),
                cy + radius * Math.sign(Math.sin(t)) * Math.pow(Math.abs(Math.sin(t)), 2 / surface.exponent));
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
    for (let i = 1; i < points.length; ++i) {
        const next = points[i];
        if (offset <= next.at) {
            const prev = points[i - 1];
            const fraction = (offset - prev.at) / Math.max(0.00001, next.at - prev.at);
            return { x: prev.x + (next.x - prev.x) * fraction, y: prev.y + (next.y - prev.y) * fraction };
        }
    }
    return points[0] || { x: 0, y: 0 };
}

function paint(ctx, points, length, circuit, fraction, color, lineWidth, width, height) {
    ctx.clearRect(0, 0, width, height);
    if (points.length < 2)
        return;

    const start = length * (circuit % 1);
    const end = start + length * fraction;
    const first = atDistance(points, length, start);
    const last = atDistance(points, length, end);
    ctx.beginPath();
    ctx.moveTo(first.x, first.y);
    for (let cycle = 0; cycle <= 1; ++cycle) {
        for (let i = 1; i < points.length; ++i) {
            const point = points[i];
            const position = point.at + cycle * length;
            if (position > start && position < end)
                ctx.lineTo(point.x, point.y);
        }
    }
    ctx.lineTo(last.x, last.y);
    ctx.strokeStyle = color;
    ctx.lineWidth = lineWidth;
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.stroke();
}

// Shared contour for the monitor border and every attached shell surface.
// All coordinates are logical Wayland pixels. Geometry is computed only from
// actual QML bounds; no compositor gap values or screen size are assumed.
function contour(
  width,
  height,
  thickness,
  radius,
  exponent,
  islands,
  hub,
  toast,
  squircle,
  bottomDock,
  topDock,
) {
  if (
    ![width, height, thickness, radius].every(Number.isFinite) ||
    width <= 0 ||
    height <= 0 ||
    thickness <= 0
  )
    return {
      inner: "",
      fill: "",
      hoverFill: "",
      pressedFill: "",
      length: 0,
      points: [],
    };

  const shapeExponent = Math.max(2, Math.min(12, Number(exponent) || 4.5));
  const edge = Math.max(1, Math.min(thickness, width / 5, height / 5));
  const left = edge;
  const top = edge;
  const right = width - edge;
  const bottom = height - edge;
  const outerRadius = Math.max(
    0,
    Math.min(radius, (right - left) / 2, (bottom - top) / 2),
  );
  const topNotches = (islands || [])
    .concat(hub && hub.visible ? [hub] : [])
    .concat(
      (Array.isArray(topDock) ? topDock : [topDock]).filter(
        (item) => item && item.visible,
      ),
    )
    .filter(
      (item) =>
        item &&
        item.visible !== false &&
        [item.x, item.y, item.width, item.height].every(Number.isFinite) &&
        item.width > 1 &&
        item.height > 1,
    )
    .map((item) => ({
      left: Math.max(left + outerRadius + 3, item.x),
      right: Math.min(right - outerRadius - 3, item.x + item.width),
      bottom: Math.min(bottom - outerRadius - 3, item.y + item.height),
      hovered: Boolean(item.hovered),
      pressed: Boolean(item.pressed),
    }))
    .filter((item) => item.right - item.left > 5 && item.bottom > top + 5)
    .sort((a, b) => a.left - b.left);

  // Merge only actual intersecting surfaces (for example a hub expanding
  // over an island). Neighbouring status islands must retain independent
  // squircle shoulders, even when their visible gap is narrow.
  const merged = [];
  for (const notch of topNotches) {
    const last = merged[merged.length - 1];
    if (last && notch.left <= last.right) {
      last.right = Math.max(last.right, notch.right);
      last.bottom = Math.max(last.bottom, notch.bottom);
      last.hovered = last.hovered || notch.hovered;
      last.pressed = last.pressed || notch.pressed;
    } else {
      merged.push({
        left: notch.left,
        right: notch.right,
        bottom: notch.bottom,
        hovered: notch.hovered,
        pressed: notch.pressed,
      });
    }
  }

  const points = [];
  const hoverPaths = [];
  const pressedPaths = [];
  let length = 0;
  function add(x, y) {
    const point = {
      x: Math.round(x * 10000) / 10000,
      y: Math.round(y * 10000) / 10000,
    };
    const previous = points[points.length - 1];
    if (previous)
      length += Math.hypot(point.x - previous.x, point.y - previous.y);
    points.push({ x: point.x, y: point.y, at: length });
  }
  function corner(cx, cy, r, start, end) {
    if (r <= 0) return;
    // Reuse the same progress distribution and corner-point construction as
    // SquircleSurface. Matching the exponent alone produces visibly different
    // sampling at small shoulder and inverted corners.
    const samples = Math.max(8, Math.min(20, Math.ceil(r * 0.7)));
    for (let i = 1; i <= samples; i++) {
      const t =
        start + (end - start) * squircle.progress(i / samples, shapeExponent);
      const vertex = squircle.cornerPoint(cx, cy, r, t, shapeExponent);
      add(vertex.x, vertex.y);
    }
  }

  add(left + outerRadius, top);
  for (let i = 0; i < merged.length; i++) {
    const notch = merged[i];
    const startPoint = points.length;
    const next = merged[i + 1];
    const preceding = i ? merged[i - 1].right : left + outerRadius;
    const following = next ? next.left : right - outerRadius;
    const leftSpace = notch.left - preceding;
    const rightSpace = following - notch.right;
    // The two shoulders have independent space constraints: a narrow right
    // neighbour must not square off the left edge of the same island.
    // Keep a straight bridge between neighbouring wells, while outer frame
    // corners can devote more of their clearance to the shoulder.
    const shoulderLimit = Math.min(radius * 0.65, (notch.bottom - top) * 0.45);
    const leftShoulder = Math.max(
      0,
      Math.min(shoulderLimit, leftSpace * (i === 0 ? 0.8 : 0.32)),
    );
    const rightShoulder = Math.max(
      0,
      Math.min(
        shoulderLimit,
        rightSpace * (i === merged.length - 1 ? 0.8 : 0.32),
      ),
    );
    const r = Math.max(
      0,
      Math.min(
        radius * 0.78,
        (notch.right - notch.left) / 2,
        (notch.bottom - top) / 2,
      ),
    );
    add(notch.left - leftShoulder, top);
    corner(
      notch.left - leftShoulder,
      top + leftShoulder,
      leftShoulder,
      -Math.PI / 2,
      0,
    );
    add(notch.left, notch.bottom - r);
    corner(notch.left + r, notch.bottom - r, r, Math.PI, Math.PI / 2);
    add(notch.right - r, notch.bottom);
    corner(notch.right - r, notch.bottom - r, r, Math.PI / 2, 0);
    add(notch.right, top + rightShoulder);
    corner(
      notch.right + rightShoulder,
      top + rightShoulder,
      rightShoulder,
      Math.PI,
      1.5 * Math.PI,
    );
    // Hover must follow exactly the composited concave boundary. Painting
    // another rounded rectangle inside the bar creates phantom pill corners.
    if (notch.hovered || notch.pressed) {
      const segment = points.slice(startPoint);
      const fillPath =
        segment
          .map(
            (point, index) =>
              (index === 0 ? "M" : "L") + point.x + " " + point.y,
          )
          .join(" ") + " Z";
      (notch.pressed ? pressedPaths : hoverPaths).push(fillPath);
    }
  }
  add(right - outerRadius, top);
  corner(right - outerRadius, top + outerRadius, outerRadius, -Math.PI / 2, 0);

  // Overlapping right-edge panels contribute one continuous envelope.
  const docks = (Array.isArray(toast) ? toast : [toast])
    .filter(
      (item) =>
        item &&
        item.visible &&
        [item.x, item.y, item.width, item.height].every(Number.isFinite) &&
        item.width > 1 &&
        item.height > 1,
    )
    .map((item) => ({
      left: Math.max(left + outerRadius + 3, item.x),
      top: Math.max(top + outerRadius + 3, item.y),
      bottom: Math.min(bottom - outerRadius - 3, item.y + item.height),
    }))
    .filter((item) => item.left < right - 6 && item.bottom > item.top + 6)
    .sort((a, b) => a.top - b.top);
  const mergedDocks = [];
  for (const notch of docks) {
    const last = mergedDocks[mergedDocks.length - 1];
    if (last && notch.top <= last.bottom + 3) {
      last.left = Math.min(last.left, notch.left);
      last.bottom = Math.max(last.bottom, notch.bottom);
    } else {
      mergedDocks.push({
        left: notch.left,
        top: notch.top,
        bottom: notch.bottom,
      });
    }
  }
  for (let i = 0; i < mergedDocks.length; i++) {
    const dock = mergedDocks[i];
    const previous = i ? mergedDocks[i - 1].bottom : top + outerRadius;
    const next =
      i + 1 < mergedDocks.length
        ? mergedDocks[i + 1].top
        : bottom - outerRadius;
    const shoulder = Math.max(
      0,
      Math.min(
        radius * 0.65,
        (dock.top - previous) * 0.43,
        (next - dock.bottom) * 0.43,
      ),
    );
    const r = Math.max(
      0,
      Math.min(
        radius * 0.78,
        (right - dock.left) / 3,
        (dock.bottom - dock.top) / 2,
      ),
    );
    add(right, dock.top - shoulder);
    corner(right - shoulder, dock.top - shoulder, shoulder, 0, Math.PI / 2);
    add(dock.left + r, dock.top);
    corner(dock.left + r, dock.top + r, r, -Math.PI / 2, -Math.PI);
    add(dock.left, dock.bottom - r);
    corner(dock.left + r, dock.bottom - r, r, Math.PI, Math.PI / 2);
    add(right - shoulder, dock.bottom);
    corner(right - shoulder, dock.bottom + shoulder, shoulder, -Math.PI / 2, 0);
  }

  add(right, bottom - outerRadius);
  corner(
    right - outerRadius,
    bottom - outerRadius,
    outerRadius,
    0,
    Math.PI / 2,
  );
  // The OSD joins the *bottom* edge at screen centre, independent of
  // notification docking on the right and the expanded hub at the top.
  const bottomNotches = (Array.isArray(bottomDock) ? bottomDock : [bottomDock])
    .filter(
      (item) =>
        item &&
        item.visible &&
        [item.x, item.y, item.width, item.height].every(Number.isFinite) &&
        item.width > 1 &&
        item.height > 0.05,
    )
    .map((item) => ({
      left: Math.max(left + outerRadius + 3, item.x),
      right: Math.min(right - outerRadius - 3, item.x + item.width),
      top: Math.max(top + outerRadius + 3, item.y),
    }))
    .filter((item) => item.right - item.left > 5 && item.top < bottom - 0.05)
    .sort((a, b) => b.right - a.right);
  const mergedBottom = [];
  for (const notch of bottomNotches) {
    const previous = mergedBottom[mergedBottom.length - 1];
    if (previous && notch.right >= previous.left - 3) {
      previous.left = Math.min(previous.left, notch.left);
      previous.top = Math.min(previous.top, notch.top);
    } else {
      mergedBottom.push({
        left: notch.left,
        right: notch.right,
        top: notch.top,
      });
    }
  }
  for (let i = 0; i < mergedBottom.length; i++) {
    const dock = mergedBottom[i];
    const preceding = i ? mergedBottom[i - 1].left : right - outerRadius;
    const following =
      i + 1 < mergedBottom.length
        ? mergedBottom[i + 1].right
        : left + outerRadius;
    const shoulder = Math.max(
      0,
      Math.min(
        radius * 0.65,
        // The bottom cutout must not intersect its own convex top corner.
        (bottom - dock.top) * 0.45,
        (preceding - dock.right) * 0.43,
        (dock.left - following) * 0.43,
      ),
    );
    const r = Math.max(
      0,
      Math.min(
        radius * 0.78,
        (dock.right - dock.left) / 2,
        (bottom - dock.top) / 2,
      ),
    );
    add(dock.right + shoulder, bottom);
    corner(
      dock.right + shoulder,
      bottom - shoulder,
      shoulder,
      Math.PI / 2,
      Math.PI,
    );
    add(dock.right, dock.top + r);
    corner(dock.right - r, dock.top + r, r, 0, -Math.PI / 2);
    add(dock.left + r, dock.top);
    corner(dock.left + r, dock.top + r, r, -Math.PI / 2, -Math.PI);
    add(dock.left, bottom - shoulder);
    corner(dock.left - shoulder, bottom - shoulder, shoulder, 0, Math.PI / 2);
  }

  add(left + outerRadius, bottom);
  corner(
    left + outerRadius,
    bottom - outerRadius,
    outerRadius,
    Math.PI / 2,
    Math.PI,
  );
  add(left, top + outerRadius);
  corner(
    left + outerRadius,
    top + outerRadius,
    outerRadius,
    Math.PI,
    Math.PI * 1.5,
  );
  const inner =
    points
      .map((point, i) => (i ? "L" : "M") + point.x + " " + point.y)
      .join(" ") + " Z";
  // Odd-even fill removes the desktop interior rather than painting over
  // clients. The inner path is reused for both the border and busy trace.
  return {
    inner,
    hoverFill: hoverPaths.join(" "),
    pressedFill: pressedPaths.join(" "),
    fill: "M0 0 H" + width + " V" + height + " H0 Z " + inner,
    length:
      length +
      Math.hypot(
        points[0].x - points[points.length - 1].x,
        points[0].y - points[points.length - 1].y,
      ),
    points,
  };
}

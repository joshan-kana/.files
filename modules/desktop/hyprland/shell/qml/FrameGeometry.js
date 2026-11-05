// Match the lower limit used by connected frame notches when positioning
// the navigation footer inside their visible rounded contour.
function hubBottomLimit(width, height, thickness, radius) {
  const edge = Math.max(1, Math.min(thickness, width / 5, height / 5));
  const innerWidth = Math.max(0, width - edge * 2);
  const innerHeight = Math.max(0, height - edge * 2);
  const outerRadius = Math.max(
    0,
    Math.min(radius, innerWidth / 2, innerHeight / 2),
  );
  return height - edge - outerRadius - 3;
}

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
  traceEnabled = true,
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
  const topSources = (islands || [])
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
    );
  // Reserve a genuine curved bridge from each outer corner into its nearest
  // attached island. The full-size panel corner cannot coexist with a more
  // outward island at the same top-edge coordinates; clamping the notch to it
  // creates the tiny, visibly square shoulders seen at both ends of the bar.
  const firstEdge = Math.min(right, ...topSources.map((item) => item.x));
  const lastEdge = Math.max(
    left,
    ...topSources.map((item) => item.x + item.width),
  );
  const cornerClearance = Math.min(20, Math.max(8, (right - left) / 20));
  const topLeftRadius = Math.min(
    outerRadius,
    Math.max(14, firstEdge - left - cornerClearance),
  );
  const topRightRadius = Math.min(
    outerRadius,
    Math.max(14, right - lastEdge - cornerClearance),
  );
  const topNotches = topSources
    .map((item) => ({
      left: Math.max(left + topLeftRadius + 3, item.x),
      right: Math.min(right - topRightRadius - 3, item.x + item.width),
      bottom: Math.min(
        hubBottomLimit(width, height, thickness, radius),
        item.y + item.height,
      ),
      hovered: Boolean(item.hovered),
      pressed: Boolean(item.pressed),
      interactionGroup: item.interactionGroup || "",
    }))
    .filter((item) => item.right - item.left > 5 && item.bottom > top + 5)
    .sort((a, b) => a.left - b.left);

  // The union of overlapping notches has a *stepped* bottom envelope.
  // A tall gallery can intersect the neighbouring short media island, but
  // must not extend its depth underneath that entire island.
  const merged = [];
  for (const notch of topNotches) {
    const last = merged[merged.length - 1];
    if (last && notch.left <= last.right) {
      last.right = Math.max(last.right, notch.right);
      last.sources.push(notch);
      last.hovered = last.hovered || notch.hovered;
      last.pressed = last.pressed || notch.pressed;
    } else {
      merged.push({
        left: notch.left,
        right: notch.right,
        hovered: notch.hovered,
        pressed: notch.pressed,
        sources: [notch],
      });
    }
  }
  for (const notch of merged) {
    if (notch.sources.length === 1) {
      notch.sections = [notch.sources[0]];
      continue;
    }
    const boundaries = [];
    for (const source of notch.sources)
      boundaries.push(source.left, source.right);
    boundaries.sort((a, b) => a - b);
    const sections = [];
    for (let j = 1; j < boundaries.length; j++) {
      const left = boundaries[j - 1];
      const right = boundaries[j];
      if (right <= left) continue;
      let bottom = -Infinity;
      for (const source of notch.sources) {
        if (source.left < right && source.right > left)
          bottom = Math.max(bottom, source.bottom);
      }
      if (!Number.isFinite(bottom)) continue;
      const previous = sections[sections.length - 1];
      if (previous && Math.abs(previous.bottom - bottom) < 0.01)
        previous.right = right;
      else sections.push({ left, right, bottom });
    }
    notch.sections = sections;
  }

  const points = [];
  const pathCommands = [];
  const hoverPaths = [];
  const pressedPaths = [];
  let length = 0;
  function add(x, y, path = true) {
    const point = {
      x: Math.round(x * 10000) / 10000,
      y: Math.round(y * 10000) / 10000,
    };
    const previous = points[points.length - 1];
    if (previous)
      length += Math.hypot(point.x - previous.x, point.y - previous.y);
    if (path) pathCommands.push(`${previous ? "L" : "M"}${point.x} ${point.y}`);
    points.push({ x: point.x, y: point.y, at: length });
  }
  function corner(cx, cy, r, start, end) {
    if (r <= 0) return;
    // Keep dense samples for accurate loading-trace arc lengths, but draw each
    // quarter as one fitted cubic. Recreating hundreds of ShapePath segments
    // during a hub morph would otherwise repeatedly retessellate the frame.
    const samples = Math.max(8, Math.min(20, Math.ceil(r * 0.7)));
    if (traceEnabled) {
      for (let i = 1; i <= samples; i++) {
        const t =
          start + (end - start) * squircle.progress(i / samples, shapeExponent);
        const vertex = squircle.cornerPoint(cx, cy, r, t, shapeExponent);
        add(vertex.x, vertex.y, false);
      }
    } else {
      // The full cubic boundary is still drawn. Detailed arc-length samples
      // are only required by the active loading trace.
      const vertex = squircle.cornerPoint(cx, cy, r, end, shapeExponent);
      add(vertex.x, vertex.y, false);
    }
    // Match the diagonal of the superellipse and the exact tangent direction
    // at both ends, including reversed concave shoulders.
    const direction = Math.sign(end - start);
    const handle = (r * (Math.pow(2, -1 / shapeExponent) - 0.5)) / 0.375;
    const first = squircle.cornerPoint(cx, cy, r, start, shapeExponent);
    const last = points[points.length - 1];
    const control1 = {
      x: first.x - direction * handle * Math.sin(start),
      y: first.y + direction * handle * Math.cos(start),
    };
    const control2 = {
      x: last.x + direction * handle * Math.sin(end),
      y: last.y - direction * handle * Math.cos(end),
    };
    const rounded = (value) => Math.round(value * 10000) / 10000;
    pathCommands.push(
      `C${rounded(control1.x)} ${rounded(control1.y)} ${rounded(control2.x)} ${rounded(control2.y)} ${last.x} ${last.y}`,
    );
  }

  add(left + topLeftRadius, top);
  for (let i = 0; i < merged.length; i++) {
    const notch = merged[i];
    const startCommand = pathCommands.length;
    const next = merged[i + 1];
    const preceding = i ? merged[i - 1].right : left + topLeftRadius;
    const following = next ? next.left : right - topRightRadius;
    const leftSpace = notch.left - preceding;
    const rightSpace = following - notch.right;
    // The two shoulders have independent space constraints: a narrow right
    // neighbour must not square off the left edge of the same island.
    // Keep a straight bridge between neighbouring wells. At the two screen
    // edges, consume the entire small corner-to-island gap with the curved
    // shoulder: a residual straight stub produced a visible hairline beside
    // the workspace and right-hand status islands.
    const sections = notch.sections;
    const first = sections[0];
    const last = sections[sections.length - 1];
    const leftShoulder = Math.max(
      0,
      Math.min(
        radius * 0.65,
        (first.bottom - top) * 0.45,
        leftSpace * (i === 0 ? 1 : 0.32),
      ),
    );
    const rightShoulder = Math.max(
      0,
      Math.min(
        radius * 0.65,
        (last.bottom - top) * 0.45,
        rightSpace * (i === merged.length - 1 ? 1 : 0.32),
      ),
    );
    const leftRadius = Math.max(
      0,
      Math.min(
        radius * 0.78,
        (first.right - first.left) / 2,
        (first.bottom - top) / 2,
      ),
    );
    const rightRadius = Math.max(
      0,
      Math.min(
        radius * 0.78,
        (last.right - last.left) / 2,
        (last.bottom - top) / 2,
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
    add(notch.left, first.bottom - leftRadius);
    corner(
      notch.left + leftRadius,
      first.bottom - leftRadius,
      leftRadius,
      Math.PI,
      Math.PI / 2,
    );
    const leftPathEnd = pathCommands.length;

    for (let j = 1; j < sections.length; j++) {
      const previous = sections[j - 1];
      const current = sections[j];
      const boundary = current.left;
      const stepRadius = Math.max(
        0,
        Math.min(
          radius * 0.65,
          (previous.right - previous.left) / 3,
          (current.right - current.left) / 3,
          Math.abs(current.bottom - previous.bottom) / 3,
        ),
      );
      add(boundary - stepRadius, previous.bottom);
      if (current.bottom > previous.bottom) {
        // Shallow island -> deep gallery, with two connected inside corners.
        corner(
          boundary - stepRadius,
          previous.bottom + stepRadius,
          stepRadius,
          -Math.PI / 2,
          0,
        );
        add(boundary, current.bottom - stepRadius);
        corner(
          boundary + stepRadius,
          current.bottom - stepRadius,
          stepRadius,
          Math.PI,
          Math.PI / 2,
        );
      } else {
        corner(
          boundary - stepRadius,
          previous.bottom - stepRadius,
          stepRadius,
          Math.PI / 2,
          0,
        );
        add(boundary, current.bottom + stepRadius);
        corner(
          boundary + stepRadius,
          current.bottom + stepRadius,
          stepRadius,
          Math.PI,
          1.5 * Math.PI,
        );
      }
    }
    const rightPathStart = pathCommands.length;
    add(notch.right - rightRadius, last.bottom);
    corner(
      notch.right - rightRadius,
      last.bottom - rightRadius,
      rightRadius,
      Math.PI / 2,
      0,
    );
    add(notch.right, top + rightShoulder);
    corner(
      notch.right + rightShoulder,
      top + rightShoulder,
      rightShoulder,
      Math.PI,
      1.5 * Math.PI,
    );
    // Hover uses the exact concave frame contour, not a separate rounded
    // rectangle. The media island has two adjacent click targets: divide
    // their shared notch at the true hit boundary without rounding it twice.
    const [firstSource, secondSource] = notch.sources;
    const divided =
      notch.sources.length === 2 &&
      firstSource.interactionGroup === "media" &&
      secondSource.interactionGroup === "media" &&
      Math.abs(firstSource.right - secondSource.left) < 0.01 &&
      Math.abs(firstSource.bottom - secondSource.bottom) < 0.01;
    if (divided) {
      const divider = firstSource.right;
      const leftPart = pathCommands
        .slice(startCommand, leftPathEnd)
        .map((command, index) =>
          index === 0 ? command.replace(/^L/, "M") : command,
        )
        .join(" ");
      const rightPart = pathCommands.slice(rightPathStart).join(" ");
      const regions = [
        {
          source: firstSource,
          path:
            leftPart +
            " L" +
            divider +
            " " +
            first.bottom +
            " L" +
            divider +
            " " +
            top +
            " Z",
        },
        {
          source: secondSource,
          path:
            "M" +
            divider +
            " " +
            top +
            " L" +
            divider +
            " " +
            last.bottom +
            " " +
            rightPart +
            " Z",
        },
      ];
      for (const region of regions) {
        if (region.source.hovered || region.source.pressed)
          (region.source.pressed ? pressedPaths : hoverPaths).push(region.path);
      }
    } else if (notch.hovered || notch.pressed) {
      const segment = pathCommands.slice(startCommand);
      const fillPath =
        segment
          .map((command, index) =>
            index === 0 ? command.replace(/^L/, "M") : command,
          )
          .join(" ") + " Z";
      (notch.pressed ? pressedPaths : hoverPaths).push(fillPath);
    }
  }
  add(right - topRightRadius, top);
  corner(
    right - topRightRadius,
    top + topRightRadius,
    topRightRadius,
    -Math.PI / 2,
    0,
  );

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
      hovered: Boolean(item.hovered),
      pressed: Boolean(item.pressed),
    }))
    .filter((item) => item.left < right - 6 && item.bottom > item.top + 6)
    .sort((a, b) => a.top - b.top);
  const mergedDocks = [];
  for (const notch of docks) {
    const last = mergedDocks[mergedDocks.length - 1];
    if (last && notch.top <= last.bottom + 3) {
      last.left = Math.min(last.left, notch.left);
      last.bottom = Math.max(last.bottom, notch.bottom);
      last.hovered = last.hovered || notch.hovered;
      last.pressed = last.pressed || notch.pressed;
    } else {
      mergedDocks.push({
        left: notch.left,
        top: notch.top,
        bottom: notch.bottom,
        hovered: notch.hovered,
        pressed: notch.pressed,
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
    const dockStartCommand = pathCommands.length;
    add(right, dock.top - shoulder);
    corner(right - shoulder, dock.top - shoulder, shoulder, 0, Math.PI / 2);
    add(dock.left + r, dock.top);
    corner(dock.left + r, dock.top + r, r, -Math.PI / 2, -Math.PI);
    add(dock.left, dock.bottom - r);
    corner(dock.left + r, dock.bottom - r, r, Math.PI, Math.PI / 2);
    add(right - shoulder, dock.bottom);
    corner(right - shoulder, dock.bottom + shoulder, shoulder, -Math.PI / 2, 0);
    if (dock.hovered || dock.pressed) {
      const fillPath =
        pathCommands
          .slice(dockStartCommand)
          .map((command, index) =>
            index === 0 ? command.replace(/^L/, "M") : command,
          )
          .join(" ") + " Z";
      (dock.pressed ? pressedPaths : hoverPaths).push(fillPath);
    }
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
  // Close on the exact first point of the adaptive top-left corner. Using
  // outerRadius here closes with a stray horizontal line over the workspace
  // island whenever its outward position requires a smaller top radius.
  add(left, top + topLeftRadius);
  corner(
    left + topLeftRadius,
    top + topLeftRadius,
    topLeftRadius,
    Math.PI,
    Math.PI * 1.5,
  );
  const inner = pathCommands.join(" ") + " Z";
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

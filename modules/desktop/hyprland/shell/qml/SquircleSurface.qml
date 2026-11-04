import QtQuick
import QtQuick.Shapes
import LinuxDesktop.Visuals 1.0

Item {
    id: root
    SquircleGeometry {
        id: geometry
    }

    default property alias contentData: content.data
    // A morphing outer contour must not force its children to relayout.
    // Other surfaces default to their ordinary live width and height.
    property real contentLayoutWidth: width
    property real contentLayoutHeight: height

    property color fillColor: "transparent"
    property real fillOpacity: 1
    // The native fill interpolates the same three spectrum stops at each
    // vertex. At zero strength this is exactly the original solid fill.
    property real reactiveGradientStrength: 0
    property color reactiveGradientLow: "transparent"
    property color reactiveGradientMid: "transparent"
    property color reactiveGradientHigh: "transparent"
    property color borderColor: "transparent"
    property real borderWidth: 0
    property real cornerRadius: 28
    property real exponent: 4.5
    // A soft, shape-clipped directional reflection, not a rectangular
    // glow overlay. The native squircle path stays authoritative.
    property color lightColor: "transparent"
    property real lightStrength: 0
    property real lightSpread: 1
    property real shadowStrength: 0
    property real shadowOffset: 3
    // A zero-sized surface has no contour yet. Keep SVG parsing valid while
    // its first frame or animated size is being measured.
    // PathSvg requires drawable geometry even before the first layout pass.
    // A move-only SVG path is invalid and causes startup parser warnings.
    readonly property string emptyPathData: "M 0 0 L 0.01 0 L 0 0.01 Z"
    readonly property string fillPathData: buildPath(0) || emptyPathData
    readonly property string borderPathData: borderWidth > 0 && borderColor.a > 0 ? (buildPath(borderWidth / 2) || emptyPathData) : emptyPathData

    function point(value: real): string {
        return Number(value).toFixed(4);
    }

    // Uniform angle steps bunch most vertices into the middle of a superellipse
    // and leave very long first/last segments. Reparameterise the quarter arc
    // so samples are distributed much more evenly around the visible curve.
    function cornerProgress(progress: real): real {
        return geometry.progress(progress, exponent);
    }

    function buildCorner(cx: real, cy: real, radius: real, start: real, end: real): string {
        // Native cubic curves eliminate the faceted line segments that become
        // especially obvious when music modulates the glow along the rim.
        const direction = Math.sign(end - start);
        const handle = radius * (Math.pow(2, -1 / exponent) - 0.5) / 0.375;
        const first = geometry.cornerPoint(cx, cy, radius, start, exponent);
        const last = geometry.cornerPoint(cx, cy, radius, end, exponent);
        const x1 = first.x - direction * handle * Math.sin(start);
        const y1 = first.y + direction * handle * Math.cos(start);
        const x2 = last.x + direction * handle * Math.sin(end);
        const y2 = last.y - direction * handle * Math.cos(end);
        return " C " + point(x1) + " " + point(y1) + " " + point(x2) + " " + point(y2) + " " + point(last.x) + " " + point(last.y);
    }

    function buildPath(inset: real): string {
        // Reactive geometry can briefly be unmeasured while a popup is
        // constructed. Never serialize NaN/Infinity into an SVG path.
        if (![width, height, inset, cornerRadius, exponent].every(Number.isFinite))
            return "";
        const innerWidth = width - inset * 2;
        const innerHeight = height - inset * 2;
        const r = Math.min(Math.max(0, cornerRadius - inset), innerWidth / 2, innerHeight / 2);

        if (innerWidth <= 0 || innerHeight <= 0 || r <= 0)
            return "";

        const left = inset;
        const top = inset;
        const right = width - inset;
        const bottom = height - inset;

        let path = "M " + point(left + r) + " " + point(top);
        path += " L " + point(right - r) + " " + point(top);
        path += buildCorner(right - r, top + r, r, -Math.PI / 2, 0);
        path += " L " + point(right) + " " + point(bottom - r);
        path += buildCorner(right - r, bottom - r, r, 0, Math.PI / 2);
        path += " L " + point(left + r) + " " + point(bottom);
        path += buildCorner(left + r, bottom - r, r, Math.PI / 2, Math.PI);
        path += " L " + point(left) + " " + point(top + r);
        path += buildCorner(left + r, top + r, r, Math.PI, Math.PI * 1.5);
        path += " Z";
        return path;
    }

    // Low-contrast, layered shadows share the exact superellipse path.
    // Unlike a rectangular drop-shadow, their contour never ends early.
    Shape {
        visible: root.shadowStrength > 0
        x: 0
        y: root.shadowOffset + 2
        width: root.width
        height: root.height
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        ShapePath {
            fillColor: Qt.rgba(0, 0, 0, root.shadowStrength * 0.30)
            strokeColor: "transparent"
            strokeWidth: 0
            PathSvg {
                path: root.fillPathData
            }
        }
    }

    Shape {
        visible: root.shadowStrength > 0
        x: 0
        y: root.shadowOffset
        width: root.width
        height: root.height
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        ShapePath {
            fillColor: Qt.rgba(0, 0, 0, root.shadowStrength * 0.58)
            strokeColor: "transparent"
            strokeWidth: 0
            PathSvg {
                path: root.fillPathData
            }
        }
    }

    // The static fill and changing luminous wash share one persistent scene
    // graph geometry, leaving shadows and the original vector outline intact.
    SquircleFillItem {
        anchors.fill: parent
        fillColor: root.fillColor
        fillOpacity: root.fillOpacity
        gradientStrength: root.reactiveGradientStrength
        gradientLowColor: root.reactiveGradientLow
        gradientMidColor: root.reactiveGradientMid
        gradientHighColor: root.reactiveGradientHigh
        cornerRadius: root.cornerRadius
        exponent: root.exponent
        lightColor: root.lightColor
        lightStrength: root.lightStrength
        lightSpread: root.lightSpread
    }

    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.borderColor
            strokeWidth: root.borderWidth
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: root.borderPathData
            }
        }
    }
    Item {
        id: content
        width: root.contentLayoutWidth
        height: root.contentLayoutHeight
        x: (root.width - width) / 2
        y: 0
    }
}

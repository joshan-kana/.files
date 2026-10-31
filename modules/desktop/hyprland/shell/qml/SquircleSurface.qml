import QtQuick
import QtQuick.Shapes

Item {
    id: root

    default property alias contentData: content.data

    property color fillColor: "transparent"
    property real fillOpacity: 1
    property color borderColor: "transparent"
    property real borderWidth: 0
    property real cornerRadius: 28
    property real exponent: 4.5
    // A soft, shape-clipped directional reflection, not a rectangular
    // glow overlay. The native squircle path stays authoritative.
    property color lightColor: "transparent"
    property real lightStrength: 0
    property real shadowStrength: 0
    property real shadowOffset: 3
    // Match arc detail to its size instead of tessellating tiny controls
    // into the same number of segments as large panels.
    readonly property int cornerSamples: Math.max(8, Math.min(20, Math.ceil(cornerRadius * 0.7)))

    // A zero-sized surface has no contour yet. Keep SVG parsing valid while
    // its first frame or animated size is being measured.
    readonly property string fillPathData: buildPath(0) || "M 0 0 L 0 0 Z"
    readonly property string borderPathData: borderWidth > 0 && borderColor.a > 0 ? (buildPath(borderWidth / 2) || "M 0 0 L 0 0 Z") : "M 0 0 L 0 0 Z"

    function point(value: real): string {
        return Number(value).toFixed(4);
    }

    // Uniform angle steps bunch most vertices into the middle of a superellipse
    // and leave very long first/last segments. Reparameterise the quarter arc
    // so samples are distributed much more evenly around the visible curve.
    function cornerProgress(progress: real): real {
        if (progress <= 0)
            return 0;
        if (progress >= 1)
            return 1;

        const power = exponent / 2;
        const leading = Math.pow(progress, power);
        const trailing = Math.pow(1 - progress, power);
        return leading / (leading + trailing);
    }

    function buildCorner(cx: real, cy: real, radius: real, start: real, end: real): string {
        let points = "";
        for (let i = 1; i <= cornerSamples; i++) {
            const progress = cornerProgress(i / cornerSamples);
            const t = start + (end - start) * progress;
            const c = Math.cos(t);
            const s = Math.sin(t);
            const px = cx + radius * Math.sign(c) * Math.pow(Math.abs(c), 2 / exponent);
            const py = cy + radius * Math.sign(s) * Math.pow(Math.abs(s), 2 / exponent);
            points += " L " + point(px) + " " + point(py);
        }
        return points;
    }

    function buildPath(inset: real): string {
        const innerWidth = width - inset * 2;
        const innerHeight = height - inset * 2;
        const r = Math.min(Math.max(0, cornerRadius - inset), innerWidth / 2, innerHeight / 2);

        if (!Number.isFinite(innerWidth) || !Number.isFinite(innerHeight) || !Number.isFinite(r) || !Number.isFinite(exponent) || exponent <= 0 || innerWidth <= 0 || innerHeight <= 0 || r <= 0)
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

    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: Qt.rgba(root.fillColor.r, root.fillColor.g, root.fillColor.b, root.fillColor.a * root.fillOpacity)
            strokeColor: "transparent"
            strokeWidth: 0

            PathSvg {
                path: root.fillPathData
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: "transparent"
            strokeWidth: 0
            fillGradient: RadialGradient {
                centerX: root.width * 0.15
                centerY: root.height * -0.16
                centerRadius: Math.max(root.width * 0.9, root.height * 2)
                focalX: centerX
                focalY: centerY

                GradientStop {
                    position: 0
                    color: Qt.rgba(root.lightColor.r, root.lightColor.g, root.lightColor.b, root.lightStrength)
                }
                GradientStop {
                    position: 0.44
                    color: Qt.rgba(root.lightColor.r, root.lightColor.g, root.lightColor.b, root.lightStrength * 0.28)
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }

            PathSvg {
                path: root.fillPathData
            }
        }

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
        anchors.fill: parent
    }
}

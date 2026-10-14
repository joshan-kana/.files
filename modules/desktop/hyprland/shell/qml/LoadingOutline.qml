import QtQuick
import QtQuick.Shapes

// Reusable busy feedback for the owner's existing squircle outline. The
// illuminated segment travels around the real contour using eased motion;
// reduced motion leaves a quiet, steady outline and performs no frame work.
Item {
    id: outline

    required property SquircleSurface surface
    property bool active: false
    property bool motionEnabled: true
    property color highlightColor: "#7bbcff"
    property real lineWidth: 2.8
    property real segmentFraction: 0.12
    property int lapDuration: 1900
    property real circuit: 0

    readonly property real inset: lineWidth * 1.3 + 0.5
    readonly property real radius: Math.max(0, Math.min(surface.cornerRadius - inset, (width - 2 * inset) / 2, (height - 2 * inset) / 2))
    readonly property real perimeter: {
        const w = width - 2 * inset;
        const h = height - 2 * inset;
        if (w <= 0 || h <= 0 || radius <= 0)
            return 1;
        let quarter = 0;
        let prevX = radius;
        let prevY = 0;
        for (let i = 1; i <= surface.cornerSamples; i++) {
            const angle = surface.cornerProgress(i / surface.cornerSamples) * Math.PI / 2;
            const x = radius * Math.pow(Math.abs(Math.cos(angle)), 2 / surface.exponent);
            const y = radius * Math.pow(Math.abs(Math.sin(angle)), 2 / surface.exponent);
            quarter += Math.hypot(x - prevX, y - prevY);
            prevX = x;
            prevY = y;
        }
        return Math.max(1, 2 * (w + h - 4 * radius) + 4 * quarter);
    }
    readonly property real perimeterUnits: perimeter / Math.max(0.1, lineWidth)
    readonly property var dashUnits: [Math.max(1, perimeterUnits * segmentFraction), Math.max(1, perimeterUnits * (1 - segmentFraction))]

    visible: active
    enabled: false
    Accessible.ignored: true

    NumberAnimation on circuit {
        from: 0
        to: 1
        duration: outline.lapDuration
        loops: Animation.Infinite
        easing.type: Easing.InOutCubic
        running: outline.active && outline.motionEnabled
    }

    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(outline.highlightColor.r, outline.highlightColor.g, outline.highlightColor.b, 0.24)
            strokeWidth: outline.lineWidth
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: outline.surface.buildPath(outline.inset) || "M 0 0"
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: outline.motionEnabled ? outline.highlightColor : Qt.rgba(outline.highlightColor.r, outline.highlightColor.g, outline.highlightColor.b, 0.43)
            strokeWidth: outline.lineWidth + 0.7
            strokeStyle: outline.motionEnabled ? ShapePath.DashLine : ShapePath.SolidLine
            dashPattern: outline.dashUnits
            dashOffset: -outline.perimeterUnits * outline.circuit
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: outline.surface.buildPath(outline.inset) || "M 0 0"
            }
        }
    }
}

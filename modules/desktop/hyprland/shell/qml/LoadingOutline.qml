import QtQuick
import QtQuick.Shapes
import "OutlineTrace.js" as OutlineTrace

// Reusable busy feedback for the owner's existing squircle outline. The
// illuminated segment travels around the real contour using eased motion;
// reduced motion softly pulses the full outline without repainting Canvas.
Item {
    id: outline

    required property SquircleSurface surface
    property bool active: false
    required property Motion motion
    readonly property bool motionEnabled: motion.enabled
    required property color highlightColor
    property real lineWidth: 2.8
    property real segmentFraction: 0.12
    property real circuit: 0

    readonly property real inset: lineWidth * 1.3 + 0.5
    // Geometry is updated only when the actual surface changes, not on every
    // paint tick; the moving segment uses the same contour as its owner.
    readonly property string contourPath: surface.buildPath(inset)
    readonly property var contour: OutlineTrace.contour(contourPath)
    readonly property real perimeter: contour.length > 1 ? contour[contour.length - 1].at : 1

    visible: active
    enabled: false
    Accessible.ignored: true

    NumberAnimation on circuit {
        from: 0
        to: 1
        duration: outline.motion.contourLap
        loops: Animation.Infinite
        easing.type: outline.motion.contourEasing
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
                path: outline.contourPath || "M 0 0 L 0.01 0 L 0 0.01 Z"
            }
        }
    }

    OutlinePulse {
        anchors.fill: parent
        active: outline.active && !outline.motionEnabled
        contourPath: outline.contourPath
        highlightColor: outline.highlightColor
        lineWidth: outline.lineWidth
    }

    Canvas {
        id: movingSegment
        anchors.fill: parent
        visible: outline.active && outline.motionEnabled
        antialiasing: true

        onPaint: OutlineTrace.paint(getContext("2d"), outline.contour, outline.perimeter, outline.circuit, outline.segmentFraction, outline.highlightColor, outline.lineWidth + 0.7, width, height)

        Connections {
            target: outline
            function onCircuitChanged() {
                movingSegment.requestPaint();
            }
            function onContourChanged() {
                movingSegment.requestPaint();
            }
            function onHighlightColorChanged() {
                movingSegment.requestPaint();
            }
            function onLineWidthChanged() {
                movingSegment.requestPaint();
            }
        }
    }
}

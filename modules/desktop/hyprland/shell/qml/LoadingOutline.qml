import QtQuick
import QtQuick.Shapes

// Shared busy state for any SquircleSurface. Animate only the composed item's
// opacity: shape tessellation and border geometry remain static during each
// slow breathing cycle, so the animation cannot interrupt the child content.
Item {
    id: outline

    required property SquircleSurface surface
    property bool active: false
    property bool motionEnabled: true
    property color highlightColor: "#7bbcff"
    property real lineWidth: 2.6
    property int breathDuration: 2300
    readonly property real inset: lineWidth * 1.3 + 0.5
    property real pulseOpacity: 0.28

    visible: active
    enabled: false
    opacity: active ? (motionEnabled ? pulseOpacity : 0.33) : 0
    Accessible.ignored: true

    SequentialAnimation on pulseOpacity {
        running: outline.active && outline.motionEnabled
        loops: Animation.Infinite
        NumberAnimation {
            from: 0.28
            to: 0.95
            duration: outline.breathDuration
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            from: 0.95
            to: 0.28
            duration: outline.breathDuration
            easing.type: Easing.InOutSine
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(outline.highlightColor.r, outline.highlightColor.g, outline.highlightColor.b, 0.36)
            strokeWidth: outline.lineWidth * 3.0
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: outline.surface.buildPath(outline.inset) || "M 0 0"
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: outline.highlightColor
            strokeWidth: outline.lineWidth
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: outline.surface.buildPath(outline.inset) || "M 0 0"
            }
        }
    }
}

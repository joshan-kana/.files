import QtQuick
import QtQuick.Shapes

// Reduced-motion busy feedback is a steady, visible contour.
// Shape geometry stays in the scene graph without an animation timer.
Item {
    id: pulse

    property bool active: false
    property string contourPath: ""
    required property color highlightColor
    property real lineWidth: 2
    readonly property real intensity: 0.72

    visible: active
    enabled: false
    Accessible.ignored: true

    Shape {
        anchors.fill: parent
        opacity: pulse.intensity
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(pulse.highlightColor.r, pulse.highlightColor.g, pulse.highlightColor.b, 0.07)
            strokeWidth: pulse.lineWidth * 4
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: pulse.contourPath || "M 0 0 L 0.01 0 L 0 0.01 Z"
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(pulse.highlightColor.r, pulse.highlightColor.g, pulse.highlightColor.b, 0.15)
            strokeWidth: pulse.lineWidth * 2.2
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: pulse.contourPath || "M 0 0 L 0.01 0 L 0 0.01 Z"
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(pulse.highlightColor.r, pulse.highlightColor.g, pulse.highlightColor.b, 0.78)
            strokeWidth: pulse.lineWidth
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: pulse.contourPath || "M 0 0 L 0.01 0 L 0 0.01 Z"
            }
        }
    }
}

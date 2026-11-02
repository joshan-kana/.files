import QtQuick
import QtQuick.Shapes

// Shared reduced-motion busy state: a slow, soft glow around the full
// outline. Only opacity changes; contour geometry stays in the scene graph.
Item {
    id: pulse

    property bool active: false
    property string contourPath: ""
    required property color highlightColor
    property real lineWidth: 2
    property real intensity: 0.22

    visible: active
    enabled: false
    Accessible.ignored: true

    SequentialAnimation on intensity {
        running: pulse.active
        loops: Animation.Infinite
        NumberAnimation {
            from: 0.22
            to: 1
            duration: 1800
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            from: 1
            to: 0.22
            duration: 1800
            easing.type: Easing.InOutSine
        }
    }

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

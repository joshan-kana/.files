pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

// A curved interior screen corner; no painted rectangular backing or focus region.
Item {
    id: corner
    property int position: 0 // top-left, top-right, bottom-left, bottom-right
    property real rounding: 32
    property color surfaceColor: "transparent"
    implicitWidth: rounding
    implicitHeight: rounding
    readonly property bool rightSide: position === 1 || position === 3
    readonly property bool bottomSide: position >= 2

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true
        ShapePath {
            fillColor: corner.surfaceColor
            strokeColor: "transparent"
            strokeWidth: 0
            startX: corner.rightSide ? corner.width : 0
            startY: corner.bottomSide ? corner.height : 0
            PathAngleArc {
                centerX: corner.rightSide ? 0 : corner.width
                centerY: corner.bottomSide ? 0 : corner.height
                radiusX: corner.rounding
                radiusY: corner.rounding
                startAngle: [180, -90, 90, 0][corner.position]
                sweepAngle: 90
                moveToStart: false
            }
            PathLine {
                x: corner.rightSide ? corner.width : 0
                y: corner.bottomSide ? corner.height : 0
            }
        }
    }
}

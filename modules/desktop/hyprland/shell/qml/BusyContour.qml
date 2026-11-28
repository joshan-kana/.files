pragma ComponentBehavior: Bound
import QtQuick
import "OutlineTrace.js" as OutlineTrace

Item {
    id: trace
    required property Motion motion
    required property string contourPath
    readonly property var points: active ? OutlineTrace.contour(contourPath) : []
    readonly property real perimeter: points.length > 1 ? points[points.length - 1].at : 0
    required property color highlightColor
    property bool active: false
    property real lineWidth: 2

    visible: active
    enabled: false
    Accessible.ignored: true

    onActiveChanged: if (motion)
        motion.setContourActive(trace, active)
    Component.onCompleted: motion.setContourActive(trace, active)
    Component.onDestruction: if (motion)
        motion.setContourActive(trace, false)

    OutlinePulse {
        anchors.fill: parent
        active: trace.active && !trace.motion.enabled
        contourPath: trace.contourPath
        highlightColor: trace.highlightColor
        lineWidth: trace.lineWidth
    }

    Canvas {
        id: movingSegment
        readonly property var bounds: trace.active && trace.motion.enabled ? OutlineTrace.traceBounds(trace.points, trace.perimeter, trace.motion.contourProgress, 0.10, Math.ceil(trace.lineWidth * 12)) : null
        x: bounds ? bounds.x : 0
        y: bounds ? bounds.y : 0
        width: bounds ? bounds.width : 1
        height: bounds ? bounds.height : 1
        visible: trace.active && trace.motion.enabled
        antialiasing: true
        onPaint: {
            if (bounds)
                OutlineTrace.paint(getContext("2d"), trace.points, trace.perimeter, trace.motion.contourProgress, 0.10, trace.highlightColor, trace.lineWidth, width, height, bounds.x, bounds.y, bounds);
        }
        onBoundsChanged: requestPaint()
        onVisibleChanged: requestPaint()
        Connections {
            target: trace
            function onHighlightColorChanged() {
                movingSegment.requestPaint();
            }
            function onLineWidthChanged() {
                movingSegment.requestPaint();
            }
        }
    }
}

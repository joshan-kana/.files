import QtQuick

Item {
    id: level
    required property Theme theme
    required property Motion motion
    property real fraction: 0
    property bool known: true
    property color accentColor: theme.accent
    property real thickness: theme.standardTrack
    implicitHeight: thickness
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: level.theme.layer3
        Rectangle {
            height: parent.height
            width: level.known ? parent.width * Math.max(0, Math.min(1, level.fraction)) : 0
            radius: height / 2
            color: level.accentColor
            Behavior on width {
                Anim {
                    motion: level.motion
                    type: Anim.FastSpatial
                }
            }
        }
    }
}

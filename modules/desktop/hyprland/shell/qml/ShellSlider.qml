import QtQuick

Item {
    id: root

    required property QtObject theme
    required property QtObject motion

    property real from: 0
    property real to: 1
    property real value: 0
    property color accentColor: theme.accent
    property real trackHeight: 10
    property real handleSize: 20
    readonly property real normalizedValue: to === from ? 0 : Math.max(0, Math.min(1, (value - from) / (to - from)))

    signal valueRequested(real value)

    implicitHeight: Math.max(handleSize, 28)
    opacity: enabled ? 1 : 0.42

    function valueForX(mouseX: real): real {
        const usable = Math.max(1, width - handleSize);
        const fraction = Math.max(0, Math.min(1, (mouseX - handleSize / 2) / usable));
        return from + fraction * (to - from);
    }

    Rectangle {
        id: track
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: root.handleSize / 2
            rightMargin: root.handleSize / 2
        }
        height: root.trackHeight
        radius: height / 2
        color: theme.layer3

        Rectangle {
            height: parent.height
            width: parent.width * root.normalizedValue
            radius: parent.radius
            color: root.accentColor

            Behavior on width {
                enabled: !interaction.pressed
                Anim {
                    motion: root.motion
                    type: Anim.FastSpatial
                }
            }
        }
    }

    Rectangle {
        id: handle
        width: root.handleSize
        height: root.handleSize
        radius: width / 2
        x: root.normalizedValue * Math.max(1, root.width - width)
        anchors.verticalCenter: parent.verticalCenter
        color: root.accentColor
        scale: interaction.pressed ? 1.18 : 1

        Behavior on x {
            enabled: !interaction.pressed
            Anim {
                motion: root.motion
                type: Anim.FastSpatial
            }
        }

        Behavior on scale {
            Anim {
                motion: root.motion
                type: Anim.FastSpatial
            }
        }
    }

    MouseArea {
        id: interaction
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: enabled ? (pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor) : Qt.ArrowCursor

        onPressed: event => root.valueRequested(root.valueForX(event.x))
        onPositionChanged: event => {
            if (pressed)
                root.valueRequested(root.valueForX(event.x));
        }
    }
}

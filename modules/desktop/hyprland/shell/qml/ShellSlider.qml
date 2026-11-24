import QtQuick

Item {
    id: root

    required property Theme theme
    required property Motion motion

    property real from: 0
    property real to: 1
    property real value: 0
    property bool interactive: true
    // Animate external/keyboard changes, never fight pointer dragging.
    property bool animateValueChanges: false
    property color accentColor: theme.accent
    property real trackHeight: 10
    property real handleSize: 20
    // Material Expressive uses a narrow, vertical pill that compresses on
    // press. Keep its centre fixed so the pointer's requested value cannot
    // jump when the thumb changes shape.
    property real thumbTrackGap: 5
    readonly property real thumbCenterX: handleSize / 2 + displayedValue * Math.max(1, width - handleSize)
    readonly property bool thumbHovered: interaction.containsMouse && Math.abs(interaction.mouseX - thumbCenterX) <= handleSize * 0.85
    readonly property real normalizedValue: to === from ? 0 : Math.max(0, Math.min(1, (value - from) / (to - from)))
    property real displayedValue: normalizedValue
    Behavior on displayedValue {
        enabled: root.animateValueChanges && root.motion.enabled && !interaction.pressed
        // A Bézier restarts its ease on every key-repeat event. Keep velocity
        // continuous while the target moves, including when direction reverses.
        SmoothedAnimation {
            velocity: 1.35
            duration: root.motion.spatialFast
            maximumEasingTime: 60
            reversingMode: SmoothedAnimation.Eased
        }
    }

    signal valueRequested(real value)
    signal interactionStarted(real value)
    signal interactionUpdated(real value)
    signal interactionFinished(real value)

    implicitHeight: Math.max(handleSize, 28)
    opacity: enabled ? 1 : 0.42

    function valueForX(mouseX: real): real {
        const usable = Math.max(1, width - handleSize);
        const fraction = Math.max(0, Math.min(1, (mouseX - handleSize / 2) / usable));
        return from + fraction * (to - from);
    }

    // Split the active and inactive tracks around the thumb instead of
    // painting a fake gap with an opaque colour over frosted surfaces.
    Rectangle {
        id: activeTrack
        anchors.verticalCenter: parent.verticalCenter
        x: root.handleSize / 2
        width: Math.max(0, root.thumbCenterX - root.thumbTrackGap - x)
        height: root.trackHeight
        radius: height / 2
        color: root.accentColor
    }

    Rectangle {
        id: inactiveTrack
        anchors.verticalCenter: parent.verticalCenter
        x: root.thumbCenterX + root.thumbTrackGap
        width: Math.max(0, root.width - root.handleSize / 2 - x)
        height: root.trackHeight
        radius: height / 2
        color: root.theme.layer3
    }

    Rectangle {
        id: handle
        width: Math.max(4, root.handleSize * (interaction.pressed ? 0.26 : root.thumbHovered ? 0.5 : 0.42))
        height: Math.min(root.height, root.handleSize * (interaction.pressed ? 1.14 : 1))
        radius: width / 2
        x: root.thumbCenterX - width / 2
        anchors.verticalCenter: parent.verticalCenter
        color: root.accentColor

        Behavior on width {
            Anim {
                motion: root.motion
                type: Anim.FastSpatial
            }
        }
        Behavior on height {
            Anim {
                motion: root.motion
                type: Anim.FastSpatial
            }
        }
    }

    MouseArea {
        id: interaction
        anchors.fill: parent
        enabled: root.enabled && root.interactive
        hoverEnabled: true
        cursorShape: enabled ? (pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor) : Qt.ArrowCursor

        onPressed: event => {
            const next = root.valueForX(event.x);
            root.interactionStarted(next);
            root.valueRequested(next);
        }
        onPositionChanged: event => {
            if (!pressed)
                return;
            const next = root.valueForX(event.x);
            root.interactionUpdated(next);
            root.valueRequested(next);
        }
        onReleased: event => {
            const next = root.valueForX(event.x);
            root.interactionFinished(next);
            root.valueRequested(next);
        }
        onCanceled: root.interactionFinished(root.value)
    }
}

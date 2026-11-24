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
    property bool animateValueChanges: true
    property color accentColor: theme.accent
    property bool temperatureTrack: false
    enum Density {
        Compact,
        Standard,
        Prominent
    }
    property int density: ShellSlider.Standard
    property real trackHeight: density === ShellSlider.Compact ? theme.compactTrack : density === ShellSlider.Prominent ? theme.prominentTrack : theme.standardTrack
    property real handleSize: theme.fontSize(density === ShellSlider.Compact ? 18 : density === ShellSlider.Prominent ? 28 : 22)
    // Material Expressive uses a narrow, vertical pill that compresses on
    // press. Keep its centre fixed so the pointer's requested value cannot
    // jump when the thumb changes shape.
    property real thumbTrackGap: 5
    readonly property real thumbCenterX: handleSize / 2 + displayedValue * Math.max(1, width - handleSize)
    readonly property bool thumbPressed: motion.enabled && (interaction.pressed || motion.keyboardSlider === root)
    readonly property bool thumbHovered: interaction.containsMouse && Math.abs(interaction.mouseX - thumbCenterX) <= handleSize * 0.85
    readonly property real normalizedValue: to === from ? 0 : Math.max(0, Math.min(1, (value - from) / (to - from)))
    property real displayedValue: interaction.pressed ? fractionForX(interaction.mouseX) : normalizedValue
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
    signal interactionCanceled

    implicitHeight: Math.max(handleSize, 28)
    opacity: enabled ? 1 : 0.42

    function fractionForX(mouseX: real): real {
        const usable = Math.max(1, width - handleSize);
        return Math.max(0, Math.min(1, (mouseX - handleSize / 2) / usable));
    }

    function valueForX(mouseX: real): real {
        return from + fractionForX(mouseX) * (to - from);
    }

    // The existing key-down dispatch owns the value change. Feedback stays
    // compressed until the physical key is released, even at a range limit.
    function beginKeyboardAdjustment(): void {
        if (enabled && visible && interactive && motion.enabled)
            motion.beginKeyboardAdjustment(root);
    }

    function clearKeyboardAdjustment(): void {
        if (motion && motion.keyboardSlider === root)
            motion.endKeyboardAdjustment();
    }

    onVisibleChanged: if (!visible)
        clearKeyboardAdjustment()
    onEnabledChanged: if (!enabled)
        clearKeyboardAdjustment()
    onInteractiveChanged: if (!interactive)
        clearKeyboardAdjustment()

    // Split the active and inactive tracks around the thumb instead of
    // painting a fake gap with an opaque colour over frosted surfaces.
    Rectangle {
        visible: root.temperatureTrack
        x: root.handleSize / 2
        width: Math.max(0, root.width - root.handleSize)
        height: root.trackHeight
        radius: height / 2
        anchors.verticalCenter: parent.verticalCenter
        // Physical colour temperature: warm at 2500 K, near-neutral at 6500 K.
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: "#ff9e50"
            }
            GradientStop {
                position: 0.5
                color: "#ffdbb5"
            }
            GradientStop {
                position: 1
                color: "#fff9f5"
            }
        }
    }

    Rectangle {
        id: activeTrack
        visible: !root.temperatureTrack
        anchors.verticalCenter: parent.verticalCenter
        x: root.handleSize / 2
        width: Math.max(0, root.thumbCenterX - root.thumbTrackGap - x)
        height: root.trackHeight
        radius: height / 2
        color: root.accentColor
    }

    Rectangle {
        id: inactiveTrack
        visible: !root.temperatureTrack
        anchors.verticalCenter: parent.verticalCenter
        x: root.thumbCenterX + root.thumbTrackGap
        width: Math.max(0, root.width - root.handleSize / 2 - x)
        height: root.trackHeight
        radius: height / 2
        color: root.theme.layer3
    }

    Rectangle {
        id: handle
        width: Math.max(4, root.handleSize * (root.thumbPressed ? 0.26 : root.motion.enabled && root.thumbHovered ? 0.5 : 0.42))
        height: Math.min(root.height, root.handleSize)
        radius: width / 2
        x: root.thumbCenterX - width / 2
        anchors.verticalCenter: parent.verticalCenter
        color: root.temperatureTrack ? root.theme.textStrong : root.accentColor
        border.width: root.temperatureTrack ? 1 : 0
        border.color: root.theme.background

        Behavior on width {
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
        onCanceled: root.interactionCanceled()
    }
}

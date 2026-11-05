import QtQuick
import QtQuick.Shapes

MouseArea {
    id: root

    required property Theme theme
    required property Motion motion

    property bool disabled: false
    property bool selected: false
    property bool manualHover: false
    property bool manualPress: false
    property bool heldPress: false
    readonly property bool visualPressed: pressed || manualPress || heldPress
    // Passive hover tracks the whole component even when a child receives
    // mouse events. The original MouseArea.containsMouse can briefly drop as
    // the pointer crosses interactive descendants, flickering shared tiles.
    property bool pointerHovered: false
    function updatePointerHover(): void {
        if (containsMouse || hoverHandler.hovered) {
            hoverExit.stop();
            pointerHovered = true;
        } else {
            hoverExit.restart();
        }
    }
    onContainsMouseChanged: updatePointerHover()
    onEnabledChanged: {
        if (!enabled) {
            hoverExit.stop();
            pointerHovered = false;
        } else {
            updatePointerHover();
        }
    }
    HoverHandler {
        id: hoverHandler
        enabled: root.enabled
        onHoveredChanged: root.updatePointerHover()
    }
    Timer {
        id: hoverExit
        interval: 55
        onTriggered: root.pointerHovered = root.enabled && (root.containsMouse || hoverHandler.hovered)
    }
    property bool showHover: true
    property color stateColor: selected ? theme.accent : theme.textStrong
    property real hoverOpacity: 0.10
    property real pressOpacity: 0.16
    property real cornerRadius: theme.radiusMedium
    property real exponent: theme.squircleExponent

    property real rippleX: width / 2
    property real rippleY: height / 2
    property real rippleRadius: 0
    property real rippleOpacity: 0
    readonly property bool animationsEnabled: motion.enabled
    readonly property real rippleExtent: Math.hypot(Math.max(rippleX, width - rippleX), Math.max(rippleY, height - rippleY)) * 1.08

    onAnimationsEnabledChanged: {
        if (!animationsEnabled) {
            growRipple.stop();
            fadeRipple.stop();
            rippleOpacity = 0;
        }
    }

    function startRipple(x: real, y: real): void {
        // An interaction with no hover surface must not leave a separate
        // ripple tracing an imaginary pill in a connected frame.
        if (!animationsEnabled || !showHover)
            return;
        fadeRipple.stop();
        growRipple.stop();
        rippleX = x;
        rippleY = y;
        rippleRadius = 0;
        rippleOpacity = 0.16;
        growRipple.restart();
    }

    signal activated(var event)

    anchors.fill: parent
    enabled: !disabled
    hoverEnabled: true
    cursorShape: disabled ? Qt.ArrowCursor : Qt.PointingHandCursor

    onClicked: event => activated(event)
    // A quick physical click can finish between two rendered frames. Preserve
    // the shared press state for one short effects interval so both detached
    // controls and connected frame contours actually display feedback.
    onPressed: event => {
        heldPress = true;
        pressFeedback.restart();
        startRipple(event.x, event.y);
    }
    onDisabledChanged: {
        if (disabled)
            heldPress = false;
    }
    Timer {
        id: pressFeedback
        interval: root.motion.enabled ? Math.max(110, root.motion.effectsFast) : 0
        onTriggered: root.heldPress = false
    }
    onReleased: fadeRipple.restart()
    onCanceled: fadeRipple.restart()

    NumberAnimation {
        id: growRipple
        target: root
        property: "rippleRadius"
        to: root.rippleExtent
        duration: root.motion.spatialSlow
        easing.type: root.motion.spatialType
        easing.bezierCurve: root.motion.spatialCurve
    }

    NumberAnimation {
        id: fadeRipple
        target: root
        property: "rippleOpacity"
        to: 0
        duration: root.motion.effectsSlow
        easing.type: root.motion.effectsType
        easing.bezierCurve: root.motion.effectsCurve
    }

    // The native fill is triangulated around a centre point. On translucent
    // hover/press feedback the triangle boundaries can leave straight seams,
    // especially through narrow mute buttons and wide network rows. Render
    // this interaction-only overlay as one shaped path using the same shared
    // squircle contour; ordinary surfaces keep the native fast fill.
    SquircleSurface {
        id: hoverSurface
        anchors.fill: parent
        cornerRadius: root.cornerRadius
        exponent: root.exponent
        fillColor: "transparent"
    }
    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        visible: opacity > 0
        opacity: {
            if (!root.showHover)
                return 0;
            if (root.visualPressed)
                return root.pressOpacity;
            if (root.pointerHovered || root.manualHover)
                return root.hoverOpacity;
            return 0;
        }
        Behavior on opacity {
            Anim {
                motion: root.motion
                type: Anim.FastEffects
            }
        }
        ShapePath {
            fillColor: root.stateColor
            strokeColor: "transparent"
            strokeWidth: -1
            PathSvg {
                path: hoverSurface.fillPathData
            }
        }
    }
    Shape {
        anchors.fill: parent
        visible: root.rippleOpacity > 0
        opacity: root.rippleOpacity
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            strokeWidth: 0
            fillGradient: RadialGradient {
                centerX: root.rippleX
                centerY: root.rippleY
                centerRadius: Math.max(1, root.rippleRadius)
                focalX: centerX
                focalY: centerY

                GradientStop {
                    position: 0
                    color: root.stateColor
                }
                GradientStop {
                    position: 0.72
                    color: root.stateColor
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }

            PathSvg {
                path: hoverSurface.fillPathData
            }
        }
    }
}

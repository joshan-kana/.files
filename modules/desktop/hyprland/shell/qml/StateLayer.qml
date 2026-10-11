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
    property bool showHover: true
    property color stateColor: selected ? theme.accent : theme.textStrong
    property real hoverOpacity: 0.08
    property real pressOpacity: 0.12
    property real cornerRadius: theme.radiusMedium

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
        if (!animationsEnabled)
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
    onPressed: event => startRipple(event.x, event.y)
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

    SquircleSurface {
        id: hoverSurface
        anchors.fill: parent
        cornerRadius: root.cornerRadius
        exponent: root.theme.squircleExponent
        fillColor: root.stateColor
        opacity: {
            if (root.pressed || root.manualPress)
                return root.pressOpacity;
            if (root.showHover && (root.containsMouse || root.manualHover))
                return root.hoverOpacity;
            return 0;
        }

        Behavior on opacity {
            Anim {
                motion: root.motion
                type: Anim.FastEffects
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

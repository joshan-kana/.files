pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: button

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property string icon: ""
    property bool lockGlyph: false
    property string label: ""
    property string shortcut: ""
    property bool selected: false
    property bool active: false
    property bool armed: false
    property color accentColor: theme.roleColor("resources")

    signal activated
    signal hovered

    implicitWidth: 154
    implicitHeight: 155

    // Port of end-4's large morphing session buttons. The existing squircle
    // owns the geometry; neither a second shape implementation nor a mask is needed.
    ShellSurface {
        id: surface
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
        }
        width: 115
        height: 115
        theme: button.theme
        motion: button.motion
        cornerRadius: button.selected || pointer.pointerHovered ? width / 2 : button.theme.radiusLarge
        exponent: button.selected || pointer.pointerHovered ? 2.2 : button.theme.squircleExponent
        fillColor: button.armed ? button.theme.focusFill : button.selected || button.active ? button.theme.blend(button.theme.controlBase, button.accentColor, button.theme.dark ? 0.24 : 0.14) : button.theme.expressiveSurfaceStrong
        luminous: button.active
        luminousColor: button.accentColor
        outlined: button.active
        borderColor: button.armed ? button.theme.warning : button.selected || button.active ? button.accentColor : "transparent"
        borderWidth: button.selected || button.armed || button.active ? button.theme.borderFocus : 0

        Behavior on cornerRadius {
            NumberAnimation {
                duration: button.motion.spatialFast
                easing.type: button.motion.spatialType
                easing.bezierCurve: button.motion.spatialCurve
            }
        }
        Behavior on exponent {
            NumberAnimation {
                duration: button.motion.spatialFast
                easing.type: button.motion.spatialType
                easing.bezierCurve: button.motion.spatialCurve
            }
        }

        // The icon represents the action, not hover or keyboard focus.
        // Reuse the same vector lock as the session lock screen.
        LockGlyph {
            visible: button.lockGlyph
            anchors.centerIn: parent
            width: 46
            height: 46
            color: button.armed ? button.theme.warning : button.accentColor
        }

        Text {
            visible: !button.lockGlyph
            anchors.centerIn: parent
            text: button.icon
            color: button.armed ? button.theme.warning : button.accentColor
            font.family: "Symbols Nerd Font"
            font.pixelSize: button.theme.fontSize(43)
            font.weight: Font.Normal
        }

        StateLayer {
            id: pointer
            theme: button.theme
            motion: button.motion
            selected: button.selected
            cornerRadius: surface.cornerRadius
            exponent: surface.exponent
            onEntered: button.hovered()
            onActivated: button.activated()
        }
    }

    // The surface morphs from a squircle to a circle on focus/hover.
    // Keep the keycap outside that shape so its corners never disappear.
    KeyHint {
        anchors {
            top: parent.top
            right: parent.right
            topMargin: button.theme.spacing2
            rightMargin: button.theme.spacing2
        }
        runtime: button.runtime
        theme: button.theme
        shortcut: button.shortcut
        compact: true
        emphasized: button.selected
        emphasisColor: button.accentColor
    }

    Text {
        anchors {
            top: surface.bottom
            topMargin: button.theme.spacing2
            horizontalCenter: parent.horizontalCenter
        }
        text: button.armed ? "CONFIRM " + button.label.toUpperCase() : button.label
        color: button.armed ? button.theme.warning : button.selected ? button.accentColor : button.theme.textStrong
        font.family: button.runtime.fontMono
        font.pixelSize: button.theme.fontSize(11)
        font.weight: button.selected ? Font.DemiBold : Font.Medium
    }
}

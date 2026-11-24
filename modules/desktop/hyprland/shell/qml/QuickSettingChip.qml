pragma ComponentBehavior: Bound
import QtQuick

// Compact, live-state action for the Controls strip. The caller owns the action.
Item {
    id: chip

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    property string title: ""
    property string icon: ""
    property string shortcut: ""
    property string detailShortcut: ""
    property string detailName: "Open details"
    signal detailsRequested
    property bool active: false
    property color activeColor: theme.accent

    signal activated

    implicitHeight: 78
    Accessible.role: Accessible.Button
    Accessible.name: detailShortcut.length > 0 ? "Open " + title + " details" : title

    // Scale inward at rest and fill the allocated bounds on hover.
    // The hub viewport clips content outside its edge during panel morphs.

    ShellSurface {
        id: chipSurface
        scale: !chip.motion.enabled ? 1 : press.visualPressed ? chip.motion.pressScaleSmall : press.pointerHovered ? 1 : 0.982
        Behavior on scale {
            enabled: chip.motion.enabled
            SpringAnimation {
                spring: chip.motion.pressSpring
                damping: chip.motion.pressDamping
                epsilon: chip.motion.pressEpsilon
            }
        }
        anchors.fill: parent
        theme: chip.theme
        motion: chip.motion
        surfaceLayer: ShellSurface.Control
        cornerRadius: chip.active ? chip.theme.radiusLarge : chip.theme.radiusMedium
        luminous: chip.active
        luminousColor: chip.activeColor
        outlined: chip.active
        borderColor: chip.active ? chip.activeColor : "transparent"
        hovered: press.pointerHovered
        fillColor: chip.active ? chip.theme.blend(chip.theme.controlBase, chip.activeColor, chip.theme.dark ? 0.12 : 0.08) : chip.theme.expressiveSurfaceStrong

        Behavior on cornerRadius {
            Anim {
                motion: chip.motion
                type: Anim.FastSpatial
            }
        }

        // Icon and title retain their own layout while shortcuts are anchored
        // independently to the tile surface.
        Column {
            anchors {
                fill: parent
                leftMargin: chip.theme.spacing2
                rightMargin: chip.theme.spacing2
                topMargin: chip.theme.spacing3 + 3
                bottomMargin: chip.theme.spacing2
            }
            spacing: chip.theme.spacing2

            Item {
                width: parent.width
                height: Math.max(chip.theme.keycapHeight - 3, chip.theme.fontSize(21))
                Text {
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        verticalCenter: parent.verticalCenter
                    }
                    text: chip.icon
                    color: chip.activeColor
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: chip.theme.fontSize(20)
                }
            }

            MarqueeText {
                width: parent.width
                text: chip.title
                color: chip.theme.textStrong
                alignCenter: true
                font.family: chip.runtime.fontSans
                font.pixelSize: chip.theme.fontSize(10)
                font.weight: chip.active ? Font.DemiBold : Font.Medium
            }
        }
        // Primary action: always in the top-left, even when focused or active.
        TileKeyHint {
            primary: true
            visible: chip.shortcut.length > 0 && chip.detailShortcut.length === 0
            shortcut: chip.shortcut
            compact: true
            runtime: chip.runtime
            motion: chip.motion
            theme: chip.theme
            emphasized: chip.active
            emphasisColor: chip.activeColor
        }
    }

    StateLayer {
        id: press
        effectScaleX: chipSurface.scale
        effectScaleY: chipSurface.scale
        theme: chip.theme
        motion: chip.motion
        selected: chip.active
        stateColor: chip.theme.textStrong
        hoverOpacity: 0.05
        pressOpacity: 0.11
        cornerRadius: chipSurface.cornerRadius
        onActivated: chip.detailShortcut.length > 0 ? chip.detailsRequested() : chip.activated()
    }

    TileQuickAction {
        runtime: chip.runtime
        theme: chip.theme
        motion: chip.motion
        shortcut: chip.detailShortcut.length > 0 ? chip.shortcut : ""
        actionName: "Activate " + chip.title
        selected: chip.active
        emphasisColor: chip.activeColor
        onActivated: chip.activated()
    }

    TileCornerAction {
        runtime: chip.runtime
        theme: chip.theme
        motion: chip.motion
        shortcut: chip.detailShortcut
        actionName: chip.detailName
        emphasisColor: chip.activeColor
        onActivated: chip.detailsRequested()
    }
}

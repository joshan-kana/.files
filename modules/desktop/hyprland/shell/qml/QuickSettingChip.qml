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

    property bool foregroundBusy: false
    property color foregroundColor: theme.accent

    signal activated

    implicitWidth: Math.max(140 * theme.textScale, labelMetrics.advanceWidth + theme.spacing2 * 2, primaryHint.implicitWidth + detailHint.implicitWidth + theme.spacing4 * 2 + theme.iconLarge)
    implicitHeight: Math.max(72, tileContent.implicitHeight + theme.spacing3 + 3 + theme.spacing2)
    TextMetrics {
        id: labelMetrics
        text: chip.title
        font: tileLabel.font
    }
    Accessible.role: Accessible.Grouping
    Accessible.name: title

    ShellSurface {
        id: chipSurface
        foregroundBusy: chip.foregroundBusy
        foregroundColor: chip.foregroundColor
        scale: press.defaultEffectScale
        anchors.fill: parent
        theme: chip.theme
        motion: chip.motion
        surfaceLayer: ShellSurface.Control
        cornerRadius: chip.active ? chip.theme.radiusLarge : chip.theme.radiusMedium
        luminous: chip.active
        luminousColor: chip.activeColor
        outlined: chip.active
        borderColor: chip.active ? chip.activeColor : "transparent"
        hovered: press.pointerHovered || press.manualHover
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
            id: tileContent
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

            ShellText {
                id: tileLabel
                width: parent.width
                runtime: chip.runtime
                theme: chip.theme
                text: chip.title
                color: chip.theme.textStrong
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.pixelSize: chip.theme.fontCompactAction
                font.weight: chip.active ? Font.DemiBold : Font.Medium
            }
        }
        // Primary action: always in the top-left, even when focused or active.
        TileKeyHint {
            id: primaryHint
            primary: true
            visible: chip.shortcut.length > 0
            shortcut: chip.shortcut
            compact: true
            runtime: chip.runtime
            motion: chip.motion
            theme: chip.theme
            emphasized: chip.active
            emphasisColor: chip.activeColor
        }
        TileKeyHint {
            id: detailHint
            visible: chip.detailShortcut.length > 0
            shortcut: chip.detailShortcut
            compact: true
            runtime: chip.runtime
            motion: chip.motion
            theme: chip.theme
            emphasisColor: chip.activeColor
        }
    }

    StateLayer {
        id: press
        growOnHover: true
        effectScaleX: chipSurface.scale
        effectScaleY: chipSurface.scale
        theme: chip.theme
        motion: chip.motion
        selected: chip.active
        manualPress: quickAction.visible && quickAction.visualPressed
        manualHover: quickAction.visible && quickAction.pointerHovered
        Accessible.role: Accessible.Button
        Accessible.name: chip.detailShortcut.length > 0 ? chip.detailName + " · " + chip.title : chip.title
        Accessible.onPressAction: chip.detailShortcut.length > 0 ? chip.detailsRequested() : chip.activated()
        stateColor: chip.theme.textStrong
        hoverOpacity: 0.05
        pressOpacity: 0.11
        cornerRadius: chipSurface.cornerRadius
        onActivated: chip.detailShortcut.length > 0 ? chip.detailsRequested() : chip.activated()
    }

    TileQuickAction {
        id: quickAction
        hint: primaryHint
        runtime: chip.runtime
        theme: chip.theme
        motion: chip.motion
        shortcut: chip.detailShortcut.length > 0 ? chip.shortcut : ""
        actionName: "Activate " + chip.title
        selected: chip.active
        emphasisColor: chip.activeColor
        onActivated: chip.activated()
    }
}

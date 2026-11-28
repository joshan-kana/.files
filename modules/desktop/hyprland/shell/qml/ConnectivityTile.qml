pragma ComponentBehavior: Bound
import QtQuick

// Prominent live connectivity control for the hub.
// The native state owner supplies every label and activation; no local polling.
Item {
    id: tile

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property string title: ""
    property string detail: ""
    property string status: ""
    property string glyph: ""
    property string actionId: ""
    property string shortcut: actionId.length > 0 ? runtime.shellHint(actionId) : ""
    property string detailActionId: ""
    property string detailShortcut: detailActionId.length > 0 ? runtime.shellHint(detailActionId) : ""
    signal detailsRequested
    property bool connected: false
    property bool pending: false
    property bool scanning: false
    property bool failed: false
    property bool unavailable: false
    // A radio toggle may be unavailable while another connection is active.
    // The detail action remains usable even when primary activation cannot run.
    property bool primaryAvailable: !unavailable
    readonly property color signalColor: failed ? theme.critical : pending || scanning ? theme.warning : connected ? theme.roleColor("connectivity") : theme.textMuted
    readonly property color foreground: theme.textStrong

    property bool foregroundBusy: false
    property color foregroundColor: theme.progressColor

    signal activated

    function trigger(): void {
        if (!enabled || !primaryAvailable || pending)
            return;
        if (detailShortcut.length > 0)
            quickAction.trigger();
        else
            interaction.trigger();
    }

    function triggerDetails(): void {
        if (!enabled)
            return;
        interaction.trigger();
    }

    implicitHeight: 92
    Accessible.role: Accessible.Grouping
    Accessible.name: title + ", " + detail + ", " + status

    ShellSurface {
        id: tileBody
        foregroundBusy: tile.foregroundBusy
        foregroundColor: tile.foregroundColor
        scale: interaction.defaultEffectScale
        anchors.fill: parent
        theme: tile.theme
        motion: tile.motion
        surfaceLayer: ShellSurface.Group
        cornerRadius: tile.theme.radiusLarge
        luminous: tile.connected || tile.pending || tile.scanning || tile.failed
        luminousColor: tile.signalColor
        hovered: interaction.pointerHovered || interaction.manualHover
        fillColor: tile.failed ? tile.theme.blend(tile.theme.groupBase, tile.theme.critical, 0.16) : tile.pending || tile.scanning ? tile.theme.blend(tile.theme.groupBase, tile.theme.warning, 0.14) : tile.connected ? tile.theme.blend(tile.theme.groupBase, tile.signalColor, tile.theme.dark ? 0.095 : 0.065) : tile.unavailable ? tile.theme.groupBase : tile.theme.expressiveSurfaceStrong

        ShellSurface {
            id: glyphSurface
            width: 47
            height: 47
            anchors {
                left: parent.left
                leftMargin: Math.max(tile.theme.spacing4, tile.theme.spacing2 + shortcutHint.implicitWidth + tile.theme.spacing3)
                verticalCenter: parent.verticalCenter
            }
            theme: tile.theme
            motion: tile.motion
            surfaceLayer: ShellSurface.Control
            cornerRadius: tile.theme.radiusMedium
            fillColor: tile.connected ? tile.theme.blend(tile.theme.controlBase, tile.signalColor, 0.17) : tile.pending || tile.scanning || tile.failed ? tile.theme.blend(tile.theme.expressiveSurface, tile.signalColor, 0.17) : tile.theme.expressiveSurface

            Text {
                anchors.centerIn: parent
                text: tile.glyph
                color: tile.unavailable ? tile.theme.textMuted : tile.connected || tile.pending || tile.scanning || tile.failed ? tile.signalColor : tile.foreground
                font.family: "Symbols Nerd Font"
                font.pixelSize: tile.theme.fontSize(27)
            }
        }

        Column {
            anchors {
                left: glyphSurface.right
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: tile.theme.spacing4
                rightMargin: tile.theme.spacing4
            }
            spacing: tile.theme.spacing2

            MarqueeText {
                // Only the first line shares vertical space with the
                // right-corner shortcut. Descriptions keep the full width.
                width: Math.max(1, parent.width - (detailAction.visible ? detailAction.width + tile.theme.spacing2 : 0))
                text: tile.title
                color: tile.foreground
                font.family: tile.runtime.fontSans
                font.pixelSize: tile.theme.fontSize(15)
                font.weight: Font.DemiBold
            }

            MarqueeText {
                width: parent.width
                text: tile.detail
                color: tile.foreground
                opacity: tile.connected ? 0.76 : 0.75
                font.family: tile.runtime.fontSans
                font.pixelSize: tile.theme.fontSize(11)
            }

            MarqueeText {
                width: parent.width
                text: tile.status
                visible: tile.status.length > 0
                color: tile.signalColor
                opacity: tile.failed || tile.pending || tile.scanning ? 1 : 0.88
                font.family: tile.runtime.fontSans
                font.pixelSize: tile.theme.fontSize(9)
                font.weight: Font.DemiBold
            }
        }

        TileKeyHint {
            id: shortcutHint
            primary: true
            visible: tile.shortcut.length > 0
            motion: tile.motion
            shortcut: tile.shortcut
            compact: true
            runtime: tile.runtime
            theme: tile.theme
            emphasized: tile.connected || quickAction.pointerHovered || quickAction.visualPressed
            emphasisColor: tile.signalColor
            available: tile.primaryAvailable && !tile.pending
        }
        TileKeyHint {
            id: detailAction
            visible: tile.detailShortcut.length > 0
            shortcut: tile.detailShortcut
            compact: true
            runtime: tile.runtime
            motion: tile.motion
            theme: tile.theme
            emphasisColor: tile.signalColor
        }
    }

    StateLayer {
        id: interaction
        growOnHover: true
        effectScaleX: tileBody.scale
        effectScaleY: tileBody.scale
        theme: tile.theme
        motion: tile.motion
        selected: tile.connected
        disabled: false
        manualPress: quickAction.visualPressed
        manualHover: quickAction.pointerHovered
        Accessible.role: Accessible.Button
        Accessible.onPressAction: interaction.trigger()
        stateColor: tile.signalColor
        cornerRadius: tile.theme.radiusLarge
        Accessible.name: "Open " + tile.title + " details"
        onActivated: tile.detailsRequested()
    }

    TileQuickAction {
        id: quickAction
        hint: shortcutHint
        runtime: tile.runtime
        theme: tile.theme
        motion: tile.motion
        shortcut: tile.shortcut
        actionName: "Toggle " + tile.title
        available: tile.primaryAvailable && !tile.pending
        selected: tile.connected
        emphasisColor: tile.signalColor
        onActivated: tile.activated()
    }
}

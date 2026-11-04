pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: panel
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property AppearancePreferences appearance

    property bool open: false
    property int selected: 0
    readonly property real windowTransparency: 1 - appearance.windowOpacity
    readonly property real glassTransparency: 1 - appearance.glassOpacity

    signal keyboardRequested

    visible: open
    implicitHeight: panelContent.implicitHeight

    function openView(): void {
        open = true;
        keyboardRequested();
    }

    function closeView(): void {
        open = false;
        keyboardRequested();
    }

    function moveSelection(steps: int): void {
        selected = Math.max(0, Math.min(1, selected + steps));
    }

    function adjustSelected(steps: int): void {
        if (selected === 0)
            appearance.setWindowOpacity(appearance.windowOpacity - steps * 0.05);
        else
            appearance.setGlassOpacity(appearance.glassOpacity - steps * 0.05);
    }

    function toggleSelected(): void {
        if (selected === 0)
            appearance.toggleWindowTransparency();
        else
            appearance.toggleShellGlass();
    }

    Column {
        id: panelContent
        width: parent.width
        spacing: panel.theme.spacing3

        DetailHero {
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            glyph: "󰈈"
            glyphColor: panel.theme.roleColor("display")
            title: "Transparency"
            detail: "Independent window and frosted-glass opacity"
        }

        Repeater {
            model: 2
            delegate: ShellSurface {
                id: tile
                required property int index
                readonly property bool windowTile: index === 0
                readonly property real transparency: windowTile ? panel.windowTransparency : panel.glassTransparency
                readonly property bool effectEnabled: windowTile ? panel.appearance.windowTransparencyEnabled : panel.appearance.shellGlassEnabled
                readonly property color accentColor: panel.theme.roleColor(windowTile ? "display" : "connectivity")
                width: panel.width
                height: 146
                theme: panel.theme
                motion: panel.motion
                surfaceLayer: ShellSurface.Group
                cornerRadius: panel.theme.radiusMedium
                selected: index === panel.selected
                outlined: selected
                borderColor: selected ? accentColor : "transparent"
                fillColor: selected ? panel.theme.blend(panel.theme.groupBase, accentColor, 0.08) : panel.theme.groupBase

                Column {
                    anchors {
                        fill: parent
                        margins: panel.theme.spacing3
                    }
                    spacing: panel.theme.spacing2

                    Row {
                        width: parent.width
                        height: 30
                        spacing: panel.theme.spacing2

                        Text {
                            id: tileIcon
                            anchors.verticalCenter: parent.verticalCenter
                            text: tile.windowTile ? "󰍹" : "󰊠"
                            color: tile.accentColor
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: panel.theme.fontSize(23)
                        }
                        Text {
                            id: tileLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: tile.windowTile ? "Hyprland windows" : "Frosted glass"
                            color: panel.theme.textStrong
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(13)
                            font.weight: Font.DemiBold
                        }
                        Item {
                            width: Math.max(1, parent.width - (tileIcon.implicitWidth + tileLabel.implicitWidth + stateText.implicitWidth + parent.spacing * 3))
                            height: 1
                        }
                        Text {
                            id: stateText
                            anchors.verticalCenter: parent.verticalCenter
                            text: (tile.effectEnabled ? "" : "Off · ") + Math.round(tile.transparency * 100) + "% transparent"
                            color: tile.effectEnabled ? panel.theme.textStrong : panel.theme.textMuted
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(11)
                        }
                    }

                    ShellSlider {
                        width: parent.width
                        theme: panel.theme
                        motion: panel.motion
                        from: tile.windowTile ? 0 : 0.05
                        to: tile.windowTile ? 0.50 : 0.65
                        value: tile.transparency
                        animateValueChanges: true
                        accentColor: tile.accentColor
                        onInteractionStarted: panel.selected = tile.index
                        onValueRequested: next => {
                            panel.selected = tile.index;
                            if (tile.windowTile)
                                panel.appearance.setWindowOpacity(1 - next);
                            else
                                panel.appearance.setGlassOpacity(1 - next);
                        }
                    }

                    Text {
                        width: parent.width
                        text: tile.windowTile ? "Change application-window opacity, including inactive windows" : "Adjust background visibility without changing blur quality"
                        color: panel.theme.textMuted
                        font.family: panel.runtime.fontMono
                        font.pixelSize: panel.theme.fontSize(10)
                        elide: Text.ElideRight
                    }
                }
            }
        }

        KeyHintStrip {
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            hints: [
                {
                    shortcut: "J/K",
                    label: "Select"
                },
                {
                    shortcut: "H/L",
                    label: "Transparency"
                },
                {
                    shortcut: "SPACE",
                    label: "Toggle"
                }
            ]
        }
    }
}

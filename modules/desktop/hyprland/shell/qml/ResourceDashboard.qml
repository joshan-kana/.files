pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: panel
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property ResourceState resourceState

    property bool open: false
    visible: open
    implicitHeight: 608

    signal keyboardRequested

    function openView(): void {
        open = true;
        keyboardRequested();
    }
    function closeView(): void {
        open = false;
        keyboardRequested();
    }

    Column {
        width: parent.width
        spacing: panel.theme.spacing3

        DetailHero {
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            glyph: "◴"
            eyebrow: "Performance / live"
            title: "Resources"
            detail: "CPU · Memory · Last " + panel.resourceState.historyLength * 2 + "s"
        }

        Row {
            width: parent.width
            spacing: panel.theme.spacing3

            Repeater {
                model: 2

                delegate: ShellSurface {
                    id: tile
                    required property int index
                    readonly property bool cpu: index === 0
                    readonly property color gaugeColor: cpu ? panel.theme.accent : panel.theme.positive
                    readonly property real percentage: cpu ? panel.resourceState.cpuPercent : panel.resourceState.memoryPercent
                    readonly property string detailText: cpu ? "Processor activity" : panel.resourceState.kibString(panel.resourceState.memoryUsed) + " / " + panel.resourceState.kibString(panel.resourceState.memoryTotal)
                    width: (panel.width - panel.theme.spacing3) * (cpu ? 0.57 : 0.43)
                    height: 245
                    theme: panel.theme
                    motion: panel.motion
                    surfaceLayer: ShellSurface.Group
                    cornerRadius: panel.theme.radiusLarge
                    fillColor: panel.theme.blend(panel.theme.groupBase, tile.gaugeColor, cpu ? (panel.theme.dark ? 0.13 : 0.08) : (panel.theme.dark ? 0.08 : 0.05))

                    Column {
                        anchors.centerIn: parent
                        spacing: panel.theme.spacing1
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: panel.theme.spacing2
                            Text {
                                text: tile.cpu ? "󰍛" : "󰘚"
                                color: tile.gaugeColor
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: panel.theme.fontSize(18)
                            }
                            Text {
                                text: tile.cpu ? "CPU" : "MEMORY"
                                color: panel.theme.textStrong
                                font.family: panel.runtime.fontMono
                                font.pixelSize: panel.theme.fontSize(12)
                                font.weight: Font.DemiBold
                            }
                        }
                        ResourceGauge {
                            anchors.horizontalCenter: parent.horizontalCenter
                            theme: panel.theme
                            motion: panel.motion
                            accentColor: tile.gaugeColor
                            value: tile.percentage
                            label: "Used"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tile.detailText
                            color: panel.theme.textMuted
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(9)
                        }
                    }
                }
            }
        }

        ShellSurface {
            width: parent.width
            height: 161
            theme: panel.theme
            motion: panel.motion
            surfaceLayer: ShellSurface.Group
            cornerRadius: panel.theme.radiusMedium

            Column {
                anchors.fill: parent
                anchors.margins: panel.theme.spacing3
                spacing: panel.theme.spacing2
                Row {
                    width: parent.width
                    Text {
                        text: "CPU HISTORY"
                        color: panel.theme.textMuted
                        font.family: panel.runtime.fontMono
                        font.pixelSize: panel.theme.fontSize(10)
                    }
                    Item {
                        width: Math.max(0, parent.width - parent.children[0].width - swapLabel.width)
                        height: 1
                    }
                    Text {
                        id: swapLabel
                        text: panel.resourceState.swapTotal > 0 ? "Swap " + Math.round(panel.resourceState.swapPercent * 100) + "%" : "No swap"
                        color: panel.theme.textMuted
                        font.family: panel.runtime.fontMono
                        font.pixelSize: panel.theme.fontSize(10)
                    }
                }
                Row {
                    width: parent.width
                    height: 103
                    spacing: 3
                    Repeater {
                        model: panel.resourceState.historyLength
                        delegate: Item {
                            id: bar
                            required property int index
                            readonly property real fraction: panel.resourceState.cpuHistory[index] || 0
                            width: Math.max(3, (parent.width - (panel.resourceState.historyLength - 1) * 3) / panel.resourceState.historyLength)
                            height: 103
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: Math.max(3, parent.height * bar.fraction)
                                radius: 3
                                color: panel.theme.accent
                                opacity: 0.6 + bar.fraction * 0.4
                            }
                        }
                    }
                }
            }
        }

        Text {
            text: "R refresh  ·  ESC back  ·  Sampled every 2s while open"
            color: panel.theme.textMuted
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(10)
        }
    }
}

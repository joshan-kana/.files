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
    implicitHeight: 780

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
            detail: "CPU · Memory · GPU · Temperature · Network · Disk · Last " + panel.resourceState.historyLength * 2 + "s"
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
            height: 93
            theme: panel.theme
            motion: panel.motion
            surfaceLayer: ShellSurface.Group
            cornerRadius: panel.theme.radiusMedium

            Row {
                anchors.fill: parent
                anchors.margins: panel.theme.spacing3
                spacing: panel.theme.spacing4

                Repeater {
                    model: [
                        {
                            title: "DISK /",
                            value: panel.resourceState.diskTotal > 0 ? Math.round(panel.resourceState.diskPercent * 100) + "%" : "N/A",
                            subtitle: panel.resourceState.diskTotal > 0 ? panel.resourceState.kibString(panel.resourceState.diskUsed) + " used" : "Capacity unavailable"
                        },
                        {
                            title: "NETWORK ↓",
                            value: panel.resourceState.networkInterface ? panel.resourceState.speedString(panel.resourceState.networkDownload) : "N/A",
                            subtitle: panel.resourceState.networkInterface || "No active interface"
                        },
                        {
                            title: "NETWORK ↑",
                            value: panel.resourceState.networkInterface ? panel.resourceState.speedString(panel.resourceState.networkUpload) : "N/A",
                            subtitle: "Outgoing traffic"
                        }
                    ]
                    delegate: Column {
                        id: metricColumn
                        required property var modelData
                        width: (parent.width - 2 * panel.theme.spacing4) / 3
                        spacing: 2
                        Text {
                            text: metricColumn.modelData.title
                            color: panel.theme.textMuted
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(10)
                        }
                        Text {
                            width: parent.width
                            text: metricColumn.modelData.value
                            color: panel.theme.textStrong
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(14)
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: metricColumn.modelData.subtitle
                            color: panel.theme.textMuted
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(9)
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        ShellSurface {
            width: parent.width
            height: 90
            theme: panel.theme
            motion: panel.motion
            surfaceLayer: ShellSurface.Group
            cornerRadius: panel.theme.radiusMedium

            Row {
                anchors.fill: parent
                anchors.margins: panel.theme.spacing3
                spacing: panel.theme.spacing4
                Repeater {
                    model: [
                        {
                            title: "GPU LOAD",
                            value: panel.resourceState.gpuPercent >= 0 ? Math.round(panel.resourceState.gpuPercent) + "%" : "Unavailable",
                            detail: "Supported driver counter"
                        },
                        {
                            title: "CPU TEMPERATURE",
                            value: panel.resourceState.cpuTemperature >= 0 ? panel.resourceState.cpuTemperature.toFixed(1) + "°C" : "Unavailable",
                            detail: "Supported thermal sensor"
                        },
                        {
                            title: "GPU TEMPERATURE",
                            value: panel.resourceState.gpuTemperature >= 0 ? panel.resourceState.gpuTemperature.toFixed(1) + "°C" : "Unavailable",
                            detail: "Supported thermal sensor"
                        }
                    ]
                    delegate: Column {
                        id: sensorColumn
                        required property var modelData
                        width: (parent.width - 2 * panel.theme.spacing4) / 3
                        spacing: 2
                        Text {
                            text: sensorColumn.modelData.title
                            color: panel.theme.textMuted
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(10)
                        }
                        Text {
                            width: parent.width
                            text: sensorColumn.modelData.value
                            color: sensorColumn.modelData.value === "Unavailable" ? panel.theme.textMuted : panel.theme.textStrong
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(14)
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: sensorColumn.modelData.detail
                            color: panel.theme.textMuted
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(9)
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        ShellSurface {
            width: parent.width
            height: 205
            theme: panel.theme
            motion: panel.motion
            surfaceLayer: ShellSurface.Group
            cornerRadius: panel.theme.radiusMedium

            Column {
                anchors.fill: parent
                anchors.margins: panel.theme.spacing3
                spacing: panel.theme.spacing2
                Repeater {
                    model: 3
                    delegate: Column {
                        id: historyRow
                        required property int index
                        readonly property var values: index === 0 ? panel.resourceState.cpuHistory : index === 1 ? panel.resourceState.memoryHistory : panel.resourceState.networkHistory
                        readonly property real maxValue: index === 2 ? Math.max(131072, ...values) : 1
                        width: parent.width
                        spacing: 2
                        Text {
                            text: historyRow.index === 0 ? "CPU HISTORY" : historyRow.index === 1 ? "MEMORY HISTORY" : "NETWORK HISTORY"
                            color: panel.theme.textMuted
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(9)
                        }
                        Row {
                            width: parent.width
                            height: 29
                            spacing: 3
                            Repeater {
                                model: panel.resourceState.historyLength
                                delegate: Item {
                                    id: bar
                                    required property int index
                                    readonly property real fraction: historyRow.maxValue > 0 ? (historyRow.values[index] || 0) / historyRow.maxValue : 0
                                    width: Math.max(3, (parent.width - (panel.resourceState.historyLength - 1) * 3) / panel.resourceState.historyLength)
                                    height: parent.height
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: Math.max(2, parent.height * bar.fraction)
                                        radius: 2
                                        color: historyRow.index === 0 ? panel.theme.accent : historyRow.index === 1 ? panel.theme.positive : panel.theme.warning
                                        opacity: 0.55 + bar.fraction * 0.45
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Text {
            text: "R refresh  ·  ESC back  ·  Sampled every 2s while open · disk/sensors every 10s"
            color: panel.theme.textMuted
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(10)
        }
    }
}

pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: panel
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property ResourceState resourceState

    property bool open: false
    property bool showCores: false
    function toggleCoreView(): void {
        showCores = !showCores;
    }
    visible: open
    implicitHeight: 882

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
                    readonly property color gaugeColor: cpu ? panel.theme.roleColor("resources") : panel.theme.roleColor("connectivity")
                    readonly property real percentage: cpu ? panel.resourceState.cpuPercent : panel.resourceState.memoryPercent
                    readonly property string detailText: cpu ? "Processor activity" : panel.resourceState.kibString(panel.resourceState.memoryUsed) + " / " + panel.resourceState.kibString(panel.resourceState.memoryTotal)
                    width: (panel.width - panel.theme.spacing3) * (cpu ? 0.57 : 0.43)
                    height: 245
                    theme: panel.theme
                    motion: panel.motion
                    surfaceLayer: ShellSurface.Group
                    cornerRadius: panel.theme.radiusLarge
                    fillColor: panel.theme.blend(panel.theme.groupBase, tile.gaugeColor, cpu ? (panel.theme.dark ? 0.065 : 0.035) : (panel.theme.dark ? 0.055 : 0.03))

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
                            known: tile.cpu ? panel.resourceState.cpuSampleReady : panel.resourceState.memoryTotal > 0
                            label: known ? "Used" : "Sampling"
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
            height: 237
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
                    height: 25
                    spacing: panel.theme.spacing3
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(1, parent.width - viewToggle.width - parent.spacing)
                        text: panel.showCores ? "LOGICAL CORES · " + panel.resourceState.coreUsage.length + " ACTIVE COUNTERS" : "RESOURCE HISTORY · LAST " + panel.resourceState.historyLength * 2 + "s"
                        color: panel.theme.textStrong
                        font.family: panel.runtime.fontMono
                        font.pixelSize: panel.theme.fontSize(10)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    ShellAction {
                        id: viewToggle
                        anchors.verticalCenter: parent.verticalCenter
                        width: 114
                        height: 25
                        runtime: panel.runtime
                        theme: panel.theme
                        motion: panel.motion
                        compact: true
                        horizontalCompact: true
                        icon: panel.showCores ? "󰥔" : "󰍛"
                        title: panel.showCores ? "HISTORY" : "CORES"
                        shortcut: "C"
                        onActivated: panel.toggleCoreView()
                    }
                }

                Column {
                    visible: !panel.showCores
                    width: parent.width
                    spacing: panel.theme.spacing2
                    Repeater {
                        model: 3
                        delegate: ResourceHistoryGraph {
                            id: historyGraph
                            required property int index
                            width: parent.width
                            height: 54
                            runtime: panel.runtime
                            theme: panel.theme
                            label: index === 0 ? "CPU" : index === 1 ? "MEMORY" : "NETWORK · RX+TX"
                            values: index === 0 ? panel.resourceState.cpuHistory : index === 1 ? panel.resourceState.memoryHistory : panel.resourceState.networkHistory
                            maximum: index === 2 ? Math.max(131072, ...values) : 1
                            graphColor: index === 0 ? panel.theme.roleColor("resources") : index === 1 ? panel.theme.roleColor("connectivity") : panel.theme.roleColor("positive")
                            currentText: index === 0 ? Math.round(panel.resourceState.cpuPercent * 100) + "%" : index === 1 ? Math.round(panel.resourceState.memoryPercent * 100) + "%" : panel.resourceState.speedString(panel.resourceState.networkDownload + panel.resourceState.networkUpload)
                            sampleLimit: panel.resourceState.historyLength
                        }
                    }
                }

                Grid {
                    id: coreGrid
                    visible: panel.showCores
                    width: parent.width
                    columns: Math.min(8, Math.max(1, panel.resourceState.coreUsage.length))
                    readonly property int rowCount: Math.max(1, Math.ceil(Math.min(32, panel.resourceState.coreUsage.length) / columns))
                    columnSpacing: panel.theme.spacing2
                    rowSpacing: panel.theme.spacing2
                    Repeater {
                        model: panel.showCores ? panel.resourceState.coreUsage.slice(0, 32) : []
                        delegate: ShellSurface {
                            id: coreTile
                            required property var modelData
                            readonly property bool hasSample: modelData.utilisation >= 0
                            readonly property real usage: hasSample ? modelData.utilisation : 0
                            width: (coreGrid.width - (coreGrid.columns - 1) * coreGrid.columnSpacing) / coreGrid.columns
                            height: Math.min(59, Math.max(26, Math.floor((126 - (coreGrid.rowCount - 1) * coreGrid.rowSpacing) / coreGrid.rowCount)))
                            theme: panel.theme
                            motion: panel.motion
                            surfaceLayer: ShellSurface.Control
                            cornerRadius: panel.theme.radiusSmall
                            fillColor: panel.theme.blend(panel.theme.controlBase, usage >= 0.8 ? panel.theme.warning : panel.theme.roleColor("resources"), 0.06 + usage * 0.30)
                            Row {
                                anchors {
                                    fill: parent
                                    leftMargin: panel.theme.spacing2
                                    rightMargin: panel.theme.spacing2
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "C" + String(coreTile.modelData.index).padStart(2, "0")
                                    color: panel.theme.textMuted
                                    font.family: panel.runtime.fontMono
                                    font.pixelSize: panel.theme.fontSize(9)
                                }
                                Item {
                                    width: Math.max(0, parent.width - 58)
                                    height: 1
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: coreTile.hasSample ? Math.round(coreTile.usage * 100) + "%" : "··"
                                    color: coreTile.usage >= 0.8 ? panel.theme.warning : panel.theme.textStrong
                                    font.family: panel.runtime.fontMono
                                    font.pixelSize: panel.theme.fontSize(coreGrid.rowCount <= 2 ? 10 : 9)
                                    font.weight: Font.DemiBold
                                }
                            }
                            Rectangle {
                                anchors {
                                    left: parent.left
                                    bottom: parent.bottom
                                }
                                width: Math.min(parent.width, Math.max(0, parent.width * coreTile.usage))
                                height: 3
                                color: coreTile.usage >= 0.8 ? panel.theme.warning : panel.theme.roleColor("resources")
                                radius: 1.5
                            }
                        }
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
                    shortcut: "C",
                    label: "Cores/history"
                },
                {
                    shortcut: "R",
                    label: "Refresh"
                },
                {
                    shortcut: "ESC",
                    label: "Back"
                }
            ]
        }
    }
}

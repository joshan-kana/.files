pragma ComponentBehavior: Bound
import QtQuick
import "DesktopIcons.js" as DesktopIcons

Item {
    id: panel
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property ResourceState resourceState

    property bool open: false
    property bool showCores: false
    property bool showProcesses: false
    onShowProcessesChanged: resourceState.showProcesses = open && showProcesses
    onOpenChanged: resourceState.showProcesses = open && showProcesses
    function toggleCoreView(): void {
        showProcesses = false;
        showCores = !showCores;
    }
    visible: open
    implicitHeight: layout.implicitHeight

    signal keyboardRequested

    function activateAction(action: string): void {
        switch (action) {
        case "ResourceDashboard.refresh":
            resourceState.refresh();
            break;
        case "ResourceDashboard.interval":
            resourceState.cycleInterval();
            break;
        case "ResourceDashboard.history":
            resourceState.cycleHistory();
            break;
        case "ResourceDashboard.processes":
            showCores = false;
            showProcesses = !showProcesses;
            break;
        case "ResourceDashboard.sort":
            if (showProcesses)
                resourceState.sortByMemory = !resourceState.sortByMemory;
            break;
        case "ResourceDashboard.defaults":
            resourceState.resetSampling();
            break;
        }
    }
    function handleKey(key: int, modifiers: int, autoRepeat: bool): bool {
        for (const action of ["refresh", "interval", "history", "processes", "sort", "defaults"]) {
            const id = "ResourceDashboard." + action;
            if (runtime.shellMatchesHint(id, key, modifiers)) {
                if (!autoRepeat)
                    activateAction(id);
                return true;
            }
        }
        if (runtime.shellMatchesHint("ResourceDashboard.toggleCores", key, modifiers)) {
            if (!autoRepeat)
                toggleCoreView();
            return true;
        }
        return false;
    }
    function openView(): void {
        open = true;
        keyboardRequested();
    }
    function closeView(): void {
        open = false;
        keyboardRequested();
    }

    Column {
        id: layout
        width: parent.width
        spacing: panel.theme.spacing3

        DetailHero {
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            glyph: DesktopIcons.glyphFor("resources")
            glyphFont: "Symbols Nerd Font"
            glyphColor: panel.theme.roleColor("resources")
            eyebrow: "Performance / live"
            title: "Resources"
            detail: "CPU · Memory · GPU · Temperature · Network · Disk · Last " + panel.resourceState.historySeconds + "s"
        }

        Flow {
            id: primaryMetrics
            width: parent.width
            spacing: panel.theme.spacing3
            readonly property int columns: width >= panel.theme.fontSize(650) ? 3 : 1
            Repeater {
                model: [
                    {
                        title: "CPU",
                        glyph: "󰍛",
                        role: "resources",
                        fraction: panel.resourceState.cpuPercent,
                        known: panel.resourceState.cpuSampleReady,
                        detail: "Processor activity"
                    },
                    {
                        title: "Memory",
                        glyph: "󰘚",
                        role: "connectivity",
                        fraction: panel.resourceState.memoryPercent,
                        known: panel.resourceState.memoryTotal > 0,
                        detail: panel.resourceState.kibString(panel.resourceState.memoryUsed) + " / " + panel.resourceState.kibString(panel.resourceState.memoryTotal)
                    },
                    {
                        title: "Storage",
                        glyph: "󰋊",
                        role: "positive",
                        fraction: panel.resourceState.diskPercent,
                        known: panel.resourceState.diskTotal > 0,
                        detail: panel.resourceState.diskTotal > 0 ? panel.resourceState.kibString(panel.resourceState.diskUsed) + " used" : "Capacity unavailable"
                    }
                ]
                delegate: ShellSurface {
                    id: metricTile
                    required property var modelData
                    width: Math.floor((primaryMetrics.width - (primaryMetrics.columns - 1) * primaryMetrics.spacing) / primaryMetrics.columns)
                    height: metricContent.implicitHeight + panel.theme.spacing4 * 2
                    theme: panel.theme
                    motion: panel.motion
                    surfaceLayer: ShellSurface.Group
                    cornerRadius: panel.theme.radiusLarge
                    readonly property color metricColor: panel.theme.roleColor(modelData.role)
                    fillColor: panel.theme.blend(panel.theme.groupBase, metricColor, panel.theme.dark ? 0.08 : 0.045)
                    Column {
                        id: metricContent
                        width: parent.width - panel.theme.spacing4 * 2
                        anchors.centerIn: parent
                        spacing: panel.theme.spacing2
                        Row {
                            spacing: panel.theme.spacing2
                            Text {
                                text: metricTile.modelData.glyph
                                color: metricTile.metricColor
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: panel.theme.iconRegular
                            }
                            ShellText {
                                runtime: panel.runtime
                                theme: panel.theme
                                text: metricTile.modelData.title
                                textRole: ShellText.Section
                            }
                        }
                        ShellText {
                            runtime: panel.runtime
                            theme: panel.theme
                            text: metricTile.modelData.known ? Math.round(metricTile.modelData.fraction * 100) + "%" : "—"
                            textRole: ShellText.Display
                            color: metricTile.metricColor
                        }
                        LevelTrack {
                            width: parent.width
                            theme: panel.theme
                            motion: panel.motion
                            fraction: metricTile.modelData.fraction
                            known: metricTile.modelData.known
                            accentColor: metricTile.metricColor
                        }
                        ShellText {
                            width: parent.width
                            runtime: panel.runtime
                            theme: panel.theme
                            text: metricTile.modelData.known ? metricTile.modelData.detail : "Unavailable or sampling"
                            textRole: ShellText.Supporting
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }

        ShellSurface {
            width: parent.width
            height: Math.max(82, panel.theme.fontSize(55) + panel.theme.spacing3 * 2)
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
                            title: "↓ Receiving",
                            value: panel.resourceState.networkInterface ? panel.resourceState.speedString(panel.resourceState.networkDownload) : "N/A",
                            subtitle: panel.resourceState.networkInterface || "No active interface"
                        },
                        {
                            title: "↑ Sending",
                            value: panel.resourceState.networkInterface ? panel.resourceState.speedString(panel.resourceState.networkUpload) : "N/A",
                            subtitle: "Outgoing traffic"
                        }
                    ]
                    delegate: Column {
                        id: metricColumn
                        required property var modelData
                        width: (parent.width - panel.theme.spacing4) / 2
                        spacing: 2
                        Text {
                            text: metricColumn.modelData.title
                            color: panel.theme.textMuted
                            font.family: panel.runtime.fontSans
                            font.pixelSize: panel.theme.fontSize(10)
                        }
                        Text {
                            width: parent.width
                            text: metricColumn.modelData.value
                            color: panel.theme.textStrong
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontReadback
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: metricColumn.modelData.subtitle
                            color: panel.theme.textMuted
                            font.family: panel.runtime.fontSans
                            font.pixelSize: panel.theme.fontUtility
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        ShellSurface {
            width: parent.width
            height: Math.max(82, panel.theme.fontSize(55) + panel.theme.spacing3 * 2)
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
                            title: "GPU load",
                            value: panel.resourceState.gpuPercent >= 0 ? Math.round(panel.resourceState.gpuPercent) + "%" : "Unavailable",
                            detail: "Supported driver counter"
                        },
                        {
                            title: "CPU temperature",
                            value: panel.resourceState.cpuTemperature >= 0 ? panel.resourceState.cpuTemperature.toFixed(1) + "°C" : "Unavailable",
                            detail: "Supported thermal sensor"
                        },
                        {
                            title: "GPU temperature",
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
                            font.family: panel.runtime.fontSans
                            font.pixelSize: panel.theme.fontSize(10)
                        }
                        Text {
                            width: parent.width
                            text: sensorColumn.modelData.value
                            color: sensorColumn.modelData.value === "Unavailable" ? panel.theme.textMuted : panel.theme.textStrong
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontReadback
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: sensorColumn.modelData.detail
                            color: panel.theme.textMuted
                            font.family: panel.runtime.fontSans
                            font.pixelSize: panel.theme.fontUtility
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        ShellText {
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            text: "Pressure (10s) · CPU " + (panel.resourceState.cpuPressure >= 0 ? panel.resourceState.cpuPressure.toFixed(2) + "%" : "N/A") + " · Memory " + (panel.resourceState.memoryPressure >= 0 ? panel.resourceState.memoryPressure.toFixed(2) + "%" : "N/A") + " · I/O " + (panel.resourceState.ioPressure >= 0 ? panel.resourceState.ioPressure.toFixed(2) + "%" : "N/A") + " · Fan " + (panel.resourceState.fanRpm >= 0 ? panel.resourceState.fanRpm + " RPM" : "N/A")
            color: panel.theme.textMuted
            wrapMode: Text.WordWrap
        }

        ShellSurface {
            width: parent.width
            height: Math.max(panel.theme.fontSize(273), historyContent.implicitHeight + panel.theme.spacing3 * 2)
            theme: panel.theme
            motion: panel.motion
            surfaceLayer: ShellSurface.Group
            cornerRadius: panel.theme.radiusMedium

            Column {
                id: historyContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: panel.theme.spacing3
                spacing: panel.theme.spacing2

                Row {
                    width: parent.width
                    height: Math.max(viewToggle.implicitHeight, panel.theme.fontSection)
                    spacing: panel.theme.spacing3
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(1, parent.width - viewToggle.width - parent.spacing)
                        text: panel.showProcesses ? (panel.resourceState.sortByMemory ? "TOP PROCESSES · MEMORY" : "TOP PROCESSES · LIFETIME CPU") : panel.showCores ? "LOGICAL CORES · " + panel.resourceState.coreUsage.length + " ACTIVE COUNTERS" : "RESOURCE HISTORY · LAST " + panel.resourceState.historySeconds + "s"
                        color: panel.theme.textStrong
                        font.family: panel.runtime.fontSans
                        font.pixelSize: panel.theme.fontSection
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    ShellAction {
                        id: viewToggle
                        anchors.verticalCenter: parent.verticalCenter
                        width: implicitWidth
                        height: implicitHeight
                        runtime: panel.runtime
                        theme: panel.theme
                        motion: panel.motion
                        compact: true
                        horizontalCompact: true
                        icon: panel.showCores ? "󰥔" : "󰍛"
                        title: panel.showCores ? "HISTORY" : "CORES"
                        shortcut: panel.runtime.shellHint("ResourceDashboard.toggleCores")
                        onActivated: panel.toggleCoreView()
                    }
                }

                Column {
                    visible: !panel.showCores && !panel.showProcesses
                    width: parent.width
                    spacing: panel.theme.spacing2
                    Repeater {
                        model: 3
                        delegate: ResourceHistoryGraph {
                            id: historyGraph
                            required property int index
                            width: parent.width
                            height: panel.theme.fontSize(67)
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

                Column {
                    visible: panel.showProcesses
                    width: parent.width
                    spacing: 3
                    Row {
                        id: processHeader
                        width: parent.width
                        spacing: panel.theme.spacing2
                        Repeater {
                            model: ["PID", "Process", "CPU avg", "Memory"]
                            delegate: ShellText {
                                required property int index
                                required property string modelData
                                width: index === 1 ? Math.max(1, processHeader.width - panel.theme.fontSize(230) - processHeader.spacing * 3) : panel.theme.fontSize(index === 0 ? 80 : 75)
                                runtime: panel.runtime
                                theme: panel.theme
                                text: modelData
                                textRole: ShellText.Utility
                            }
                        }
                    }
                    Repeater {
                        model: panel.showProcesses ? panel.resourceState.processes : []
                        delegate: Row {
                            id: processRow
                            required property var modelData
                            width: parent.width
                            spacing: panel.theme.spacing2
                            ShellText {
                                width: panel.theme.fontSize(80)
                                runtime: panel.runtime
                                theme: panel.theme
                                text: processRow.modelData.pid
                            }
                            ShellText {
                                width: Math.max(1, parent.width - panel.theme.fontSize(230) - parent.spacing * 3)
                                runtime: panel.runtime
                                theme: panel.theme
                                text: processRow.modelData.name
                                elide: Text.ElideRight
                            }
                            ShellText {
                                width: panel.theme.fontSize(75)
                                runtime: panel.runtime
                                theme: panel.theme
                                text: processRow.modelData.cpu.toFixed(1) + "%"
                            }
                            ShellText {
                                width: panel.theme.fontSize(75)
                                runtime: panel.runtime
                                theme: panel.theme
                                text: processRow.modelData.memory.toFixed(1) + "%"
                            }
                        }
                    }
                    ShellText {
                        visible: !panel.resourceState.processesAvailable
                        runtime: panel.runtime
                        theme: panel.theme
                        text: "Sampling process counters…"
                        color: panel.theme.textMuted
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
                                    font.pixelSize: panel.theme.fontUtility
                                }
                                Item {
                                    width: Math.max(0, parent.width - 58)
                                    height: 1
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: coreTile.hasSample ? Math.round(coreTile.usage * 100) + "%" : "··"
                                    color: coreTile.usage >= 0.8 ? panel.theme.readableRoleColor("warning") : panel.theme.textStrong
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

        Row {
            width: parent.width
            height: 40
            spacing: panel.theme.spacing2
            Repeater {
                model: [
                    {
                        action: "ResourceDashboard.refresh",
                        title: "Refresh"
                    },
                    {
                        action: "ResourceDashboard.interval",
                        title: panel.resourceState.intervalSeconds + "s sampling"
                    },
                    {
                        action: "ResourceDashboard.history",
                        title: panel.resourceState.historyLength + " samples"
                    },
                    {
                        action: "ResourceDashboard.processes",
                        title: panel.showProcesses ? "History" : "Processes"
                    },
                    {
                        action: "ResourceDashboard.sort",
                        title: panel.resourceState.sortByMemory ? "Sort: memory" : "Sort: CPU"
                    },
                    {
                        action: "ResourceDashboard.defaults",
                        title: "Defaults"
                    }
                ]
                delegate: ShellAction {
                    required property var modelData
                    width: (panel.width - 5 * panel.theme.spacing2) / 6
                    height: 40
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    compact: true
                    horizontalCompact: true
                    title: modelData.title
                    shortcut: panel.runtime.shellHint(modelData.action)
                    enabled: modelData.action !== "ResourceDashboard.sort" || panel.showProcesses
                    onActivated: panel.activateAction(modelData.action)
                }
            }
        }
    }
}

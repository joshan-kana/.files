pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
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
    signal revealSelection(real top, real bottom)

    function revealSelector(selector: ShellValueSelector): void {
        Qt.callLater(() => {
            if (panel.open && selector.expanded) {
                const top = selector.mapToItem(panel, 0, 0).y;
                panel.revealSelection(top, top + selector.height);
            }
        });
    }

    function activateAction(action: string): void {
        switch (action) {
        case "ResourceDashboard.refresh":
            resourceState.refresh();
            break;
        case "ResourceDashboard.interval":
            intervalSelector.toggle();
            break;
        case "ResourceDashboard.history":
            historySelector.toggle();
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
    function cancelNested(): bool {
        return diskSelector.cancel() || intervalSelector.cancel() || historySelector.cancel();
    }
    function handleKey(key: int, modifiers: int, autoRepeat: bool): bool {
        const selector = diskSelector.expanded ? diskSelector : intervalSelector.expanded ? intervalSelector : historySelector.expanded ? historySelector : null;
        if (selector) {
            if (runtime.shellNavigates("controls", "up", key))
                selector.moveHighlight(-1);
            else if (runtime.shellNavigates("controls", "down", key))
                selector.moveHighlight(1);
            else if (key === runtime.shellKeyCode("controls", "Return") || key === runtime.shellKeyCode("controls", "Enter")) {
                if (!autoRepeat)
                    selector.commit();
            } else if (key === runtime.shellKeyCode("controls", "Backspace")) {
                selector.cancel();
            }
            return true;
        }
        for (const action of ["refresh", "interval", "history", "processes", "sort", "defaults", "disk"]) {
            const id = "ResourceDashboard." + action;
            if (runtime.shellMatchesHint(id, key, modifiers)) {
                if (!autoRepeat) {
                    switch (action) {
                    case "refresh":
                        refreshResources.trigger();
                        break;
                    case "defaults":
                        resetSampling.trigger();
                        break;
                    case "disk":
                        diskSelector.toggle();
                        break;
                    case "processes":
                        processesAction.trigger();
                        break;
                    case "sort":
                        if (sortAction.visible)
                            sortAction.trigger();
                        break;
                    default:
                        activateAction(id);
                        break;
                    }
                }
                return true;
            }
        }
        if (runtime.shellMatchesHint("ResourceDashboard.toggleCores", key, modifiers)) {
            if (!autoRepeat)
                coresAction.trigger();
            return true;
        }
        return false;
    }
    function openView(): void {
        open = true;
        keyboardRequested();
    }
    function closeView(): void {
        cancelNested();
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
            actions: [
                ShellUtilityAction {
                    id: resetSampling
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    icon: DesktopIcons.actionGlyph("reset")
                    title: "Restore sampling defaults"
                    shortcut: panel.runtime.shellHint("ResourceDashboard.defaults")
                    onActivated: {
                        panel.cancelNested();
                        panel.resourceState.resetSampling();
                    }
                },
                ShellUtilityAction {
                    id: refreshResources
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    icon: DesktopIcons.actionGlyph("refresh")
                    title: "Refresh resources"
                    shortcut: panel.runtime.shellHint("ResourceDashboard.refresh")
                    onActivated: panel.activateAction("ResourceDashboard.refresh")
                }
            ]
        }

        ShellValueSelector {
            id: diskSelector
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            title: "Storage filesystem"
            shortcut: panel.runtime.shellHint("ResourceDashboard.disk")
            confirmShortcut: panel.runtime.shellHint("SystemContent.legend.activate_confirm")
            accentColor: panel.theme.roleColor("positive")
            options: panel.resourceState.disks.map(entry => entry.target + " · " + entry.source)
            selectedIndex: panel.resourceState.disks.findIndex(entry => entry.target === panel.resourceState.diskTarget)
            onOpened: {
                intervalSelector.cancel();
                historySelector.cancel();
                panel.revealSelector(diskSelector);
            }
            onChosen: index => panel.resourceState.selectDisk(index)
        }

        GridLayout {
            id: primaryMetrics
            width: parent.width
            columnSpacing: panel.theme.spacing3
            rowSpacing: panel.theme.spacing3
            columns: Math.max(1, Math.min(3, Math.floor((width + columnSpacing) / (panel.theme.fontSize(210) + columnSpacing))))
            uniformCellWidths: true
            uniformCellHeights: true
            readonly property var metrics: [
                {
                    title: "CPU",
                    glyph: "󰍛",
                    role: "resources",
                    fraction: panel.resourceState.cpuPercent,
                    known: panel.resourceState.cpuSampleReady,
                    detail: "Processor activity",
                    history: panel.resourceState.cpuHistory
                },
                {
                    title: "Memory",
                    glyph: "󰘚",
                    role: "connectivity",
                    fraction: panel.resourceState.memoryPercent,
                    known: panel.resourceState.memoryTotal > 0,
                    detail: panel.resourceState.kibString(panel.resourceState.memoryUsed) + " / " + panel.resourceState.kibString(panel.resourceState.memoryTotal),
                    history: panel.resourceState.memoryHistory
                },
                {
                    title: "Storage",
                    glyph: "󰋊",
                    role: "positive",
                    fraction: panel.resourceState.diskPercent,
                    known: panel.resourceState.diskTotal > 0,
                    detail: panel.resourceState.diskTotal > 0 ? panel.resourceState.kibString(panel.resourceState.diskUsed) + " / " + panel.resourceState.kibString(panel.resourceState.diskTotal) : "Capacity unavailable",
                    history: panel.resourceState.diskHistory,
                    maximum: Math.max(131072, ...panel.resourceState.diskHistory),
                    io: true
                }
            ]
            Repeater {
                id: primaryMetricCards
                model: primaryMetrics.metrics.length
                delegate: ShellSurface {
                    id: metricTile
                    required property int index
                    readonly property var metric: primaryMetrics.metrics[index]
                    Layout.columnSpan: primaryMetrics.columns === 2 && index === 2 ? 2 : 1
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 1
                    Layout.preferredWidth: (primaryMetrics.width - (primaryMetrics.columns - 1) * primaryMetrics.columnSpacing) / primaryMetrics.columns
                    implicitHeight: metricContent.implicitHeight + panel.theme.spacing4 * 2
                    theme: panel.theme
                    motion: panel.motion
                    surfaceLayer: ShellSurface.Group
                    cornerRadius: panel.theme.radiusLarge
                    readonly property color metricColor: panel.theme.roleColor(metric.role)
                    fillColor: panel.theme.blend(panel.theme.groupBase, metricColor, panel.theme.dark ? 0.08 : 0.045)
                    Column {
                        id: metricContent
                        width: parent.width - panel.theme.spacing4 * 2
                        anchors.centerIn: parent
                        spacing: panel.theme.spacing2
                        Row {
                            spacing: panel.theme.spacing2
                            Text {
                                text: metricTile.metric.glyph
                                color: metricTile.metricColor
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: panel.theme.iconRegular
                            }
                            ShellText {
                                runtime: panel.runtime
                                theme: panel.theme
                                text: metricTile.metric.title
                                textRole: ShellText.Section
                            }
                        }
                        ResourceGauge {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(parent.width, implicitWidth)
                            height: width
                            theme: panel.theme
                            motion: panel.motion
                            value: metricTile.metric.fraction
                            known: metricTile.metric.known
                            accentColor: metricTile.metricColor
                        }
                        ShellText {
                            width: parent.width
                            runtime: panel.runtime
                            theme: panel.theme
                            text: metricTile.metric.known ? metricTile.metric.detail : "Unavailable or sampling"
                            textRole: ShellText.Supporting
                            wrapMode: Text.WordWrap
                        }
                        ShellText {
                            width: parent.width
                            runtime: panel.runtime
                            theme: panel.theme
                            text: metricTile.metric.io ? (panel.resourceState.diskIoKnown ? "↓ " + panel.resourceState.speedString(panel.resourceState.diskRead) + " · ↑ " + panel.resourceState.speedString(panel.resourceState.diskWrite) : "Device I/O unavailable or sampling") : "Utilisation history"
                            textRole: ShellText.Utility
                            wrapMode: Text.WordWrap
                        }
                        ResourceHistoryGraph {
                            width: parent.width
                            height: panel.theme.fontSize(80)
                            runtime: panel.runtime
                            theme: panel.theme
                            label: metricTile.metric.title
                            currentText: ""
                            showHeader: false
                            graphColor: metricTile.metricColor
                            values: metricTile.metric.history || []
                            maximum: metricTile.metric.maximum || 1
                            sampleLimit: panel.resourceState.historyLength
                        }
                    }
                }
            }
        }

        ShellSurface {
            width: parent.width
            height: traffic.implicitHeight + panel.theme.spacing3 * 2
            theme: panel.theme
            motion: panel.motion
            surfaceLayer: ShellSurface.Group
            cornerRadius: panel.theme.radiusMedium

            Grid {
                id: traffic
                width: parent.width - panel.theme.spacing3 * 2
                anchors.centerIn: parent
                columns: width >= panel.theme.fontSize(360) ? 2 : 1
                columnSpacing: panel.theme.spacing4
                rowSpacing: panel.theme.spacing3

                Repeater {
                    model: [
                        {
                            title: "↓ Receiving",
                            value: panel.resourceState.networkInterface ? panel.resourceState.speedString(panel.resourceState.networkDownload) : "N/A",
                            subtitle: panel.resourceState.networkInterface || "No active interface",
                            role: "connectivity",
                            history: panel.resourceState.receiveHistory
                        },
                        {
                            title: "↑ Sending",
                            value: panel.resourceState.networkInterface ? panel.resourceState.speedString(panel.resourceState.networkUpload) : "N/A",
                            subtitle: "Outgoing traffic",
                            role: "resources",
                            history: panel.resourceState.sendHistory
                        }
                    ]
                    delegate: Column {
                        id: metricColumn
                        required property var modelData
                        width: (traffic.width - traffic.columnSpacing * (traffic.columns - 1)) / traffic.columns
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
                        ResourceHistoryGraph {
                            width: parent.width
                            height: panel.theme.fontSize(66)
                            runtime: panel.runtime
                            theme: panel.theme
                            label: metricColumn.modelData.title
                            currentText: ""
                            showHeader: false
                            graphColor: panel.theme.roleColor(metricColumn.modelData.role)
                            values: metricColumn.modelData.history
                            maximum: Math.max(131072, ...panel.resourceState.receiveHistory, ...panel.resourceState.sendHistory)
                            sampleLimit: panel.resourceState.historyLength
                        }
                    }
                }
            }
        }

        Flow {
            width: parent.width
            spacing: panel.theme.spacing3
            Repeater {
                model: [
                    {
                        label: "GPU",
                        value: panel.resourceState.gpuPercent >= 0 ? Math.round(panel.resourceState.gpuPercent) + "%" : "",
                        role: "resources"
                    },
                    {
                        label: "CPU temperature",
                        value: panel.resourceState.cpuTemperature >= 0 ? panel.resourceState.cpuTemperature.toFixed(1) + "°C" : "",
                        role: "temperature"
                    },
                    {
                        label: "GPU temperature",
                        value: panel.resourceState.gpuTemperature >= 0 ? panel.resourceState.gpuTemperature.toFixed(1) + "°C" : "",
                        role: "temperature"
                    }
                ].filter(sensor => sensor.value.length > 0)
                delegate: ShellSurface {
                    id: sensor
                    required property var modelData
                    width: sensorReadback.implicitWidth + panel.theme.spacing3 * 2
                    height: sensorReadback.implicitHeight + panel.theme.spacing2 * 2
                    theme: panel.theme
                    motion: panel.motion
                    surfaceLayer: ShellSurface.Group
                    cornerRadius: height / 2
                    ShellText {
                        id: sensorReadback
                        anchors.centerIn: parent
                        runtime: panel.runtime
                        theme: panel.theme
                        text: sensor.modelData.label + " · " + sensor.modelData.value
                        color: panel.theme.readableRoleColor(sensor.modelData.role)
                        textRole: ShellText.Readback
                    }
                }
            }
        }
        ShellText {
            width: parent.width
            visible: panel.resourceState.gpuPercent < 0 || panel.resourceState.cpuTemperature < 0 || panel.resourceState.gpuTemperature < 0
            runtime: panel.runtime
            theme: panel.theme
            text: "Unavailable: " + [panel.resourceState.gpuPercent < 0 ? "GPU load" : "", panel.resourceState.cpuTemperature < 0 ? "CPU temperature" : "", panel.resourceState.gpuTemperature < 0 ? "GPU temperature" : ""].filter(Boolean).join(" · ")
            textRole: ShellText.Supporting
            wrapMode: Text.WordWrap
        }

        ShellText {
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            text: "Pressure (10s) · CPU " + (panel.resourceState.cpuPressure >= 0 ? panel.resourceState.cpuPressure.toFixed(2) + "%" : "N/A") + " · Memory " + (panel.resourceState.memoryPressure >= 0 ? panel.resourceState.memoryPressure.toFixed(2) + "%" : "N/A") + " · I/O " + (panel.resourceState.ioPressure >= 0 ? panel.resourceState.ioPressure.toFixed(2) + "%" : "N/A") + " · Fan " + (panel.resourceState.fanRpm >= 0 ? panel.resourceState.fanRpm + " RPM" : "N/A")
            color: panel.theme.textMuted
            wrapMode: Text.WordWrap
        }

        CenteredActionFlow {
            width: parent.width
            spacing: panel.theme.spacing2
            ShellAction {
                id: coresAction
                width: Math.min(parent.width, implicitWidth)
                height: implicitHeight
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                horizontalCompact: true
                icon: "󰍛"
                title: "Logical cores"
                active: panel.showCores
                activeColor: panel.theme.roleColor("resources")
                shortcut: panel.runtime.shellHint("ResourceDashboard.toggleCores")
                onActivated: panel.toggleCoreView()
            }
            ShellAction {
                id: processesAction
                width: Math.min(parent.width, implicitWidth)
                height: implicitHeight
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                horizontalCompact: true
                icon: "󰓅"
                title: "Processes"
                active: panel.showProcesses
                activeColor: panel.theme.roleColor("resources")
                shortcut: panel.runtime.shellHint("ResourceDashboard.processes")
                onActivated: panel.activateAction("ResourceDashboard.processes")
            }
            ShellAction {
                id: sortAction
                visible: panel.showProcesses
                width: Math.min(parent.width, implicitWidth)
                height: implicitHeight
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                horizontalCompact: true
                title: panel.resourceState.sortByMemory ? "Sort: memory" : "Sort: CPU"
                shortcut: panel.runtime.shellHint("ResourceDashboard.sort")
                onActivated: panel.activateAction("ResourceDashboard.sort")
            }
        }

        ShellSurface {
            visible: panel.showCores || panel.showProcesses
            width: parent.width
            height: visible ? historyContent.implicitHeight + panel.theme.spacing3 * 2 : 0
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

                ShellText {
                    width: parent.width
                    runtime: panel.runtime
                    theme: panel.theme
                    text: panel.showProcesses ? (panel.resourceState.sortByMemory ? "Top processes · memory" : "Top processes · CPU average") : "Logical cores · " + panel.resourceState.coreUsage.length + " active counters"
                    textRole: ShellText.Section
                    wrapMode: Text.WordWrap
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
                    columns: Math.min(8, Math.max(1, panel.resourceState.coreUsage.length), Math.max(1, Math.floor(width / panel.theme.fontSize(88))))
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
                            height: panel.theme.fontSize(36)
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
                                    width: Math.max(0, parent.width - panel.theme.fontSize(66))
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
            spacing: panel.theme.spacing2
            ShellValueSelector {
                id: intervalSelector
                width: Math.max(1, (parent.width - parent.spacing) / 2)
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                title: "Sampling interval"
                shortcut: panel.runtime.shellHint("ResourceDashboard.interval")
                confirmShortcut: panel.runtime.shellHint("SystemContent.legend.activate_confirm")
                accentColor: panel.theme.roleColor("resources")
                readonly property var values: panel.runtime.constraints.resourceSampling.intervalSeconds.values
                options: values.map(value => value + "s")
                selectedIndex: values.indexOf(panel.resourceState.intervalSeconds)
                onOpened: {
                    historySelector.cancel();
                    diskSelector.cancel();
                    panel.revealSelector(intervalSelector);
                }
                onChosen: index => panel.resourceState.setInterval(values[index])
            }
            ShellValueSelector {
                id: historySelector
                width: intervalSelector.width
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                title: "History length"
                shortcut: panel.runtime.shellHint("ResourceDashboard.history")
                confirmShortcut: panel.runtime.shellHint("SystemContent.legend.activate_confirm")
                accentColor: panel.theme.roleColor("resources")
                readonly property var values: panel.runtime.constraints.resourceSampling.historyLength.values
                options: values.map(value => value + " samples")
                selectedIndex: values.indexOf(panel.resourceState.historyLength)
                onOpened: {
                    intervalSelector.cancel();
                    diskSelector.cancel();
                    panel.revealSelector(historySelector);
                }
                onChosen: index => panel.resourceState.setHistory(values[index])
            }
        }
    }
}

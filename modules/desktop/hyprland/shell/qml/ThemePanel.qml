pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: panel

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    signal keyboardRequested
    signal switchLaunched
    signal switchFinished

    property bool open: false
    property var themes: []
    property string defaultTheme: ""
    property string currentTheme: ""
    property int selectedIndex: 0
    property string statusText: ""
    property bool statusError: false
    property bool operationRunning: false
    property string operationPhase: "idle"
    property string operationTarget: ""
    property string operationLog: ""

    Connections {
        target: panel.runtime

        function onThemeChanged(): void {
            panel.refreshCurrentTheme();
        }
    }

    implicitHeight: header.height + panel.theme.spacing4 * 3 + Math.min(505, Math.max(280, Math.ceil(themes.length / 2) * themeList.cellHeight)) + footer.implicitHeight
    visible: open

    property StdioCollector registryOutput: StdioCollector {}
    property StdioCollector registryError: StdioCollector {}
    property StdioCollector currentOutput: StdioCollector {}
    property StdioCollector currentError: StdioCollector {}

    property Process registryProcess: Process {
        stdout: panel.registryOutput
        stderr: panel.registryError

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                panel.setError(panel.registryError.text, "FAILED TO LOAD THEME REGISTRY");
                return;
            }

            try {
                const parsed = JSON.parse(panel.registryOutput.text);
                panel.defaultTheme = parsed.default || "";
                panel.themes = parsed.themes || [];
                panel.selectCurrentTheme();
            } catch (error) {
                panel.setError(error.toString(), "INVALID THEME REGISTRY");
            }
        }
    }

    // Launch only; the scoped operation is owned and tracked by systemd.
    property StdioCollector switchErrors: StdioCollector {}
    property Process switchProcess: Process {
        stderr: panel.switchErrors
        onExited: (exitCode, exitStatus) => {
            panel.refreshOperation();
            panel.refreshCurrentTheme();
        }
    }

    // The job is a systemd scope with persistent state/logs; the view only
    // observes it, so shell restarts do not erase build progress or cancel it.
    property StdioCollector statusOutput: StdioCollector {}
    property StdioCollector logOutput: StdioCollector {}
    property Process statusProcess: Process {
        stdout: panel.statusOutput
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                return;
            try {
                const status = JSON.parse(panel.statusOutput.text);
                panel.operationRunning = status.running;
                panel.operationPhase = status.phase;
                panel.operationTarget = status.target;
                if (status.running && (status.phase === "authorizing" || status.phase === "activating"))
                    panel.switchLaunched();
                else
                    panel.switchFinished();
                if (status.phase === "completed" || status.phase === "failed" || status.phase === "cancelled") {
                    panel.statusText = status.phase === "completed" ? "THEME ACTIVATED" : status.phase === "cancelled" ? "THEME BUILD CANCELLED" : "LAST THEME ACTIVATION FAILED";
                    panel.statusError = status.phase === "failed";
                }
            } catch (error) {
                panel.setError("", "THEME OPERATION STATE UNAVAILABLE");
            }
        }
    }
    property Process logProcess: Process {
        stdout: panel.logOutput
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                panel.operationLog = panel.logOutput.text.replace(/\x1b\[[0-9;]*[A-Za-z]/g, "").replace(/\r/g, "").trim();
        }
    }
    property Timer operationPoll: Timer {
        interval: 900
        repeat: true
        // Opening the gallery requests one snapshot. Only an ongoing theme
        // operation needs subsequent status checks while systemd owns it.
        running: panel.operationRunning
        onTriggered: panel.refreshOperation()
    }
    function refreshOperation(): void {
        if (runtime.themeSet.length === 0)
            return;
        if (!statusProcess.running)
            statusProcess.exec([runtime.themeSet, "status"]);
        if (!logProcess.running && (operationRunning || operationPhase === "failed"))
            logProcess.exec([runtime.themeSet, "logs"]);
    }
    function cancelOperation(): void {
        if (!operationRunning || (operationPhase !== "preparing" && operationPhase !== "building"))
            return;
        statusText = "STOPPING THEME BUILD…";
        Quickshell.execDetached([runtime.themeSet, "cancel"]);
        Qt.callLater(refreshOperation);
    }

    property Process currentProcess: Process {
        stdout: panel.currentOutput
        stderr: panel.currentError

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                panel.setError(panel.currentError.text, "FAILED TO READ ACTIVE THEME");
                return;
            }

            panel.currentTheme = panel.currentOutput.text.trim();
            panel.selectCurrentTheme();
        }
    }

    function setError(detail: string, fallback: string): void {
        const message = (detail || "").trim();
        statusText = message.length > 0 ? message : fallback;
        statusError = true;
    }

    function themeLabel(name: string): string {
        for (const entry of themes) {
            if (entry.name === name)
                return entry.label || entry.name;
        }

        return name;
    }

    function selectedTheme(): var {
        if (themes.length === 0)
            return null;

        return themes[Math.max(0, Math.min(selectedIndex, themes.length - 1))];
    }

    function selectCurrentTheme(): void {
        if (themes.length === 0) {
            selectedIndex = 0;
            return;
        }

        for (let index = 0; index < themes.length; index++) {
            if (themes[index].name === currentTheme) {
                selectedIndex = index;
                return;
            }
        }

        selectedIndex = 0;
    }

    function refreshCurrentTheme(): void {
        if (runtime.themeSet.length > 0 && !currentProcess.running)
            currentProcess.exec([runtime.themeSet, "current"]);
    }

    function refresh(): void {
        statusText = "";
        statusError = false;

        if (runtime.themeSet.length === 0) {
            setError("", "THEME SWITCHER UNAVAILABLE");
            return;
        }

        if (!registryProcess.running)
            registryProcess.exec([runtime.themeSet, "list", "--json"]);

        refreshCurrentTheme();
    }

    function openView(): void {
        open = true;
        refreshOperation();
        selectedIndex = 0;
        refresh();
        keyboardRequested();
    }

    function closeView(): void {
        open = false;
        statusText = "";
        statusError = false;
        keyboardRequested();
    }

    function moveHalfPage(direction: int): void {
        const rows = Math.max(1, Math.floor(themeList.height / themeList.cellHeight / 2));
        moveSelection(direction * rows * themeList.columnCount);
    }

    function moveSelection(delta: int): void {
        if (themes.length === 0)
            return;
        selectedIndex = Math.max(0, Math.min(themes.length - 1, selectedIndex + delta));
    }

    function moveGrid(x: int, y: int): void {
        moveSelection(x + y * themeList.columnCount);
    }

    function activateSelected(): void {
        if (runtime.themeSet.length === 0 || switchProcess.running || operationRunning)
            return;

        const selected = selectedTheme();
        if (!selected)
            return;

        if (selected.name === currentTheme) {
            statusText = "ALREADY ACTIVE // " + (selected.label || selected.name).toUpperCase();
            statusError = false;
            return;
        }

        statusText = "APPLYING " + (selected.label || selected.name).toUpperCase() + "…";
        statusError = false;
        operationRunning = true;
        operationPhase = "preparing";
        operationTarget = selected.name;
        Qt.callLater(() => {
            if (switchProcess && !switchProcess.running)
                switchProcess.exec([runtime.themeSet, "switch", selected.name]);
        });
    }

    DetailHero {
        id: header
        width: parent.width
        quiet: true
        height: implicitHeight
        runtime: panel.runtime
        theme: panel.theme
        motion: panel.motion
        glyph: "◈"
        glyphColor: panel.theme.roleColor("display")
        eyebrow: "Appearance / system themes"
        title: "Theme gallery"
        detail: panel.currentTheme.length > 0 ? "Active · " + panel.themeLabel(panel.currentTheme) : "Resolving active theme…"
    }

    GridView {
        id: themeList
        anchors {
            top: header.bottom
            right: parent.right
            bottom: footer.top
            left: parent.left
            topMargin: panel.theme.spacing4
            bottomMargin: panel.theme.spacing3
        }
        readonly property int columnCount: width < 580 || panel.theme.textScale >= 1.5 ? 1 : 2
        cellWidth: width / columnCount
        cellHeight: 230
        model: panel.themes
        clip: true
        currentIndex: panel.selectedIndex
        highlightMoveDuration: 0
        boundsBehavior: Flickable.StopAtBounds
        onCurrentIndexChanged: {
            if (currentIndex >= 0)
                positionViewAtIndex(currentIndex, GridView.Contain);
        }

        delegate: Item {
            id: themeCard
            required property var modelData
            required property int index
            readonly property var preview: modelData.preview

            width: themeList.cellWidth
            height: themeList.cellHeight
            scale: previewPress.pressed ? 0.985 : 1

            Behavior on scale {
                Anim {
                    motion: panel.motion
                    type: Anim.FastSpatial
                }
            }

            ShellSurface {
                id: card
                anchors {
                    fill: parent
                    rightMargin: panel.theme.spacing3
                    bottomMargin: panel.theme.spacing3
                }
                theme: panel.theme
                motion: panel.motion
                surfaceLayer: ShellSurface.Control
                cornerRadius: panel.theme.radiusLarge
                borderColor: themeCard.index === panel.selectedIndex ? panel.theme.accent : "transparent"
                borderWidth: themeCard.index === panel.selectedIndex ? panel.theme.borderFocus * 2 : 0

                Column {
                    anchors {
                        fill: parent
                        margins: panel.theme.spacing3
                    }
                    spacing: panel.theme.spacing2

                    // Miniature window surfaces sample the official registry
                    // colours. They are intentionally schematic, not another
                    // themed app implementation or a hard-coded Base16 skin.
                    ShellSurface {
                        id: palettePreview
                        width: parent.width
                        height: 145
                        theme: panel.theme
                        motion: panel.motion
                        surfaceLayer: ShellSurface.Group
                        cornerRadius: panel.theme.radiusMedium
                        fillColor: themeCard.preview ? themeCard.preview.background : panel.theme.surface
                        borderWidth: 1
                        borderColor: themeCard.preview ? themeCard.preview.outline : panel.theme.subtleBorder
                        clip: true

                        Rectangle {
                            width: parent.width
                            height: 23
                            radius: 8
                            color: themeCard.preview ? themeCard.preview.surface : panel.theme.surface
                        }
                        Row {
                            x: 10
                            y: 8
                            spacing: 5
                            Repeater {
                                model: 3
                                delegate: Rectangle {
                                    required property int index
                                    width: 7
                                    height: 7
                                    radius: 4
                                    color: themeCard.preview && themeCard.preview.swatches.length > 0 ? themeCard.preview.swatches[index % themeCard.preview.swatches.length] : panel.theme.accent
                                }
                            }
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 9
                            width: 32
                            height: 5
                            radius: 3
                            color: themeCard.preview ? themeCard.preview.text : panel.theme.textStrong
                            opacity: 0.3
                        }
                        Rectangle {
                            x: parent.width - 32
                            y: 8
                            width: 21
                            height: 7
                            radius: 4
                            color: themeCard.preview && themeCard.preview.swatches.length > 3 ? themeCard.preview.swatches[3] : panel.theme.accent
                            opacity: 0.85
                        }

                        Rectangle {
                            id: samplePane
                            x: 10
                            y: 32
                            width: Math.max(90, parent.width * 0.6)
                            height: 84
                            radius: 10
                            color: themeCard.preview ? themeCard.preview.surface : panel.theme.surfaceRaised

                            Rectangle {
                                x: 10
                                y: 10
                                width: parent.width - 20
                                height: 6
                                radius: 3
                                color: themeCard.preview && themeCard.preview.swatches.length > 0 ? themeCard.preview.swatches[0] : panel.theme.accent
                            }
                            Text {
                                x: 10
                                y: 22
                                text: "Ag"
                                color: themeCard.preview ? themeCard.preview.text : panel.theme.textStrong
                                font.family: panel.runtime.fontMono
                                font.pixelSize: panel.theme.fontSize(22)
                                font.weight: Font.DemiBold
                            }
                            Rectangle {
                                x: 46
                                y: 34
                                width: Math.max(8, parent.width - 60)
                                height: 5
                                radius: 3
                                color: themeCard.preview ? themeCard.preview.text : panel.theme.textStrong
                                opacity: 0.8
                            }
                            Rectangle {
                                x: 46
                                y: 46
                                width: Math.max(8, (parent.width - 60) * 0.65)
                                height: 4
                                radius: 2
                                color: themeCard.preview ? themeCard.preview.text : panel.theme.textStrong
                                opacity: 0.35
                            }
                            Rectangle {
                                x: 10
                                y: 64
                                width: Math.max(8, parent.width * 0.42)
                                height: 9
                                radius: 5
                                color: themeCard.preview && themeCard.preview.swatches.length > 1 ? themeCard.preview.swatches[1] : panel.theme.accent
                            }
                        }

                        Column {
                            id: metricsColumn
                            x: samplePane.x + samplePane.width + 12
                            y: samplePane.y + 5
                            width: Math.max(1, parent.width - x - 10)
                            spacing: 9
                            Repeater {
                                model: 3
                                delegate: Row {
                                    id: sampleMetric
                                    required property int index
                                    width: metricsColumn.width
                                    spacing: 4
                                    Rectangle {
                                        width: 9
                                        height: 9
                                        radius: 5
                                        color: themeCard.preview && themeCard.preview.swatches.length > 0 ? themeCard.preview.swatches[(sampleMetric.index + 2) % themeCard.preview.swatches.length] : panel.theme.accent
                                    }
                                    Rectangle {
                                        width: Math.max(4, sampleMetric.width - 18 - sampleMetric.index * 9)
                                        height: 6
                                        radius: 3
                                        color: themeCard.preview ? themeCard.preview.text : panel.theme.textStrong
                                        opacity: 0.6 - sampleMetric.index * 0.13
                                    }
                                }
                            }
                        }
                        Row {
                            x: 10
                            y: parent.height - 15
                            width: parent.width - 20
                            spacing: 5
                            Repeater {
                                model: themeCard.preview ? themeCard.preview.swatches : []
                                delegate: Rectangle {
                                    required property var modelData
                                    width: Math.max(1, (palettePreview.width - 20 - 20) / 5)
                                    height: 6
                                    radius: 3
                                    color: modelData
                                }
                            }
                        }

                        // Wallpaper-derived themes have no fixed scheme until
                        // activation. Show their source image instead of
                        // borrowing an unrelated currently active palette.
                        Item {
                            anchors.fill: parent
                            visible: themeCard.modelData.name === "wallpaper"
                            Image {
                                anchors.fill: parent
                                source: panel.runtime.wallpaper.length > 0 ? "file://" + panel.runtime.wallpaper : ""
                                sourceSize: Qt.size(400, 220)
                                asynchronous: true
                                cache: true
                                fillMode: Image.PreserveAspectCrop
                            }
                            Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(0.06, 0.07, 0.09, 0.55)
                            }
                            Column {
                                anchors.centerIn: parent
                                spacing: 5
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰸉"
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: panel.theme.fontSize(25)
                                    color: "#ffffff"
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "DYNAMIC PALETTE"
                                    color: "#ffffff"
                                    font.family: panel.runtime.fontMono
                                    font.pixelSize: panel.theme.fontSize(11)
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 0.7
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "DERIVED FROM WALLPAPER"
                                    color: "#ffffff"
                                    opacity: 0.8
                                    font.family: panel.runtime.fontMono
                                    font.pixelSize: panel.theme.fontSize(9)
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: panel.theme.spacing2
                        Text {
                            width: parent.width - status.width - parent.spacing
                            text: themeCard.modelData.label || themeCard.modelData.name
                            color: panel.theme.textStrong
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(12)
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            id: status
                            text: themeCard.modelData.name === panel.currentTheme ? "ACTIVE" : ""
                            color: panel.theme.positive
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(9)
                        }
                    }
                }

                StateLayer {
                    id: previewPress
                    theme: panel.theme
                    motion: panel.motion
                    selected: themeCard.index === panel.selectedIndex
                    cornerRadius: panel.theme.radiusLarge
                    onActivated: {
                        panel.selectedIndex = themeCard.index;
                        panel.activateSelected();
                    }
                }
            }
        }
    }

    Column {
        id: footer

        anchors {
            right: parent.right
            bottom: parent.bottom
            left: parent.left
        }
        spacing: panel.theme.spacing2

        Row {
            anchors.right: parent.right
            spacing: panel.theme.spacing2
            Repeater {
                model: [
                    {
                        shortcut: "H/L",
                        label: "Choose"
                    },
                    {
                        shortcut: "J/K",
                        label: "Rows"
                    },
                    {
                        shortcut: "ENTER",
                        label: "Apply"
                    },
                    {
                        shortcut: "ESC",
                        label: "Back"
                    }
                ]
                delegate: KeyHint {
                    required property var modelData
                    shortcut: modelData.shortcut
                    label: modelData.label
                    theme: panel.theme
                    runtime: panel.runtime
                }
            }
        }

        Row {
            width: parent.width
            visible: panel.operationRunning
            spacing: panel.theme.spacing2
            Text {
                width: Math.max(1, parent.width - cancelButton.width - parent.spacing)
                anchors.verticalCenter: parent.verticalCenter
                text: panel.operationPhase.toUpperCase() + " · " + panel.themeLabel(panel.operationTarget)
                color: panel.theme.accent
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontKeyHint
                elide: Text.ElideRight
            }
            ShellAction {
                id: cancelButton
                width: 125
                height: 36
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                horizontalCompact: true
                title: panel.operationPhase === "building" || panel.operationPhase === "preparing" ? "Cancel build" : "Activating"
                icon: "󰅖"
                shortcut: "X"
                enabled: panel.operationPhase === "building" || panel.operationPhase === "preparing"
                onActivated: panel.cancelOperation()
            }
        }
        Text {
            width: parent.width
            visible: panel.operationRunning || panel.operationPhase === "failed"
            text: panel.operationLog
            maximumLineCount: 3
            elide: Text.ElideLeft
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            color: panel.theme.textMuted
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(9)
        }

        Text {
            width: parent.width
            visible: panel.statusText.length > 0
            text: panel.statusText
            color: panel.theme.readableRoleColor(panel.statusError ? "critical" : "positive")
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(8)
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
        }
    }
}

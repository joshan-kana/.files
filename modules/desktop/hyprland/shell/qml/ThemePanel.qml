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

    Connections {
        target: panel.runtime

        function onThemeChanged(): void {
            panel.refreshCurrentTheme();
        }
    }

    implicitHeight: header.height + panel.theme.spacing4 * 3 + Math.min(680, Math.max(390, Math.ceil(themes.length / 2) * themeList.cellHeight)) + footer.implicitHeight
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

    // Keep the prompt's launch process alive so the hub can relinquish its
    // keyboard grab without disappearing. The terminal runs on the dedicated
    // system workspace, independent of the user's Super+X workspace.
    property Process switchProcess: Process {
        onExited: (exitCode, exitStatus) => {
            panel.switchFinished();
            panel.statusText = exitCode === 0 ? "THEME SWITCH FINISHED" : "THEME SWITCH DID NOT COMPLETE";
            panel.statusError = exitCode !== 0;
            panel.refreshCurrentTheme();
        }
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
        if (runtime.themeSet.length === 0 || switchProcess.running)
            return;

        const selected = selectedTheme();
        if (!selected)
            return;

        if (selected.name === currentTheme) {
            statusText = "ALREADY ACTIVE // " + (selected.label || selected.name).toUpperCase();
            statusError = false;
            return;
        }

        statusText = "OPENING TERMINAL // " + (selected.label || selected.name).toUpperCase();
        statusError = false;
        // Release the hub grab before the terminal is created, but keep the
        // palette visible. The process owns the handoff until the prompt exits.
        switchLaunched();
        Qt.callLater(() => {
            if (switchProcess && !switchProcess.running)
                switchProcess.exec([runtime.themeSet, "switch", selected.name]);
        });
    }

    ShellSurface {
        id: header
        width: parent.width
        height: 140
        theme: panel.theme
        motion: panel.motion
        surfaceLayer: ShellSurface.Group
        cornerRadius: panel.theme.radiusLarge

        ShellSurface {
            width: 76
            height: 76
            anchors.left: parent.left
            anchors.leftMargin: panel.theme.spacing4
            anchors.verticalCenter: parent.verticalCenter
            theme: panel.theme
            motion: panel.motion
            surfaceLayer: ShellSurface.Control
            cornerRadius: panel.theme.radiusMedium

            Text {
                anchors.centerIn: parent
                text: "◈"
                color: panel.theme.accent
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(38)
            }
        }

        Column {
            anchors {
                fill: parent
                margins: panel.theme.spacing4
                leftMargin: panel.theme.spacing4 + 94
            }
            spacing: panel.theme.spacing2

            Text {
                text: "Appearance"
                color: panel.theme.accent
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(11)
                font.weight: Font.Medium
            }

            Text {
                text: "Theme registry"
                color: panel.theme.textStrong
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSubpanelTitle
                font.weight: Font.DemiBold
            }

            Text {
                text: panel.currentTheme.length > 0 ? "Active · " + panel.themeLabel(panel.currentTheme) : "Resolving active theme…"
                color: panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(9)
                font.letterSpacing: 0.8
            }
        }
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
        cellHeight: 206
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
            scale: previewPress.pressed ? 0.985 : previewPress.containsMouse ? 1.012 : 1

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

                    ShellSurface {
                        width: parent.width
                        height: 122
                        theme: panel.theme
                        motion: panel.motion
                        surfaceLayer: ShellSurface.Group
                        cornerRadius: panel.theme.radiusMedium
                        fillColor: themeCard.preview ? themeCard.preview.background : panel.theme.surface
                        clip: true

                        Row {
                            anchors {
                                top: parent.top
                                left: parent.left
                                right: parent.right
                                margins: panel.theme.spacing2
                            }
                            spacing: 5
                            Repeater {
                                model: 3
                                delegate: Rectangle {
                                    required property int index
                                    width: index === 0 ? 28 : 8
                                    height: 8
                                    radius: 4
                                    color: themeCard.preview && themeCard.preview.swatches.length > 0 ? themeCard.preview.swatches[index % themeCard.preview.swatches.length] : panel.theme.accent
                                }
                            }
                        }

                        Rectangle {
                            x: 12
                            y: 28
                            width: parent.width * 0.57
                            height: 73
                            radius: 10
                            color: themeCard.preview ? Qt.tint(themeCard.preview.background, Qt.rgba(themeCard.preview.text.r, themeCard.preview.text.g, themeCard.preview.text.b, 0.12)) : panel.theme.layer3

                            Rectangle {
                                x: 9
                                y: 9
                                width: parent.width - 18
                                height: 8
                                radius: 4
                                color: themeCard.preview && themeCard.preview.swatches.length ? themeCard.preview.swatches[0] : panel.theme.accent
                            }
                            Rectangle {
                                x: 9
                                y: 24
                                width: parent.width * 0.72
                                height: 5
                                radius: 3
                                color: themeCard.preview ? themeCard.preview.text : panel.theme.textStrong
                                opacity: 0.65
                            }
                            Rectangle {
                                x: 9
                                y: 36
                                width: parent.width * 0.47
                                height: 5
                                radius: 3
                                color: themeCard.preview ? themeCard.preview.text : panel.theme.textStrong
                                opacity: 0.42
                            }
                            Rectangle {
                                x: 9
                                y: 54
                                width: parent.width - 18
                                height: 8
                                radius: 4
                                color: themeCard.preview && themeCard.preview.swatches.length > 1 ? themeCard.preview.swatches[1] : panel.theme.accent
                                opacity: 0.80
                            }
                        }

                        Column {
                            anchors {
                                right: parent.right
                                rightMargin: 12
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 5
                            Repeater {
                                model: themeCard.preview ? themeCard.preview.swatches : []
                                delegate: Rectangle {
                                    required property var modelData
                                    width: 28
                                    height: 11
                                    radius: 5
                                    color: modelData
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
                            text: themeCard.modelData.name === panel.currentTheme ? "ACTIVE" : themeCard.index === panel.selectedIndex ? "SELECTED" : ""
                            color: themeCard.modelData.name === panel.currentTheme ? panel.theme.positive : panel.theme.accent
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
                        if (panel.selectedIndex === themeCard.index)
                            panel.activateSelected();
                        else
                            panel.selectedIndex = themeCard.index;
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

        Text {
            width: parent.width
            visible: panel.statusText.length > 0
            text: panel.statusText
            color: panel.statusError ? panel.theme.critical : panel.theme.positive
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(8)
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
        }

        Row {
            anchors.right: parent.right
            spacing: panel.theme.spacing4

            Text {
                text: "↑/↓  SELECT"
                color: panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontKeyHint
                font.letterSpacing: 0.8
            }

            Text {
                text: "ENTER  SWITCH"
                color: panel.theme.accent
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontKeyHint
                font.letterSpacing: 0.8
            }

            Text {
                text: "ESC  BACK"
                color: panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontKeyHint
                font.letterSpacing: 0.8
            }
        }
    }
}

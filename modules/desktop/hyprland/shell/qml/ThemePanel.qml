pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

Item {
    id: panel

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    signal keyboardRequested

    property bool open: false
    property var themes: []
    property string defaultTheme: ""
    property string currentTheme: ""
    property int selectedIndex: 0
    property string statusText: ""
    property bool statusError: false

    readonly property bool applying: switchProcess.running

    Connections {
        target: panel.runtime

        function onThemeChanged(): void {
            panel.refreshCurrentTheme();
        }
    }

    visible: open

    property StdioCollector registryOutput: StdioCollector {}
    property StdioCollector registryError: StdioCollector {}
    property StdioCollector currentOutput: StdioCollector {}
    property StdioCollector currentError: StdioCollector {}
    property StdioCollector switchError: StdioCollector {}

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

    property Process switchProcess: Process {
        stderr: panel.switchError

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                panel.setError(panel.switchError.text, "FAILED TO OPEN THEME TERMINAL");
            else {
                // The full-system theme switch happens in stock nh, not here.
                panel.statusText = "CHECK TERMINAL // SYSTEM THEME SWITCH";
                panel.statusError = false;
            }
            panel.keyboardRequested();
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
        const rowHeight = themeList.currentItem ? themeList.currentItem.height + themeList.spacing : 64;
        const rows = Math.max(1, Math.floor(themeList.height / Math.max(1, rowHeight) / 2));
        moveSelection(direction * rows);
    }

    function moveSelection(delta: int): void {
        if (themes.length === 0)
            return;

        selectedIndex = Math.max(0, Math.min(themes.length - 1, selectedIndex + delta));
    }

    function activateSelected(): void {
        if (runtime.themeSet.length === 0 || applying)
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
        switchProcess.exec([runtime.themeSet, "switch", selected.name]);
    }

    Column {
        id: header

        width: parent.width
        spacing: panel.theme.spacing1

        Text {
            text: "Appearance"
            color: panel.theme.accent
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(11)
            font.weight: Font.Medium
        }

        Text {
            text: "Palette switcher"
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

    ListView {
        id: themeList

        anchors {
            top: header.bottom
            right: parent.right
            bottom: footer.top
            left: parent.left
            topMargin: panel.theme.spacing4
            bottomMargin: panel.theme.spacing3
        }

        model: panel.themes
        spacing: panel.theme.spacing2
        clip: true
        currentIndex: panel.selectedIndex
        // Keyboard auto-repeat must not queue smooth highlight/scroll motion.
        highlightMoveDuration: 0
        highlightResizeDuration: 0
        boundsBehavior: Flickable.StopAtBounds

        onCurrentIndexChanged: {
            if (currentIndex >= 0)
                positionViewAtIndex(currentIndex, ListView.Contain);
        }

        delegate: ShellSurface {
            id: themeRow

            required property var modelData
            required property int index

            width: ListView.view.width
            height: 82
            theme: panel.theme
            motion: panel.motion
            surfaceLayer: ShellSurface.Control
            cornerRadius: theme.radiusMedium
            fillColor: modelData.preview ? modelData.preview.background : theme.layer3
            borderColor: index === panel.selectedIndex ? panel.theme.accent : "transparent"
            borderWidth: index === panel.selectedIndex ? panel.theme.borderFocus * 2 : 0

            StateLayer {
                theme: panel.theme
                motion: panel.motion
                // Preserve each palette's own foreground/background contrast.
                // The outer accent border communicates keyboard selection.
                stateColor: themeRow.modelData.preview ? themeRow.modelData.preview.text : panel.theme.textStrong
                cornerRadius: panel.theme.radiusMedium

                onActivated: {
                    panel.selectedIndex = themeRow.index;
                    panel.activateSelected();
                }
            }

            Row {
                anchors {
                    fill: parent
                    margins: panel.theme.spacing3
                }
                spacing: panel.theme.spacing3

                Column {
                    width: parent.width - swatchPreview.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Row {
                        width: parent.width
                        spacing: panel.theme.spacing2

                        Text {
                            width: parent.width - stateBadge.width - parent.spacing
                            text: themeRow.modelData.label || themeRow.modelData.name
                            color: themeRow.modelData.preview ? themeRow.modelData.preview.text : panel.theme.textStrong
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(14)
                            font.weight: themeRow.modelData.name === panel.currentTheme ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }

                        Text {
                            id: stateBadge
                            text: themeRow.modelData.name === panel.currentTheme ? "ACTIVE" : (themeRow.modelData.name === panel.defaultTheme ? "DEFAULT" : "")
                            color: themeRow.modelData.preview ? themeRow.modelData.preview.text : panel.theme.textMuted
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(8)
                            font.weight: Font.DemiBold
                        }
                    }

                    Text {
                        text: themeRow.modelData.name.toUpperCase() + (themeRow.index === panel.selectedIndex ? " // SELECTED" : "")
                        color: themeRow.modelData.preview ? themeRow.modelData.preview.text : panel.theme.textMuted
                        opacity: 0.72
                        font.family: panel.runtime.fontMono
                        font.pixelSize: panel.theme.fontSize(8)
                        font.letterSpacing: 0.7
                    }
                }

                Row {
                    id: swatchPreview

                    width: 112
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Repeater {
                        model: themeRow.modelData.preview ? themeRow.modelData.preview.swatches : []

                        delegate: Rectangle {
                            required property var modelData

                            width: 18
                            height: 30
                            radius: 7
                            color: modelData
                            border.width: panel.theme.borderThin
                            border.color: panel.theme.subtleBorder
                        }
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
            color: panel.statusError ? panel.theme.critical : (panel.applying ? panel.theme.warning : panel.theme.positive)
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
                text: panel.applying ? "ENTER  OPENING" : "ENTER  SWITCH"
                color: panel.applying ? panel.theme.warning : panel.theme.accent
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

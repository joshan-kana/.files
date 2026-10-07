import QtQuick
import Quickshell.Io

Item {
    id: panel

    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion

    signal keyboardRequested

    property bool open: false
    property var themes: []
    property string defaultTheme: ""
    property string currentTheme: ""
    property string pendingTheme: ""
    property string desiredTheme: ""
    property string builtActivation: ""
    property int selectedIndex: 0
    property string statusText: ""
    property bool statusError: false

    readonly property bool applying: buildProcess.running || activateProcess.running

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
    property StdioCollector buildOutput: StdioCollector {}
    property StdioCollector buildError: StdioCollector {}
    property StdioCollector activateOutput: StdioCollector {}
    property StdioCollector activateError: StdioCollector {}

    Timer {
        id: nextThemeTimer
        interval: 0
        repeat: false
        onTriggered: panel.startDesiredTheme()
    }

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

    property Process buildProcess: Process {
        stdout: panel.buildOutput
        stderr: panel.buildError

        onExited: (exitCode, exitStatus) => {
            const completedTheme = panel.pendingTheme;

            if (exitCode !== 0) {
                if (completedTheme === panel.desiredTheme)
                    panel.setError(panel.buildError.text, "THEME BUILD FAILED");
                panel.pendingTheme = "";
                nextThemeTimer.restart();
                panel.keyboardRequested();
                return;
            }

            const activation = panel.buildOutput.text.trim().split("\n").filter(line => line.length > 0).pop() || "";
            panel.pendingTheme = "";

            if (completedTheme !== panel.desiredTheme) {
                nextThemeTimer.restart();
                panel.keyboardRequested();
                return;
            }

            if (activation.length === 0) {
                panel.setError("", "THEME BUILD RETURNED NO ACTIVATION");
                panel.keyboardRequested();
                return;
            }

            panel.builtActivation = activation;
            panel.pendingTheme = completedTheme;
            panel.statusText = "ACTIVATING // " + panel.themeLabel(completedTheme).toUpperCase();
            panel.statusError = false;
            activateProcess.exec([runtime.themeSet, "activate-built", completedTheme, activation]);
        }
    }

    property Process activateProcess: Process {
        stdout: panel.activateOutput
        stderr: panel.activateError

        onExited: (exitCode, exitStatus) => {
            const completedTheme = panel.pendingTheme;
            panel.pendingTheme = "";
            panel.builtActivation = "";

            if (exitCode === 0) {
                panel.currentTheme = completedTheme;
                panel.statusText = "ACTIVE // " + panel.themeLabel(panel.currentTheme).toUpperCase();
                panel.statusError = false;
                panel.selectCurrentTheme();
            } else if (completedTheme === panel.desiredTheme) {
                panel.setError(panel.activateError.text, "THEME SWITCH FAILED");
            }

            nextThemeTimer.restart();
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

    function moveSelection(delta: int): void {
        if (themes.length === 0)
            return;

        selectedIndex = Math.max(0, Math.min(themes.length - 1, selectedIndex + delta));
    }

    function startDesiredTheme(): void {
        if (runtime.themeSet.length === 0 || applying || desiredTheme.length === 0)
            return;

        if (desiredTheme === currentTheme) {
            statusText = "ACTIVE // " + themeLabel(currentTheme).toUpperCase();
            statusError = false;
            return;
        }

        pendingTheme = desiredTheme;
        statusText = "BUILDING // " + themeLabel(pendingTheme).toUpperCase();
        statusError = false;
        buildProcess.exec([runtime.themeSet, "build", pendingTheme]);
    }

    function activateSelected(): void {
        if (runtime.themeSet.length === 0)
            return;

        const selected = selectedTheme();
        if (!selected)
            return;

        desiredTheme = selected.name;

        if (applying) {
            if (desiredTheme !== pendingTheme) {
                statusText = "QUEUED // " + (selected.label || selected.name).toUpperCase();
                statusError = false;
            }
            return;
        }

        if (selected.name === currentTheme) {
            statusText = "ALREADY ACTIVE // " + (selected.label || selected.name).toUpperCase();
            statusError = false;
            return;
        }

        startDesiredTheme();
    }

    Column {
        id: header

        width: parent.width
        spacing: theme.spacing1

        Text {
            text: "Appearance"
            color: theme.accent
            font.family: runtime.fontSans
            font.pixelSize: theme.fontSize(11)
            font.weight: Font.Medium
        }

        Text {
            text: "Palette switcher"
            color: theme.textStrong
            font.family: runtime.fontSans
            font.pixelSize: theme.fontSubpanelTitle
            font.weight: Font.DemiBold
        }

        Text {
            text: currentTheme.length > 0 ? "Active · " + panel.themeLabel(currentTheme) : "Resolving active theme…"
            color: theme.textMuted
            font.family: runtime.fontMono
            font.pixelSize: theme.fontSize(9)
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
            topMargin: theme.spacing4
            bottomMargin: theme.spacing3
        }

        model: panel.themes
        spacing: theme.spacing2
        clip: true
        currentIndex: panel.selectedIndex
        boundsBehavior: Flickable.StopAtBounds

        delegate: SquircleSurface {
            id: themeRow

            required property var modelData
            required property int index

            width: ListView.view.width
            height: 82
            exponent: theme.squircleExponent
            cornerRadius: theme.radiusMedium
            fillColor: modelData.preview ? modelData.preview.background : theme.background
            borderColor: modelData.name === panel.currentTheme ? theme.positive : (index === panel.selectedIndex ? theme.accent : theme.outline)
            borderWidth: index === panel.selectedIndex || modelData.name === panel.currentTheme ? theme.borderFocus : theme.borderThin

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    panel.selectedIndex = themeRow.index;
                    panel.activateSelected();
                }
            }

            Row {
                anchors {
                    fill: parent
                    margins: theme.spacing3
                }
                spacing: theme.spacing3

                Column {
                    width: parent.width - swatchPreview.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Row {
                        width: parent.width
                        spacing: theme.spacing2

                        Text {
                            width: parent.width - stateBadge.width - parent.spacing
                            text: modelData.label || modelData.name
                            color: modelData.preview ? modelData.preview.text : theme.textStrong
                            font.family: runtime.fontSans
                            font.pixelSize: theme.fontSize(14)
                            font.weight: modelData.name === panel.currentTheme ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }

                        Text {
                            id: stateBadge
                            text: modelData.name === panel.currentTheme ? "ACTIVE" : (modelData.name === panel.defaultTheme ? "DEFAULT" : "")
                            color: modelData.name === panel.currentTheme ? theme.positive : theme.textMuted
                            font.family: runtime.fontMono
                            font.pixelSize: theme.fontSize(8)
                            font.weight: Font.DemiBold
                        }
                    }

                    Text {
                        text: modelData.name.toUpperCase() + (index === panel.selectedIndex ? " // SELECTED" : "")
                        color: modelData.preview ? modelData.preview.text : theme.textMuted
                        opacity: 0.72
                        font.family: runtime.fontMono
                        font.pixelSize: theme.fontSize(8)
                        font.letterSpacing: 0.7
                    }
                }

                Row {
                    id: swatchPreview

                    width: 112
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Repeater {
                        model: modelData.preview ? modelData.preview.swatches : []

                        delegate: Rectangle {
                            required property var modelData

                            width: 18
                            height: 30
                            radius: 7
                            color: modelData
                            border.width: theme.borderThin
                            border.color: theme.subtleBorder
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
        spacing: theme.spacing2

        Text {
            width: parent.width
            visible: statusText.length > 0
            text: statusText
            color: statusError ? theme.critical : (applying ? theme.warning : theme.positive)
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            font.family: runtime.fontMono
            font.pixelSize: theme.fontSize(8)
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
        }

        Row {
            anchors.right: parent.right
            spacing: theme.spacing4

            Text {
                text: "↑/↓  SELECT"
                color: theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(8)
                font.letterSpacing: 0.8
            }

            Text {
                text: panel.applying ? "ENTER  QUEUE" : "ENTER  APPLY"
                color: panel.applying ? theme.warning : theme.accent
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(8)
                font.letterSpacing: 0.8
            }

            Text {
                text: "ESC  BACK"
                color: theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(8)
                font.letterSpacing: 0.8
            }
        }
    }
}

import QtQuick
import Quickshell.Io

Item {
    id: panel

    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion

    signal keyboardRequested()

    property bool open: false
    property var themes: []
    property string defaultTheme: ""
    property string currentTheme: ""
    property string pendingTheme: ""
    property int selectedIndex: 0
    property string statusText: ""
    property bool statusError: false

    readonly property bool applying: applyProcess.running

    visible: open

    property StdioCollector registryOutput: StdioCollector {}
    property StdioCollector registryError: StdioCollector {}
    property StdioCollector currentOutput: StdioCollector {}
    property StdioCollector currentError: StdioCollector {}
    property StdioCollector applyOutput: StdioCollector {}
    property StdioCollector applyError: StdioCollector {}

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

    property Process applyProcess: Process {
        stdout: panel.applyOutput
        stderr: panel.applyError

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                panel.currentTheme = panel.pendingTheme;
                panel.statusText = "ACTIVE // " + panel.themeLabel(panel.currentTheme).toUpperCase();
                panel.statusError = false;
                panel.selectCurrentTheme();
            } else {
                panel.setError(panel.applyError.text, "THEME SWITCH FAILED");
            }

            panel.pendingTheme = "";
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

    function refresh(): void {
        statusText = "";
        statusError = false;

        if (runtime.themeSet.length === 0) {
            setError("", "THEME SWITCHER UNAVAILABLE");
            return;
        }

        if (!registryProcess.running)
            registryProcess.exec([runtime.themeSet, "list", "--json"]);

        if (!currentProcess.running)
            currentProcess.exec([runtime.themeSet, "current"]);
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
        if (themes.length === 0 || applying)
            return;

        selectedIndex = Math.max(0, Math.min(themes.length - 1, selectedIndex + delta));
    }

    function activateSelected(): void {
        if (applying || runtime.themeSet.length === 0)
            return;

        const selected = selectedTheme();
        if (!selected)
            return;

        if (selected.name === currentTheme) {
            statusText = "ALREADY ACTIVE // " + (selected.label || selected.name).toUpperCase();
            statusError = false;
            return;
        }

        pendingTheme = selected.name;
        statusText = "APPLYING // " + (selected.label || selected.name).toUpperCase();
        statusError = false;
        applyProcess.exec([runtime.themeSet, selected.name]);
    }

    Column {
        id: header

        width: parent.width
        spacing: theme.spacing1

        Text {
            text: "THEME // STYLIX"
            color: theme.accent
            font.family: runtime.fontMono
            font.pixelSize: theme.fontSubpanelEyebrow
            font.weight: Font.DemiBold
            font.letterSpacing: 1.6
        }

        Text {
            text: "Palette switcher"
            color: theme.textStrong
            font.family: runtime.fontSans
            font.pixelSize: theme.fontSubpanelTitle
            font.weight: Font.DemiBold
        }

        Text {
            text: currentTheme.length > 0
                ? "ACTIVE // " + panel.themeLabel(currentTheme).toUpperCase()
                : "RESOLVING ACTIVE THEME"
            color: theme.textMuted
            font.family: runtime.fontMono
            font.pixelSize: 9
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
            borderColor: modelData.name === panel.currentTheme
                ? theme.positive
                : (index === panel.selectedIndex ? theme.accent : theme.outline)
            borderWidth: index === panel.selectedIndex || modelData.name === panel.currentTheme
                ? theme.borderFocus
                : theme.borderThin

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    panel.selectedIndex = themeRow.index;
                    panel.keyboardRequested();
                }

                onDoubleClicked: {
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
                            font.pixelSize: 14
                            font.weight: modelData.name === panel.currentTheme ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }

                        Text {
                            id: stateBadge
                            text: modelData.name === panel.currentTheme
                                ? "ACTIVE"
                                : (modelData.name === panel.defaultTheme ? "DEFAULT" : "")
                            color: modelData.name === panel.currentTheme ? theme.positive : theme.textMuted
                            font.family: runtime.fontMono
                            font.pixelSize: 8
                            font.weight: Font.DemiBold
                        }
                    }

                    Text {
                        text: modelData.name.toUpperCase()
                            + (index === panel.selectedIndex ? " // SELECTED" : "")
                        color: modelData.preview ? modelData.preview.text : theme.textMuted
                        opacity: 0.72
                        font.family: runtime.fontMono
                        font.pixelSize: 8
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
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.14)
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
            font.pixelSize: 8
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
                font.pixelSize: 8
                font.letterSpacing: 0.8
            }

            Text {
                text: panel.applying ? "ENTER  APPLYING" : "ENTER  APPLY"
                color: panel.applying ? theme.warning : theme.accent
                font.family: runtime.fontMono
                font.pixelSize: 8
                font.letterSpacing: 0.8
            }

            Text {
                text: "ESC  BACK"
                color: theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: 8
                font.letterSpacing: 0.8
            }
        }
    }
}

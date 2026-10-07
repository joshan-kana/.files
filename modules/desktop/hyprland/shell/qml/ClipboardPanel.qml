import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: panel

    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion

    property bool open: false
    property bool closing: false
    property var entries: []
    property int selectedIndex: 0

    readonly property var filteredEntries: {
        const query = search.text.trim().toLowerCase();
        const source = entries || [];

        if (query.length === 0)
            return source.slice(0, 100);

        return source.filter(entry => entry.preview.toLowerCase().includes(query) || entry.kind.toLowerCase().includes(query)).slice(0, 100);
    }

    visible: open || closing
    color: "transparent"
    focusable: open
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    WlrLayershell.namespace: "linux-desktop-clipboard"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property StdioCollector queryOutput: StdioCollector {}
    property StdioCollector queryError: StdioCollector {}
    property StdioCollector copyError: StdioCollector {}

    property Process queryProcess: Process {
        stdout: panel.queryOutput
        stderr: panel.queryError

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                panel.entries = panel.parseHistory(panel.queryOutput.text);
            else
                panel.entries = [];

            panel.selectedIndex = 0;
        }
    }

    property Process copyProcess: Process {
        stderr: panel.copyError
    }

    Timer {
        id: closeTimer
        interval: motion.fast
        onTriggered: panel.closing = false
    }

    onFilteredEntriesChanged: {
        selectedIndex = Math.max(0, Math.min(selectedIndex, Math.max(0, filteredEntries.length - 1)));
    }

    function sanitisePreview(raw: string): var {
        const compact = raw.replace(/\r/g, " ").replace(/\n/g, " ").replace(/\s+/g, " ").trim();

        if (compact.length === 0)
            return {
                kind: "TEXT",
                preview: "[empty clipboard item]"
            };

        let suspicious = 0;
        const sample = compact.slice(0, 160);

        for (let i = 0; i < sample.length; i++) {
            const code = sample.charCodeAt(i);
            if (code === 0xfffd || code < 32 || (code >= 127 && code <= 159))
                suspicious++;
        }

        if (suspicious >= 3 || suspicious / sample.length > 0.08)
            return {
                kind: "BINARY",
                preview: "[image or binary clipboard item]"
            };

        return {
            kind: "TEXT",
            preview: compact
        };
    }

    function parseHistory(output: string): var {
        const parsed = [];

        for (const line of output.split("\n")) {
            const tab = line.indexOf("\t");
            if (tab <= 0)
                continue;

            const id = parseInt(line.slice(0, tab));
            if (!isFinite(id))
                continue;

            const safe = sanitisePreview(line.slice(tab + 1));
            parsed.push({
                id: id,
                kind: safe.kind,
                preview: safe.preview
            });
        }

        return parsed;
    }

    function refresh(): void {
        if (runtime.cliphist.length === 0 || queryProcess.running)
            return;

        queryProcess.exec([runtime.cliphist, "list"]);
    }

    function show(): void {
        closeTimer.stop();
        closing = false;
        search.text = "";
        selectedIndex = 0;
        open = true;
        refresh();
        search.forceActiveFocus();
    }

    function hide(): void {
        open = false;

        if (motion.fast === 0)
            closing = false;
        else {
            closing = true;
            closeTimer.restart();
        }
    }

    function toggle(): void {
        if (open)
            hide();
        else
            show();
    }

    function activateSelected(): void {
        if (filteredEntries.length === 0 || runtime.clipboardCopy.length === 0)
            return;

        const safeIndex = Math.max(0, Math.min(selectedIndex, filteredEntries.length - 1));
        const entry = filteredEntries[safeIndex];

        copyProcess.exec([runtime.clipboardCopy, String(entry.id)]);
        hide();
    }

    Rectangle {
        anchors.fill: parent
        color: theme.scrim
        opacity: panel.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: motion.fast
                easing.type: panel.open ? motion.enterType : motion.exitType
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: panel.hide()
        }
    }

    SquircleSurface {
        id: card

        width: Math.min(panel.width - 80, 820)
        height: Math.min(panel.height - 120, 680)
        anchors.centerIn: parent

        exponent: theme.squircleExponent
        cornerRadius: theme.radiusPanel
        fillColor: theme.panelFill
        borderColor: theme.panelBorder
        borderWidth: theme.borderThin

        scale: panel.open ? 1 : theme.panelClosedScale
        opacity: panel.open ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: motion.normal
                easing.type: motion.enterType
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: motion.fast
            }
        }

        Item {
            anchors.fill: parent
            anchors.margins: theme.spacing5

            Column {
                id: header
                width: parent.width
                spacing: theme.spacing2

                Text {
                    text: entries.length + (entries.length === 1 ? " item" : " items")
                    color: theme.accent
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(12)
                    font.weight: Font.Medium
                }

                Text {
                    text: "Clipboard"
                    color: theme.textStrong
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontPanelTitle
                    font.weight: Font.DemiBold
                }

                SquircleSurface {
                    width: parent.width
                    height: 50
                    exponent: theme.squircleExponent
                    cornerRadius: theme.radiusMedium
                    fillColor: theme.background
                    borderColor: search.activeFocus ? theme.accent : theme.outline
                    borderWidth: search.activeFocus ? theme.borderFocus : theme.borderThin

                    TextInput {
                        id: search

                        anchors {
                            fill: parent
                            leftMargin: theme.spacing4
                            rightMargin: theme.spacing4
                        }

                        verticalAlignment: TextInput.AlignVCenter
                        color: theme.textStrong
                        selectionColor: theme.accent
                        selectedTextColor: theme.background
                        font.family: runtime.fontMono
                        font.pixelSize: theme.fontSize(14)
                        clip: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Search clipboard…"
                            visible: search.text.length === 0
                            color: theme.textMuted
                            opacity: 0.55
                            font: search.font
                        }

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                panel.hide();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down) {
                                panel.selectedIndex = Math.min(panel.filteredEntries.length - 1, panel.selectedIndex + 1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                panel.selectedIndex = Math.max(0, panel.selectedIndex - 1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                panel.activateSelected();
                                event.accepted = true;
                            }
                        }
                    }
                }
            }

            ListView {
                id: list

                anchors {
                    top: header.bottom
                    right: parent.right
                    bottom: footer.top
                    left: parent.left
                    topMargin: theme.spacing4
                    bottomMargin: theme.spacing4
                }

                model: panel.filteredEntries
                spacing: theme.spacing2
                clip: true
                currentIndex: panel.selectedIndex
                boundsBehavior: Flickable.StopAtBounds

                delegate: SquircleSurface {
                    id: item

                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    height: 62
                    exponent: theme.squircleExponent
                    cornerRadius: theme.radiusMedium
                    fillColor: index === panel.selectedIndex ? theme.focusFill : theme.background
                    borderColor: index === panel.selectedIndex ? theme.accent : theme.outline
                    borderWidth: index === panel.selectedIndex ? theme.borderFocus : theme.borderThin

                    MouseArea {
                        anchors.fill: parent
                        onClicked: panel.selectedIndex = item.index
                        onDoubleClicked: {
                            panel.selectedIndex = item.index;
                            panel.activateSelected();
                        }
                    }

                    Row {
                        anchors {
                            fill: parent
                            margins: theme.spacing3
                        }
                        spacing: theme.spacing3

                        Text {
                            width: 56
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.kind
                            color: modelData.kind === "BINARY" ? theme.warning : theme.accent
                            font.family: runtime.fontMono
                            font.pixelSize: theme.fontSize(9)
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.8
                        }

                        Text {
                            width: parent.width - 56 - parent.spacing
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.preview
                            color: theme.text
                            font.family: runtime.fontMono
                            font.pixelSize: theme.fontSize(12)
                            elide: Text.ElideRight
                        }
                    }
                }

                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            }

            Text {
                anchors.centerIn: list
                visible: !queryProcess.running && panel.filteredEntries.length === 0
                text: search.text.length > 0 ? "NO MATCHES" : "CLIPBOARD HISTORY IS EMPTY"
                color: theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(11)
                font.letterSpacing: 1.1
            }

            Text {
                anchors.centerIn: list
                visible: queryProcess.running
                text: "Loading history…"
                color: theme.accent
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(11)
                font.letterSpacing: 1.1
            }

            Row {
                id: footer
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                }
                spacing: theme.spacing4

                Text {
                    text: "↑↓  NAVIGATE"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(9)
                    font.letterSpacing: 1
                }

                Text {
                    text: "ENTER  COPY"
                    color: theme.accent
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(9)
                    font.letterSpacing: 1
                }

                Text {
                    text: "ESC  CLOSE"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(9)
                    font.letterSpacing: 1
                }
            }
        }
    }
}

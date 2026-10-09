pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: panel

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

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
        interval: panel.motion.fast
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
        color: panel.theme.scrim
        opacity: panel.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: panel.motion.fast
                easing.type: panel.open ? panel.motion.enterType : panel.motion.exitType
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: panel.hide()
        }
    }

    ShellSurface {
        id: card

        width: Math.min(panel.width - 80, 820)
        height: Math.min(panel.height - 120, 680)
        anchors.centerIn: parent

        theme: panel.theme
        motion: panel.motion
        surfaceLayer: ShellSurface.Pane
        cornerRadius: theme.radiusPanel

        scale: panel.open ? 1 : theme.panelClosedScale
        opacity: panel.open ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: panel.motion.normal
                easing.type: panel.motion.enterType
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: panel.motion.fast
            }
        }

        Item {
            anchors.fill: parent
            anchors.margins: panel.theme.spacing5

            Column {
                id: header
                width: parent.width
                spacing: panel.theme.spacing2

                Text {
                    text: panel.entries.length + (panel.entries.length === 1 ? " item" : " items")
                    color: panel.theme.accent
                    font.family: panel.runtime.fontMono
                    font.pixelSize: panel.theme.fontSize(12)
                    font.weight: Font.Medium
                }

                Text {
                    text: "Clipboard"
                    color: panel.theme.textStrong
                    font.family: panel.runtime.fontMono
                    font.pixelSize: panel.theme.fontPanelTitle
                    font.weight: Font.DemiBold
                }

                SquircleSurface {
                    width: parent.width
                    height: 50
                    exponent: panel.theme.squircleExponent
                    cornerRadius: panel.theme.radiusMedium
                    fillColor: panel.theme.background
                    borderColor: search.activeFocus ? panel.theme.accent : panel.theme.outline
                    borderWidth: search.activeFocus ? panel.theme.borderFocus : panel.theme.borderThin

                    TextInput {
                        id: search

                        anchors {
                            fill: parent
                            leftMargin: panel.theme.spacing4
                            rightMargin: panel.theme.spacing4
                        }

                        verticalAlignment: TextInput.AlignVCenter
                        color: panel.theme.textStrong
                        selectionColor: panel.theme.accent
                        selectedTextColor: panel.theme.background
                        font.family: panel.runtime.fontMono
                        font.pixelSize: panel.theme.fontSize(14)
                        clip: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Search clipboard…"
                            visible: search.text.length === 0
                            color: panel.theme.textMuted
                            opacity: 0.55
                            font: search.font
                        }

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Tab) {
                                list.forceActiveFocus();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
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
                    topMargin: panel.theme.spacing4
                    bottomMargin: panel.theme.spacing4
                }

                model: panel.filteredEntries
                spacing: panel.theme.spacing2
                clip: true
                currentIndex: panel.selectedIndex
                boundsBehavior: Flickable.StopAtBounds

                Keys.priority: Keys.BeforeItem
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Tab || event.key === Qt.Key_I || event.key === Qt.Key_Slash) {
                        search.forceActiveFocus();
                    } else if (event.key === Qt.Key_Escape) {
                        panel.hide();
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                        panel.selectedIndex = Math.min(panel.filteredEntries.length - 1, panel.selectedIndex + 1);
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                        panel.selectedIndex = Math.max(0, panel.selectedIndex - 1);
                    } else if (event.key === Qt.Key_U || event.key === Qt.Key_D) {
                        const rowHeight = list.currentItem ? list.currentItem.height + list.spacing : 62;
                        const rows = Math.max(1, Math.floor(list.height / Math.max(1, rowHeight) / 2));
                        panel.selectedIndex = Math.max(0, Math.min(panel.filteredEntries.length - 1, panel.selectedIndex + (event.key === Qt.Key_D ? rows : -rows)));
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        panel.activateSelected();
                    } else {
                        return;
                    }
                    event.accepted = true;
                }

                delegate: SquircleSurface {
                    id: item

                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    height: 62
                    exponent: panel.theme.squircleExponent
                    cornerRadius: panel.theme.radiusMedium
                    fillColor: index === panel.selectedIndex ? panel.theme.focusFill : panel.theme.background
                    borderColor: index === panel.selectedIndex ? panel.theme.accent : panel.theme.outline
                    borderWidth: index === panel.selectedIndex ? panel.theme.borderFocus : panel.theme.borderThin

                    StateLayer {
                        theme: panel.theme
                        motion: panel.motion
                        selected: item.index === panel.selectedIndex
                        cornerRadius: panel.theme.radiusMedium
                        onActivated: panel.selectedIndex = item.index
                        onDoubleClicked: {
                            panel.selectedIndex = item.index;
                            panel.activateSelected();
                        }
                    }

                    Row {
                        anchors {
                            fill: parent
                            margins: panel.theme.spacing3
                        }
                        spacing: panel.theme.spacing3

                        Text {
                            width: 56
                            anchors.verticalCenter: parent.verticalCenter
                            text: item.modelData.kind
                            color: item.modelData.kind === "BINARY" ? panel.theme.warning : panel.theme.accent
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(9)
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.8
                        }

                        Text {
                            width: parent.width - 56 - parent.spacing
                            anchors.verticalCenter: parent.verticalCenter
                            text: item.modelData.preview
                            color: panel.theme.text
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(12)
                            elide: Text.ElideRight
                        }
                    }
                }

                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            }

            Text {
                anchors.centerIn: list
                visible: !panel.queryProcess.running && panel.filteredEntries.length === 0
                text: search.text.length > 0 ? "NO MATCHES" : "CLIPBOARD HISTORY IS EMPTY"
                color: panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(11)
                font.letterSpacing: 1.1
            }

            Text {
                anchors.centerIn: list
                visible: panel.queryProcess.running
                text: "Loading history…"
                color: panel.theme.accent
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(11)
                font.letterSpacing: 1.1
            }

            Row {
                id: footer
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                }
                spacing: panel.theme.spacing4

                Text {
                    text: search.activeFocus ? "TAB  NAVIGATE" : "J/K  MOVE   U/D  HALF PAGE"
                    color: panel.theme.textMuted
                    font.family: panel.runtime.fontMono
                    font.pixelSize: panel.theme.fontSize(9)
                    font.letterSpacing: 1
                }

                Text {
                    text: "ENTER  COPY"
                    color: panel.theme.accent
                    font.family: panel.runtime.fontMono
                    font.pixelSize: panel.theme.fontSize(9)
                    font.letterSpacing: 1
                }

                Text {
                    text: "ESC  CLOSE"
                    color: panel.theme.textMuted
                    font.family: panel.runtime.fontMono
                    font.pixelSize: panel.theme.fontSize(9)
                    font.letterSpacing: 1
                }
            }
        }
    }
}

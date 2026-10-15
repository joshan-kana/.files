pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: panel
    // Pre-constructed content hosted by the single permanent modal layer.
    property var screen: null

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property bool open: false
    property bool closing: false
    property var entries: []
    property int selectedIndex: 0
    property bool hideAfterCopy: false
    property string copyFeedback: ""
    property string previewText: ""
    property int previewTextEntryId: -1
    // cliphist list already supplies selected text: render that in the same
    // frame as navigation, then replace it with the full decoded entry.
    readonly property string selectedText: currentEntry && currentEntry.kind === "TEXT" ? (previewTextEntryId === currentEntry.id ? previewText : currentEntry.preview) : ""
    property string previewImagePath: ""
    property int previewJobId: -1
    property string previewJobKind: ""
    readonly property var currentEntry: filteredEntries.length > 0 ? filteredEntries[Math.max(0, Math.min(selectedIndex, filteredEntries.length - 1))] : null
    signal copyCompleted(bool success)

    readonly property var filteredEntries: {
        const query = search.text.trim().toLowerCase();
        const source = entries || [];

        if (query.length === 0)
            return source.slice(0, 100);

        return source.filter(entry => entry.preview.toLowerCase().includes(query) || entry.kind.toLowerCase().includes(query)).slice(0, 100);
    }

    visible: open || closing

    anchors.fill: parent

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

    property StdioCollector previewOutput: StdioCollector {}
    property Process previewProcess: Process {
        stdout: panel.previewOutput
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && panel.currentEntry && panel.open && panel.currentEntry.id === panel.previewJobId && (panel.previewJobKind === "text" || panel.currentEntry.kind === "IMAGE")) {
                if (panel.previewJobKind === "text") {
                    panel.previewText = panel.previewOutput.text.slice(0, 8192);
                    panel.previewTextEntryId = panel.previewJobId;
                } else
                    panel.previewImagePath = panel.previewOutput.text.trim();
            }
            if (panel.currentEntry && panel.open && (panel.currentEntry.id !== panel.previewJobId || (panel.currentEntry.kind === "IMAGE" && panel.previewJobKind !== "image")))
                previewTimer.restart();
            if (!panel.open && !panel.closing)
                panel.clearPreviewFiles();
        }
    }

    Timer {
        id: previewTimer
        // Coalesce rapid navigation within one event loop, not 100 ms.
        interval: 0
        onTriggered: panel.loadPreview()
    }

    onCurrentEntryChanged: {
        previewTextEntryId = -1;
        previewText = "";
        previewImagePath = "";
        if (open)
            previewTimer.restart();
    }

    function loadPreview(): void {
        if (!open || !currentEntry || runtime.clipboardPreview.length === 0 || previewProcess.running)
            return;
        if (currentEntry.kind !== "TEXT" && currentEntry.kind !== "IMAGE")
            return;
        previewJobId = currentEntry.id;
        previewJobKind = currentEntry.kind === "TEXT" ? "text" : "image";
        if (previewJobKind === "text")
            previewProcess.exec([runtime.cliphist, "decode", String(previewJobId)]);
        else
            previewProcess.exec([runtime.clipboardPreview, "image", String(previewJobId)]);
    }

    function clearPreviewFiles(): void {
        previewImagePath = "";
        previewTextEntryId = -1;
        previewText = "";
        if (runtime.clipboardPreview.length > 0)
            Quickshell.execDetached([runtime.clipboardPreview, "clear"]);
    }

    property Process copyProcess: Process {
        stderr: panel.copyError
        onExited: (exitCode, exitStatus) => {
            const success = exitCode === 0;
            panel.copyFeedback = success ? "COPIED" : "COPY FAILED";
            panel.copyCompleted(success);
            if (success && panel.hideAfterCopy)
                panel.hide();
            panel.hideAfterCopy = false;
        }
    }

    Timer {
        id: closeTimer
        interval: panel.motion.normal + (panel.motion.enabled ? 24 : 0)
        onTriggered: {
            panel.closing = false;
            if (!panel.open && !panel.previewProcess.running)
                panel.clearPreviewFiles();
        }
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

        if (/^\[\[ binary data .* (png|jpeg|jpg|webp|gif|bmp) \d+x\d+ \]\]$/i.test(compact))
            return {
                kind: "IMAGE",
                preview: compact.slice(3, -3)
            };

        if (suspicious >= 3 || suspicious / sample.length > 0.08 || compact.startsWith("[[ binary data"))
            return {
                kind: "BINARY",
                preview: "[binary clipboard item]"
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
        open = true;
        closing = false;
        search.text = "";
        copyFeedback = "";
        selectedIndex = 0;
        refresh();
        previewTimer.restart();
        search.forceActiveFocus();
    }

    function hide(): void {
        if (!open)
            return;

        // Preserve the Wayland surface until the longer spatial exit finishes.
        closing = motion.enabled;
        open = false;

        if (closing)
            closeTimer.restart();
        else if (!previewProcess.running)
            clearPreviewFiles();
    }

    function toggle(): void {
        if (open)
            hide();
        else
            show();
    }

    function copyEntry(entryId: int, closeOnSuccess: bool): bool {
        if (runtime.clipboardCopy.length === 0 || copyProcess.running)
            return false;
        hideAfterCopy = closeOnSuccess;
        copyFeedback = "COPYING";
        copyProcess.exec([runtime.clipboardCopy, String(entryId)]);
        return true;
    }

    function activateSelected(): void {
        if (filteredEntries.length === 0)
            return;
        const safeIndex = Math.max(0, Math.min(selectedIndex, filteredEntries.length - 1));
        copyEntry(filteredEntries[safeIndex].id, true);
    }

    Rectangle {
        anchors.fill: parent
        color: panel.theme.scrim
        opacity: 0 // Background dimming is compositor-owned in this benchmark.

        Behavior on opacity {
            NumberAnimation {
                duration: panel.motion.fast
                easing.type: panel.open ? panel.motion.enterType : panel.motion.exitType
                easing.bezierCurve: panel.open ? panel.motion.enterCurve : panel.motion.exitCurve
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: panel.hide()
        }
    }

    ShellSurface {
        id: card

        width: Math.min(panel.width - 72, 1020)
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
                easing.type: panel.open ? panel.motion.enterType : panel.motion.exitType
                easing.bezierCurve: panel.open ? panel.motion.enterCurve : panel.motion.exitCurve
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: panel.motion.fast
                easing.type: panel.motion.effectsType
                easing.bezierCurve: panel.motion.effectsCurve
            }
        }

        Item {
            anchors.fill: parent
            anchors.margins: panel.theme.spacing5

            Column {
                id: header
                width: parent.width
                spacing: panel.theme.spacing2

                DetailHero {
                    width: parent.width
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    glyph: "▣"
                    eyebrow: "History / Clipboard"
                    title: "Clipboard"
                    detail: panel.entries.length + (panel.entries.length === 1 ? " item" : " items") + " · Search and paste"
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
                    right: previewPane.visible ? previewPane.left : parent.right
                    bottom: footer.top
                    left: parent.left
                    rightMargin: previewPane.visible ? panel.theme.spacing3 : 0
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
                            width: 64
                            anchors.verticalCenter: parent.verticalCenter
                            text: item.modelData.kind
                            color: item.modelData.kind !== "TEXT" ? panel.theme.warning : panel.theme.accent
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(9)
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.8
                        }

                        Text {
                            width: parent.width - 64 - parent.spacing
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

            ShellSurface {
                id: previewPane
                visible: card.width >= 820
                anchors {
                    top: list.top
                    right: parent.right
                    bottom: list.bottom
                }
                width: 340
                theme: panel.theme
                motion: panel.motion
                surfaceLayer: ShellSurface.Group
                cornerRadius: panel.theme.radiusMedium
                clip: true

                Column {
                    anchors {
                        fill: parent
                        margins: panel.theme.spacing4
                    }
                    spacing: panel.theme.spacing3

                    Row {
                        width: parent.width
                        spacing: panel.theme.spacing2
                        Text {
                            text: "◈"
                            color: panel.theme.accent
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(19)
                        }
                        Column {
                            spacing: panel.theme.spacing1
                            ShellText {
                                text: "SELECTED ITEM"
                                runtime: panel.runtime
                                theme: panel.theme
                                color: panel.theme.textMuted
                                font.pixelSize: panel.theme.fontSize(10)
                            }
                            ShellText {
                                text: panel.currentEntry ? panel.currentEntry.kind + " · #" + panel.currentEntry.id : "EMPTY"
                                runtime: panel.runtime
                                theme: panel.theme
                                color: panel.theme.textStrong
                                font.pixelSize: panel.theme.fontSize(12)
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    ShellSurface {
                        width: parent.width
                        height: Math.max(90, previewPane.height - 178)
                        theme: panel.theme
                        motion: panel.motion
                        surfaceLayer: ShellSurface.Control
                        cornerRadius: panel.theme.radiusMedium
                        clip: true

                        Flickable {
                            id: textPreview
                            anchors {
                                fill: parent
                                margins: panel.theme.spacing3
                            }
                            visible: !!panel.currentEntry && panel.currentEntry.kind === "TEXT"
                            contentHeight: previewBody.implicitHeight
                            contentWidth: width
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Text {
                                id: previewBody
                                width: textPreview.width
                                text: panel.selectedText
                                wrapMode: Text.WrapAnywhere
                                color: panel.theme.textStrong
                                font.family: panel.runtime.fontMono
                                font.pixelSize: panel.theme.fontSize(12)
                                lineHeight: 1.4
                                textFormat: Text.PlainText
                            }
                        }

                        Image {
                            anchors {
                                fill: parent
                                margins: panel.theme.spacing2
                            }
                            visible: !!panel.currentEntry && panel.currentEntry.kind === "IMAGE" && panel.previewImagePath.length > 0
                            source: panel.previewImagePath.length > 0 ? "file://" + panel.previewImagePath : ""
                            asynchronous: true
                            cache: false
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        Column {
                            visible: !!panel.currentEntry && panel.currentEntry.kind !== "TEXT" && panel.previewImagePath.length === 0
                            anchors.centerIn: parent
                            width: parent.width - panel.theme.spacing5 * 2
                            spacing: panel.theme.spacing4
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "▧"
                                color: panel.theme.accent
                                font.family: panel.runtime.fontMono
                                font.pixelSize: panel.theme.fontSize(44)
                            }
                            ShellText {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                runtime: panel.runtime
                                theme: panel.theme
                                text: panel.currentEntry && panel.currentEntry.kind === "IMAGE" ? "Rendering thumbnail…" : "Binary item · Preview unavailable"
                                color: panel.theme.textMuted
                                font.pixelSize: panel.theme.fontSize(11)
                            }
                        }
                    }

                    ShellText {
                        width: parent.width
                        runtime: panel.runtime
                        theme: panel.theme
                        text: panel.copyFeedback.length > 0 ? panel.copyFeedback : "ENTER COPY · J/K NAVIGATE"
                        color: panel.copyFeedback === "COPY FAILED" ? panel.theme.warning : panel.theme.textMuted
                        font.pixelSize: panel.theme.fontSize(10)
                        elide: Text.ElideRight
                    }
                }
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

            KeyHintStrip {
                id: footer
                width: parent.width
                anchors.bottom: parent.bottom
                runtime: panel.runtime
                theme: panel.theme
                hints: [
                    {
                        shortcut: search.activeFocus ? "TAB" : "J/K",
                        label: search.activeFocus ? "Navigate" : "Move"
                    },
                    {
                        shortcut: "U/D",
                        label: "Half page",
                        visible: !search.activeFocus
                    },
                    {
                        shortcut: "ENTER",
                        label: "Copy"
                    },
                    {
                        shortcut: "ESC",
                        label: "Close"
                    }
                ]
            }
        }
    }
}

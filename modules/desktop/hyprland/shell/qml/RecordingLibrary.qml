pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "DesktopIcons.js" as DesktopIcons
import Quickshell
import Quickshell.Io

Item {
    id: library

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    signal keyboardRequested

    property bool open: false
    property var entries: []
    property string listingSignature: ""
    property int selectedIndex: 0
    property string previewName: ""
    property string previewPath: ""
    property bool ocrVisible: false
    property string ocrText: ""
    property var ocrWords: []
    property int ocrImageWidth: 1
    property int ocrImageHeight: 1
    property string ocrRequestName: ""
    property string pendingTextName: ""
    property int wordSelectionStart: -1
    property int wordSelectionEnd: -1
    readonly property bool wordSelectionAvailable: wordSelectionStart >= 0 && wordSelectionEnd >= 0
    property string deletePending: ""
    property string statusText: ""
    property bool statusError: false
    property bool editorRequestRunning: false
    readonly property var selectedEntry: entries.length > 0 ? entries[Math.max(0, Math.min(selectedIndex, entries.length - 1))] : null
    readonly property bool isBusy: listProcess.running || actionProcess.running || ocrProcess.running

    implicitHeight: 128 + statusBanner.implicitHeight + theme.spacing4 * 3 + 392 + footer.implicitHeight
    visible: open

    function formatBytes(value: real): string {
        return value >= 1048576 ? (value / 1048576).toFixed(1) + " MiB" : Math.max(0, Math.round(value / 1024)) + " KiB";
    }
    function timeLabel(value: real): string {
        if (!Number.isFinite(value) || value <= 0)
            return "DURATION UNKNOWN";
        const seconds = Math.floor(value);
        return Math.floor(seconds / 3600) > 0 ? Math.floor(seconds / 3600) + ":" + String(Math.floor(seconds / 60) % 60).padStart(2, "0") + ":" + String(seconds % 60).padStart(2, "0") : Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0");
    }
    function refresh(): void {
        if (!open || runtime.recordingLibrary.length === 0 || listProcess.running)
            return;
        listProcess.exec([runtime.recordingLibrary, "list"]);
    }
    function openView(): void {
        open = true;
        selectedIndex = 0;
        entries = [];
        listingSignature = "";
        deletePending = "";
        statusText = "";
        editorRequestRunning = false;
        editorRequestTimeout.stop();
        closeText();
        refresh();
        keyboardRequested();
    }
    function queueText(name: string): void {
        if (!/^(?:Screenshot-[0-9]{8}-[0-9]{6}-[0-9]+\.png|Recording-[0-9]{8}-[0-9]{6}-[0-9]+\.mp4)$/.test(name))
            return;
        pendingTextName = name;
        if (open) {
            refresh();
            if (entries.some(entry => entry.name === name))
                Qt.callLater(openPendingText);
        }
    }

    function openPendingText(): void {
        if (!open || !pendingTextName || entries.length === 0)
            return;
        const name = pendingTextName;
        const index = entries.findIndex(entry => entry.name === name);
        if (index < 0) {
            // A refresh may still be replacing an older gallery snapshot.
            if (listProcess.running)
                return;
            pendingTextName = "";
            statusText = "CAPTURE NOT FOUND";
            statusError = true;
            return;
        }
        pendingTextName = "";
        choose(index);
        Qt.callLater(() => {
            if (open && selectedEntry && selectedEntry.name === name)
                showText();
        });
    }

    onEntriesChanged: if (pendingTextName)
        Qt.callLater(openPendingText)

    function closeView(): void {
        if (!open)
            return;
        open = false;
        editorRequestRunning = false;
        editorRequestTimeout.stop();
        deletePending = "";
        previewName = "";
        previewPath = "";
        closeText();
        if (!previewProcess.running)
            clearPreview();
        keyboardRequested();
    }
    function clearPreview(): void {
        previewPath = "";
        if (runtime.recordingLibrary.length > 0)
            Quickshell.execDetached([runtime.recordingLibrary, "clear-preview"]);
    }
    function parseListing(output: string): var {
        const result = [];
        for (const row of output.split("\n")) {
            const columns = row.split("\t");
            if (columns.length !== 4 || !/^(Recording-[0-9]{8}-[0-9]{6}-[0-9]+\.mp4|Screenshot-[0-9]{8}-[0-9]{6}-[0-9]+\.png)$/.test(columns[1]))
                continue;
            const size = Number(columns[2]);
            const modified = Number(columns[0]);
            const duration = Number(columns[3]);
            if (!Number.isFinite(size) || !Number.isFinite(modified) || !Number.isFinite(duration))
                continue;
            result.push({
                name: columns[1],
                isImage: columns[1].endsWith(".png"),
                size,
                modified,
                duration
            });
        }
        return result.slice(0, 100);
    }
    function choose(index: int): void {
        if (entries.length === 0)
            return;
        selectedIndex = Math.max(0, Math.min(entries.length - 1, index));
        deletePending = "";
        statusText = "";
        closeText();
    }
    function moveSelection(delta: int): void {
        choose(selectedIndex + delta);
    }
    function openSelected(): void {
        if (!selectedEntry || !open)
            return;
        if (deletePending === selectedEntry.name) {
            confirmDelete();
            return;
        }
        Quickshell.execDetached([runtime.recordingLibrary, "open", selectedEntry.name]);
        statusText = "OPEN REQUESTED · " + selectedEntry.name;
        statusError = false;
    }
    function editSelected(): void {
        if (!selectedEntry || !open || isBusy || runtime.recordingLibrary.length === 0)
            return;
        editorRequestRunning = true;
        editorRequestTimeout.restart();
        Quickshell.execDetached([runtime.recordingLibrary, "edit", selectedEntry.name]);
        statusText = "OPENING EDITOR · " + selectedEntry.name;
        statusError = false;
    }
    function copySelected(): void {
        if (!selectedEntry || !selectedEntry.isImage || isBusy)
            return;
        Quickshell.execDetached([runtime.recordingLibrary, "copy", selectedEntry.name]);
        statusText = "COPY REQUESTED · " + selectedEntry.name;
        statusError = false;
    }
    function closeText(): void {
        ocrVisible = false;
        wordSelectionStart = -1;
        wordSelectionEnd = -1;
        ocrText = "";
        ocrWords = [];
        ocrRequestName = "";
    }

    function parseWords(tsv: string): var {
        const words = [];
        for (const row of tsv.trim().split("\n").slice(1)) {
            const fields = row.split("\t");
            if (fields.length < 12 || fields[0] !== "5" || Number(fields[10]) < 0)
                continue;
            const [left, top, width, height] = fields.slice(6, 10).map(Number);
            const label = fields.slice(11).join("\t").trim();
            if (!label || ![left, top, width, height].every(Number.isFinite) || width <= 0 || height <= 0)
                continue;
            words.push({
                left,
                top,
                width,
                height,
                text: label,
                line: fields.slice(1, 5).join(":")
            });
        }
        return words;
    }

    function showText(): void {
        if (ocrVisible) {
            closeText();
            keyboardRequested();
            return;
        }
        if (!selectedEntry || isBusy || runtime.recordingLibrary.length === 0)
            return;
        statusText = selectedEntry.isImage ? "READING IMAGE TEXT…" : "READING VIDEO PREVIEW FRAME…";
        statusError = false;
        ocrRequestName = selectedEntry.name;
        ocrProcess.exec([runtime.recordingLibrary, "ocr", selectedEntry.name]);
    }

    function wordAt(x: real, y: real): int {
        if (ocrWords.length === 0 || previewImage.paintedWidth <= 0 || previewImage.paintedHeight <= 0)
            return -1;
        const px = x / Math.max(1, previewImage.paintedWidth) * ocrImageWidth;
        const py = y / Math.max(1, previewImage.paintedHeight) * ocrImageHeight;
        let closest = -1;
        let distance = Infinity;
        for (let i = 0; i < ocrWords.length; i++) {
            const word = ocrWords[i];
            const dx = Math.max(word.left - px, 0, px - word.left - word.width);
            const dy = Math.max(word.top - py, 0, py - word.top - word.height);
            const d = dx * dx + dy * dy;
            if (d < distance) {
                distance = d;
                closest = i;
            }
        }
        return distance <= (ocrImageWidth / Math.max(1, previewImage.paintedWidth) * 14) ** 2 ? closest : -1;
    }

    function selectWordAt(x: real, y: real, extend: bool): void {
        const index = wordAt(x, y);
        if (index < 0) {
            if (!extend) {
                wordSelectionStart = -1;
                wordSelectionEnd = -1;
            }
            return;
        }
        recognisedText.deselect();
        if (!extend || wordSelectionStart < 0)
            wordSelectionStart = index;
        wordSelectionEnd = index;
    }

    function moveWordSelection(direction: int, extend: bool): void {
        if (!ocrVisible || ocrWords.length === 0)
            return;
        const current = wordSelectionEnd >= 0 ? wordSelectionEnd : direction > 0 ? -1 : ocrWords.length;
        const next = Math.max(0, Math.min(ocrWords.length - 1, current + direction));
        recognisedText.deselect();
        if (!extend || wordSelectionStart < 0)
            wordSelectionStart = next;
        wordSelectionEnd = next;
    }

    function selectAllWords(): void {
        if (!ocrVisible || ocrWords.length === 0)
            return;
        recognisedText.deselect();
        wordSelectionStart = 0;
        wordSelectionEnd = ocrWords.length - 1;
    }

    function wordInSelection(index: int): bool {
        return wordSelectionAvailable && index >= Math.min(wordSelectionStart, wordSelectionEnd) && index <= Math.max(wordSelectionStart, wordSelectionEnd);
    }

    function highlightedText(): string {
        if (!wordSelectionAvailable)
            return "";
        const start = Math.min(wordSelectionStart, wordSelectionEnd);
        const end = Math.max(wordSelectionStart, wordSelectionEnd);
        let result = "";
        for (let i = start; i <= end; i++) {
            const word = ocrWords[i];
            if (!word)
                break;
            result += i === start ? "" : word.line === ocrWords[i - 1].line ? " " : "\n";
            result += word.text;
        }
        return result;
    }

    function copyHighlightedText(): void {
        if (wordSelectionAvailable) {
            wordCopyBuffer.selectAll();
            wordCopyBuffer.copy();
        } else if (recognisedText.selectedText.length > 0) {
            recognisedText.copy();
        } else {
            return;
        }
        statusText = "SELECTED TEXT COPIED";
        statusError = false;
    }

    function requestDelete(): void {
        if (!selectedEntry || isBusy)
            return;
        if (deletePending === selectedEntry.name) {
            confirmDelete();
            return;
        }
        deletePending = selectedEntry.name;
        statusText = "MOVE TO TRASH? · ENTER / CONFIRM DELETE";
        statusError = true;
    }
    function confirmDelete(): void {
        if (!selectedEntry || deletePending !== selectedEntry.name || actionProcess.running)
            return;
        actionProcess.exec([runtime.recordingLibrary, "trash", deletePending]);
    }
    function cancelDelete(): void {
        deletePending = "";
        statusText = "";
        statusError = false;
    }

    Timer {
        id: editorRequestTimeout
        interval: 900
        onTriggered: library.editorRequestRunning = false
    }

    property StdioCollector listOutput: StdioCollector {}
    property Process listProcess: Process {
        stdout: library.listOutput
        onExited: (exitCode, exitStatus) => {
            if (!library.open)
                return;
            if (exitCode === 0) {
                const nextEntries = library.parseListing(library.listOutput.text);
                const nextSignature = JSON.stringify(nextEntries);
                // Replacing an identical JS-array model destroys and recreates
                // its Qt delegate metadata without any visible result. This
                // was racing recorder state changes and keyboard navigation.
                if (nextSignature === library.listingSignature) {
                    if (library.pendingTextName)
                        Qt.callLater(library.openPendingText);
                    return;
                }
                const previous = library.selectedEntry ? library.selectedEntry.name : "";
                const same = nextEntries.findIndex(entry => entry.name === previous);
                const nextIndex = Math.max(0, Math.min(nextEntries.length - 1, same >= 0 ? same : library.selectedIndex));
                Qt.callLater(() => {
                    if (!library.open || nextSignature === library.listingSignature)
                        return;
                    library.listingSignature = nextSignature;
                    library.entries = nextEntries;
                    library.selectedIndex = nextIndex;
                });
            } else {
                library.statusError = true;
                library.statusText = "CAPTURES UNAVAILABLE";
            }
        }
    }
    property StdioCollector previewOutput: StdioCollector {}
    property Process previewProcess: Process {
        stdout: library.previewOutput
        onExited: (exitCode, exitStatus) => {
            if (library.open && library.selectedEntry && library.selectedEntry.name === library.previewName && exitCode === 0) {
                const lines = library.previewOutput.text.trim().split("\n");
                library.previewPath = lines[0] || "";
            }
            if (library.open && library.selectedEntry && library.selectedEntry.name !== library.previewName)
                previewTimer.restart();
            if (!library.open)
                library.clearPreview();
        }
    }
    property StdioCollector ocrOutput: StdioCollector {}
    property StdioCollector ocrError: StdioCollector {}
    property Process ocrProcess: Process {
        stdout: library.ocrOutput
        stderr: library.ocrError
        onExited: (exitCode, exitStatus) => {
            if (!library.open || !library.selectedEntry || library.selectedEntry.name !== library.ocrRequestName)
                return;
            if (exitCode !== 0) {
                library.statusError = true;
                library.statusText = library.ocrError.text.trim() || "TEXT RECOGNITION FAILED";
                return;
            }
            try {
                const result = JSON.parse(library.ocrOutput.text);
                const words = library.parseWords(result.tsv);
                if (!result.text.trim() || words.length === 0)
                    throw new Error("No readable text in this capture");
                library.ocrImageWidth = result.width;
                library.ocrImageHeight = result.height;
                library.ocrText = result.text;
                library.ocrWords = words;
                library.wordSelectionStart = -1;
                library.wordSelectionEnd = -1;
                library.ocrVisible = true;
                library.statusError = false;
                library.statusText = "SELECT TEXT IN THE PREVIEW OR RECOGNISED CONTENT";
                library.keyboardRequested();
            } catch (error) {
                library.statusError = true;
                library.statusText = "NO READABLE TEXT FOUND";
            }
        }
    }
    property Process actionProcess: Process {
        onExited: (exitCode, exitStatus) => {
            const deleted = library.deletePending;
            library.deletePending = "";
            library.statusError = exitCode !== 0;
            library.statusText = exitCode === 0 ? "MOVED TO TRASH · " + deleted : "COULD NOT MOVE CAPTURE TO TRASH";
            if (exitCode === 0)
                library.refresh();
        }
    }
    Timer {
        id: previewTimer
        interval: 0
        onTriggered: library.loadPreview()
    }
    onSelectedEntryChanged: {
        // A list refresh can replace the metadata object without changing the
        // selected clip. Keep its decoded preview until the actual file changes.
        if (selectedEntry && previewName === selectedEntry.name)
            return;
        previewPath = "";
        if (open && selectedEntry)
            previewTimer.restart();
    }
    function loadPreview(): void {
        if (!open || !selectedEntry || previewProcess.running)
            return;
        previewName = selectedEntry.name;
        previewProcess.exec([runtime.recordingLibrary, "preview", previewName]);
    }

    DetailHero {
        id: hero
        width: parent.width
        height: implicitHeight
        runtime: library.runtime
        theme: library.theme
        motion: library.motion
        glyph: DesktopIcons.glyphFor("captures")
        glyphFont: "Symbols Nerd Font"
        glyphColor: library.theme.roleColor("capture")
        eyebrow: "Capture / Local library"
        title: "Captures"
        detail: library.entries.length + (library.entries.length === 1 ? " saved image or video" : " saved images and videos")
    }

    PanelStatus {
        id: statusBanner
        anchors {
            top: hero.bottom
            left: parent.left
            right: parent.right
            topMargin: library.theme.spacing2
        }
        runtime: library.runtime
        theme: library.theme
        motion: library.motion
        message: library.statusText
        idleMessage: library.entries.length > 0 ? "Choose a capture to open or share" : "No saved captures"
        phase: library.statusError ? "error" : library.deletePending.length > 0 ? "warning" : library.isBusy || library.editorRequestRunning ? "busy" : "idle"
    }

    Row {
        id: panes
        anchors {
            top: statusBanner.bottom
            left: parent.left
            right: parent.right
            bottom: footer.top
            topMargin: library.theme.spacing3
            bottomMargin: library.theme.spacing3
        }
        spacing: library.theme.spacing3

        ShellSurface {
            id: listPane
            visible: !library.ocrVisible || panes.width >= 620
            width: previewPane.visible ? Math.max(290, parent.width * 0.52) : parent.width
            height: parent.height
            theme: library.theme
            motion: library.motion
            surfaceLayer: ShellSurface.Group
            cornerRadius: library.theme.radiusMedium
            clip: true
            ListView {
                id: fileList
                anchors {
                    fill: parent
                    margins: library.theme.spacing2
                }
                // Numeric model avoids transient file objects becoming
                // delegate metaobjects during recorder finalisation.
                model: library.entries.length
                currentIndex: library.selectedIndex
                spacing: library.theme.spacing2
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                onCurrentIndexChanged: {
                    if (currentIndex >= 0)
                        positionViewAtIndex(currentIndex, ListView.Contain);
                }
                delegate: ShellSurface {
                    id: recordRow
                    required property int index
                    readonly property var entry: library.entries[index] || null
                    width: ListView.view.width
                    height: 61
                    theme: library.theme
                    motion: library.motion
                    surfaceLayer: ShellSurface.Control
                    cornerRadius: library.theme.radiusMedium
                    selected: false
                    outlined: index === library.selectedIndex
                    fillColor: index === library.selectedIndex ? library.theme.blend(library.theme.controlBase, library.theme.roleColor("capture"), library.theme.dark ? 0.075 : 0.045) : library.theme.controlBase
                    borderColor: index === library.selectedIndex ? library.theme.roleColor("capture") : library.theme.subtleBorder
                    StateLayer {
                        theme: library.theme
                        motion: library.motion
                        selected: recordRow.index === library.selectedIndex
                        cornerRadius: library.theme.radiusMedium
                        onActivated: library.choose(recordRow.index)
                    }
                    Column {
                        anchors {
                            fill: parent
                            margins: library.theme.spacing2
                        }
                        spacing: library.theme.spacing1
                        MarqueeText {
                            width: parent.width
                            text: recordRow.entry ? recordRow.entry.name.replace(/^(Recording|Screenshot)-/, "") : ""
                            textFormat: Text.PlainText
                            color: library.theme.textStrong
                            font.family: library.runtime.fontSans
                            font.pixelSize: library.theme.fontSize(11)
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: library.formatBytes(recordRow.entry ? recordRow.entry.size : 0) + (recordRow.entry && recordRow.entry.isImage ? " · IMAGE" : " · VIDEO")
                            color: library.theme.textMuted
                            font.family: library.runtime.fontMono
                            font.pixelSize: library.theme.fontSize(9)
                        }
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: !library.listProcess.running && library.entries.length === 0
                text: "NO SAVED CAPTURES"
                color: library.theme.textMuted
                font.family: library.runtime.fontSans
                font.pixelSize: library.theme.fontSize(11)
            }
        }

        ShellSurface {
            id: previewPane
            visible: library.ocrVisible || panes.width >= 620
            width: Math.max(1, listPane.visible ? panes.width - listPane.width - panes.spacing : panes.width)
            height: parent.height
            theme: library.theme
            motion: library.motion
            surfaceLayer: ShellSurface.Group
            cornerRadius: library.theme.radiusMedium
            clip: true

            Column {
                anchors {
                    fill: parent
                    margins: library.theme.spacing3
                }
                spacing: library.theme.spacing3
                ShellSurface {
                    width: parent.width
                    height: library.ocrVisible ? 162 : 180
                    theme: library.theme
                    motion: library.motion
                    surfaceLayer: ShellSurface.Control
                    cornerRadius: library.theme.radiusMedium
                    clip: true
                    Image {
                        id: previewImage
                        anchors.fill: parent
                        source: library.previewPath.length > 0 ? "file://" + library.previewPath : ""
                        visible: library.previewPath.length > 0
                        asynchronous: true
                        cache: false
                        fillMode: Image.PreserveAspectFit
                    }
                    // Word rectangles use original pixel coordinates and are mapped
                    // through PreserveAspectFit, including the letterboxed margins.
                    Item {
                        id: textHighlights
                        visible: library.ocrVisible && previewImage.status === Image.Ready
                        x: previewImage.x + (previewImage.width - previewImage.paintedWidth) / 2
                        y: previewImage.y + (previewImage.height - previewImage.paintedHeight) / 2
                        width: previewImage.paintedWidth
                        height: previewImage.paintedHeight
                        clip: true
                        Repeater {
                            model: library.ocrWords
                            delegate: Rectangle {
                                id: wordHighlight
                                required property int index
                                required property var modelData
                                x: modelData.left / Math.max(1, library.ocrImageWidth) * textHighlights.width
                                y: modelData.top / Math.max(1, library.ocrImageHeight) * textHighlights.height
                                width: modelData.width / Math.max(1, library.ocrImageWidth) * textHighlights.width
                                height: modelData.height / Math.max(1, library.ocrImageHeight) * textHighlights.height
                                color: library.wordInSelection(index) ? Qt.rgba(library.theme.accent.r, library.theme.accent.g, library.theme.accent.b, 0.50) : Qt.rgba(library.theme.accent.r, library.theme.accent.g, library.theme.accent.b, 0.10)
                                border.width: library.wordInSelection(index) ? 1 : 0
                                border.color: library.theme.accent
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.IBeamCursor
                            onPressed: mouse => library.selectWordAt(mouse.x, mouse.y, false)
                            onPositionChanged: mouse => {
                                if (pressed)
                                    library.selectWordAt(mouse.x, mouse.y, true);
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: library.previewPath.length === 0
                        text: library.selectedEntry ? "󰕧" : "󰋼"
                        color: library.theme.roleColor("capture")
                        font.family: library.runtime.fontSans
                        font.pixelSize: library.theme.fontSize(38)
                    }
                }
                MarqueeText {
                    width: parent.width
                    text: library.selectedEntry ? (library.selectedEntry.isImage ? "IMAGE" : library.timeLabel(library.selectedEntry.duration)) + " · " + library.formatBytes(library.selectedEntry.size) : "SELECT A CAPTURE"
                    color: library.theme.textStrong
                    font.family: library.runtime.fontSans
                    font.pixelSize: library.theme.fontSize(11)
                    font.weight: Font.DemiBold
                }
                ShellSurface {
                    visible: library.ocrVisible
                    width: parent.width
                    height: Math.max(76, previewPane.height - 162 - 160)
                    theme: library.theme
                    motion: library.motion
                    surfaceLayer: ShellSurface.Control
                    cornerRadius: library.theme.radiusMedium
                    clip: true
                    Flickable {
                        id: ocrViewport
                        anchors {
                            fill: parent
                            margins: library.theme.spacing2
                        }
                        clip: true
                        contentWidth: Math.max(width, recognisedText.contentWidth)
                        contentHeight: Math.max(height, recognisedText.contentHeight)
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {}
                        ScrollBar.horizontal: ScrollBar {}
                        TextArea {
                            id: recognisedText
                            width: Math.max(ocrViewport.width, implicitWidth)
                            height: Math.max(ocrViewport.height, contentHeight)
                            text: library.ocrText
                            readOnly: true
                            selectByMouse: true
                            persistentSelection: true
                            onSelectedTextChanged: {
                                if (selectedText.length > 0) {
                                    library.wordSelectionStart = -1;
                                    library.wordSelectionEnd = -1;
                                }
                            }
                            wrapMode: TextEdit.NoWrap
                            textFormat: TextEdit.PlainText
                            color: library.theme.textStrong
                            selectionColor: library.theme.accent
                            selectedTextColor: library.theme.background
                            font.family: library.runtime.fontSans
                            font.pixelSize: library.theme.fontSize(12)
                            background: null
                            Keys.onEscapePressed: event => {
                                library.closeText();
                                library.keyboardRequested();
                                event.accepted = true;
                            }
                        }
                    }
                    TextEdit {
                        id: wordCopyBuffer
                        visible: false
                        text: library.highlightedText()
                    }
                }
                Row {
                    visible: library.ocrVisible
                    width: parent.width
                    height: visible ? 34 : 0
                    spacing: library.theme.spacing2
                    ShellAction {
                        width: (parent.width - parent.spacing) / 2
                        height: 34
                        runtime: library.runtime
                        theme: library.theme
                        motion: library.motion
                        compact: true
                        horizontalCompact: true
                        title: "Copy selection"
                        shortcut: library.runtime.shellHint("RecordingLibrary.copy")
                        enabled: recognisedText.selectedText.length > 0 || library.wordSelectionAvailable
                        onActivated: library.copyHighlightedText()
                    }
                    ShellAction {
                        width: (parent.width - parent.spacing) / 2
                        height: 34
                        runtime: library.runtime
                        theme: library.theme
                        motion: library.motion
                        compact: true
                        horizontalCompact: true
                        title: "Done"
                        shortcut: library.runtime.shellHint("RecordingLibrary.ocr")
                        onActivated: {
                            library.closeText();
                            library.keyboardRequested();
                        }
                    }
                }
                Grid {
                    visible: !library.ocrVisible
                    width: parent.width
                    columns: 2
                    spacing: library.theme.spacing2
                    ShellAction {
                        width: (previewPane.width - library.theme.spacing3 * 2 - library.theme.spacing2) / 2
                        height: 34
                        runtime: library.runtime
                        theme: library.theme
                        motion: library.motion
                        compact: true
                        horizontalCompact: true
                        title: "Open"
                        shortcut: library.runtime.shellHint("RecordingLibrary.open")
                        enabled: !!library.selectedEntry && !library.isBusy
                        onActivated: library.openSelected()
                    }
                    ShellAction {
                        width: (previewPane.width - library.theme.spacing3 * 2 - library.theme.spacing2) / 2
                        height: 34
                        runtime: library.runtime
                        theme: library.theme
                        motion: library.motion
                        compact: true
                        horizontalCompact: true
                        title: library.selectedEntry && library.selectedEntry.isImage ? "Markup" : "Trim"
                        shortcut: library.runtime.shellHint("RecordingLibrary.edit")
                        enabled: !!library.selectedEntry && !library.isBusy
                        onActivated: library.editSelected()
                    }
                    ShellAction {
                        width: (previewPane.width - library.theme.spacing3 * 2 - library.theme.spacing2) / 2
                        height: 34
                        runtime: library.runtime
                        theme: library.theme
                        motion: library.motion
                        compact: true
                        horizontalCompact: true
                        title: "Copy"
                        shortcut: library.runtime.shellHint("RecordingLibrary.copy")
                        enabled: !!library.selectedEntry && library.selectedEntry.isImage && !library.isBusy
                        onActivated: library.copySelected()
                    }
                    ShellAction {
                        width: (previewPane.width - library.theme.spacing3 * 2 - library.theme.spacing2) / 2
                        height: 34
                        runtime: library.runtime
                        theme: library.theme
                        motion: library.motion
                        compact: true
                        horizontalCompact: true
                        title: library.selectedEntry && library.deletePending === library.selectedEntry.name ? "Confirm" : "Trash"
                        shortcut: library.runtime.shellHint("RecordingLibrary.delete")
                        enabled: !!library.selectedEntry && !library.isBusy
                        active: !!library.selectedEntry && library.deletePending === library.selectedEntry.name
                        onActivated: library.requestDelete()
                    }
                    ShellAction {
                        width: (previewPane.width - library.theme.spacing3 * 2 - library.theme.spacing2) / 2
                        height: 34
                        runtime: library.runtime
                        theme: library.theme
                        motion: library.motion
                        compact: true
                        horizontalCompact: true
                        title: library.selectedEntry && library.selectedEntry.isImage ? "Select text" : "Frame text"
                        shortcut: library.runtime.shellHint("RecordingLibrary.ocr")
                        enabled: !!library.selectedEntry && !library.isBusy
                        onActivated: library.showText()
                    }
                }
            }
        }
    }

    Column {
        id: footer
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        spacing: library.theme.spacing2
        ShellAction {
            visible: panes.width < 620 && !!library.selectedEntry
            width: parent.width
            height: visible ? 34 : 0
            runtime: library.runtime
            theme: library.theme
            motion: library.motion
            compact: true
            horizontalCompact: true
            title: library.ocrVisible ? "Back to captures" : library.selectedEntry && library.selectedEntry.isImage ? "Select image text" : "Select frame text"
            shortcut: library.runtime.shellHint("RecordingLibrary.ocr")
            enabled: !!library.selectedEntry && !library.isBusy
            onActivated: library.showText()
        }
        KeyHintStrip {
            width: parent.width
            runtime: library.runtime
            theme: library.theme
            hints: library.ocrVisible ? [
                {
                    shortcut: library.runtime.shellHint("RecordingLibrary.word"),
                    label: "Word"
                },
                {
                    shortcut: library.runtime.shellHint("RecordingLibrary.extend"),
                    label: "Extend"
                }
            ] : [
                {
                    shortcut: library.runtime.shellHint("RecordingLibrary.choose"),
                    label: "Choose"
                },
                {
                    shortcut: library.runtime.shellHint("RecordingLibrary.page"),
                    label: "Page"
                },
                {
                    shortcut: library.runtime.shellHint("RecordingLibrary.refresh"),
                    label: "Refresh"
                }
            ]
        }
    }
}

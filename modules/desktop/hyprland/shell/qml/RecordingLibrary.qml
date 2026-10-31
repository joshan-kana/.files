pragma ComponentBehavior: Bound
import QtQuick
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
    property string deletePending: ""
    property string statusText: ""
    property bool statusError: false
    readonly property var selectedEntry: entries.length > 0 ? entries[Math.max(0, Math.min(selectedIndex, entries.length - 1))] : null
    readonly property bool isBusy: listProcess.running || actionProcess.running

    implicitHeight: 128 + theme.spacing4 * 2 + 392 + footer.implicitHeight
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
        refresh();
        keyboardRequested();
    }
    function closeView(): void {
        if (!open)
            return;
        open = false;
        deletePending = "";
        previewName = "";
        previewPath = "";
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
        Quickshell.execDetached([runtime.recordingLibrary, "edit", selectedEntry.name]);
        statusText = "EDITOR REQUESTED · " + selectedEntry.name;
        statusError = false;
    }
    function copySelected(): void {
        if (!selectedEntry || !selectedEntry.isImage || isBusy)
            return;
        Quickshell.execDetached([runtime.recordingLibrary, "copy", selectedEntry.name]);
        statusText = "COPY REQUESTED · " + selectedEntry.name;
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
                if (nextSignature === library.listingSignature)
                    return;
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
        glyph: "󰕧"
        glyphFont: "Symbols Nerd Font"
        glyphColor: library.theme.roleColor("capture")
        eyebrow: "Capture / Local library"
        title: "Captures"
        detail: library.entries.length + (library.entries.length === 1 ? " saved image or video" : " saved images and videos")
    }

    Row {
        id: panes
        anchors {
            top: hero.bottom
            left: parent.left
            right: parent.right
            bottom: footer.top
            topMargin: library.theme.spacing3
            bottomMargin: library.theme.spacing3
        }
        spacing: library.theme.spacing3

        ShellSurface {
            id: listPane
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
                            font.family: library.runtime.fontMono
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
                font.family: library.runtime.fontMono
                font.pixelSize: library.theme.fontSize(11)
            }
        }

        ShellSurface {
            id: previewPane
            visible: panes.width >= 620
            width: Math.max(1, panes.width - listPane.width - panes.spacing)
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
                    height: 211
                    theme: library.theme
                    motion: library.motion
                    surfaceLayer: ShellSurface.Control
                    cornerRadius: library.theme.radiusMedium
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: library.previewPath.length > 0 ? "file://" + library.previewPath : ""
                        visible: library.previewPath.length > 0
                        asynchronous: true
                        cache: false
                        fillMode: Image.PreserveAspectFit
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: library.previewPath.length === 0
                        text: library.selectedEntry ? "󰕧" : "󰋼"
                        color: library.theme.roleColor("capture")
                        font.family: library.runtime.fontMono
                        font.pixelSize: library.theme.fontSize(38)
                    }
                }
                MarqueeText {
                    width: parent.width
                    text: library.selectedEntry ? (library.selectedEntry.isImage ? "IMAGE" : library.timeLabel(library.selectedEntry.duration)) + " · " + library.formatBytes(library.selectedEntry.size) : "SELECT A CAPTURE"
                    color: library.theme.textStrong
                    font.family: library.runtime.fontMono
                    font.pixelSize: library.theme.fontSize(11)
                    font.weight: Font.DemiBold
                }
                Grid {
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
                        shortcut: "ENTER"
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
                        shortcut: "E"
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
                        shortcut: "C"
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
                        shortcut: "D"
                        enabled: !!library.selectedEntry && !library.isBusy
                        active: !!library.selectedEntry && library.deletePending === library.selectedEntry.name
                        onActivated: library.requestDelete()
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
        Text {
            visible: library.statusText.length > 0
            width: parent.width
            text: library.statusText
            color: library.deletePending.length > 0 ? library.theme.readableRoleColor("warning") : library.statusError ? library.theme.readableRoleColor("critical") : library.theme.readableRoleColor("capture")
            font.family: library.runtime.fontMono
            font.pixelSize: library.theme.fontSize(10)
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
        KeyHintStrip {
            width: parent.width
            runtime: library.runtime
            theme: library.theme
            hints: [
                {
                    shortcut: "J/K",
                    label: "Choose"
                },
                {
                    shortcut: "U/D",
                    label: "Page"
                },
                {
                    shortcut: "R",
                    label: "Refresh"
                },
                {
                    shortcut: "ESC",
                    label: "Back"
                }
            ]
        }
    }
}

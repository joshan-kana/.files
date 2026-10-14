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
            if (columns.length !== 4 || !/^Recording-[0-9]{8}-[0-9]{6}-[0-9]+\.mp4$/.test(columns[1]))
                continue;
            const size = Number(columns[2]);
            const modified = Number(columns[0]);
            const duration = Number(columns[3]);
            if (!Number.isFinite(size) || !Number.isFinite(modified) || !Number.isFinite(duration))
                continue;
            result.push({
                name: columns[1],
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
                library.statusText = "RECORDING DIRECTORY UNAVAILABLE";
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
            library.statusText = exitCode === 0 ? "MOVED TO TRASH · " + deleted : "COULD NOT MOVE RECORDING TO TRASH";
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
        height: 128
        runtime: library.runtime
        theme: library.theme
        motion: library.motion
        glyph: "󰕧"
        glyphColor: library.theme.accent
        eyebrow: "Capture / Local library"
        title: "Recordings"
        detail: library.entries.length + (library.entries.length === 1 ? " clip" : " clips") + " · ~/Videos/Screencasts"
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
                    selected: index === library.selectedIndex
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
                        Text {
                            width: parent.width
                            text: recordRow.entry ? recordRow.entry.name.replace(/^Recording-/, "") : ""
                            textFormat: Text.PlainText
                            color: library.theme.textStrong
                            font.family: library.runtime.fontMono
                            font.pixelSize: library.theme.fontSize(11)
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            text: library.formatBytes(recordRow.entry ? recordRow.entry.size : 0) + " · MP4"
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
                text: "NO COMPLETED RECORDINGS"
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
                        color: library.theme.accent
                        font.family: library.runtime.fontMono
                        font.pixelSize: library.theme.fontSize(38)
                    }
                }
                Text {
                    width: parent.width
                    text: library.selectedEntry ? library.timeLabel(library.selectedEntry.duration) + " · " + library.formatBytes(library.selectedEntry.size) : "SELECT A CLIP"
                    color: library.theme.textStrong
                    font.family: library.runtime.fontMono
                    font.pixelSize: library.theme.fontSize(11)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Row {
                    width: parent.width
                    spacing: library.theme.spacing2
                    ShellAction {
                        width: (parent.width - parent.spacing) / 2
                        height: 37
                        runtime: library.runtime
                        theme: library.theme
                        motion: library.motion
                        compact: true
                        horizontalCompact: true
                        icon: "󰐊"
                        title: "OPEN"
                        shortcut: "ENTER"
                        enabled: !!library.selectedEntry && !library.isBusy
                        onActivated: library.openSelected()
                    }
                    ShellAction {
                        width: (parent.width - parent.spacing) / 2
                        height: 37
                        runtime: library.runtime
                        theme: library.theme
                        motion: library.motion
                        compact: true
                        horizontalCompact: true
                        icon: "󰩺"
                        title: library.selectedEntry && library.deletePending === library.selectedEntry.name ? "CONFIRM" : "TRASH"
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
            color: library.statusError ? library.theme.warning : library.theme.accent
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
                    label: "Select"
                },
                {
                    shortcut: "ENTER",
                    label: "Open"
                },
                {
                    shortcut: "D",
                    label: "Trash"
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

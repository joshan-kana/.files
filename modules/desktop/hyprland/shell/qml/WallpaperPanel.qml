pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: panel

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property bool open: false
    property var entries: []
    property string currentPath: ""
    property string searchText: ""
    property string resizeMode: "fit"
    property string statusText: ""
    property int selectedIndex: 0

    readonly property var filteredEntries: entries.filter(path => path.toLowerCase().includes(searchText.toLowerCase()))
    readonly property string outputName: {
        const window = QsWindow.window as QsWindow;
        return window && window.screen ? window.screen.name : "all";
    }
    readonly property bool busy: applyProcess.running || resetProcess.running
    readonly property bool searching: searchField.activeFocus

    signal keyboardRequested

    visible: open
    implicitWidth: 512
    implicitHeight: 610

    onOpenChanged: {
        if (open)
            refresh();
        else {
            searchField.text = "";
            statusText = "";
        }
    }
    onFilteredEntriesChanged: selectedIndex = Math.max(0, Math.min(selectedIndex, Math.max(0, filteredEntries.length - 1)))

    property StdioCollector listOutput: StdioCollector {}
    property StdioCollector listError: StdioCollector {}
    property StdioCollector currentOutput: StdioCollector {}
    property StdioCollector applyError: StdioCollector {}

    property Process listProcess: Process {
        stdout: panel.listOutput
        stderr: panel.listError
        onExited: (code, status) => {
            if (code !== 0) {
                panel.statusText = panel.listError.text.trim() || "Could not open wallpaper library";
                return;
            }
            try {
                panel.entries = JSON.parse(panel.listOutput.text);
                const position = panel.entries.indexOf(panel.currentPath);
                panel.selectedIndex = position >= 0 ? position : 0;
            } catch (error) {
                panel.statusText = "Invalid wallpaper library response";
            }
        }
    }

    property Process currentProcess: Process {
        stdout: panel.currentOutput
        onExited: (code, status) => {
            if (code === 0) {
                panel.currentPath = panel.currentOutput.text.trim();
                const position = panel.filteredEntries.indexOf(panel.currentPath);
                if (position >= 0)
                    panel.selectedIndex = position;
            }
        }
    }

    property Process applyProcess: Process {
        stderr: panel.applyError
        onExited: (code, status) => {
            if (code === 0) {
                panel.currentPath = panel.selectedPath();
                panel.statusText = "Applied to " + panel.outputName;
            } else {
                panel.statusText = panel.applyError.text.trim() || "Wallpaper apply failed";
            }
            panel.keyboardRequested();
        }
    }

    property Process resetProcess: Process {
        stderr: panel.applyError
        onExited: (code, status) => {
            panel.statusText = code === 0 ? "Restored Stylix wallpaper" : (panel.applyError.text.trim() || "Wallpaper reset failed");
            panel.refreshCurrent();
            panel.keyboardRequested();
        }
    }

    function openView(): void {
        open = true;
    }
    function closeView(): void {
        open = false;
    }

    function refresh(): void {
        if (runtime.wallpaperLibrary.length === 0)
            return;
        if (!listProcess.running)
            listProcess.exec([runtime.wallpaperLibrary, "list"]);
        refreshCurrent();
    }

    function refreshCurrent(): void {
        if (runtime.wallpaperLibrary.length > 0 && !currentProcess.running)
            currentProcess.exec([runtime.wallpaperLibrary, "current", outputName]);
    }

    function selectedPath(): string {
        return filteredEntries.length > 0 ? filteredEntries[Math.max(0, Math.min(selectedIndex, filteredEntries.length - 1))] : "";
    }

    function moveSelection(delta: int): void {
        if (filteredEntries.length === 0)
            return;
        const count = filteredEntries.length;
        selectedIndex = ((selectedIndex + delta) % count + count) % count;
        gallery.currentIndex = selectedIndex;
    }

    function activateThumbnail(index: int): void {
        const alreadySelected = selectedIndex === index;
        selectedIndex = index;
        if (alreadySelected)
            applySelected();
        keyboardRequested();
    }

    function toggleFit(): void {
        resizeMode = resizeMode === "fit" ? "crop" : "fit";
    }
    function applySelected(): void {
        if (busy || !selectedPath() || runtime.wallpaperLibrary.length === 0)
            return;
        statusText = "Applying wallpaper…";
        applyProcess.exec([runtime.wallpaperLibrary, "set", outputName, resizeMode, selectedPath()]);
    }

    function resetWallpaper(): void {
        if (busy || runtime.wallpaperLibrary.length === 0)
            return;
        resetProcess.exec([runtime.wallpaperLibrary, "reset", outputName]);
    }

    function enterSearch(): void {
        searchField.forceActiveFocus();
    }
    function leaveSearch(): void {
        panel.keyboardRequested();
    }

    Column {
        anchors.fill: parent
        spacing: panel.theme.spacing3

        Text {
            text: "APPEARANCE / WALLPAPERS"
            color: panel.theme.accent
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(10)
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2
        }

        Text {
            text: "Wallpaper library"
            color: panel.theme.textStrong
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontPanelTitle
            font.weight: Font.DemiBold
        }

        Text {
            text: panel.outputName + "  ·  H/J/K/L navigate  ·  / search  ·  Enter apply  ·  F fit/fill  ·  R reset"
            width: parent.width
            color: panel.theme.textMuted
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(9)
            wrapMode: Text.WordWrap
        }

        ShellSurface {
            width: parent.width
            height: 39
            theme: panel.theme
            motion: panel.motion
            surfaceLayer: ShellSurface.Control
            cornerRadius: theme.radiusMedium

            TextInput {
                id: searchField
                anchors {
                    fill: parent
                    leftMargin: panel.theme.spacing3
                    rightMargin: panel.theme.spacing3
                }
                verticalAlignment: TextInput.AlignVCenter
                text: panel.searchText
                onTextChanged: panel.searchText = text
                color: panel.theme.textStrong
                selectionColor: panel.theme.accent
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(12)
                focus: false
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        panel.leaveSearch();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        panel.applySelected();
                        panel.leaveSearch();
                        event.accepted = true;
                    }
                }
            }

            Text {
                anchors {
                    left: parent.left
                    leftMargin: panel.theme.spacing3
                    verticalCenter: parent.verticalCenter
                }
                visible: searchField.text.length === 0 && !searchField.activeFocus
                text: "/  Search wallpapers"
                color: panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(11)
            }
        }

        Item {
            width: parent.width
            height: 410

            // Caelestia-style centre-selected wallpaper carousel, keeping our
            // own Theme/Motion/StateLayer and awww-backed selection action.
            PathView {
                id: gallery
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: parent.height - 56
                clip: true
                interactive: false
                highlightMoveDuration: panel.motion.enabled ? panel.motion.spatialFast : 0
                model: panel.filteredEntries
                pathItemCount: Math.min(5, Math.max(3, count))
                currentIndex: panel.selectedIndex
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                snapMode: PathView.SnapToItem

                onCurrentIndexChanged: {
                    if (currentIndex >= 0)
                        panel.selectedIndex = currentIndex;
                }

                WheelHandler {
                    target: null
                    onWheel: event => panel.moveSelection(event.angleDelta.y > 0 ? -1 : 1)
                }

                path: Path {
                    startX: -30
                    startY: gallery.height / 2

                    PathAttribute {
                        name: "z"
                        value: 0
                    }
                    PathLine {
                        x: gallery.width / 2
                        y: gallery.height / 2
                    }
                    PathAttribute {
                        name: "z"
                        value: 1
                    }
                    PathLine {
                        x: gallery.width + 30
                        y: gallery.height / 2
                    }
                    PathAttribute {
                        name: "z"
                        value: 0
                    }
                }

                delegate: Item {
                    id: entry
                    required property string modelData
                    required property int index
                    readonly property bool current: PathView.isCurrentItem
                    width: 206
                    height: 180
                    z: current ? 2 : 1
                    scale: current ? 1 : PathView.onPath ? 0.77 : 0.5
                    opacity: PathView.onPath ? 1 : 0

                    Behavior on scale {
                        Anim {
                            motion: panel.motion
                            type: Anim.DefaultSpatial
                        }
                    }
                    Behavior on opacity {
                        Anim {
                            motion: panel.motion
                            type: Anim.FastEffects
                        }
                    }

                    ShellSurface {
                        anchors.fill: parent
                        theme: panel.theme
                        motion: panel.motion
                        surfaceLayer: ShellSurface.Group
                        cornerRadius: theme.radiusMedium
                        selected: entry.current
                        outlined: entry.current
                        clip: true

                        Image {
                            anchors {
                                top: parent.top
                                left: parent.left
                                right: parent.right
                            }
                            height: 139
                            source: "file://" + entry.modelData
                            sourceSize: Qt.size(380, 250)
                            asynchronous: true
                            cache: true
                            fillMode: Image.PreserveAspectCrop
                        }

                        Text {
                            anchors {
                                left: parent.left
                                right: parent.right
                                bottom: parent.bottom
                                margins: panel.theme.spacing2
                            }
                            text: entry.modelData.slice(entry.modelData.lastIndexOf("/") + 1)
                            color: panel.theme.textStrong
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(10)
                            elide: Text.ElideMiddle
                        }

                        StateLayer {
                            theme: panel.theme
                            motion: panel.motion
                            selected: entry.current
                            cornerRadius: parent.cornerRadius
                            onActivated: panel.activateThumbnail(entry.index)
                        }
                    }
                }
            }

            Text {
                anchors {
                    top: gallery.bottom
                    left: parent.left
                    right: parent.right
                }
                height: 44
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: panel.selectedPath().length > 0 ? panel.selectedPath().slice(panel.selectedPath().lastIndexOf("/") + 1) : ""
                color: panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(11)
                elide: Text.ElideMiddle
            }

            Text {
                anchors.centerIn: parent
                visible: panel.filteredEntries.length === 0
                text: panel.searchText.length > 0 ? "No matching wallpapers" : "Add images or GIFs to ~/Pictures/Wallpapers"
                color: panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(11)
            }
        }

        Row {
            width: parent.width
            spacing: panel.theme.spacing2

            ShellAction {
                width: (parent.width - parent.spacing * 2) / 3
                height: 40
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                title: panel.resizeMode === "fit" ? "F  Fit" : "F  Fill"
                onActivated: panel.toggleFit()
            }

            ShellAction {
                width: (parent.width - parent.spacing * 2) / 3
                height: 40
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                title: "R  Default"
                enabled: !panel.busy
                onActivated: panel.resetWallpaper()
            }

            ShellAction {
                width: (parent.width - parent.spacing * 2) / 3
                height: 40
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                title: "Enter  Apply"
                enabled: panel.selectedPath().length > 0 && !panel.busy
                onActivated: panel.applySelected()
            }
        }

        Text {
            text: panel.statusText
            visible: text.length > 0
            color: panel.theme.textMuted
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(10)
            elide: Text.ElideRight
            width: parent.width
        }
    }
}

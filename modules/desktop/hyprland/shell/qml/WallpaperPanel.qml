pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: panel

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property AppearancePreferences appearance

    property bool open: false
    property var entries: []
    property string currentPath: ""
    property string applyingPath: ""
    property string searchText: ""
    readonly property string resizeMode: appearance.wallpaperResizeMode
    property string statusText: ""
    property int selectedIndex: 0
    property bool loading: false
    property bool resetPending: false

    readonly property var filteredEntries: entries.filter(path => path.toLowerCase().includes(searchText.toLowerCase()))
    property string selectedOutput: ""
    property string currentRequestOutput: ""
    property bool currentRefreshPending: false
    readonly property string hostOutput: {
        const window = QsWindow.window as QsWindow;
        return window && window.screen ? window.screen.name : "all";
    }
    readonly property var outputChoices: {
        const choices = ["all"];
        for (const screen of Quickshell.screens) {
            if (screen.name.length > 0 && !choices.includes(screen.name))
                choices.push(screen.name);
        }
        return choices;
    }
    readonly property string outputName: outputChoices.includes(selectedOutput) ? selectedOutput : outputChoices.includes(hostOutput) ? hostOutput : "all"
    readonly property string outputLabel: outputName === "all" ? "All displays" : outputName
    onOutputNameChanged: {
        if (open && !busy)
            refreshCurrent();
    }
    readonly property bool busy: applyProcess.running || resetProcess.running
    readonly property bool searching: searchField.activeFocus

    signal keyboardRequested

    visible: open
    implicitWidth: 512
    implicitHeight: 760

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
            panel.loading = false;
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
            if (code === 0 && panel.currentRequestOutput === panel.outputName) {
                panel.currentPath = panel.currentOutput.text.trim();
                const position = panel.filteredEntries.indexOf(panel.currentPath);
                if (position >= 0)
                    panel.selectedIndex = position;
            }
            if (panel.currentRefreshPending) {
                panel.currentRefreshPending = false;
                Qt.callLater(() => panel.refreshCurrent());
            }
        }
    }

    property Process applyProcess: Process {
        stderr: panel.applyError
        onExited: (code, status) => {
            if (code === 0) {
                panel.currentPath = panel.applyingPath;
                panel.statusText = "Applied to " + panel.outputName;
            } else {
                panel.statusText = panel.applyError.text.trim() || "Wallpaper apply failed";
            }
            panel.keyboardRequested();
            if (panel.resetPending) {
                panel.resetPending = false;
                Qt.callLater(() => panel.resetWallpaper());
            }
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
        selectedOutput = hostOutput;
        open = true;
    }
    function cycleOutput(): void {
        if (!open || busy || outputChoices.length < 2)
            return;
        const index = outputChoices.indexOf(outputName);
        selectedOutput = outputChoices[(index + 1) % outputChoices.length];
        currentPath = "";
        statusText = "TARGET · " + outputLabel.toUpperCase();
        keyboardRequested();
    }
    function closeView(): void {
        open = false;
    }

    function refresh(): void {
        if (runtime.wallpaperLibrary.length === 0)
            return;
        if (!listProcess.running) {
            loading = true;
            listProcess.exec([runtime.wallpaperLibrary, "list"]);
        }
        refreshCurrent();
    }

    function refreshCurrent(): void {
        if (runtime.wallpaperLibrary.length === 0 || !open)
            return;
        if (currentProcess.running) {
            currentRefreshPending = true;
            return;
        }
        currentRequestOutput = outputName;
        currentProcess.exec([runtime.wallpaperLibrary, "current", currentRequestOutput]);
    }

    function selectedPath(): string {
        return filteredEntries.length > 0 ? filteredEntries[Math.max(0, Math.min(selectedIndex, filteredEntries.length - 1))] : "";
    }

    function moveSelection(delta: int): void {
        if (filteredEntries.length === 0)
            return;
        selectedIndex = Math.max(0, Math.min(filteredEntries.length - 1, selectedIndex + delta));
    }

    function moveGrid(x: int, y: int): void {
        moveSelection(x + y * gallery.columnCount);
    }

    function moveHalfPage(direction: int): void {
        const rows = Math.max(1, Math.floor(gallery.height / gallery.cellHeight / 2));
        moveSelection(direction * rows * gallery.columnCount);
    }

    function activateThumbnail(index: int): void {
        selectedIndex = index;
        applySelected();
        keyboardRequested();
    }

    function toggleFit(): void {
        appearance.toggleWallpaperResizeMode();
    }
    function applySelected(): void {
        if (busy || !selectedPath() || runtime.wallpaperLibrary.length === 0)
            return;
        applyingPath = selectedPath();
        statusText = "Applying wallpaper to " + outputLabel + "…";
        applyProcess.exec([runtime.wallpaperLibrary, "set", outputName, resizeMode, applyingPath]);
    }

    function resetWallpaper(): void {
        if (runtime.wallpaperLibrary.length === 0 || resetProcess.running)
            return;
        if (applyProcess.running) {
            resetPending = true;
            statusText = "Restoring wallpaper after current selection…";
            return;
        }
        statusText = "Restoring Stylix wallpaper on " + outputLabel + "…";
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

        DetailHero {
            width: parent.width
            quiet: true
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            glyph: "▧"
            glyphColor: panel.theme.roleColor("wallpaper")
            eyebrow: "Appearance / wallpapers"
            title: "Wallpaper library"
            detail: panel.outputLabel + " · " + (panel.busy ? "Applying wallpaper…" : panel.resizeMode.toUpperCase() + " · Image / video")
        }

        SearchFieldSurface {
            width: parent.width
            height: 39
            theme: panel.theme
            motion: panel.motion
            fieldFocused: searchField.activeFocus

            TextInput {
                id: searchField
                anchors {
                    fill: parent
                    leftMargin: panel.theme.spacing3
                    rightMargin: outputButton.width + panel.theme.spacing3 * 2
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

            ShellAction {
                id: outputButton
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    rightMargin: panel.theme.spacing1
                }
                width: 161
                height: parent.height - panel.theme.spacing1 * 2
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                horizontalCompact: true
                icon: panel.outputName === "all" ? "󰍺" : "󰍹"
                title: panel.outputLabel
                shortcut: "M"
                enabled: !panel.busy && panel.outputChoices.length > 1
                onActivated: panel.cycleOutput()
            }

            Text {
                anchors {
                    left: parent.left
                    leftMargin: panel.theme.spacing3
                    verticalCenter: parent.verticalCenter
                }
                width: Math.max(1, parent.width - outputButton.width - panel.theme.spacing4 * 2)
                elide: Text.ElideRight
                visible: searchField.text.length === 0 && !searchField.activeFocus
                text: "/  Search wallpapers"
                color: panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(11)
            }
        }

        Item {
            width: parent.width
            height: 465

            // The theme gallery's compact, scrollable card grid is a better
            // match for choosing from a library than a one-at-a-time carousel.
            GridView {
                id: gallery
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: parent.height - 56
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                readonly property int columnCount: width < 430 || panel.theme.textScale >= 1.5 ? 2 : width < 690 ? 3 : 4
                cellWidth: width / columnCount
                cellHeight: 145
                model: panel.filteredEntries
                currentIndex: panel.selectedIndex
                highlightMoveDuration: 0
                onCurrentIndexChanged: {
                    if (currentIndex >= 0)
                        positionViewAtIndex(currentIndex, GridView.Contain);
                }

                delegate: Item {
                    id: entry
                    required property string modelData
                    required property int index
                    readonly property bool current: index === panel.selectedIndex
                    readonly property bool applied: modelData === panel.currentPath
                    readonly property bool animatedFile: /\.(mp4|webm|mkv|mov|gif)$/i.test(modelData)
                    readonly property bool previewActive: current || cardPress.containsMouse
                    property string posterPath: ""
                    property string motionPosterPath: ""
                    property StdioCollector motionPosterOutput: StdioCollector {}
                    property Process motionPosterProcess: Process {
                        stdout: entry.motionPosterOutput
                        onExited: (code, status) => {
                            if (code === 0 && entry.previewActive)
                                entry.motionPosterPath = entry.motionPosterOutput.text.trim();
                        }
                    }
                    Timer {
                        id: motionPreviewDebounce
                        interval: 220
                        onTriggered: {
                            if (entry.animatedFile && entry.previewActive && panel.open && panel.runtime.wallpaperLibrary.length > 0 && !entry.motionPosterProcess.running && entry.motionPosterPath.length === 0)
                                entry.motionPosterProcess.exec([panel.runtime.wallpaperLibrary, "thumbnail-animated", entry.modelData]);
                        }
                    }
                    onPreviewActiveChanged: {
                        if (previewActive && animatedFile && panel.open && motionPosterPath.length === 0)
                            motionPreviewDebounce.restart();
                        else
                            motionPreviewDebounce.stop();
                    }
                    Connections {
                        target: panel
                        function onOpenChanged(): void {
                            if (panel.open && entry.previewActive && entry.animatedFile && entry.motionPosterPath.length === 0)
                                motionPreviewDebounce.restart();
                            if (!panel.open) {
                                motionPreviewDebounce.stop();
                                entry.motionPosterPath = "";
                            }
                        }
                    }
                    property StdioCollector posterOutput: StdioCollector {}
                    property Process posterProcess: Process {
                        stdout: entry.posterOutput
                        onExited: (code, status) => {
                            if (code === 0)
                                entry.posterPath = entry.posterOutput.text.trim();
                        }
                    }
                    Component.onCompleted: {
                        if (panel.runtime.wallpaperLibrary.length > 0)
                            posterProcess.exec([panel.runtime.wallpaperLibrary, "thumbnail", modelData]);
                        if (previewActive && animatedFile && panel.open && motionPosterPath.length === 0)
                            motionPreviewDebounce.restart();
                    }

                    width: gallery.cellWidth
                    height: gallery.cellHeight
                    scale: cardPress.pressed ? 0.985 : 1
                    Behavior on scale {
                        Anim {
                            motion: panel.motion
                            type: Anim.FastSpatial
                        }
                    }

                    ShellSurface {
                        anchors {
                            fill: parent
                            rightMargin: panel.theme.spacing2
                            bottomMargin: panel.theme.spacing2
                        }
                        theme: panel.theme
                        motion: panel.motion
                        surfaceLayer: ShellSurface.Control
                        cornerRadius: panel.theme.radiusMedium
                        selected: entry.current
                        clip: true

                        Image {
                            anchors {
                                top: parent.top
                                left: parent.left
                                right: parent.right
                                bottom: filenameBar.top
                            }
                            source: entry.posterPath.length > 0 ? "file://" + entry.posterPath : ""
                            sourceSize: Qt.size(300, 180)
                            asynchronous: true
                            cache: true
                            fillMode: Image.PreserveAspectCrop
                        }

                        AnimatedImage {
                            anchors {
                                top: parent.top
                                left: parent.left
                                right: parent.right
                                bottom: filenameBar.top
                            }
                            source: entry.previewActive && panel.open && entry.motionPosterPath.length > 0 ? "file://" + entry.motionPosterPath : ""
                            fillMode: Image.PreserveAspectCrop
                            playing: entry.previewActive && panel.open
                            visible: status === AnimatedImage.Ready && playing
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: entry.posterPath.length === 0
                            text: entry.animatedFile ? "󰐊" : "󰋩"
                            color: panel.theme.textMuted
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(19)
                        }

                        Text {
                            anchors {
                                top: parent.top
                                left: parent.left
                                margins: panel.theme.spacing2
                            }
                            visible: entry.animatedFile && entry.posterPath.length > 0
                            text: "󰐊"
                            color: "#ffffff"
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(15)
                        }

                        Rectangle {
                            id: filenameBar
                            anchors {
                                left: parent.left
                                right: parent.right
                                bottom: parent.bottom
                            }
                            height: 32
                            color: panel.theme.surface

                            Row {
                                anchors {
                                    fill: parent
                                    leftMargin: panel.theme.spacing2
                                    rightMargin: panel.theme.spacing2
                                }
                                spacing: panel.theme.spacing1
                                Text {
                                    width: Math.max(1, parent.width - stateLabel.implicitWidth - parent.spacing)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: entry.modelData.slice(entry.modelData.lastIndexOf("/") + 1)
                                    color: panel.theme.textStrong
                                    font.family: panel.runtime.fontMono
                                    font.pixelSize: panel.theme.fontSize(10)
                                    elide: Text.ElideRight
                                }
                                Text {
                                    id: stateLabel
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: entry.applied ? "ACTIVE" : ""
                                    color: panel.theme.positive
                                    font.family: panel.runtime.fontMono
                                    font.pixelSize: panel.theme.fontSize(9)
                                }
                            }
                        }

                        StateLayer {
                            id: cardPress
                            theme: panel.theme
                            motion: panel.motion
                            selected: entry.current
                            cornerRadius: panel.theme.radiusMedium
                            onActivated: panel.activateThumbnail(entry.index)
                        }

                        // Match the Theme Picker's focus outline. The frame
                        // must sit above the preview image, not behind it.
                        SquircleSurface {
                            anchors.fill: parent
                            visible: entry.current
                            cornerRadius: panel.theme.radiusMedium
                            exponent: panel.theme.squircleExponent
                            borderColor: panel.theme.roleColor("wallpaper")
                            borderWidth: panel.theme.borderFocus * 2
                        }
                    }
                }
            }

            ShellSurface {
                id: currentWallpaperPreview
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: gallery.height
                visible: panel.filteredEntries.length === 0 && !panel.loading && panel.searchText.length === 0 && panel.runtime.wallpaper.length > 0
                theme: panel.theme
                motion: panel.motion
                surfaceLayer: ShellSurface.Group
                cornerRadius: panel.theme.radiusLarge
                clip: true

                Image {
                    anchors.fill: parent
                    source: panel.runtime.wallpaper.length > 0 ? "file://" + panel.runtime.wallpaper : ""
                    sourceSize: Qt.size(900, 600)
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                }

                Rectangle {
                    anchors {
                        bottom: parent.bottom
                        left: parent.left
                        right: parent.right
                    }
                    height: 84
                    color: Qt.rgba(panel.theme.background.r, panel.theme.background.g, panel.theme.background.b, 0.82)

                    Column {
                        anchors {
                            fill: parent
                            margins: panel.theme.spacing4
                        }
                        spacing: panel.theme.spacing2
                        Text {
                            text: "CURRENT · STYLIX"
                            color: panel.theme.readableRoleColor("wallpaper")
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontPanelEyebrow
                            font.weight: Font.DemiBold
                        }
                        Text {
                            width: parent.width
                            text: "Theme wallpaper"
                            color: panel.theme.textStrong
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(16)
                            font.weight: Font.DemiBold
                        }
                        Text {
                            width: parent.width
                            text: "Add files to ~/wallpapers to build a gallery"
                            color: panel.theme.text
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(10)
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            MarqueeText {
                anchors {
                    top: gallery.bottom
                    left: parent.left
                    right: parent.right
                }
                height: 44
                alignCenter: true
                text: panel.selectedPath().length > 0 ? panel.selectedPath().slice(panel.selectedPath().lastIndexOf("/") + 1) : ""
                color: panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(11)
            }

            Text {
                anchors.centerIn: parent
                visible: panel.filteredEntries.length === 0 && (panel.loading || panel.searchText.length > 0 || panel.runtime.wallpaper.length === 0)
                text: panel.loading ? "Loading wallpapers…" : panel.searchText.length > 0 ? "No matching wallpapers" : "Add images, GIFs or videos to ~/wallpapers"
                color: panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(11)
            }
        }

        Row {
            width: parent.width
            spacing: panel.theme.spacing2

            ShellAction {
                width: (parent.width - parent.spacing) / 2
                height: 40
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                title: panel.resizeMode === "fit" ? "Fit" : "Fill"
                shortcut: "F"
                horizontalCompact: true
                onActivated: panel.toggleFit()
            }

            ShellAction {
                width: (parent.width - parent.spacing) / 2
                height: 40
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                title: "Default"
                shortcut: "R"
                horizontalCompact: true
                enabled: !panel.busy
                onActivated: panel.resetWallpaper()
            }
        }

        KeyHintStrip {
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            hints: [
                {
                    shortcut: "H/J/K/L",
                    label: "Choose"
                },
                {
                    shortcut: "U/D",
                    label: "Page"
                },
                {
                    shortcut: "/",
                    label: "Search"
                },
                {
                    shortcut: "ENTER",
                    label: "Set"
                }
            ]
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

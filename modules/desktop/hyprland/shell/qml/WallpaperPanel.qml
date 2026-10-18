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
    property string featuredPosterPath: ""
    onSelectedIndexChanged: featuredPosterPath = ""
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
                panel.currentPath = panel.selectedPath();
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
        statusText = "Applying wallpaper to " + outputLabel + "…";
        applyProcess.exec([runtime.wallpaperLibrary, "set", outputName, resizeMode, selectedPath()]);
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
            eyebrow: "Appearance / wallpapers"
            title: "Wallpaper library"
            detail: panel.outputLabel + " · " + (panel.busy ? "Applying wallpaper…" : panel.resizeMode.toUpperCase() + " · Image / video")
        }

        AppearancePreview {
            id: featuredPreview
            width: parent.width
            height: 174
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            mode: "wallpaper"
            imagePath: {
                const path = panel.selectedPath();
                if (path.length === 0)
                    return panel.runtime.wallpaper;
                if (/\.(mp4|webm|mkv|mov|gif)$/i.test(path))
                    return panel.featuredPosterPath;
                return path;
            }
            selectionName: {
                const path = panel.selectedPath();
                return path.length > 0 ? path.slice(path.lastIndexOf("/") + 1) : "Default wallpaper";
            }
            context: panel.resizeMode.toUpperCase() + " · " + panel.outputLabel
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
            height: 300

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
                    // Keep neighbouring cards visible as previews without
                    // letting their edges crowd the full-size selection.
                    startX: -gallery.width * 0.13
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
                        x: gallery.width * 1.13
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
                    readonly property bool animatedFile: /\.(mp4|webm|mkv|mov|gif)$/i.test(modelData)
                    property string posterPath: ""
                    property string motionPosterPath: ""
                    property StdioCollector motionPosterOutput: StdioCollector {}
                    property Process motionPosterProcess: Process {
                        stdout: entry.motionPosterOutput
                        onExited: (code, status) => {
                            if (code === 0 && entry.current)
                                entry.motionPosterPath = entry.motionPosterOutput.text.trim();
                        }
                    }
                    Timer {
                        id: motionPreviewDebounce
                        interval: 220
                        onTriggered: {
                            if (entry.animatedFile && entry.current && panel.open && panel.motion.enabled && panel.runtime.wallpaperLibrary.length > 0 && !entry.motionPosterProcess.running)
                                entry.motionPosterProcess.exec([panel.runtime.wallpaperLibrary, "thumbnail-animated", entry.modelData]);
                        }
                    }
                    onCurrentChanged: {
                        if (current)
                            panel.featuredPosterPath = posterPath;
                        if (current && animatedFile && panel.open && panel.motion.enabled)
                            motionPreviewDebounce.restart();
                    }
                    Connections {
                        target: panel
                        function onOpenChanged(): void {
                            if (panel.open && entry.current && entry.animatedFile && panel.motion.enabled)
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
                            if (code === 0) {
                                entry.posterPath = entry.posterOutput.text.trim();
                                if (entry.current)
                                    panel.featuredPosterPath = entry.posterPath;
                            }
                        }
                    }

                    Component.onCompleted: {
                        if (animatedFile && panel.runtime.wallpaperLibrary.length > 0)
                            posterProcess.exec([panel.runtime.wallpaperLibrary, "thumbnail", modelData]);
                        if (current && animatedFile && panel.open && panel.motion.enabled)
                            motionPreviewDebounce.restart();
                    }
                    width: 336
                    height: 236
                    z: current ? 2 : 1
                    scale: current ? 1 : PathView.onPath ? 0.58 : 0.5
                    opacity: PathView.onPath ? (current ? 1 : 0.84) : 0

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
                            height: parent.height
                            source: entry.animatedFile ? (entry.posterPath.length > 0 ? "file://" + entry.posterPath : "") : "file://" + entry.modelData
                            sourceSize: Qt.size(620, 400)
                            asynchronous: true
                            cache: true
                            fillMode: Image.PreserveAspectCrop
                        }

                        AnimatedImage {
                            anchors {
                                top: parent.top
                                left: parent.left
                                right: parent.right
                            }
                            height: parent.height
                            source: entry.current && panel.open && panel.motion.enabled && entry.motionPosterPath.length > 0 ? "file://" + entry.motionPosterPath : ""
                            fillMode: Image.PreserveAspectCrop
                            playing: entry.current && panel.open && panel.motion.enabled
                            visible: status === AnimatedImage.Ready && playing
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: entry.animatedFile && entry.posterPath.length === 0
                            text: "󰐊"
                            color: panel.theme.accent
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(32)
                        }

                        // Selected filename is already in the dedicated caption
                        // beneath the carousel; repeating it on every shrunken
                        // side card made the gallery unnecessarily crowded.

                        StateLayer {
                            theme: panel.theme
                            motion: panel.motion
                            selected: entry.current
                            cornerRadius: panel.theme.radiusMedium
                            onActivated: panel.activateThumbnail(entry.index)
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
                            color: panel.theme.accent
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
                width: (parent.width - parent.spacing * 2) / 3
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
                width: (parent.width - parent.spacing * 2) / 3
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

            ShellAction {
                width: (parent.width - parent.spacing * 2) / 3
                height: 40
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                title: "Apply"
                shortcut: "ENTER"
                horizontalCompact: true
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

pragma ComponentBehavior: Bound
import QtQuick
import "DesktopIcons.js" as DesktopIcons
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
    property var favoritePaths: []
    property bool favoritesOnly: false
    property string collectionFilter: ""
    readonly property string libraryRoot: Quickshell.env("HOME") + "/wallpapers/"
    readonly property var collections: ["", ...new Set(entries.map(path => path.startsWith(libraryRoot) ? path.slice(libraryRoot.length, path.lastIndexOf("/")) : "").filter(value => value.length > 0))].sort()
    property bool policyView: false
    property var policy: ({
            mode: "off",
            target: "all",
            intervalMinutes: 60,
            favoritesOnly: false,
            collection: "",
            dayStart: 420,
            nightStart: 1140,
            dayWallpaper: "",
            nightWallpaper: ""
        })
    property bool policyKnown: false
    property string policyError: ""
    property double nextDue: 0
    property string policyPhase: ""
    property string scheduleCandidate: ""
    readonly property string foregroundRole: "wallpaper"
    property string activePolicyCommand: ""
    readonly property bool foregroundBusy: busy || (policyBusy && activePolicyCommand !== "status")
    readonly property bool policyBusy: policyProcess.running
    property bool refreshPolicyPending: false

    property Process policyProcess: Process {
        stdout: StdioCollector {
            id: policyOutput
        }
        stderr: StdioCollector {
            id: policyErrors
        }
        onExited: (code, status) => {
            if (code === 0) {
                try {
                    const data = JSON.parse(policyOutput.text);
                    panel.policy = data.policy;
                    panel.favoritePaths = data.favorites;
                    panel.policyKnown = true;
                    panel.policyError = data.error || "";
                    panel.nextDue = data.nextDue;
                    panel.policyPhase = data.phase;
                    if (panel.open && !panel.busy)
                        panel.refreshCurrent();
                } catch (_) {
                    panel.policyError = "Invalid wallpaper policy response";
                }
            } else {
                panel.policyError = policyErrors.text.trim() || "Wallpaper policy failed";
            }
            if (panel.refreshPolicyPending) {
                panel.refreshPolicyPending = false;
                Qt.callLater(() => panel.refreshPolicy());
            }
        }
    }
    property FileView rotationReadback: FileView {
        path: panel.open ? (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/desktop-shell/wallpapers/rotation.json" : ""
        watchChanges: panel.open
        printErrors: false
        onFileChanged: {
            reload();
            panel.refreshPolicy();
        }
    }
    function runPolicy(action: string, args = []): void {
        if (!runtime.wallpaperPolicy || policyBusy)
            return;
        policyError = "";
        activePolicyCommand = action;
        policyProcess.exec([runtime.wallpaperPolicy, action, ...args]);
    }
    function refreshPolicy(): void {
        if (!open)
            return;
        if (policyBusy) {
            refreshPolicyPending = true;
            return;
        }
        runPolicy("status");
    }
    function setPolicy(key: string, value: var): void {
        runPolicy("set", [key, JSON.stringify(value)]);
    }
    function cycleCollection(): void {
        collectionFilter = collections[(collections.indexOf(collectionFilter) + 1) % collections.length];
        selectedIndex = 0;
    }
    function timeLabel(minutes: int): string {
        return String(Math.floor(minutes / 60)).padStart(2, "0") + ":" + String(minutes % 60).padStart(2, "0");
    }
    function togglePolicyView(): void {
        if (policyView) {
            policyView = false;
        } else {
            scheduleCandidate = selectedPath();
            policyView = true;
            refreshPolicy();
        }
        keyboardRequested();
    }
    readonly property var galleryPolicyActions: [
        {
            action: "WallpaperPanel.favorite",
            title: favoritePaths.includes(selectedPath()) ? "Remove favourite" : "Favourite",
            enabled: policyKnown && !policyBusy && selectedPath() !== ""
        },
        {
            action: "WallpaperPanel.favorites",
            title: favoritesOnly ? "Favourites only" : "All wallpapers",
            enabled: true
        },
        {
            action: "WallpaperPanel.collection",
            title: collectionFilter || "All folders",
            enabled: collections.length > 1
        },
        {
            action: "WallpaperPanel.rotation",
            title: "Rotation · " + (policy.mode === "dayNight" ? "Day/night" : policy.mode === "interval" ? "Interval" : "Off"),
            enabled: !!runtime.wallpaperPolicy
        }
    ]
    readonly property var scheduleActions: [
        {
            action: "WallpaperPolicy.mode",
            title: policy.mode === "dayNight" ? "Day/night" : policy.mode === "interval" ? "Interval" : "Off"
        },
        {
            action: "WallpaperPolicy.target",
            title: "Target · " + policy.target
        },
        {
            action: "WallpaperPolicy.period",
            title: policy.intervalMinutes + " min"
        },
        {
            action: "WallpaperPolicy.favorites",
            title: policy.favoritesOnly ? "Favourites" : "Entire library"
        },
        {
            action: "WallpaperPolicy.collection",
            title: policy.collection || "All folders"
        },
        {
            action: "WallpaperPolicy.day",
            title: "Use selection for day"
        },
        {
            action: "WallpaperPolicy.night",
            title: "Use selection for night"
        },
        {
            action: "WallpaperPolicy.dayEarlier",
            title: "Day −30 min"
        },
        {
            action: "WallpaperPolicy.dayLater",
            title: "Day +30 min"
        },
        {
            action: "WallpaperPolicy.nightEarlier",
            title: "Night −30 min"
        },
        {
            action: "WallpaperPolicy.nightLater",
            title: "Night +30 min"
        },
        {
            action: "WallpaperPolicy.next",
            title: "Rotate now"
        },
        {
            action: "WallpaperPolicy.defaults",
            title: "Restore policy defaults"
        },
        {
            action: "WallpaperPanel.rotation",
            title: "Back to wallpapers"
        }
    ]
    function policyActionEnabled(action: string): bool {
        if (action === "WallpaperPanel.rotation")
            return true;
        if (!policyKnown || policyBusy)
            return false;
        if (action === "WallpaperPolicy.day" || action === "WallpaperPolicy.night")
            return scheduleCandidate !== "";
        if (action === "WallpaperPolicy.next")
            return policy.mode === "interval";
        if (action === "WallpaperPolicy.target")
            return outputAvailable;
        return true;
    }
    function invokePolicyAction(action: string): void {
        if (action === "WallpaperPanel.rotation") {
            togglePolicyView();
            return;
        }
        if (!policyView) {
            if (action === "WallpaperPanel.favorite" && policyKnown && selectedPath() !== "")
                runPolicy("favorite", [selectedPath()]);
            else if (action === "WallpaperPanel.favorites") {
                favoritesOnly = !favoritesOnly;
                selectedIndex = 0;
            } else if (action === "WallpaperPanel.collection")
                cycleCollection();
            return;
        }
        if (!policyActionEnabled(action))
            return;
        switch (action) {
        case "WallpaperPolicy.mode":
            {
                const modes = ["off", "interval", "dayNight"];
                setPolicy("mode", modes[(modes.indexOf(policy.mode) + 1) % modes.length]);
                break;
            }
        case "WallpaperPolicy.target":
            setPolicy("target", outputName);
            break;
        case "WallpaperPolicy.period":
            {
                const choices = [5, 15, 30, 60, 120];
                setPolicy("intervalMinutes", choices[(choices.indexOf(policy.intervalMinutes) + 1) % choices.length]);
                break;
            }
        case "WallpaperPolicy.favorites":
            setPolicy("favoritesOnly", !policy.favoritesOnly);
            break;
        case "WallpaperPolicy.collection":
            setPolicy("collection", collections[(collections.indexOf(policy.collection) + 1) % collections.length]);
            break;
        case "WallpaperPolicy.day":
            setPolicy("dayWallpaper", scheduleCandidate);
            break;
        case "WallpaperPolicy.night":
            setPolicy("nightWallpaper", scheduleCandidate);
            break;
        case "WallpaperPolicy.dayEarlier":
            setPolicy("dayStart", (policy.dayStart + 1410) % 1440);
            break;
        case "WallpaperPolicy.dayLater":
            setPolicy("dayStart", (policy.dayStart + 30) % 1440);
            break;
        case "WallpaperPolicy.nightEarlier":
            setPolicy("nightStart", (policy.nightStart + 1410) % 1440);
            break;
        case "WallpaperPolicy.nightLater":
            setPolicy("nightStart", (policy.nightStart + 30) % 1440);
            break;
        case "WallpaperPolicy.next":
            runPolicy("next");
            break;
        case "WallpaperPolicy.defaults":
            runPolicy("reset");
            break;
        }
    }
    function handlePolicyKey(key: int, modifiers: int, autoRepeat: bool): bool {
        const actions = policyView ? scheduleActions : galleryPolicyActions;
        for (const entry of actions) {
            if (runtime.shellMatchesHint(entry.action, key, modifiers)) {
                if (!autoRepeat)
                    invokePolicyAction(entry.action);
                return true;
            }
        }
        return false;
    }

    property string currentPath: ""
    property string applyingPath: ""
    property string searchText: ""
    readonly property string resizeMode: appearance.wallpaperResizeMode
    property string statusText: ""
    property int selectedIndex: 0
    property bool loading: false
    property bool transitionPending: false
    Timer {
        id: transitionComplete
        interval: 1100
        repeat: false
        onTriggered: panel.transitionPending = false
    }
    property bool resetPending: false

    readonly property var filteredEntries: entries.filter(path => path.toLowerCase().includes(searchText.toLowerCase()) && (!favoritesOnly || favoritePaths.includes(path)) && (!collectionFilter || path.startsWith(libraryRoot + collectionFilter + "/")))
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
    // An unset preference preserves the first-use behavior (this monitor).
    // Once chosen, the saved target owns the setting across panel reloads
    // and Quickshell restarts. A disconnected monitor stays selected instead
    // of silently redirecting wallpaper application to another output.
    readonly property string outputName: appearance.wallpaperTargetOutput.length > 0 ? appearance.wallpaperTargetOutput : hostOutput
    readonly property bool outputAvailable: outputName === "all" || outputChoices.includes(outputName)
    readonly property string outputLabel: outputName === "all" ? "All displays" : outputName + (outputAvailable ? "" : " (disconnected)")
    onOutputNameChanged: {
        currentPath = "";
        if (open && !busy && outputAvailable)
            refreshCurrent();
    }
    onOutputAvailableChanged: {
        if (open && !busy && outputAvailable)
            refreshCurrent();
    }
    readonly property bool busy: applyProcess.running || resetProcess.running || transitionPending
    readonly property bool searching: searchField.activeFocus

    signal keyboardRequested

    visible: open
    implicitWidth: 1120
    // Derive the detail height from its content so shared navigation retains
    // the same clearance as other details when the gallery layout changes.
    implicitHeight: policyView ? policyLayout.implicitHeight : galleryLayout.implicitHeight

    onOpenChanged: {
        if (open) {
            refresh();
            refreshPolicy();
        } else {
            policyView = false;
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
            transitionComplete.restart();
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
            transitionComplete.restart();
            panel.statusText = code === 0 ? "Restored Stylix wallpaper" : (panel.applyError.text.trim() || "Wallpaper reset failed");
            panel.refreshCurrent();
            panel.keyboardRequested();
        }
    }

    // Populate thumbnail data while Controls is idle, before the gallery's
    // opening morph. Reuse the snapshot on entry; refreshing the on-disk
    // library remains a separate, deferred operation.
    function prewarm(): void {
        if (runtime.wallpaperLibrary.length > 0 && entries.length === 0 && !listProcess.running)
            listProcess.exec([runtime.wallpaperLibrary, "list"]);
    }

    function openView(): void {
        open = true;
        if (!outputAvailable)
            statusText = "Selected monitor is disconnected · choose another target (M)";
    }
    function cycleOutput(): void {
        if (!open || busy || outputChoices.length < 2)
            return;
        const index = outputChoices.indexOf(outputName);
        appearance.setWallpaperTargetOutput(outputChoices[(index + 1) % outputChoices.length]);
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
        if (!listProcess.running && entries.length === 0) {
            loading = true;
            listProcess.exec([runtime.wallpaperLibrary, "list"]);
        }
        refreshCurrent();
    }

    function refreshCurrent(): void {
        if (runtime.wallpaperLibrary.length === 0 || !open || !outputAvailable)
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
        if (busy || !outputAvailable || !selectedPath() || runtime.wallpaperLibrary.length === 0)
            return;
        transitionPending = true;
        applyingPath = selectedPath();
        statusText = "Applying wallpaper to " + outputLabel + "…";
        applyProcess.exec([runtime.wallpaperLibrary, "set", outputName, resizeMode, applyingPath]);
    }

    function resetWallpaper(): void {
        if (runtime.wallpaperLibrary.length === 0 || !outputAvailable || resetProcess.running)
            return;
        if (applyProcess.running) {
            resetPending = true;
            statusText = "Restoring wallpaper after current selection…";
            return;
        }
        transitionPending = true;
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
        id: galleryLayout
        visible: !panel.policyView
        anchors.fill: parent
        spacing: panel.theme.spacing3

        DetailHero {
            width: parent.width
            quiet: true
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            glyph: DesktopIcons.glyphFor("wallpaper")
            glyphFont: "Symbols Nerd Font"
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
                font.family: panel.runtime.fontSans
                font.pixelSize: panel.theme.fontSize(12)
                focus: false
                Keys.onPressed: event => {
                    if (event.key === panel.runtime.shellKeyCode("controls", "Escape")) {
                        panel.leaveSearch();
                        event.accepted = true;
                    } else if (event.key === panel.runtime.shellKeyCode("controls", "Return") || event.key === panel.runtime.shellKeyCode("controls", "Enter")) {
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
                shortcut: panel.runtime.shellHint("WallpaperPanel.display")
                enabled: !panel.busy && (panel.outputChoices.length > 1 || !panel.outputAvailable)
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
                text: "Search wallpapers"
                color: panel.theme.textMuted
                font.family: panel.runtime.fontSans
                font.pixelSize: panel.theme.fontSize(11)
            }
        }

        PanelStatus {
            id: statusBanner
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            idleMessage: "Choose a wallpaper and display target"
            message: panel.statusText
            phase: !panel.outputAvailable || /fail|error|invalid|disconnected|could not/i.test(panel.statusText) ? "error" : panel.busy || panel.loading ? "busy" : /applied|restored/i.test(panel.statusText) ? "success" : "idle"
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
                height: parent.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                readonly property int columnCount: panel.theme.textScale >= 1.5 || width < 580 ? 1 : width < 950 ? 2 : 3
                cellWidth: width / columnCount
                cellHeight: 215
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
                    readonly property bool previewActive: current || cardPress.pointerHovered
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
                            if (entry.animatedFile && entry.previewActive && panel.open && !panel.policyView && panel.runtime.wallpaperLibrary.length > 0 && !entry.motionPosterProcess.running && entry.motionPosterPath.length === 0)
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
                            sourceSize: Qt.size(480, 300)
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
                            source: entry.previewActive && panel.open && !panel.policyView && entry.motionPosterPath.length > 0 ? "file://" + entry.motionPosterPath : ""
                            fillMode: Image.PreserveAspectCrop
                            playing: entry.previewActive && panel.open && !panel.policyView
                            visible: status === AnimatedImage.Ready && playing
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: entry.posterPath.length === 0
                            text: entry.animatedFile ? "󰐊" : "󰋩"
                            color: panel.theme.textMuted
                            font.family: panel.runtime.fontSans
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
                            font.family: panel.runtime.fontSans
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
                                    text: entry.applied ? "ACTIVE" : panel.favoritePaths.includes(entry.modelData) ? "♥" : ""
                                    color: panel.theme.positive
                                    font.family: panel.runtime.fontSans
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
                visible: panel.filteredEntries.length === 0 && !panel.loading && !panel.favoritesOnly && panel.collectionFilter === "" && panel.searchText.length === 0 && panel.runtime.wallpaper.length > 0
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
                        top: parent.top
                        right: parent.right
                        margins: panel.theme.spacing3
                    }
                    width: stylixLabel.implicitWidth + panel.theme.spacing3 * 2
                    height: 28
                    radius: panel.theme.radiusSmall
                    color: Qt.rgba(0, 0, 0, 0.76)

                    Text {
                        id: stylixLabel
                        anchors.centerIn: parent
                        text: "STYLIX"
                        color: "#ffffff"
                        font.family: panel.runtime.fontSans
                        font.pixelSize: panel.theme.fontSize(10)
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: panel.filteredEntries.length === 0 && (panel.loading || panel.searchText.length > 0 || panel.favoritesOnly || panel.collectionFilter !== "" || panel.runtime.wallpaper.length === 0)
                text: panel.loading ? "Loading wallpapers…" : panel.searchText.length > 0 || panel.favoritesOnly || panel.collectionFilter !== "" ? "No matching wallpapers" : "Add images, GIFs or videos to ~/wallpapers"
                color: panel.theme.textMuted
                font.family: panel.runtime.fontSans
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
                shortcut: panel.runtime.shellHint("WallpaperPanel.fit")
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
                shortcut: panel.runtime.shellHint("WallpaperPanel.default")
                horizontalCompact: true
                enabled: !panel.busy
                onActivated: panel.resetWallpaper()
            }
        }

        Row {
            width: parent.width
            spacing: panel.theme.spacing2
            Repeater {
                model: panel.galleryPolicyActions
                delegate: ShellAction {
                    id: galleryAction
                    required property var modelData
                    width: (panel.width - 3 * panel.theme.spacing2) / 4
                    height: 40
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    compact: true
                    horizontalCompact: true
                    title: modelData.title
                    shortcut: panel.runtime.shellHint(modelData.action)
                    enabled: modelData.enabled
                    onActivated: panel.invokePolicyAction(galleryAction.modelData.action)
                }
            }
        }

        KeyHintStrip {
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            hints: [
                {
                    shortcut: panel.runtime.shellHint("WallpaperPanel.columns"),
                    label: "Columns"
                },
                {
                    shortcut: panel.runtime.shellHint("WallpaperPanel.rows"),
                    label: "Rows"
                },
                {
                    shortcut: panel.runtime.shellHint("WallpaperPanel.page"),
                    label: "Page"
                },
                {
                    shortcut: panel.runtime.shellHint("WallpaperPanel.search"),
                    label: "Search"
                },
                {
                    shortcut: panel.runtime.shellHint("WallpaperPanel.set"),
                    label: "Set"
                }
            ]
        }
    }

    Column {
        id: policyLayout
        visible: panel.policyView
        width: parent.width
        spacing: panel.theme.spacing3

        DetailHero {
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            glyph: DesktopIcons.glyphFor("wallpaper")
            glyphFont: "Symbols Nerd Font"
            glyphColor: panel.theme.roleColor("wallpaper")
            eyebrow: "Wallpaper library / rotation"
            title: "Wallpaper rotation"
            detail: "One session schedule · selected target " + panel.outputLabel
        }
        ShellText {
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            text: panel.policyError || (panel.policyBusy ? "Applying policy…" : panel.policy.mode === "off" ? "Automatic wallpaper changes disabled" : panel.policy.mode === "interval" ? "Next rotation · " + (panel.nextDue > 0 ? Qt.formatDateTime(new Date(panel.nextDue * 1000), "ddd HH:mm") : "Not scheduled") : "Current phase · " + (panel.policyPhase || "Waiting for valid selections"))
            color: panel.policyError ? panel.theme.warning : panel.theme.textMuted
            wrapMode: Text.WordWrap
        }
        ShellText {
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            text: "Selected wallpaper · " + (panel.scheduleCandidate ? panel.scheduleCandidate.slice(panel.scheduleCandidate.lastIndexOf("/") + 1) : "None")
            elide: Text.ElideRight
        }
        ShellText {
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            text: "Day " + panel.timeLabel(panel.policy.dayStart) + " · " + (panel.policy.dayWallpaper || "Not selected") + "    |    Night " + panel.timeLabel(panel.policy.nightStart) + " · " + (panel.policy.nightWallpaper || "Not selected")
            wrapMode: Text.WordWrap
            color: panel.theme.textMuted
        }
        Grid {
            id: scheduleGrid
            width: parent.width
            columns: panel.theme.textScale >= 1.5 ? 2 : 3
            rowSpacing: panel.theme.spacing2
            columnSpacing: panel.theme.spacing2
            Repeater {
                model: panel.scheduleActions
                delegate: ShellAction {
                    id: scheduleAction
                    required property var modelData
                    width: (panel.width - (scheduleGrid.columns - 1) * panel.theme.spacing2) / scheduleGrid.columns
                    height: 44
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    compact: true
                    horizontalCompact: true
                    title: modelData.title
                    shortcut: panel.runtime.shellHint(modelData.action)
                    enabled: panel.policyActionEnabled(modelData.action)
                    onActivated: panel.invokePolicyAction(scheduleAction.modelData.action)
                }
            }
        }
        ShellText {
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            text: "Manual wallpaper selections remain in effect until the next scheduled interval or day/night boundary. All-display rotation intentionally replaces output-specific selections."
            wrapMode: Text.WordWrap
            color: panel.theme.textMuted
        }
    }
}

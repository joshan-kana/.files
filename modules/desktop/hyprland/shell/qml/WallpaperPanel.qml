pragma ComponentBehavior: Bound
import QtQuick
import "ClockFormatting.js" as ClockFormatting
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
    property var policy: runtime.configData.wallpaperRotation
    property bool policyKnown: false
    property string policyError: ""
    property double nextDue: 0
    property string policyPhase: ""
    property string scheduleCandidate: ""
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
        return ClockFormatting.minutesLabel(minutes);
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
            glyph: favoritePaths.includes(selectedPath()) ? "󰋑" : "󰋕",
            iconOnly: true,
            title: favoritePaths.includes(selectedPath()) ? "Remove favourite" : "Favourite",
            enabled: policyKnown && !policyBusy && selectedPath() !== ""
        },
        {
            action: "WallpaperPanel.favorites",
            glyph: "󰓎",
            active: favoritesOnly,
            title: favoritesOnly ? "Favourites only" : "All wallpapers",
            enabled: true
        },
        {
            action: "WallpaperPanel.collection",
            glyph: "󰉋",
            title: collectionFilter || "All folders",
            enabled: collections.length > 1
        },
        {
            action: "WallpaperPanel.display",
            glyph: panel.outputName === "all" ? "󰍺" : "󰍹",
            title: panel.outputLabel,
            enabled: !panel.busy && (panel.outputChoices.length > 1 || !panel.outputAvailable)
        },
        {
            action: "WallpaperPanel.fit",
            glyph: panel.resizeMode === "fit" ? "󰩨" : "󰊓",
            title: panel.resizeMode === "fit" ? "Fit" : "Fill",
            enabled: !panel.busy
        },
        {
            action: "WallpaperPanel.rotation",
            glyph: "󰥔",
            active: policy.mode !== "off",
            title: "Schedule · " + (policy.mode === "dayNight" ? "Day/night" : policy.mode === "interval" ? "Interval" : "Off"),
            enabled: !!runtime.wallpaperPolicy
        },
        {
            action: "WallpaperPanel.default",
            glyph: DesktopIcons.actionGlyph("reset"),
            title: "Default wallpaper",
            enabled: !panel.busy
        }
    ]
    readonly property var scheduleActions: [
        {
            action: "WallpaperPolicy.mode",
            glyph: policy.mode === "dayNight" ? "󰖔" : policy.mode === "interval" ? "󰥔" : "󰜺",
            title: policy.mode === "dayNight" ? "Day/night" : policy.mode === "interval" ? "Interval" : "Off"
        },
        {
            action: "WallpaperPolicy.target",
            activeOnly: true,
            glyph: "󰍺",
            title: "Schedule target · " + policy.target
        },
        {
            action: "WallpaperPolicy.period",
            intervalOnly: true,
            title: policy.intervalMinutes + " min"
        },
        {
            action: "WallpaperPolicy.favorites",
            intervalOnly: true,
            title: policy.favoritesOnly ? "Favourites" : "Entire library"
        },
        {
            action: "WallpaperPolicy.collection",
            intervalOnly: true,
            title: policy.collection || "All folders"
        },
        {
            action: "WallpaperPolicy.day",
            dayNightOnly: true,
            title: "Use selection for day"
        },
        {
            action: "WallpaperPolicy.night",
            dayNightOnly: true,
            title: "Use selection for night"
        },
        {
            action: "WallpaperPolicy.dayEarlier",
            dayNightOnly: true,
            title: "Day −30 min"
        },
        {
            action: "WallpaperPolicy.dayLater",
            dayNightOnly: true,
            title: "Day +30 min"
        },
        {
            action: "WallpaperPolicy.nightEarlier",
            dayNightOnly: true,
            title: "Night −30 min"
        },
        {
            action: "WallpaperPolicy.nightLater",
            dayNightOnly: true,
            title: "Night +30 min"
        },
        {
            action: "WallpaperPolicy.next",
            intervalOnly: true,
            title: "Rotate now"
        },
        {
            action: "WallpaperPolicy.defaults",
            glyph: DesktopIcons.actionGlyph("reset"),
            title: "Restore policy defaults"
        },
        {
            action: "WallpaperPanel.rotation",
            glyph: "󰁍",
            title: "Back to wallpapers"
        }
    ].filter(entry => (!entry.intervalOnly || policy.mode === "interval") && (!entry.dayNightOnly || policy.mode === "dayNight") && (!entry.activeOnly || policy.mode !== "off"))
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
            if (action === "WallpaperPanel.display")
                cycleOutput();
            else if (action === "WallpaperPanel.fit")
                toggleFit();
            else if (action === "WallpaperPanel.default")
                resetWallpaper();
            else if (action === "WallpaperPanel.favorite" && policyKnown && selectedPath() !== "")
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
                const modes = runtime.constraints.wallpaperRotation.mode.values;
                setPolicy("mode", modes[(modes.indexOf(policy.mode) + 1) % modes.length]);
                break;
            }
        case "WallpaperPolicy.target":
            setPolicy("target", outputName);
            break;
        case "WallpaperPolicy.period":
            {
                const choices = runtime.constraints.wallpaperRotation.intervalMinutes.values;
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
    function triggerPolicyAction(action: string): void {
        if (!policyView) {
            if (action === "WallpaperPanel.default")
                wallpaperReset.trigger();
            else
                galleryButtons.triggerAction(action);
            return;
        }
        switch (action) {
        case "WallpaperPolicy.defaults":
            scheduleReset.trigger();
            break;
        case "WallpaperPolicy.mode":
            {
                const modes = ["off", "interval", "dayNight"];
                (wallpaperModeChoices.itemAt((modes.indexOf(policy.mode) + 1) % modes.length) as ShellChoice)?.trigger();
                break;
            }
        case "WallpaperPolicy.period":
            intervalButton.trigger();
            break;
        case "WallpaperPolicy.favorites":
            favoriteSwitch.trigger();
            break;
        case "WallpaperPolicy.collection":
        case "WallpaperPolicy.next":
            intervalActions.triggerAction(action);
            break;
        case "WallpaperPolicy.target":
        case "WallpaperPanel.rotation":
            scheduleButtons.triggerAction(action);
            break;
        default:
            (phaseRepeater.itemAt(action.startsWith("WallpaperPolicy.night") ? 1 : 0) as SchedulePhase)?.triggerAction(action);
            break;
        }
    }

    function handlePolicyKey(key: int, modifiers: int, autoRepeat: bool): bool {
        const actions = policyView ? scheduleActions : galleryPolicyActions;
        for (const entry of actions) {
            if (runtime.shellMatchesHint(entry.action, key, modifiers)) {
                if (!autoRepeat && entry.enabled !== false && (!policyView || policyActionEnabled(entry.action)))
                    triggerPolicyAction(entry.action);
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
                panel.statusText = panel.listError.text.trim() || "Could not open Wallpaper gallery";
                return;
            }
            try {
                panel.entries = JSON.parse(panel.listOutput.text);
                const position = panel.entries.indexOf(panel.currentPath);
                panel.selectedIndex = position >= 0 ? position : 0;
            } catch (error) {
                panel.statusText = "Invalid Wallpaper gallery response";
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
            title: "Wallpaper gallery"
            detail: panel.outputLabel + " · " + (panel.busy ? "Applying wallpaper…" : panel.resizeMode.toUpperCase() + " · Image / video")
            actions: [
                ShellUtilityAction {
                    id: wallpaperReset
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    icon: DesktopIcons.actionGlyph("reset")
                    title: "Default wallpaper"
                    shortcut: panel.runtime.shellHint("WallpaperPanel.default")
                    enabled: !panel.busy
                    onActivated: panel.invokePolicyAction("WallpaperPanel.default")
                }
            ]
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
                    rightMargin: panel.theme.spacing3
                }
                verticalAlignment: TextInput.AlignVCenter
                text: panel.searchText
                onTextChanged: panel.searchText = text
                color: panel.theme.textStrong
                selectionColor: panel.theme.selectionFill
                font.family: panel.runtime.fontSans
                font.pixelSize: panel.theme.fontSize(12)
                focus: false
                Keys.onPressed: event => {
                    if (event.key === panel.runtime.shellKeyCode("controls", "Escape")) {
                        if (!event.isAutoRepeat)
                            panel.leaveSearch();
                        event.accepted = true;
                    } else if (event.key === panel.runtime.shellKeyCode("controls", "Return") || event.key === panel.runtime.shellKeyCode("controls", "Enter")) {
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
                width: Math.max(1, parent.width - panel.theme.spacing3 * 2)
                elide: Text.ElideRight
                visible: searchField.text.length === 0 && !searchField.activeFocus
                text: "Search wallpapers"
                color: panel.theme.textMuted
                font.family: panel.runtime.fontSans
                font.pixelSize: panel.theme.fontSize(11)
            }
        }

        GalleryActionBar {
            id: galleryButtons
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            entries: panel.galleryPolicyActions.filter(entry => entry.action !== "WallpaperPanel.default")
            onActionRequested: action => panel.invokePolicyAction(action)
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
            height: Math.min(panel.theme.fontSize(465), Math.max(panel.theme.fontSize(220), Math.ceil(panel.filteredEntries.length / Math.max(1, gallery.columnCount)) * gallery.cellHeight))

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
                readonly property int columnCount: panel.theme.galleryColumns(width)
                cellWidth: width / columnCount
                cellHeight: panel.theme.galleryCellHeight(cellWidth)
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
                        clipContentToShape: true

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
                            height: Math.max(32, panel.theme.fontSize(34))
                            color: panel.theme.surface

                            Row {
                                anchors {
                                    fill: parent
                                    leftMargin: panel.theme.spacing2
                                    rightMargin: panel.theme.spacing2
                                }
                                spacing: panel.theme.spacing1
                                Text {
                                    width: Math.max(1, parent.width - stateLabel.implicitWidth - favoriteMark.width - parent.spacing * 2)
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
                                    text: entry.applied ? "󰄬" : ""
                                    color: panel.theme.positive
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: panel.theme.iconSmall
                                }
                                Text {
                                    id: favoriteMark
                                    readonly property bool marked: panel.favoritePaths.includes(entry.modelData)
                                    visible: marked
                                    width: marked ? panel.theme.iconSmall + panel.theme.spacing1 : 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰋑"
                                    color: panel.theme.readableRoleColor("wallpaper")
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: panel.theme.iconSmall
                                }
                            }
                        }

                        StateLayer {
                            id: cardPress
                            theme: panel.theme
                            motion: panel.motion
                            selected: entry.current
                            cornerRadius: panel.theme.radiusMedium
                            Accessible.name: entry.modelData.slice(entry.modelData.lastIndexOf("/") + 1) + (entry.applied ? ", active wallpaper" : "")
                            onActivated: panel.activateThumbnail(entry.index)
                        }

                        // Match the Theme Picker's focus outline. The frame
                        // must sit above the preview image, not behind it.
                        SquircleSurface {
                            anchors.fill: parent
                            visible: entry.current
                            cornerRadius: panel.theme.radiusMedium
                            exponent: panel.theme.squircleExponent
                            borderColor: panel.theme.choiceColor
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
                clipContentToShape: true

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
            eyebrow: "Wallpaper gallery"
            title: "Wallpaper schedule"
            detail: "One session schedule · selected target " + panel.outputLabel
            actions: [
                ShellUtilityAction {
                    id: scheduleReset
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    icon: DesktopIcons.actionGlyph("reset")
                    title: "Restore schedule defaults"
                    shortcut: panel.runtime.shellHint("WallpaperPolicy.defaults")
                    enabled: panel.policyActionEnabled("WallpaperPolicy.defaults")
                    onActivated: panel.invokePolicyAction("WallpaperPolicy.defaults")
                }
            ]
        }
        ShellSurface {
            width: parent.width
            height: modeRow.implicitHeight + panel.theme.spacing3 * 2
            theme: panel.theme
            motion: panel.motion
            surfaceLayer: ShellSurface.Group
            cornerRadius: panel.theme.radiusMedium
            Column {
                id: modeRow
                width: parent.width - panel.theme.spacing3 * 2
                anchors.centerIn: parent
                spacing: panel.theme.spacing2
                Row {
                    width: parent.width
                    spacing: panel.theme.spacing2
                    ShellText {
                        width: Math.max(1, parent.width - cycleHint.implicitWidth - parent.spacing)
                        runtime: panel.runtime
                        theme: panel.theme
                        text: "Schedule mode"
                        textRole: ShellText.Section
                        wrapMode: Text.WordWrap
                    }
                    KeyHint {
                        id: cycleHint
                        runtime: panel.runtime
                        theme: panel.theme
                        shortcut: panel.runtime.shellHint("WallpaperPolicy.mode")
                        label: "Cycle"
                        compact: true
                    }
                }
                Flow {
                    id: modeChoices
                    width: parent.width
                    spacing: Math.max(2, panel.theme.spacing1 / 2)
                    readonly property int columns: width >= panel.theme.fontSize(420) ? Math.max(1, wallpaperModeChoices.count) : 1
                    Repeater {
                        id: wallpaperModeChoices
                        model: panel.runtime.constraints.wallpaperRotation.mode.values.map(mode => ({
                                    id: mode,
                                    title: ({
                                            off: "Off",
                                            interval: "Interval",
                                            dayNight: "Day / night"
                                        })[mode],
                                    glyph: ({
                                            off: "󰜺",
                                            interval: "󰥔",
                                            dayNight: "󰖔"
                                        })[mode]
                                }))
                        delegate: ShellChoice {
                            required property int index
                            required property var modelData
                            width: Math.floor((modeChoices.width - (modeChoices.columns - 1) * modeChoices.spacing) / modeChoices.columns)
                            height: Math.max(panel.theme.fontSize(58), implicitHeight)
                            runtime: panel.runtime
                            theme: panel.theme
                            motion: panel.motion
                            icon: modelData.glyph
                            title: modelData.title
                            compact: true
                            joined: modeChoices.columns > 1
                            choices: wallpaperModeChoices
                            choiceIndex: index
                            active: panel.policy.mode === modelData.id
                            enabled: panel.policyActionEnabled("WallpaperPolicy.mode")
                            onActivated: if (panel.policy.mode !== modelData.id)
                                panel.setPolicy("mode", modelData.id)
                        }
                    }
                }
                ShellText {
                    width: parent.width
                    runtime: panel.runtime
                    theme: panel.theme
                    text: !panel.policyKnown ? "Reading schedule…" : panel.policy.mode === "off" ? "Manual wallpaper selection" : panel.policy.mode === "interval" ? "Change after a fixed interval" : "Change at daily boundaries"
                    textRole: ShellText.Supporting
                    wrapMode: Text.WordWrap
                }
            }
        }
        PanelStatus {
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            message: panel.policyError || (panel.policyBusy && panel.activePolicyCommand !== "status" ? "Applying schedule…" : "")
            motion: panel.motion
            phase: panel.policyError.length > 0 ? "error" : "busy"
            visible: message.length > 0
            height: visible ? implicitHeight : 0
        }
        ShellSurface {
            id: intervalCard
            visible: panel.policyKnown && panel.policy.mode === "interval"
            width: parent.width
            height: intervalContent.implicitHeight + panel.theme.spacing3 * 2
            theme: panel.theme
            motion: panel.motion
            surfaceLayer: ShellSurface.Group
            cornerRadius: panel.theme.radiusLarge
            property double clockSeconds: Date.now() / 1000
            Timer {
                running: panel.open && panel.policyView && intervalCard.visible
                interval: 1000
                repeat: true
                triggeredOnStart: true
                onTriggered: intervalCard.clockSeconds = Date.now() / 1000
            }
            Column {
                id: intervalContent
                width: parent.width - panel.theme.spacing3 * 2
                anchors.centerIn: parent
                spacing: panel.theme.spacing3
                Row {
                    width: parent.width
                    spacing: panel.theme.spacing2
                    Column {
                        width: Math.max(1, parent.width - intervalButton.width - parent.spacing)
                        anchors.verticalCenter: parent.verticalCenter
                        ShellText {
                            runtime: panel.runtime
                            theme: panel.theme
                            text: panel.nextDue > 0 ? Math.max(0, Math.ceil((panel.nextDue - intervalCard.clockSeconds) / 60)) + " min" : "Not scheduled"
                            textRole: ShellText.Display
                            color: panel.theme.readableRoleColor("wallpaper")
                        }
                        ShellText {
                            runtime: panel.runtime
                            theme: panel.theme
                            text: panel.nextDue > 0 ? "Next change · " + ClockFormatting.wallClock(new Date(panel.nextDue * 1000)) : "No next change reported"
                            textRole: ShellText.Supporting
                        }
                    }
                    ShellAction {
                        id: intervalButton
                        width: implicitWidth
                        height: implicitHeight
                        anchors.verticalCenter: parent.verticalCenter
                        runtime: panel.runtime
                        theme: panel.theme
                        motion: panel.motion
                        compact: true
                        horizontalCompact: true
                        title: panel.policy.intervalMinutes + " min interval"
                        icon: "󰥔"
                        shortcut: panel.runtime.shellHint("WallpaperPolicy.period")
                        enabled: panel.policyActionEnabled("WallpaperPolicy.period")
                        onActivated: panel.invokePolicyAction("WallpaperPolicy.period")
                    }
                }
                LevelTrack {
                    width: parent.width
                    theme: panel.theme
                    motion: panel.motion
                    known: panel.nextDue > 0
                    fraction: Math.max(0, Math.min(1, (panel.nextDue - intervalCard.clockSeconds) / (panel.policy.intervalMinutes * 60)))
                }
                Row {
                    width: parent.width
                    spacing: panel.theme.spacing2
                    ShellText {
                        width: Math.max(1, parent.width - favoriteSwitch.width - parent.spacing)
                        anchors.verticalCenter: parent.verticalCenter
                        runtime: panel.runtime
                        theme: panel.theme
                        text: "Favourites only"
                        textRole: ShellText.Action
                        wrapMode: Text.WordWrap
                    }
                    ShellAction {
                        id: favoriteSwitch
                        width: implicitWidth
                        height: implicitHeight
                        runtime: panel.runtime
                        theme: panel.theme
                        motion: panel.motion
                        title: "Schedule favourite wallpapers only"
                        iconOnly: true
                        switchControl: true
                        compact: true
                        active: panel.policy.favoritesOnly
                        shortcut: panel.runtime.shellHint("WallpaperPolicy.favorites")
                        enabled: panel.policyActionEnabled("WallpaperPolicy.favorites")
                        onActivated: panel.invokePolicyAction("WallpaperPolicy.favorites")
                    }
                }
                GalleryActionBar {
                    id: intervalActions
                    width: parent.width
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    entries: panel.scheduleActions.filter(entry => ["WallpaperPolicy.collection", "WallpaperPolicy.next"].includes(entry.action)).map(entry => Object.assign({}, entry, {
                            enabled: panel.policyActionEnabled(entry.action)
                        }))
                    onActionRequested: action => panel.invokePolicyAction(action)
                }
            }
        }

        ShellSurface {
            visible: panel.policyKnown && panel.policy.mode === "dayNight"
            width: parent.width
            height: dailyContent.implicitHeight + panel.theme.spacing3 * 2
            theme: panel.theme
            motion: panel.motion
            surfaceLayer: ShellSurface.Group
            cornerRadius: panel.theme.radiusLarge
            Column {
                id: dailyContent
                width: parent.width - panel.theme.spacing3 * 2
                anchors.centerIn: parent
                spacing: panel.theme.spacing3
                ShellText {
                    width: parent.width
                    runtime: panel.runtime
                    theme: panel.theme
                    text: panel.policyPhase ? "Current phase · " + panel.policyPhase : "Daily schedule"
                    textRole: ShellText.Section
                    wrapMode: Text.WordWrap
                }
                ScheduleBand {
                    width: parent.width
                    height: implicitHeight
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    label: "Night wallpaper phase"
                    startMinute: panel.policy.nightStart
                    endMinute: panel.policy.dayStart
                    phaseColor: panel.theme.roleColor("night")
                }
                Flow {
                    id: phaseFlow
                    width: parent.width
                    spacing: panel.theme.spacing2
                    readonly property int columns: width >= panel.theme.fontSize(480) ? 2 : 1
                    Repeater {
                        id: phaseRepeater
                        model: panel.open && panel.policyView && panel.policy.mode === "dayNight" ? 2 : 0
                        delegate: SchedulePhase {}
                    }
                }
                MarqueeText {
                    width: parent.width
                    text: "Selected wallpaper · " + (panel.scheduleCandidate ? panel.scheduleCandidate.split("/").pop() : "None")
                    color: panel.theme.textMuted
                    font.family: panel.runtime.fontSans
                    font.pixelSize: panel.theme.fontSupporting
                }
            }
        }
        GalleryActionBar {
            id: scheduleButtons
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            entries: panel.scheduleActions.filter(entry => ["WallpaperPolicy.target", "WallpaperPanel.rotation"].includes(entry.action)).map(entry => Object.assign({}, entry, {
                    enabled: panel.policyActionEnabled(entry.action)
                }))
            onActionRequested: action => panel.invokePolicyAction(action)
        }
        ShellText {
            visible: panel.policy.mode !== "off"
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            text: "Manual selections last until the next scheduled change."
            wrapMode: Text.WordWrap
            color: panel.theme.textMuted
        }
    }
    component SchedulePhase: ShellSurface {
        id: phase
        required property int index
        readonly property bool night: index === 1
        readonly property string path: night ? panel.policy.nightWallpaper : panel.policy.dayWallpaper
        readonly property string role: night ? "night" : "daylight"
        readonly property string actionPrefix: night ? "WallpaperPolicy.night" : "WallpaperPolicy.day"
        property string posterPath: ""
        property string requestedPath: ""
        width: (phaseFlow.width - (phaseFlow.columns - 1) * phaseFlow.spacing) / phaseFlow.columns
        height: phaseInfo.implicitHeight + panel.theme.spacing3 * 2
        theme: panel.theme
        motion: panel.motion
        surfaceLayer: ShellSurface.Control
        cornerRadius: panel.theme.radiusMedium
        function triggerAction(action: string): void {
            if (action.endsWith("Earlier"))
                phaseStepper.decrease();
            else if (action.endsWith("Later"))
                phaseStepper.increase();
            else
                phaseChoose.trigger();
        }
        function refreshPoster(): void {
            if (posterProbe.running)
                return;
            posterPath = "";
            requestedPath = path;
            if (path && panel.runtime.wallpaperLibrary)
                posterProbe.exec([panel.runtime.wallpaperLibrary, "thumbnail", path]);
        }
        onPathChanged: refreshPoster()
        Component.onCompleted: refreshPoster()
        Process {
            id: posterProbe
            stdout: StdioCollector {
                id: phasePosterOutput
            }
            onExited: (code, status) => {
                if (phase.requestedPath !== phase.path)
                    phase.refreshPoster();
                else if (code === 0)
                    phase.posterPath = phasePosterOutput.text.trim();
            }
        }
        Column {
            id: phaseInfo
            width: parent.width - panel.theme.spacing3 * 2
            anchors.centerIn: parent
            spacing: panel.theme.spacing2
            ShellText {
                runtime: panel.runtime
                theme: panel.theme
                text: phase.night ? "Night" : "Day"
                textRole: ShellText.Section
                color: panel.theme.readableRoleColor(phase.role)
            }
            ShellSurface {
                width: parent.width
                height: Math.min(panel.theme.fontSize(150), width * 0.56)
                theme: panel.theme
                motion: panel.motion
                cornerRadius: panel.theme.radiusSmall
                clipContentToShape: true
                Image {
                    anchors.fill: parent
                    source: phase.posterPath ? "file://" + phase.posterPath : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(480, 300)
                }
                ShellText {
                    anchors.centerIn: parent
                    visible: !phase.posterPath
                    runtime: panel.runtime
                    theme: panel.theme
                    text: phase.path ? "Preview unavailable" : "Not selected"
                    textRole: ShellText.Supporting
                }
            }
            MarqueeText {
                width: parent.width
                text: phase.path ? phase.path.split("/").pop() : "No wallpaper selected"
                font.family: panel.runtime.fontSans
                font.pixelSize: panel.theme.fontSupporting
                color: panel.theme.textMuted
            }
            ShellStepper {
                id: phaseStepper
                anchors.horizontalCenter: parent.horizontalCenter
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                title: "Start time"
                readback: panel.timeLabel(phase.night ? panel.policy.nightStart : panel.policy.dayStart)
                decreaseShortcut: panel.runtime.shellHint(phase.actionPrefix + "Earlier")
                increaseShortcut: panel.runtime.shellHint(phase.actionPrefix + "Later")
                canDecrease: panel.policyActionEnabled(phase.actionPrefix + "Earlier")
                canIncrease: panel.policyActionEnabled(phase.actionPrefix + "Later")
                onDecreased: panel.invokePolicyAction(phase.actionPrefix + "Earlier")
                onIncreased: panel.invokePolicyAction(phase.actionPrefix + "Later")
            }
            ShellAction {
                id: phaseChoose
                width: parent.width
                height: implicitHeight
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                horizontalCompact: true
                icon: "󰋩"
                title: "Use selection"
                shortcut: panel.runtime.shellHint(phase.actionPrefix)
                enabled: panel.policyActionEnabled(phase.actionPrefix)
                onActivated: panel.invokePolicyAction(phase.actionPrefix)
            }
        }
    }
}

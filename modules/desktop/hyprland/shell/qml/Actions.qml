import QtQuick
import Quickshell
import Quickshell.Io
import "ActionCatalog.js" as ActionCatalog
import "DesktopIcons.js" as DesktopIcons

QtObject {
    id: actions
    property bool wallpaperSpectrumEnabled: false
    property bool musicReactiveEnabled: false
    signal statusInspectionRequested
    readonly property var paletteCommands: ActionCatalog.commands({
        wallpaperSpectrumEnabled: wallpaperSpectrumEnabled,
        musicReactiveEnabled: musicReactiveEnabled,
        seekSeconds: mediaState.seekSeconds,
        nightLightStep: runtime.constraints.nightLight.temperature.shortcutStep,
        rememberRecents: launcher.rememberRecents,
        terminal: runtime.terminal,
        audioAvailable: systemState.audioAvailable,
        brightnessAvailable: brightnessState.supported,
        glyphFor: DesktopIcons.glyphFor
    })
    required property RuntimeConfig runtime
    required property ScreenRouter screenRouter
    required property AmbientBar ambientBar
    required property ShellExpansionState expansionState
    property bool themePanelOpen: false
    property bool sessionPanelOpen: false
    property bool resourcesPanelOpen: false
    property bool wallpaperPanelOpen: false
    property bool recordingsPanelOpen: false
    required property ShortcutCheatsheet cheatsheet
    required property CommandPalette launcher
    required property ClipboardPanel clipboardPanel
    property bool mixerDetailOpen: false
    property bool systemDetailOpen: false
    required property OverviewPanel overviewPanel
    required property MediaState mediaState
    required property SystemState systemState
    required property BrightnessState brightnessState
    required property NightLightState nightLightState
    required property NotificationState notificationState
    required property Motion motion
    required property AppearancePreferences appearance
    required property SceneState scenes
    required property ResourceState resources
    required property WeatherState weather
    required property ScreenshotPicker capture

    // Reset is a shell operation, independent of the lifetime of Controls.
    property bool resetRunning: false
    property string resetStatus: ""
    property var resetSteps: []
    property var resetErrors: []
    property int resetIndex: 0
    property bool waitingForNightLightReset: false
    property bool resetTimedOut: false
    property Timer resetDeadline: Timer {
        interval: 15000
        repeat: false
        onTriggered: {
            if (!actions.resetRunning)
                return;
            if (actions.waitingForNightLightReset) {
                actions.waitingForNightLightReset = false;
                actions.resetErrors = [...actions.resetErrors, "Night Light timed out"];
                actions.resetNextPreference();
            } else {
                actions.resetTimedOut = true;
                actions.preferenceReset.signal(9);
            }
        }
    }

    function resetStepSucceeded(step: var, code: int, output: string): bool {
        if (code !== 0)
            return false;
        if (step.expectedText !== undefined)
            return output.trim() === step.expectedText;
        if (step.expectedField !== undefined) {
            try {
                const value = JSON.parse(output)[step.expectedField];
                return typeof value === "number" && typeof step.expectedValue === "number" ? Math.abs(value - step.expectedValue) < 0.00001 : value === step.expectedValue;
            } catch (_) {
                return false;
            }
        }
        return true;
    }

    property Process preferenceReset: Process {
        stdout: StdioCollector {
            id: resetOutput
        }
        onExited: (code, status) => {
            actions.resetDeadline.stop();
            if (actions.resetTimedOut || !actions.resetStepSucceeded(actions.resetSteps[actions.resetIndex], code, resetOutput.text))
                actions.resetErrors = [...actions.resetErrors, actions.resetSteps[actions.resetIndex].label];
            actions.resetIndex++;
            actions.resetNextPreference();
        }
    }

    property Connections nightLightReset: Connections {
        target: actions.nightLightState
        function onResetFinished(success, reason) {
            if (!actions.waitingForNightLightReset)
                return;
            actions.resetDeadline.stop();
            actions.waitingForNightLightReset = false;
            if (!success)
                actions.resetErrors = [...actions.resetErrors, "Night Light"];
            actions.resetNextPreference();
        }
    }

    function restoreDesktopDefaults(): void {
        if (resetRunning)
            return;
        resetRunning = true;
        resetStatus = "Restoring defaults…";
        scenes.stop();
        appearance.resetToDeclared(false);
        motion.resetToDeclared(false);
        capture.resetToDeclared();
        weather.resetLocation();
        weather.resetUnits();
        systemState.resetSessionPreferences();
        notificationState.resetToDeclared();
        resources.resetSampling();

        resetErrors = [];
        if (!runtime.hyprctl)
            resetErrors.push("Compositor unavailable");
        if (!runtime.vhsControl)
            resetErrors.push("VHS unavailable");
        const steps = appearance.resetOperations().concat(motion.resetOperations());
        if (runtime.captureLocations)
            steps.push({
                label: "Capture locations",
                command: [runtime.captureLocations, "reset"]
            });
        if (runtime.wallpaperLibrary) {
            for (const output of Quickshell.screens.map(screen => screen.name).filter(name => !!name).concat(["all"]))
                steps.push({
                    label: "Wallpaper (" + output + ")",
                    command: [runtime.wallpaperLibrary, "reset", output]
                });
        } else {
            resetErrors.push("Wallpaper gallery unavailable");
        }
        if (runtime.wallpaperPolicy)
            steps.push({
                label: "Wallpaper schedule",
                command: [runtime.wallpaperPolicy, "reset"]
            });
        resetSteps = steps;
        resetIndex = 0;
        if (runtime.nightLightControl) {
            waitingForNightLightReset = true;
            resetDeadline.restart();
            nightLightState.resetToDeclared();
        } else {
            resetNextPreference();
        }
    }

    function resetNextPreference(): void {
        if (resetIndex >= resetSteps.length) {
            resetRunning = false;
            resetStatus = resetErrors.length > 0 ? "Could not restore: " + resetErrors.join(", ") + "." : "Defaults restored";
            return;
        }
        resetTimedOut = false;
        resetDeadline.restart();
        preferenceReset.exec(resetSteps[resetIndex].command);
    }

    signal frozenCaptureRequested(bool copy)
    signal recordingSelectionRequested
    signal wallpaperSpectrumToggleRequested
    signal musicReactiveToggleRequested
    property StdioCollector recordingStatusOutput: StdioCollector {}
    property Process recordingStatus: Process {
        stdout: actions.recordingStatusOutput
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                return;
            if (actions.recordingStatusOutput.text.trim() === "active") {
                Quickshell.execDetached([actions.runtime.recordingToggle, "stop"]);
            } else {
                actions.recordingSelectionRequested();
            }
        }
    }

    function hideTransient(except: string): void {
        if (except !== "cheatsheet" && cheatsheet.open)
            cheatsheet.hide();
        if (except !== "launcher" && launcher.open)
            launcher.hide();
        if (except !== "clipboard" && clipboardPanel.open)
            clipboardPanel.hide();
        if (except !== "overview" && overviewPanel.open)
            overviewPanel.hide();
        // All hub tabs use one expansion surface. Switching between them must
        // not close/reopen the hub; other transient panels still dismiss it.
        if (!["media", "system", "calendar", "weather", "activity"].includes(except) && expansionState.hasCurrent)
            expansionState.close();
    }

    function toggleCheatsheet(): void {
        if (!cheatsheet.open)
            hideTransient("cheatsheet");
        cheatsheet.toggle();
    }

    function toggleLauncher(): void {
        if (!launcher.open)
            hideTransient("launcher");
        launcher.toggle();
    }

    function toggleClipboard(): void {
        if (!clipboardPanel.open)
            hideTransient("clipboard");
        clipboardPanel.toggle();
    }

    function toggleOverview(): void {
        if (!overviewPanel.open)
            hideTransient("overview");
        overviewPanel.toggle();
    }

    function toggleAudioMixer(): void {
        toggleSystemDetail("mixer", mixerDetailOpen);
    }

    function lockSession(): void {
        if (runtime.lockSession.length > 0)
            Quickshell.execDetached([runtime.lockSession]);
    }

    function toggleMedia(targetScreen: var, origin: var): void {
        const screen = targetScreen || screenRouter.focusedScreen;
        if (!screen)
            return;

        const geometry = origin || ambientBar.originFor(screen, "media");
        const opening = !(expansionState.hasCurrent && expansionState.currentName === "media" && expansionState.screen === screen);
        if (opening)
            hideTransient("media");

        expansionState.toggle("media", screen, geometry.center, geometry.width, geometry.height, "");
    }

    function mediaPlayPause(): void {
        mediaState.togglePlaying();
    }

    function mediaNext(): void {
        mediaState.next();
    }

    function mediaPrevious(): void {
        mediaState.previous();
    }

    function mediaSeekForward(): void {
        mediaState.seekStep(1);
    }

    function mediaSeekBackward(): void {
        mediaState.seekStep(-1);
    }

    function mediaToggleShuffle(): void {
        mediaState.toggleShuffle();
    }

    function mediaCyclePlayer(): void {
        mediaState.cyclePlayer();
    }

    function showSystem(targetScreen: var, origin: var, view: string): void {
        const screen = targetScreen || screenRouter.focusedScreen;
        if (!screen)
            return;

        const geometry = origin || ambientBar.originFor(screen, "system");
        hideTransient("system");
        expansionState.show("system", screen, geometry.center, geometry.width, geometry.height, view || "");
    }

    function toggleSystem(targetScreen: var, origin: var): void {
        const screen = targetScreen || screenRouter.focusedScreen;
        if (!screen)
            return;

        const geometry = origin || ambientBar.originFor(screen, "system");
        const showingSystem = expansionState.hasCurrent && expansionState.currentName === "system" && expansionState.screen === screen;
        if (showingSystem && systemDetailOpen) {
            // The Controls shortcut returns from any nested detail, including
            // views opened directly from the Controls page.
            showSystem(screen, origin, "controls");
            return;
        }
        if (!showingSystem)
            hideTransient("system");

        expansionState.toggle("system", screen, geometry.center, geometry.width, geometry.height, "");
    }

    function toggleCalendar(targetScreen: var, origin: var): void {
        const screen = targetScreen || screenRouter.focusedScreen;
        if (!screen)
            return;

        const geometry = origin || ambientBar.originFor(screen, "calendar");
        const opening = !(expansionState.hasCurrent && expansionState.currentName === "calendar" && expansionState.screen === screen);
        if (opening)
            hideTransient("calendar");

        expansionState.toggle("calendar", screen, geometry.center, geometry.width, geometry.height, "");
    }

    function toggleWeather(targetScreen: var, origin: var): void {
        const screen = targetScreen || screenRouter.focusedScreen;
        if (!screen)
            return;

        const geometry = origin || ambientBar.originFor(screen, "calendar");
        const opening = !(expansionState.hasCurrent && expansionState.currentName === "weather" && expansionState.screen === screen);
        if (opening)
            hideTransient("weather");

        expansionState.toggle("weather", screen, geometry.center, geometry.width, geometry.height, "");
    }

    // Repeating a detail shortcut closes the hub; it must not navigate back
    // to the underlying Controls tab. A detail dismissed with Escape can reopen.
    function toggleSystemDetail(view: string, detailOpen: bool): void {
        if (expansionState.hasCurrent && expansionState.currentName === "system" && detailOpen) {
            expansionState.close();
            return;
        }
        showSystem(null, null, view);
    }

    function showResources(): void {
        toggleSystemDetail("resources", resourcesPanelOpen);
    }

    function showTheme(): void {
        toggleSystemDetail("theme", themePanelOpen);
    }

    function showWallpaper(): void {
        toggleSystemDetail("wallpaper", wallpaperPanelOpen);
    }

    function showCaptures(): void {
        toggleSystemDetail("recordings", recordingsPanelOpen);
    }

    function showSession(): void {
        toggleSystemDetail("session", sessionPanelOpen);
    }

    function showNotifications(targetScreen: var, origin: var): void {
        if (notificationState.locked)
            return;
        const screen = targetScreen || screenRouter.focusedScreen;
        if (!screen)
            return;

        const geometry = origin || ambientBar.originFor(screen, "activity");
        notificationState.requestFocusLatest();
        notificationState.hidePopup();
        hideTransient("activity");
        expansionState.show("activity", screen, geometry.center, geometry.width, geometry.height, "");
    }

    function toggleNotifications(targetScreen: var, origin: var): void {
        if (notificationState.locked)
            return;
        const screen = targetScreen || screenRouter.focusedScreen;
        if (!screen)
            return;

        const geometry = origin || ambientBar.originFor(screen, "activity");
        const opening = !(expansionState.hasCurrent && expansionState.currentName === "activity" && expansionState.screen === screen);
        if (opening) {
            notificationState.requestFocusLatest();
            notificationState.hidePopup();
            hideTransient("activity");
        }
        expansionState.toggle("activity", screen, geometry.center, geometry.width, geometry.height, "");
    }

    function clearNotifications(): void {
        notificationState.clearAll();
    }

    function volumeUp(): void {
        systemState.adjustVolume(systemState.volumeStep);
    }

    function volumeDown(): void {
        systemState.adjustVolume(-systemState.volumeStep);
    }

    function toggleMute(): void {
        systemState.toggleMute();
    }

    function brightnessUp(): void {
        brightnessState.adjust(brightnessState.adjustmentStep);
    }

    function brightnessDown(): void {
        brightnessState.adjust(-brightnessState.adjustmentStep);
    }

    function toggleRecording(): void {
        if (runtime.recordingToggle.length > 0 && !recordingStatus.running)
            recordingStatus.exec([runtime.recordingToggle, "status"]);
    }

    function captureScreenshot(copy: bool, target: string): void {
        hideTransient("");
        // Share Hyprland's screenshot backend for region and active-output capture.
        Quickshell.execDetached(copy ? ["grimblast", "copy", target] : ["grimblast", "--notify", "save", target]);
    }

    function pickColour(): void {
        hideTransient("");
        if (runtime.colourPicker.length > 0)
            Quickshell.execDetached([runtime.colourPicker]);
    }

    function captureRegion(copy: bool): void {
        // Snapshot the scene before hiding menus and other transient layers.
        frozenCaptureRequested(copy);
    }

    function invokeCommand(commandId: string): void {
        if (commandId === "status.inspect")
            statusInspectionRequested();
        else if (commandId === "session.lock")
            lockSession();
        else if (commandId === "audio.mixer")
            toggleAudioMixer();
        else if (commandId === "media.spectrumSettings")
            showSystem(null, null, "spectrum");
        else if (commandId === "media.wallpaperSpectrum")
            wallpaperSpectrumToggleRequested();
        else if (commandId === "media.reactiveShell")
            musicReactiveToggleRequested();
        else if (commandId === "overview.toggle")
            toggleOverview();
        else if (commandId === "clipboard.toggle")
            toggleClipboard();
        else if (commandId === "nightLight.toggle")
            nightLightState.toggle();
        else if (commandId === "nightLight.warmer")
            nightLightState.warmer();
        else if (commandId === "nightLight.cooler")
            nightLightState.cooler();
        else if (commandId === "colour.pick")
            pickColour();
        else if (commandId === "capture.liveRegion")
            captureScreenshot(true, "area");
        else if (commandId === "capture.region")
            captureRegion(true);
        else if (commandId === "capture.saveRegion")
            captureRegion(false);
        else if (commandId === "capture.output")
            captureScreenshot(true, "output");
        else if (commandId === "capture.saveOutput")
            captureScreenshot(false, "output");
        else if (commandId === "capture.recordToggle")
            toggleRecording();
        else if (commandId === "media.toggle")
            toggleMedia();
        else if (commandId === "media.playPause")
            mediaPlayPause();
        else if (commandId === "media.next")
            mediaNext();
        else if (commandId === "media.previous")
            mediaPrevious();
        else if (commandId === "media.seekForward")
            mediaSeekForward();
        else if (commandId === "media.seekBackward")
            mediaSeekBackward();
        else if (commandId === "media.shuffle")
            mediaToggleShuffle();
        else if (commandId === "media.cyclePlayer")
            mediaCyclePlayer();
        else if (commandId === "controls.toggle")
            toggleSystem();
        else if (commandId === "controls.network")
            showSystem(null, null, "network");
        else if (commandId === "controls.bluetooth")
            showSystem(null, null, "bluetooth");
        else if (commandId === "home.toggle")
            toggleCalendar();
        else if (commandId === "weather.toggle")
            toggleWeather();
        else if (commandId === "resources.toggle")
            showResources();
        else if (commandId === "theme.toggle")
            showTheme();
        else if (commandId === "wallpaper.toggle")
            showWallpaper();
        else if (commandId === "captures.library")
            showCaptures();
        else if (commandId === "session.toggle")
            showSession();
        else if (commandId === "notifications.toggle")
            toggleNotifications();
        else if (commandId === "notifications.clear")
            clearNotifications();
        else if (commandId === "shortcuts.toggle")
            toggleCheatsheet();
        else if (commandId === "animations.toggle")
            toggleAnimations();
        else if (commandId === "audio.volumeUp")
            volumeUp();
        else if (commandId === "audio.volumeDown")
            volumeDown();
        else if (commandId === "audio.toggleMute")
            toggleMute();
        else if (commandId === "brightness.up")
            brightnessUp();
        else if (commandId === "brightness.down")
            brightnessDown();
        else if (commandId === "terminal.open")
            launchTerminal();
    }

    function toggleAnimations(): void {
        motion.toggle();
    }

    function launchTerminal(): void {
        if (runtime.terminal.length === 0)
            return;

        Quickshell.execDetached([runtime.terminal]);
    }
}

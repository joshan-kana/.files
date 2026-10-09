import QtQuick
import Quickshell

QtObject {
    required property RuntimeConfig runtime
    required property ScreenRouter screenRouter
    required property AmbientBar ambientBar
    required property ShellExpansionState expansionState
    required property ShortcutCheatsheet cheatsheet
    required property CommandPalette launcher
    required property ClipboardPanel clipboardPanel
    required property AudioMixerPanel audioMixerPanel
    required property OverviewPanel overviewPanel
    required property MediaState mediaState
    required property SystemState systemState
    required property BrightnessState brightnessState
    required property NotificationState notificationState
    required property NotificationPopup notificationPopup
    required property Motion motion

    function hideTransient(except: string): void {
        if (except !== "cheatsheet" && cheatsheet.open)
            cheatsheet.hide();
        if (except !== "launcher" && launcher.open)
            launcher.hide();
        if (except !== "clipboard" && clipboardPanel.open)
            clipboardPanel.hide();
        if (except !== "audio" && audioMixerPanel.open)
            audioMixerPanel.hide();
        if (except !== "overview" && overviewPanel.open)
            overviewPanel.hide();
        if (except !== "media" && expansionState.hasCurrent && expansionState.currentName === "media")
            expansionState.close();
        if (except !== "system" && expansionState.hasCurrent && expansionState.currentName === "system")
            expansionState.close();
        if (except !== "calendar" && expansionState.hasCurrent && expansionState.currentName === "calendar")
            expansionState.close();
        if (except !== "weather" && expansionState.hasCurrent && expansionState.currentName === "weather")
            expansionState.close();
        if (except !== "activity" && expansionState.hasCurrent && expansionState.currentName === "activity")
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
        if (!audioMixerPanel.open)
            hideTransient("audio");
        audioMixerPanel.toggle();
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
        const fromControls = expansionState.hasCurrent && expansionState.currentName === "system";
        if (opening)
            hideTransient("media");

        expansionState.toggle("media", screen, geometry.center, geometry.width, geometry.height, fromControls ? "controls" : "");
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
        mediaState.seek(10);
    }

    function mediaSeekBackward(): void {
        mediaState.seek(-10);
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
        const opening = !(expansionState.hasCurrent && expansionState.currentName === "system" && expansionState.screen === screen);
        if (opening)
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

    function showResources(): void {
        showSystem(null, null, "resources");
    }

    function showTheme(): void {
        showSystem(null, null, "theme");
    }

    function showSession(): void {
        showSystem(null, null, "session");
    }

    function showNotifications(targetScreen: var, origin: var): void {
        const screen = targetScreen || screenRouter.focusedScreen;
        if (!screen)
            return;

        const geometry = origin || ambientBar.originFor(screen, "activity");
        notificationPopup.concealForActivity();
        hideTransient("activity");
        expansionState.show("activity", screen, geometry.center, geometry.width, geometry.height, "");
    }

    function toggleNotifications(targetScreen: var, origin: var): void {
        const screen = targetScreen || screenRouter.focusedScreen;
        if (!screen)
            return;

        const geometry = origin || ambientBar.originFor(screen, "activity");
        const opening = !(expansionState.hasCurrent && expansionState.currentName === "activity" && expansionState.screen === screen);
        if (opening) {
            notificationPopup.concealForActivity();
            hideTransient("activity");
        }
        expansionState.toggle("activity", screen, geometry.center, geometry.width, geometry.height, "");
    }

    function clearNotifications(): void {
        notificationState.clearAll();
    }

    function volumeUp(): void {
        systemState.adjustVolume(0.05);
    }

    function volumeDown(): void {
        systemState.adjustVolume(-0.05);
    }

    function toggleMute(): void {
        systemState.toggleMute();
    }

    function brightnessUp(): void {
        brightnessState.adjust(5);
    }

    function brightnessDown(): void {
        brightnessState.adjust(-5);
    }

    function toggleRecording(): void {
        hideTransient("");
        if (runtime.recordingToggle.length > 0)
            Quickshell.execDetached([runtime.recordingToggle]);
    }

    function captureScreenshot(copy: bool, target: string): void {
        hideTransient("");
        // Share Hyprland's screenshot backend for region and active-output capture.
        Quickshell.execDetached(copy ? ["grimblast", "copy", target] : ["grimblast", "--notify", "save", target]);
    }

    function captureRegion(copy: bool): void {
        captureScreenshot(copy, "area");
    }

    function invokeCommand(commandId: string): void {
        if (commandId === "session.lock")
            lockSession();
        else if (commandId === "audio.mixer")
            toggleAudioMixer();
        else if (commandId === "overview.toggle")
            toggleOverview();
        else if (commandId === "clipboard.toggle")
            toggleClipboard();
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
        else if (commandId === "system.toggle")
            toggleSystem();
        else if (commandId === "calendar.toggle")
            toggleCalendar();
        else if (commandId === "weather.toggle")
            toggleWeather();
        else if (commandId === "resources.toggle")
            showResources();
        else if (commandId === "theme.toggle")
            showTheme();
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

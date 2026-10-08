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
    required property MediaState mediaState
    required property SystemState systemState
    required property BrightnessState brightnessState
    required property NotificationCenter notificationCenter
    required property NotificationState notificationState
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
        if (except !== "media" && expansionState.hasCurrent && expansionState.currentName === "media")
            expansionState.close();
        if (except !== "system" && expansionState.hasCurrent && expansionState.currentName === "system")
            expansionState.close();
        if (except !== "calendar" && expansionState.hasCurrent && expansionState.currentName === "calendar")
            expansionState.close();
        if (except !== "weather" && expansionState.hasCurrent && expansionState.currentName === "weather")
            expansionState.close();
        if (except !== "notifications" && notificationCenter.open)
            notificationCenter.hide();
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

    function showTheme(): void {
        showSystem(null, null, "theme");
    }

    function showSession(): void {
        showSystem(null, null, "session");
    }

    function showNotifications(): void {
        hideTransient("notifications");
        notificationCenter.show();
    }

    function toggleNotifications(): void {
        if (!notificationCenter.open)
            hideTransient("notifications");
        notificationCenter.toggle();
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

    function invokeCommand(commandId: string): void {
        if (commandId === "session.lock")
            lockSession();
        else if (commandId === "audio.mixer")
            toggleAudioMixer();
        else if (commandId === "clipboard.toggle")
            toggleClipboard();
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

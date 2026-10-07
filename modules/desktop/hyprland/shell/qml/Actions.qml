import QtQuick
import Quickshell

QtObject {
    required property QtObject runtime
    required property QtObject cheatsheet
    required property QtObject launcher
    required property QtObject clipboardPanel
    required property QtObject audioMixerPanel
    required property QtObject mediaPanel
    required property QtObject mediaState
    required property QtObject systemPanel
    required property QtObject systemState
    required property QtObject brightnessState
    required property QtObject notificationCenter
    required property QtObject notificationState
    required property QtObject motion

    function hideTransient(except: string): void {
        if (except !== "cheatsheet" && cheatsheet.open)
            cheatsheet.hide();
        if (except !== "launcher" && launcher.open)
            launcher.hide();
        if (except !== "clipboard" && clipboardPanel.open)
            clipboardPanel.hide();
        if (except !== "audio" && audioMixerPanel.open)
            audioMixerPanel.hide();
        if (except !== "media" && mediaPanel.open)
            mediaPanel.hide();
        if (except !== "system" && systemPanel.open)
            systemPanel.hide();
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

    function toggleMedia(): void {
        if (!mediaPanel.open)
            hideTransient("media");
        mediaPanel.toggle();
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

    function toggleSystem(): void {
        if (!systemPanel.open)
            hideTransient("system");
        systemPanel.toggle();
    }

    function showTheme(): void {
        hideTransient("system");
        systemPanel.showTheme();
    }

    function showSession(): void {
        hideTransient("system");
        systemPanel.showSession();
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

import QtQuick
import Quickshell

QtObject {
    required property QtObject runtime
    required property QtObject prototype
    required property QtObject cheatsheet
    required property QtObject launcher
    required property QtObject mediaPanel
    required property QtObject systemPanel
    required property QtObject systemState
    required property QtObject motion

    function showPrototype(): void {
        prototype.visible = true;
    }

    function hidePrototype(): void {
        prototype.visible = false;
    }

    function togglePrototype(): void {
        prototype.visible = !prototype.visible;
    }

    function toggleCheatsheet(): void {
        cheatsheet.toggle();
    }

    function toggleLauncher(): void {
        launcher.toggle();
    }

    function toggleMedia(): void {
        mediaPanel.toggle();
    }

    function toggleSystem(): void {
        systemPanel.toggle();
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

    function invokeCommand(commandId: string): void {
        if (commandId === "media.toggle")
            toggleMedia();
        else if (commandId === "system.toggle")
            toggleSystem();
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

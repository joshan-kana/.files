import QtQuick
import Quickshell

QtObject {
    required property QtObject runtime
    required property QtObject prototype
    required property QtObject cheatsheet
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

    function toggleAnimations(): void {
        motion.toggle();
    }

    function launchTerminal(): void {
        if (runtime.terminal.length === 0)
            return;

        Quickshell.execDetached([runtime.terminal]);
    }
}

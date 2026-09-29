import QtQuick
import Quickshell

QtObject {
    required property QtObject runtime
    required property QtObject prototype

    function showPrototype(): void {
        prototype.visible = true;
    }

    function hidePrototype(): void {
        prototype.visible = false;
    }

    function togglePrototype(): void {
        prototype.visible = !prototype.visible;
    }

    function launchTerminal(): void {
        if (runtime.terminal.length === 0)
            return;

        Quickshell.execDetached([runtime.terminal]);
    }
}

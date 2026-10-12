import QtQuick
import Quickshell.Io

QtObject {
    id: root

    required property SystemState system
    required property BrightnessState brightness
    required property RuntimeConfig runtime

    property bool ready: false
    property bool visible: false
    property string kind: ""
    property string label: ""
    property int value: 0
    property bool muted: false
    property bool keyboardLocked: false
    property string keyboardKind: ""
    property string requestedKeyboardKind: ""

    property StdioCollector keyboardOutput: StdioCollector {}
    property Process keyboardQuery: Process {
        stdout: root.keyboardOutput
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || !root.ready)
                return;
            let devices;
            try {
                devices = JSON.parse(root.keyboardOutput.text);
            } catch (error) {
                return;
            }
            const keyboards = devices.keyboards || [];
            const keyboard = keyboards.find(device => device.main && device.name !== "power-button") || keyboards.find(device => device.name !== "power-button");
            if (!keyboard)
                return;
            const kind = root.requestedKeyboardKind;
            const locked = kind === "caps" ? keyboard.capsLock : keyboard.numLock;
            if (typeof locked !== "boolean")
                return;
            root.keyboardLocked = locked;
            root.keyboardKind = kind;
            root.show("keyboard", kind === "caps" ? "CAPS LOCK" : "NUM LOCK", locked ? 100 : 0, false);
        }
    }

    function refreshKeyboardLocks(kind: string): void {
        if (kind !== "caps" && kind !== "num")
            return;
        requestedKeyboardKind = kind;
        if (runtime.hyprctl.length > 0 && !keyboardQuery.running)
            keyboardQuery.exec([runtime.hyprctl, "-j", "devices"]);
    }

    property Timer startupGate: Timer {
        interval: 800
        running: true
        repeat: false
        onTriggered: root.ready = true
    }

    property Timer hideTimer: Timer {
        interval: 900
        repeat: false
        onTriggered: root.visible = false
    }

    property Connections audioConnections: Connections {
        target: root.system

        function onVolumePercentChanged(): void {
            if (root.ready)
                root.showAudio();
        }

        function onMutedChanged(): void {
            if (root.ready)
                root.showAudio();
        }
    }

    property Connections brightnessConnections: Connections {
        target: root.brightness

        function onPercentChanged(): void {
            if (root.ready && root.brightness.initialized && root.brightness.supported)
                root.showBrightness();
        }
    }

    function show(kindName: string, text: string, amount: int, isMuted: bool): void {
        kind = kindName;
        label = text;
        value = Math.max(0, Math.min(100, amount));
        muted = isMuted;
        visible = true;
        hideTimer.restart();
    }

    function showAudio(): void {
        show("volume", system.muted ? "AUDIO // MUTED" : "VOLUME", system.volumePercent, system.muted);
    }

    function showBrightness(): void {
        show("brightness", "BRIGHTNESS", brightness.percent, false);
    }
}

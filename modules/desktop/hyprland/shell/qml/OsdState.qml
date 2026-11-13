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
    required property KeyboardState keyboard
    required property ScreenRouter screens
    property var activeScreen: null
    property var deferredFeedback: null
    readonly property int currentPriority: kind === "microphone" ? 2 : kind === "keyboard" ? 1 : 0

    property Connections keyboardConnections: Connections {
        target: root.keyboard
        function onRefreshed(reason: string): void {
            if (reason !== "caps" && reason !== "num" || !root.ready)
                return;
            const state = reason === "caps" ? root.keyboard.capsState : root.keyboard.numState;
            root.keyboardState = state;
            root.show("keyboard", reason === "caps" ? "Caps Lock" : "Num Lock", state === "on" ? 100 : 0, false);
        }
    }
    property string keyboardState: "unknown"
    function refreshKeyboardLocks(kind: string): void {
        if (kind === "caps" || kind === "num")
            keyboard.refresh(kind);
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
        onTriggered: {
            root.visible = false;
            if (root.deferredFeedback) {
                const deferred = root.deferredFeedback;
                root.deferredFeedback = null;
                root.show(deferred.kind, deferred.label, deferred.value, deferred.muted);
            }
        }
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

    property Connections microphoneConnections: Connections {
        target: root.system
        function onMicrophoneVolumePercentChanged(): void {
            if (root.ready && root.system.microphoneAvailable)
                root.showMicrophone();
        }
        function onMicrophoneMutedChanged(): void {
            if (root.ready && root.system.microphoneAvailable)
                root.showMicrophone();
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
        const incomingPriority = kindName === "microphone" ? 2 : kindName === "keyboard" ? 1 : 0;
        if (visible && kindName !== kind && incomingPriority < currentPriority) {
            deferredFeedback = {
                kind: kindName,
                label: text,
                value: amount,
                muted: isMuted
            };
            return;
        }
        kind = kindName;
        label = text;
        activeScreen = screens.focusedScreen;
        value = Math.max(0, Math.min(100, amount));
        muted = isMuted;
        visible = true;
        hideTimer.restart();
    }

    function showAudio(): void {
        show("volume", system.muted ? "Output muted" : "Output volume", system.volumePercent, system.muted);
    }

    function showMicrophone(): void {
        if (!system.microphoneAvailable)
            return;
        show("microphone", system.microphoneMuted ? "Microphone muted" : "Microphone input", system.microphoneVolumePercent, system.microphoneMuted);
    }

    function showBrightness(): void {
        show("brightness", "Brightness", brightness.percent, false);
    }
}

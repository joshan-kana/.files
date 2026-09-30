import QtQuick

QtObject {
    id: root

    required property QtObject system
    required property QtObject brightness

    property bool ready: false
    property bool visible: false
    property string kind: ""
    property string label: ""
    property int value: 0
    property bool muted: false

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
        show(
            "volume",
            system.muted ? "AUDIO // MUTED" : "VOLUME",
            system.volumePercent,
            system.muted
        );
    }

    function showBrightness(): void {
        show("brightness", "BRIGHTNESS", brightness.percent, false);
    }
}

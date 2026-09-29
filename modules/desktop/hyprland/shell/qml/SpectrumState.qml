import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: spectrum

    property bool active: false
    property bool connectionGate: true
    readonly property bool connected: socket.connected

    property var bands: []
    property real rms: 0
    property real peak: 0
    property real sub: 0
    property real bass: 0
    property real mid: 0
    property real high: 0
    property int sampleRate: 0
    property int sequence: 0

    property Socket socket: Socket {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/linux-desktop-spectrum.sock"
        connected: spectrum.active && spectrum.connectionGate

        parser: SplitParser {
            onRead: message => {
                try {
                    const frame = JSON.parse(message);
                    spectrum.sequence = frame.seq || 0;
                    spectrum.sampleRate = frame.rate || 0;
                    spectrum.rms = frame.rms || 0;
                    spectrum.peak = frame.peak || 0;
                    spectrum.sub = frame.sub || 0;
                    spectrum.bass = frame.bass || 0;
                    spectrum.mid = frame.mid || 0;
                    spectrum.high = frame.high || 0;
                    spectrum.bands = frame.bands || [];
                } catch (error) {
                    console.warn("spectrum: invalid frame:", error);
                }
            }
        }

        onError: error => {
            if (!spectrum.active)
                return;

            spectrum.connectionGate = false;
            reconnectTimer.restart();
        }
    }

    property Timer reconnectTimer: Timer {
        interval: 750
        repeat: false
        onTriggered: {
            if (spectrum.active)
                spectrum.connectionGate = true;
        }
    }

    onActiveChanged: {
        if (active) {
            connectionGate = true;
        } else {
            reconnectTimer.stop();
            bands = [];
            rms = 0;
            peak = 0;
            sub = 0;
            bass = 0;
            mid = 0;
            high = 0;
        }
    }
}

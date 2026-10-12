pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: spectrum

    property bool active: false
    property bool connectionGate: true
    readonly property Socket currentSocket: socketLoader.item as Socket
    readonly property bool connected: currentSocket ? currentSocket.connected : false

    property var bands: []
    property var targetBands: []
    property bool interpolating: false
    property bool decaying: false
    readonly property bool hasEnergy: bands.some(value => value > 0.002)
    property real rms: 0
    property real peak: 0
    property real sub: 0
    property real bass: 0
    property real mid: 0
    property real high: 0
    property int sampleRate: 0
    property real lowHz: 20
    property real highHz: 20000
    property int sequence: 0

    // Audio buffers arrive independently of display refresh. Let the scene graph
    // interpolate between samples rather than redrawing only on PipeWire callbacks.
    property FrameAnimation interpolationFrame: FrameAnimation {
        running: spectrum.interpolating && (spectrum.active || spectrum.decaying)
        onTriggered: spectrum.advanceBands(frameTime)
    }

    function updateBands(values: var): void {
        const next = values || [];
        if (bands.length !== next.length) {
            bands = next;
            targetBands = next;
            interpolating = false;
            return;
        }

        targetBands = next;
        for (let i = 0; i < next.length; i++) {
            if (Math.abs(next[i] - bands[i]) > 0.002) {
                interpolating = true;
                return;
            }
        }

        // Avoid repainting a static spectrum for every silent audio buffer.
        interpolating = false;
    }

    function advanceBands(frameTime: real): void {
        const delta = Math.min(Math.max(frameTime, 0), 0.05);
        if (delta === 0)
            return;

        // Preserve the last audio frame as it settles after the socket closes.
        // The shorter live interpolation remains unchanged while playing.
        const values = [];
        let maxDifference = 0;
        const bassEnd = targetBands.length * Math.log(250 / Math.max(1, lowHz)) / Math.log(Math.max(2, highHz / Math.max(1, lowHz)));
        for (let i = 0; i < targetBands.length; i++) {
            const lowBand = i <= bassEnd;
            // Kick transients should arrive immediately and fall cleanly.
            // Higher bands retain a softer but still responsive decay.
            const rate = decaying ? 10 : lowBand ? (targetBands[i] > bands[i] ? 320 : 110) : (targetBands[i] > bands[i] ? 120 : 45);
            const blend = 1 - Math.exp(-delta * rate);
            const value = bands[i] + (targetBands[i] - bands[i]) * blend;
            values.push(value);
            maxDifference = Math.max(maxDifference, Math.abs(targetBands[i] - value));
        }

        bands = maxDifference < 0.002 ? targetBands : values;
        if (maxDifference < 0.002) {
            interpolating = false;
            if (decaying) {
                decaying = false;
                bands = [];
                targetBands = [];
            }
        }
    }

    property Component socketComponent: Component {
        Socket {
            id: spectrumSocket

            path: Quickshell.env("XDG_RUNTIME_DIR") + "/linux-desktop-spectrum.sock"
            connected: false

            Component.onCompleted: Qt.callLater(() => {
                if (spectrum.active && spectrum.socketLoader.item === spectrumSocket)
                    spectrumSocket.connected = true;
            })

            parser: SplitParser {
                onRead: message => {
                    try {
                        const frame = JSON.parse(message);
                        spectrum.sequence = frame.seq || 0;
                        spectrum.sampleRate = frame.rate || 0;
                        spectrum.lowHz = frame.lowHz || 20;
                        spectrum.highHz = frame.highHz || 20000;
                        spectrum.rms = frame.rms || 0;
                        spectrum.peak = frame.peak || 0;
                        spectrum.sub = frame.sub || 0;
                        spectrum.bass = frame.bass || 0;
                        spectrum.mid = frame.mid || 0;
                        spectrum.high = frame.high || 0;
                        spectrum.updateBands(frame.bands);
                    } catch (error) {
                        console.warn("spectrum: invalid frame:", error);
                    }
                }
            }

            onError: error => {
                if (!spectrum.active)
                    return;

                Qt.callLater(() => {
                    if (!spectrum.active || spectrum.socketLoader.item !== spectrumSocket)
                        return;

                    spectrum.connectionGate = false;
                    spectrum.reconnectTimer.restart();
                });
            }
        }
    }

    property Loader socketLoader: Loader {
        active: spectrum.active && spectrum.connectionGate
        sourceComponent: spectrum.socketComponent
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
            decaying = false;
            connectionGate = true;
        } else {
            reconnectTimer.stop();
            // No more PipeWire work, but keep rendering the final frame until
            // it reaches silence. FrameAnimation stops itself after the tail.
            targetBands = bands.map(() => 0);
            decaying = hasEnergy;
            interpolating = decaying;
            if (!decaying) {
                bands = [];
                targetBands = [];
            }
            rms = 0;
            peak = 0;
            sub = 0;
            bass = 0;
            mid = 0;
            high = 0;
        }
    }
}

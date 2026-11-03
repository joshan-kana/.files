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
    // Reuse alternating output buffers. Each published frame has a different
    // identity so QML bindings are notified without allocating a new array.
    property var frameA: []
    property var frameB: []
    property bool interpolating: false
    property bool decaying: false
    property bool hasEnergy: false
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
            hasEnergy = next.some(value => value > 0.002);
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
        const values = bands === frameA ? frameB : frameA;
        values.length = targetBands.length;
        let maxDifference = 0;
        let energy = false;
        const bassEnd = targetBands.length * Math.log(250 / Math.max(1, lowHz)) / Math.log(Math.max(2, highHz / Math.max(1, lowHz)));
        // Five easing coefficients per display frame, not one exponential for
        // every FFT band. These are identical to the previous per-band rates.
        const bassAttack = 1 - Math.exp(-delta * 320);
        const bassRelease = 1 - Math.exp(-delta * 110);
        const highAttack = 1 - Math.exp(-delta * 120);
        const highRelease = 1 - Math.exp(-delta * 45);
        const decay = decaying ? 1 - Math.exp(-delta * 10) : 0;
        for (let i = 0; i < targetBands.length; i++) {
            const current = bands[i];
            const target = targetBands[i];
            const blend = decaying ? decay : i <= bassEnd ? (target > current ? bassAttack : bassRelease) : (target > current ? highAttack : highRelease);
            const value = current + (target - current) * blend;
            values[i] = value;
            energy = energy || value > 0.002;
            maxDifference = Math.max(maxDifference, Math.abs(target - value));
        }

        const settled = maxDifference < 0.002;
        bands = settled ? targetBands : values;
        hasEnergy = settled ? targetBands.some(value => value > 0.002) : energy;
        if (settled) {
            interpolating = false;
            if (decaying) {
                decaying = false;
                bands = [];
                targetBands = [];
                hasEnergy = false;
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
                hasEnergy = false;
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

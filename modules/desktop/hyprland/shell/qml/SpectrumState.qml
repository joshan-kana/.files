pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: spectrum

    required property AppearancePreferences appearance
    property int visualizerSubscribers: 0
    property bool active: false
    property real sensitivity: 1.0
    property real attackMultiplier: 1.0
    property real releaseMultiplier: 1.0
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
    property bool smoothingSilence: false
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
    property SpectrumScale frequencyScale: SpectrumScale {
        lowHz: spectrum.lowHz
        highHz: spectrum.highHz
    }

    // Audio buffers arrive independently of display refresh. Let the scene graph
    // interpolate between samples rather than redrawing only on PipeWire callbacks.
    property FrameAnimation interpolationFrame: FrameAnimation {
        running: spectrum.interpolating && (spectrum.active || spectrum.decaying) && (spectrum.smoothingSilence || spectrum.decaying)
        onTriggered: spectrum.advanceBands(frameTime)
    }

    function updateBands(values: var): void {
        const next = values || [];
        const incomingEnergy = next.some(value => value > 0.002);

        // Native visualisers interpolate the full target independently of
        // the GUI thread. QML only maintains the visibility/decay envelope
        // during silence, never publishes live per-display-frame bands.
        if (!decaying && incomingEnergy) {
            if (bands.length !== next.length)
                bands = next;
            targetBands = next;
            hasEnergy = true;
            smoothingSilence = false;
            interpolating = false;
            return;
        }

        // A silent packet must not abruptly hide the visualizer. Reuse the
        // existing original QML release envelope only until energy settles.
        if (!decaying && !incomingEnergy && hasEnergy) {
            if (!smoothingSilence)
                bands = targetBands;
            smoothingSilence = true;
        }

        if (bands.length !== next.length) {
            bands = next;
            targetBands = next;
            hasEnergy = incomingEnergy;
            interpolating = false;
            smoothingSilence = false;
            return;
        }

        targetBands = next;
        for (let i = 0; i < next.length; i++) {
            if (Math.abs(next[i] - bands[i]) > 0.002) {
                interpolating = true;
                return;
            }
        }

        bands = targetBands;
        hasEnergy = incomingEnergy;
        interpolating = false;
        if (!hasEnergy)
            smoothingSilence = false;
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
        const bassAttack = 1 - Math.exp(-delta * 320 * attackMultiplier);
        const bassRelease = 1 - Math.exp(-delta * 110 * releaseMultiplier);
        const highAttack = 1 - Math.exp(-delta * 120 * attackMultiplier);
        const highRelease = 1 - Math.exp(-delta * 45 * releaseMultiplier);
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
            if (smoothingSilence && !hasEnergy)
                smoothingSilence = false;
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

            path: Quickshell.env("XDG_RUNTIME_DIR") + "/desktop-shell-spectrum.sock"
            connected: false

            Component.onCompleted: Qt.callLater(() => {
                if (spectrum.active && spectrum.socketLoader.item === spectrumSocket)
                    spectrumSocket.connected = true;
            })

            parser: SplitParser {
                onRead: message => {
                    try {
                        const frame = JSON.parse(message);
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
                        spectrum.sequence = frame.seq || 0;
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
            smoothingSilence = false;
            connectionGate = true;
        } else {
            reconnectTimer.stop();
            if (!smoothingSilence)
                bands = targetBands;
            smoothingSilence = false;
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

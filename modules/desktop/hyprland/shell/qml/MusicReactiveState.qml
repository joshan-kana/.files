pragma ComponentBehavior: Bound
import QtQuick
import "ReactiveAudio.js" as ReactiveAudio

QtObject {
    id: reactive

    required property SpectrumState spectrum
    property bool enabled: false

    property real sustain: 0
    property real beatPulse: 0
    property real treble: 0
    property real kick: 0
    property real body: 0
    property real presence: 0
    property real motionAmount: 0
    property var spectrumLevels: [0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var impulseLevels: [0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var bandBaselines: [0, 0, 0, 0, 0, 0, 0, 0, 0]
    property real bassBaseline: 0
    property real peakBaseline: 0
    property real rmsBaseline: 0
    property real midBaseline: 0
    property real fluxBaseline: 0
    property real sinceKick: 1
    property var previousBands: []
    property bool baselineReady: false
    property real lastUpdateMs: 0
    property bool releasing: false

    // The analyser can disconnect immediately when a player pauses. Finish
    // the same short audio-envelope release instead of snapping the surface
    // to its non-reactive paint state. The timer runs only while decaying.
    property Timer disconnectRelease: Timer {
        interval: 16
        repeat: true
        running: reactive.releasing && reactive.enabled
        onTriggered: {
            const now = Date.now();
            const dt = reactive.lastUpdateMs > 0 ? Math.max(0.001, Math.min(0.08, (now - reactive.lastUpdateMs) / 1000)) : 1 / 60;
            reactive.lastUpdateMs = now;
            ReactiveAudio.advanceAudio(reactive, {
                rms: 0,
                peak: 0,
                sub: 0,
                bass: 0,
                mid: 0,
                high: 0,
                bands: [],
                lowHz: reactive.spectrum ? reactive.spectrum.lowHz : 20,
                highHz: reactive.spectrum ? reactive.spectrum.highHz : 20000
            }, dt);
            if (reactive.sustain < 0.0002 && reactive.kick < 0.001 && Math.max(...reactive.spectrumLevels, ...reactive.impulseLevels) < 0.001) {
                reactive.reset();
            }
        }
    }

    function updateAudio(): void {
        if (!enabled)
            return;
        const now = Date.now();
        const dt = lastUpdateMs > 0 ? Math.max(0.001, Math.min(0.08, (now - lastUpdateMs) / 1000)) : 1 / 120;
        lastUpdateMs = now;
        if (!spectrum || !spectrum.connected) {
            releasing = true;
            return;
        }
        releasing = false;
        ReactiveAudio.advanceAudio(reactive, {
            rms: spectrum.rms,
            peak: spectrum.peak,
            sub: spectrum.sub,
            bass: spectrum.bass,
            mid: spectrum.mid,
            high: spectrum.high,
            bands: spectrum.targetBands,
            lowHz: spectrum.lowHz,
            highHz: spectrum.highHz
        }, dt);
    }

    function reset(): void {
        releasing = false;
        sustain = 0;
        beatPulse = 0;
        treble = 0;
        kick = 0;
        body = 0;
        presence = 0;
        motionAmount = 0;
        spectrumLevels = [0, 0, 0, 0, 0, 0, 0, 0, 0];
        impulseLevels = [0, 0, 0, 0, 0, 0, 0, 0, 0];
        bandBaselines = [0, 0, 0, 0, 0, 0, 0, 0, 0];
        bassBaseline = 0;
        peakBaseline = 0;
        rmsBaseline = 0;
        midBaseline = 0;
        fluxBaseline = 0;
        sinceKick = 1;
        previousBands = [];
        baselineReady = false;
        lastUpdateMs = 0;
    }

    onEnabledChanged: {
        if (enabled)
            updateAudio();
        else
            reset();
    }

    property Connections audioUpdates: Connections {
        target: reactive.spectrum
        function onSequenceChanged(): void {
            reactive.updateAudio();
        }
        function onConnectedChanged(): void {
            if ((!reactive.spectrum || !reactive.spectrum.connected) && reactive.enabled)
                reactive.releasing = true;
            else
                reactive.releasing = false;
        }
    }
}

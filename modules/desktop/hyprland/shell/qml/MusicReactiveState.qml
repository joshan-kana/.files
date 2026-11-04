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
    property real flowPhase: 0
    property real bassBaseline: 0
    property real peakBaseline: 0
    property real rmsBaseline: 0
    property real midBaseline: 0
    property real fluxBaseline: 0
    property real sinceKick: 1
    property var previousBands: []
    property bool baselineReady: false
    property real lastUpdateMs: 0

    function updateAudio(): void {
        if (!enabled)
            return;
        const now = Date.now();
        const dt = lastUpdateMs > 0 ? Math.max(0.001, Math.min(0.08, (now - lastUpdateMs) / 1000)) : 1 / 120;
        lastUpdateMs = now;
        if (!spectrum.connected) {
            reset();
            return;
        }
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
        sustain = 0;
        beatPulse = 0;
        treble = 0;
        kick = 0;
        body = 0;
        presence = 0;
        motionAmount = 0;
        flowPhase = 0;
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
            if (!reactive.spectrum.connected)
                reactive.reset();
        }
    }
}

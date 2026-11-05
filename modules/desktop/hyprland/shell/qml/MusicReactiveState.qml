pragma ComponentBehavior: Bound
import QtQuick

QtObject {
    id: reactive

    required property SpectrumState spectrum
    property bool enabled: false

    // Sustained sub-bass stays visibly present. A separately tracked slower
    // envelope makes kick/808 attacks produce a distinct, brief accent.
    property real sustain: 0
    property real beatPulse: 0
    property real treble: 0
    property real bassBaseline: 0
    property real peakBaseline: 0
    property real bassVariation: 0
    property bool baselineReady: false
    property real lastUpdateMs: 0

    function clamp(value: real): real {
        return Math.max(0, Math.min(1, value));
    }

    function updateAudio(): void {
        if (!enabled)
            return;

        // Consume native spectrum events without dropping frames or snapping
        // the resulting colours into a tiny number of discrete brightnesses.
        const now = Date.now();
        const elapsed = lastUpdateMs > 0 ? Math.max(0.001, Math.min(0.2, (now - lastUpdateMs) / 1000)) : 1 / 60;
        lastUpdateMs = now;
        const follow = alpha => 1 - Math.pow(1 - alpha, elapsed * 15);

        // Silence must be identical to reactive mode being disabled. A
        // connected analyser is not itself evidence of audible input.
        const loudness = Math.max(spectrum.rms, spectrum.peak * 0.35);
        if (!spectrum.connected || loudness <= 0.003) {
            reset();
            return;
        }
        const presence = clamp((loudness - 0.003) / 0.025);
        const bass = clamp(spectrum.sub * 0.78 + spectrum.bass * 0.22);
        const peak = clamp(spectrum.peak);
        if (!baselineReady) {
            bassBaseline = bass;
            peakBaseline = peak;
            baselineReady = true;
        }

        // Loudness alone does not drive the shell straight to full brightness.
        // The dynamic term tracks changes relative to the song's current
        // low-frequency energy while a quiet steady glow preserves long 808s.
        const difference = bass - bassBaseline;
        const range = Math.max(0.07, bassVariation * 2.7);
        const relativeBass = clamp(0.5 + difference / range);
        const attack = clamp(Math.max(0, difference) / range * 0.9 + Math.max(0, peak - peakBaseline) * 1.4);
        bassVariation += (Math.abs(difference) - bassVariation) * follow(0.09);
        bassBaseline += difference * follow(0.027);
        peakBaseline += (peak - peakBaseline) * follow(0.045);

        // Reserve most of the intensity range for actual musical variation.
        // Bass-heavy tracks no longer pin the whole interface to maximum glow.
        sustain = presence * clamp(0.10 + bass * 0.16 + relativeBass * 0.43 + Math.sqrt(clamp(spectrum.mid)) * 0.10);
        beatPulse = presence * clamp(Math.max(attack, beatPulse * Math.pow(0.52, elapsed * 15)));
        treble = presence * clamp(Math.sqrt(clamp(spectrum.high)));
    }

    function reset(): void {
        sustain = 0;
        beatPulse = 0;
        treble = 0;
        bassBaseline = 0;
        peakBaseline = 0;
        bassVariation = 0;
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

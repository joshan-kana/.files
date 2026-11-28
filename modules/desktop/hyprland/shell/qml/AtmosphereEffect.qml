pragma ComponentBehavior: Bound
import QtQuick

// A single premultiplied, texture-free procedural pass. Soft compositions
// do not need a full-resolution offscreen texture; crisp patterns do.
ShaderEffect {
    id: effect
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property string mode
    required property real intensity
    required property real speed
    required property MusicReactiveState reactive
    property bool audioSync: false
    readonly property vector4d audio: audioSync && animating ? Qt.vector4d(reactive.sustain, reactive.beatPulse, reactive.treble, 0) : Qt.vector4d(0, 0, 0, 0)
    readonly property color toneA: theme.spectrumColor(0.0)
    readonly property color toneB: theme.spectrumColor(0.25)
    readonly property color toneC: theme.spectrumColor(0.5)
    readonly property color toneD: theme.spectrumColor(0.75)
    readonly property color toneE: theme.spectrumColor(1.0)
    readonly property real aspect: width / Math.max(1, height)
    // Shader IDs are stable even when the presentation order changes.
    readonly property int style: ({
            aurora: 0,
            liquid: 1,
            nebula: 2,
            ripples: 3,
            geometry: 4,
            flow: 5,
            prism: 6
        })[mode] ?? -1
    readonly property bool soft: style === 0 || style === 1 || style === 2
    property real phase: 0.65
    readonly property bool animating: enabled && visible && motion.enabled && width > 0 && height > 0

    property bool demandRegistered: false
    function syncDemand(): void {
        const needed = animating && audioSync;
        if (!reactive || needed === demandRegistered)
            return;
        reactive.effectSubscribers += needed ? 1 : -1;
        demandRegistered = needed;
    }
    onAnimatingChanged: syncDemand()
    onAudioSyncChanged: syncDemand()
    Component.onCompleted: syncDemand()
    Component.onDestruction: {
        if (demandRegistered && reactive)
            reactive.effectSubscribers--;
    }

    fragmentShader: "file://" + runtime.atmosphereShader
    blending: true

    // The soft glow pass uses fewer expensive fragment evaluations. The
    // final composite remains display-sized and bilinear-filtered.
    layer.enabled: soft && width > 900
    layer.smooth: true
    layer.textureSize: Qt.size(Math.max(1, Math.ceil(width * 0.75)), Math.max(1, Math.ceil(height * 0.75)))

    FrameAnimation {
        running: effect.animating
        onTriggered: effect.phase = (effect.phase + Math.min(frameTime, 0.05) * effect.speed * 0.105) % (Math.PI * 2)
    }
}

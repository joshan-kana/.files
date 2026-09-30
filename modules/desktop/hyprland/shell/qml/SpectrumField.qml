import QtQuick

Item {
    id: root

    required property QtObject spectrum
    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion

    property bool active: true

    readonly property bool ready: shader.status === ShaderEffect.Compiled
    readonly property int shaderStatus: shader.status
    readonly property string shaderLog: shader.log
    readonly property real phaseTime: shader.uTime

    clip: true

    ShaderEffect {
        id: shader
        anchors.fill: parent
        blending: true

        property var source: null
        property real uTime: 0
        property real uAspect: width / Math.max(1, height)
        property real uSub: root.spectrum.sub
        property real uBass: root.spectrum.bass
        property real uMid: root.spectrum.mid
        property real uHigh: root.spectrum.high
        property real uPeak: root.spectrum.peak
        property color uAccent: root.theme.accent
        property color uPositive: root.theme.positive
        property color uWarning: root.theme.warning

        fragmentShader: root.runtime.spectrumFieldShader
    }

    Timer {
        interval: 16
        repeat: true
        running: root.active && root.visible && root.motion.enabled

        onTriggered: shader.uTime += interval / 1000
    }

    Connections {
        target: root.motion

        function onEnabledChanged() {
            if (!root.motion.enabled)
                shader.uTime = 0;
        }
    }
}

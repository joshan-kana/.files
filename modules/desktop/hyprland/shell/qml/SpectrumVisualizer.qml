pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    required property SpectrumState spectrum
    required property Theme theme
    required property string surfaceKey
    required property Motion motion
    property int baseDensity: 48
    readonly property real baseOpacity: 0.8
    // Wallpaper has independent demand even when its layer is hidden in silence.
    property bool drivesDemand: true
    readonly property string mode: spectrum.appearance.spectrumMode(surfaceKey)
    readonly property bool engaged: enabled && visible && width > 0 && height > 0 && opacity > 0
    readonly property int density: Math.max(2, Math.min(Math.round(baseDensity * spectrum.appearance.spectrumDensity), Math.floor(width / 3), Math.max(2, spectrum.targetBands.length)))
    property bool demandRegistered: false
    function syncDemand(): void {
        const needed = engaged && drivesDemand;
        if (!spectrum || needed === demandRegistered)
            return;
        spectrum.visualizerSubscribers += needed ? 1 : -1;
        demandRegistered = needed;
    }
    onEngagedChanged: syncDemand()
    onDrivesDemandChanged: syncDemand()
    Component.onCompleted: syncDemand()
    Component.onDestruction: {
        if (demandRegistered && spectrum)
            spectrum.visualizerSubscribers--;
    }
    SpectrumRenderer {
        anchors.fill: parent
        spectrum: root.spectrum
        theme: root.theme
        frequencyScale: root.spectrum.frequencyScale
        barCount: root.density
        visible: root.engaged && (root.mode === "bars" || opacity > 0.01)
        opacity: root.mode === "bars" ? Math.min(1, root.baseOpacity * root.spectrum.appearance.spectrumOpacity) : 0
        Behavior on opacity {
            NumberAnimation {
                duration: root.motion.fast
                easing.type: root.motion.enterType
                easing.bezierCurve: root.motion.enterCurve
            }
        }
    }
    SpectrumRenderer {
        anchors.fill: parent
        spectrum: root.spectrum
        theme: root.theme
        frequencyScale: root.spectrum.frequencyScale
        barCount: root.density
        curve: true
        visible: root.engaged && (root.mode === "curve" || opacity > 0.01)
        opacity: root.mode === "curve" ? Math.min(1, root.baseOpacity * root.spectrum.appearance.spectrumOpacity) : 0
        Behavior on opacity {
            NumberAnimation {
                duration: root.motion.fast
                easing.type: root.motion.enterType
                easing.bezierCurve: root.motion.enterCurve
            }
        }
    }
}

import QtQuick

QtObject {
    required property QtObject runtime

    property bool enabled: runtime.animationsEnabled

    readonly property int instant: 0
    readonly property int fast: enabled ? 100 : 0
    readonly property int normal: enabled ? 160 : 0
    readonly property int slow: enabled ? 220 : 0
    readonly property int pulse: enabled ? 520 : 0

    readonly property int spatialFast: enabled ? 150 : 0
    readonly property int spatialNormal: enabled ? 220 : 0
    readonly property int spatialSlow: enabled ? 320 : 0
    readonly property int effectsFast: enabled ? 90 : 0
    readonly property int effectsNormal: enabled ? 150 : 0
    readonly property int effectsSlow: enabled ? 220 : 0

    readonly property int enterType: Easing.OutCubic
    readonly property int exitType: Easing.InCubic
    readonly property int pulseType: Easing.InOutSine
    readonly property int spatialType: Easing.OutQuint
    readonly property int effectsType: Easing.OutCubic

    function toggle(): void {
        enabled = !enabled;
    }
}

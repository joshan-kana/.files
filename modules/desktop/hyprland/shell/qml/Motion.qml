import QtQuick

QtObject {
    required property QtObject runtime

    property bool enabled: runtime.animationsEnabled

    readonly property int instant: 0
    readonly property int fast: enabled ? 100 : 0
    readonly property int normal: enabled ? 160 : 0
    readonly property int slow: enabled ? 220 : 0
    readonly property int pulse: enabled ? 520 : 0

    readonly property int enterType: Easing.OutCubic
    readonly property int exitType: Easing.InCubic
    readonly property int pulseType: Easing.InOutSine

    function toggle(): void {
        enabled = !enabled;
    }
}

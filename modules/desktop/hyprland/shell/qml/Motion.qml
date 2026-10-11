import QtQuick
import Quickshell

QtObject {
    required property RuntimeConfig runtime

    property bool enabled: runtime.animationsEnabled

    readonly property int instant: 0
    readonly property int fast: enabled ? 100 : 0
    readonly property int normal: enabled ? 160 : 0
    readonly property int slow: enabled ? 220 : 0
    readonly property int pulse: enabled ? 520 : 0

    readonly property int spatialFast: enabled ? 150 : 0
    // Geometry morphs settle after the shorter content transition.
    readonly property int morph: enabled ? 240 : 0
    readonly property int contentFade: enabled ? 115 : 0
    readonly property int spatialNormal: enabled ? 220 : 0
    readonly property int spatialSlow: enabled ? 320 : 0
    readonly property int effectsFast: enabled ? 90 : 0
    readonly property int effectsNormal: enabled ? 150 : 0
    readonly property int effectsSlow: enabled ? 220 : 0

    // CSS-style cubic Bézier profiles shared by all shell animations.
    // Short feedback stays responsive, while large surface changes have a
    // deliberate ease-in and longer settling phase. Never overshoot geometry.
    readonly property var spatialCurve: [0.35, 0, 0.15, 1, 1, 1]
    readonly property var morphCurve: [0.4, 0, 0.2, 1, 1, 1]
    readonly property var enterCurve: [0, 0, 0.2, 1, 1, 1]
    readonly property var exitCurve: [0.4, 0, 1, 1, 1, 1]
    readonly property var effectsCurve: [0.2, 0, 0.2, 1, 1, 1]

    readonly property int enterType: Easing.BezierSpline
    readonly property int exitType: Easing.BezierSpline
    readonly property int pulseType: Easing.InOutSine
    readonly property int spatialType: Easing.BezierSpline
    readonly property int morphType: Easing.BezierSpline
    readonly property int effectsType: Easing.BezierSpline

    Component.onCompleted: syncWallpaperMotion()

    function syncWallpaperMotion(): void {
        if (runtime.wallpaperLibrary.length > 0)
            Quickshell.execDetached([runtime.wallpaperLibrary, "motion", enabled ? "on" : "off"]);
    }

    function toggle(): void {
        enabled = !enabled;
        Quickshell.execDetached(["hyprctl", "eval", "hl.config({ animations = { enabled = " + (enabled ? "true" : "false") + " } })"]);
        syncWallpaperMotion();
    }
}

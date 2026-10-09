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

    readonly property int spatialFast: enabled ? 100 : 0
    // Smoother than OutQuint for large surface-size changes: no first-frame jump.
    readonly property int morph: enabled ? 180 : 0
    readonly property int spatialNormal: enabled ? 220 : 0
    readonly property int spatialSlow: enabled ? 320 : 0
    readonly property int effectsFast: enabled ? 90 : 0
    readonly property int effectsNormal: enabled ? 150 : 0
    readonly property int effectsSlow: enabled ? 220 : 0

    readonly property int enterType: Easing.OutCubic
    readonly property int exitType: Easing.InCubic
    readonly property int pulseType: Easing.InOutSine
    readonly property int spatialType: Easing.OutQuint
    readonly property int morphType: Easing.InOutCubic
    readonly property int effectsType: Easing.OutCubic

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

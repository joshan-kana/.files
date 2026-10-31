import QtQuick
import Quickshell
import QtCore

QtObject {
    id: root
    required property RuntimeConfig runtime

    // A user-selected motion preference survives shell reload, logout and
    // reboot independently of the Nix-generated runtime defaults.
    property Settings preferences: Settings {
        id: preferences
        location: "file://" + Quickshell.env("HOME") + "/.config/linux-desktop/preferences.ini"
        category: "Motion"
        property bool animationsEnabled: root.runtime.animationsEnabled
    }
    readonly property bool enabled: preferences.animationsEnabled

    readonly property int instant: 0
    readonly property int fast: enabled ? 100 : 0
    readonly property int normal: enabled ? 160 : 0
    readonly property int slow: enabled ? 220 : 0
    readonly property int pulse: enabled ? 520 : 0

    readonly property int spatialFast: enabled ? 170 : 0
    // Geometry morphs settle after the shorter content transition.
    readonly property int morph: enabled ? 270 : 0
    readonly property int contentFade: enabled ? 115 : 0
    readonly property int spatialNormal: enabled ? 250 : 0
    readonly property int spatialSlow: enabled ? 320 : 0
    readonly property int effectsFast: enabled ? 90 : 0
    readonly property int effectsNormal: enabled ? 150 : 0
    readonly property int effectsSlow: enabled ? 220 : 0

    // CSS-style cubic Bézier profiles shared by all shell animations.
    // Short feedback stays responsive, while large surface changes have a
    // deliberate ease-in and longer settling phase. Never overshoot geometry.
    readonly property var spatialCurve: [0.3, 0, 0.12, 1, 1, 1]
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

    Component.onCompleted: {
        syncCompositorMotion();
        syncWallpaperMotion();
    }

    function syncCompositorMotion(): void {
        Quickshell.execDetached(["hyprctl", "eval", "hl.config({ animations = { enabled = " + (enabled ? "true" : "false") + " } })"]);
    }

    function syncWallpaperMotion(): void {
        if (runtime.wallpaperLibrary.length > 0)
            Quickshell.execDetached([runtime.wallpaperLibrary, "motion", enabled ? "on" : "off"]);
    }

    function toggle(): void {
        preferences.animationsEnabled = !preferences.animationsEnabled;
        preferences.setValue("animationsEnabled", preferences.animationsEnabled);
        preferences.sync();
        syncCompositorMotion();
        syncWallpaperMotion();
    }
}

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
        property string preferenceSource: ""
    }
    readonly property bool enabled: preferences.preferenceSource === "default" ? runtime.animationsEnabled : preferences.animationsEnabled

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

    function syncCompositorMotion(): void {
        Quickshell.execDetached([runtime.hyprctl, "eval", "hl.config({ animations = { enabled = " + (enabled ? "true" : "false") + " } })"]);
    }

    function syncWallpaperMotion(): void {
        if (runtime.wallpaperLibrary.length > 0)
            Quickshell.execDetached([runtime.wallpaperLibrary, "motion", enabled ? "on" : "off"]);
    }

    Component.onCompleted: {
        if (preferences.preferenceSource === "") {
            // Preserve explicitly stored values from older settings files.
            preferences.preferenceSource = preferences.value("animationsEnabled", null) === null ? "default" : "user";
            preferences.setValue("preferenceSource", preferences.preferenceSource);
            preferences.sync();
        }
        syncCompositorMotion();
        syncWallpaperMotion();
    }

    function resetToDeclared(): void {
        preferences.preferenceSource = "default";
        preferences.setValue("preferenceSource", "default");
        preferences.sync();
        syncCompositorMotion();
        syncWallpaperMotion();
    }

    function toggle(): void {
        preferences.animationsEnabled = !enabled;
        preferences.setValue("animationsEnabled", preferences.animationsEnabled);
        preferences.preferenceSource = "user";
        preferences.setValue("preferenceSource", "user");
        preferences.sync();
        syncCompositorMotion();
        syncWallpaperMotion();
    }
}

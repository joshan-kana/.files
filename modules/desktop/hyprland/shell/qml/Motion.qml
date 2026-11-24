import QtQuick
import Quickshell
import QtCore

QtObject {
    id: root
    required property RuntimeConfig runtime

    // A user-selected motion preference survives shell reload, logout and
    // reboot independently of the Nix-generated runtime defaults.
    property Settings preferences: Settings {
        id: qmlPreferences
        location: "file://" + (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/desktop-shell/preferences.ini"
        category: "Motion"
        property bool animationsEnabled: root.runtime.animationsEnabled
        property string preferenceSource: ""
        property real durationOverride: 0
    }
    readonly property bool enabled: qmlPreferences.preferenceSource === "default" ? runtime.animationsEnabled : qmlPreferences.animationsEnabled

    readonly property real durationMultiplier: qmlPreferences.durationOverride > 0 ? Math.max(0.75, Math.min(1.5, qmlPreferences.durationOverride)) : runtime.motionDurationMultiplier
    function setDurationMultiplier(value: real): void {
        qmlPreferences.durationOverride = Math.max(0.75, Math.min(1.5, value));
        qmlPreferences.sync();
    }
    function resetDurationMultiplier(): void {
        qmlPreferences.durationOverride = 0;
        qmlPreferences.sync();
    }
    readonly property int fast: enabled ? 100 : 0
    readonly property int normal: enabled ? 160 : 0
    readonly property int contourLap: enabled ? 1900 : 0
    readonly property int spinnerCycle: enabled ? 1100 : 0

    readonly property int spatialFast: enabled ? Math.round(150 * durationMultiplier) : 0
    // Geometry morphs settle after the shorter content transition.
    readonly property int morph: enabled ? Math.round(240 * durationMultiplier) : 0
    readonly property int contentFade: enabled ? Math.round(115 * durationMultiplier) : 0
    readonly property int spatialNormal: enabled ? Math.round(220 * durationMultiplier) : 0
    readonly property int spatialSlow: enabled ? Math.round(320 * durationMultiplier) : 0
    readonly property int effectsFast: enabled ? Math.round(90 * durationMultiplier) : 0
    readonly property int effectsNormal: enabled ? Math.round(150 * durationMultiplier) : 0
    readonly property int effectsSlow: enabled ? Math.round(220 * durationMultiplier) : 0

    // Low-amplitude press deformation: fast engagement, gently damped return.
    // Surface geometry and hit regions stay fixed while their visual item scales.
    readonly property real pressScaleSmall: 0.94
    readonly property real pressScaleNormal: 0.965
    readonly property real hoverRestScale: 0.988
    readonly property real pressGroupCompress: 0.94
    readonly property real pressSpring: 3.5
    readonly property real pressDamping: 0.75
    readonly property real pressEpsilon: 0.0008

    // The active keyboard adjustment belongs to the physical key, not the
    // interval between repeat events. The scoped key owner records presses
    // and releases; only the slider that actually adjusts receives feedback.
    property Item keyboardSlider: null
    property int keyboardEventKey: 0
    property int adjustmentKey: 0

    function noteKeyDown(key: int): void {
        if ([Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_AltGr].includes(key))
            return;
        if (keyboardSlider && key !== adjustmentKey)
            endKeyboardAdjustment();
        keyboardEventKey = key;
    }

    function beginKeyboardAdjustment(slider: Item): void {
        if (!keyboardEventKey)
            return;
        adjustmentKey = keyboardEventKey;
        keyboardSlider = slider;
    }

    function releaseAdjustmentKey(key: int): bool {
        if (key !== adjustmentKey || !keyboardSlider)
            return false;
        endKeyboardAdjustment();
        return true;
    }

    function endKeyboardAdjustment(): void {
        keyboardSlider = null;
        adjustmentKey = 0;
        keyboardEventKey = 0;
    }

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
        if (qmlPreferences.preferenceSource === "") {
            // Preserve explicitly stored values from older settings files.
            qmlPreferences.preferenceSource = qmlPreferences.value("animationsEnabled", null) === null ? "default" : "user";
            qmlPreferences.setValue("preferenceSource", qmlPreferences.preferenceSource);
            qmlPreferences.sync();
        }
        syncCompositorMotion();
        syncWallpaperMotion();
    }

    function resetToDeclared(): void {
        resetDurationMultiplier();
        qmlPreferences.preferenceSource = "default";
        qmlPreferences.setValue("preferenceSource", "default");
        qmlPreferences.sync();
        syncCompositorMotion();
        syncWallpaperMotion();
    }

    function toggle(): void {
        qmlPreferences.animationsEnabled = !enabled;
        qmlPreferences.setValue("animationsEnabled", qmlPreferences.animationsEnabled);
        qmlPreferences.preferenceSource = "user";
        qmlPreferences.setValue("preferenceSource", "user");
        qmlPreferences.sync();
        syncCompositorMotion();
        syncWallpaperMotion();
    }
}

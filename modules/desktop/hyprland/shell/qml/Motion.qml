import QtQuick
import Quickshell

QtObject {
    id: root
    required property RuntimeConfig runtime

    // A user-selected motion preference survives shell reload, logout and
    // reboot independently of the Nix-generated runtime defaults.
    property PreferenceStore preferences: PreferenceStore {
        id: qmlPreferences
        category: "Motion"
        defaults: ({
                animationsEnabled: root.runtime.animationsEnabled,
                durationMultiplier: root.runtime.motionDurationMultiplier
            })
    }
    readonly property bool enabled: qmlPreferences.value("animationsEnabled")
    readonly property real durationMultiplier: runtime.bounded("motion", "durationMultiplier", qmlPreferences.value("durationMultiplier"))
    function setDurationMultiplier(value: real): void {
        qmlPreferences.set("durationMultiplier", runtime.bounded("motion", "durationMultiplier", value));
    }
    function resetDurationMultiplier(): void {
        qmlPreferences.reset("durationMultiplier");
    }
    readonly property int fast: enabled ? 100 : 0
    readonly property int normal: enabled ? 160 : 0
    readonly property int contourLap: enabled ? 1900 : 0
    readonly property int contourEasing: Easing.InOutSine
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
        const duration = qmlPreferences.legacy("durationOverride", 0);
        qmlPreferences.initialize({
            animationsEnabled: qmlPreferences.legacyMarked("animationsEnabled", "preferenceSource"),
            durationMultiplier: duration > 0 ? duration : undefined
        });
        syncCompositorMotion();
        syncWallpaperMotion();
    }

    function resetToDeclared(): void {
        qmlPreferences.resetAll();
        syncCompositorMotion();
        syncWallpaperMotion();
    }

    function toggle(): void {
        qmlPreferences.set("animationsEnabled", !enabled);
        syncCompositorMotion();
        syncWallpaperMotion();
    }
}

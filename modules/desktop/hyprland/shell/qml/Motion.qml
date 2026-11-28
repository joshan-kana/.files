import QtQuick
import Quickshell
import Quickshell.Hyprland

QtObject {
    id: root
    required property RuntimeConfig runtime

    // A user-selected motion preference survives shell reload, logout and
    // reboot independently of the Nix-generated runtime defaults.
    property PreferenceStore preferences: PreferenceStore {
        id: qmlPreferences
        category: "Motion"
        constraints: root.runtime.constraints.motion
        defaults: ({
                animationsEnabled: root.runtime.animationsEnabled,
                durationMultiplier: root.runtime.motionDurationMultiplier
            })
    }
    property var sceneEnabled: null
    readonly property bool enabled: sceneEnabled === null ? qmlPreferences.value("animationsEnabled") : sceneEnabled

    function setSceneEnabled(value: var): void {
        const before = enabled;
        sceneEnabled = value;
        if (before !== enabled) {
            syncCompositorMotion();
            syncWallpaperMotion();
        }
    }
    readonly property real durationMultiplier: qmlPreferences.value("durationMultiplier")
    function setDurationMultiplier(value: real): void {
        qmlPreferences.set("durationMultiplier", runtime.bounded("motion", "durationMultiplier", value));
    }
    function resetDurationMultiplier(): void {
        qmlPreferences.reset("durationMultiplier");
    }
    readonly property int fast: enabled ? Math.round(100 * durationMultiplier) : 0
    readonly property int normal: enabled ? Math.round(160 * durationMultiplier) : 0
    readonly property int contourLap: enabled ? 1900 : 0
    readonly property int contourEasing: Easing.InOutSine
    // One eased phase for visible busy contours. Keep it alive across a
    // navigation morph so a tile handing off to the frame does not restart.
    property var contourOwners: []
    property real contourProgress: 0
    property bool contourRunning: false
    property NumberAnimation contourAnimation: NumberAnimation {
        target: root
        property: "contourProgress"
        from: 0
        to: 1
        duration: root.contourLap
        loops: Animation.Infinite
        easing.type: root.contourEasing
        running: root.enabled && root.contourRunning
    }
    property Timer contourIdle: Timer {
        interval: Math.max(1, root.morph)
        onTriggered: {
            if (root.contourOwners.length === 0)
                root.contourRunning = false;
        }
    }
    function setContourActive(owner: QtObject, active: bool): void {
        const next = contourOwners.filter(item => item && item !== owner);
        if (active)
            next.push(owner);
        contourOwners = next;
        if (next.length > 0) {
            contourIdle.stop();
            contourRunning = true;
        } else if (contourRunning) {
            contourIdle.restart();
        }
    }

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
    readonly property real pressScaleSmall: 0.98
    readonly property real pressScaleNormal: 0.98
    readonly property real hoverRestScale: 0.988
    readonly property real pressGroupCompress: 0.985
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

    property Connections compositorReload: Connections {
        target: Hyprland
        function onRawEvent(event): void {
            if (event.name === "configreloaded")
                root.syncCompositorMotion();
        }
    }
    property Connections runtimeChanges: Connections {
        target: root.runtime
        function onHyprctlChanged(): void {
            root.syncCompositorMotion();
        }
    }

    function compositorMotionCommand(): var {
        return [runtime.hyprctl, "eval", "hl.config({ animations = { enabled = " + (enabled ? "true" : "false") + " } })"];
    }

    function syncCompositorMotion(): void {
        if (runtime.hyprctl)
            Quickshell.execDetached(compositorMotionCommand());
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

    function resetToDeclared(apply = true): void {
        if (sceneEnabled !== null) {
            sceneEnabled = runtime.animationsEnabled;
            qmlPreferences.reset("durationMultiplier");
        } else
            qmlPreferences.resetAll();
        if (apply) {
            syncCompositorMotion();
            syncWallpaperMotion();
        }
    }

    function resetOperations(): var {
        const steps = [];
        if (runtime.hyprctl)
            steps.push({
                label: "Compositor motion",
                command: compositorMotionCommand(),
                expectedText: "ok"
            }, {
                label: "Compositor motion readback",
                command: [runtime.hyprctl, "-j", "getoption", "animations:enabled"],
                expectedField: "bool",
                expectedValue: enabled
            });
        if (runtime.wallpaperLibrary)
            steps.push({
                label: "Wallpaper motion",
                command: [runtime.wallpaperLibrary, "motion", enabled ? "on" : "off"]
            }, {
                label: "Wallpaper motion readback",
                command: [runtime.wallpaperLibrary, "motion", "status"],
                expectedText: enabled ? "on" : "off"
            });
        return steps;
    }

    function toggle(): void {
        if (sceneEnabled !== null)
            sceneEnabled = !enabled;
        else
            qmlPreferences.set("animationsEnabled", !enabled);
        syncCompositorMotion();
        syncWallpaperMotion();
    }
}

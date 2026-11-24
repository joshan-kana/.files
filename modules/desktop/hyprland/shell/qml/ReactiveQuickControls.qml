pragma ComponentBehavior: Bound
import QtQuick
import "DesktopIcons.js" as DesktopIcons

// Contextual controls use the same preferences, ranges and presets as the
// full reactive-audio editor. No second settings store or audio analyser.
Row {
    id: controls
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property AppearancePreferences appearance
    property bool engaged: false
    property var parameterKeys: ["musicReactiveIntensity"]
    property string scope: "controls"
    property int parameterIndex: 0
    property bool editing: false
    signal keyboardRequested
    readonly property var parameters: parameterKeys.map(key => appearance.reactiveParameters.find(entry => entry.key === key)).filter(entry => !!entry)
    readonly property var parameter: parameters[parameterIndex] || parameters[0]
    readonly property real parameterValue: parameter ? Math.round(appearance[parameter.key] * 100) : 0
    readonly property var helpBindings: [
        {
            key: runtime.shellHint("ReactiveQuickControls.toggle"),
            action: "Toggle music-reactive shell"
        },
        {
            key: runtime.shellHint("ReactiveQuickControls.preset"),
            action: "Cycle reactive preset"
        },
        {
            key: runtime.shellHint("ReactiveQuickControls.target"),
            action: "Cycle tint target"
        },
        {
            key: runtime.shellHint("ReactiveQuickControls.parameter"),
            action: "Select / cycle reactive parameter, then " + runtime.shellHint("SettingsDetail.adjust") + " to adjust"
        }
    ]

    spacing: theme.spacing2
    height: 58
    onEngagedChanged: if (!engaged)
        editing = false
    onParametersChanged: {
        parameterIndex = 0;
        editing = false;
    }

    function cyclePreset(): void {
        const choices = ["Subtle", "Default", "Energetic"];
        appearance.applyReactivePreset(choices[(choices.indexOf(appearance.musicReactivePreset) + 1) % choices.length]);
    }
    function selectParameter(): void {
        if (!parameters.length)
            return;
        if (editing)
            parameterIndex = (parameterIndex + 1) % parameters.length;
        editing = true;
        keyboardRequested();
    }
    function cancelEditing(): bool {
        if (!editing)
            return false;
        editing = false;
        return true;
    }
    function handleKey(key: int, modifiers: int, autoRepeat: bool): bool {
        if (!engaged || !visible)
            return false;
        if (runtime.shellMatchesHint("ReactiveQuickControls.toggle", key, modifiers)) {
            if (!autoRepeat)
                appearance.toggleMusicReactive();
            return true;
        }
        if (runtime.shellMatchesHint("ReactiveQuickControls.preset", key, modifiers)) {
            if (!autoRepeat)
                cyclePreset();
            return true;
        }
        if (runtime.shellMatchesHint("ReactiveQuickControls.target", key, modifiers)) {
            if (!autoRepeat)
                appearance.cycleReactiveTarget();
            return true;
        }
        if (runtime.shellMatchesHint("ReactiveQuickControls.parameter", key, modifiers)) {
            if (!autoRepeat)
                selectParameter();
            return true;
        }
        if (editing && parameter && modifiers === Qt.NoModifier && (runtime.shellNavigates(scope, "left", key) || runtime.shellNavigates(scope, "right", key))) {
            parameterSlider.beginKeyboardAdjustment();
            appearance.setReactiveParameter(parameter.key, (parameterValue + (runtime.shellNavigates(scope, "left", key) ? -1 : 1) * parameter.step) / 100);
            return true;
        }
        if (key === runtime.shellKeyCode(scope, "Escape") && cancelEditing())
            return true;
        if (![Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_AltGr].includes(key))
            editing = false;
        return false;
    }

    ShellAction {
        width: Math.max(1, (controls.width - controls.spacing * 3) * 0.23)
        height: controls.height
        runtime: controls.runtime
        theme: controls.theme
        motion: controls.motion
        compact: true
        horizontalCompact: true
        title: controls.appearance.musicReactiveEnabled ? "Reactive on" : "Reactive off"
        icon: DesktopIcons.toggleGlyph(controls.appearance.musicReactiveEnabled)
        shortcut: controls.runtime.shellHint("ReactiveQuickControls.toggle")
        active: controls.appearance.musicReactiveEnabled
        onActivated: controls.appearance.toggleMusicReactive()
    }
    ShellAction {
        width: Math.max(1, (controls.width - controls.spacing * 3) * 0.22)
        height: controls.height
        runtime: controls.runtime
        theme: controls.theme
        motion: controls.motion
        compact: true
        horizontalCompact: true
        title: controls.appearance.musicReactivePreset
        shortcut: controls.runtime.shellHint("ReactiveQuickControls.preset")
        onActivated: controls.cyclePreset()
    }
    ShellAction {
        width: Math.max(1, (controls.width - controls.spacing * 3) * 0.22)
        height: controls.height
        runtime: controls.runtime
        theme: controls.theme
        motion: controls.motion
        compact: true
        horizontalCompact: true
        title: ({
                all: "Frame + shell",
                frame: "Frame only",
                shell: "Shell only"
            })[controls.appearance.musicReactiveTarget]
        shortcut: controls.runtime.shellHint("ReactiveQuickControls.target")
        onActivated: controls.appearance.cycleReactiveTarget()
    }
    Column {
        width: Math.max(1, (controls.width - controls.spacing * 3) * 0.33)
        height: controls.height
        ShellAction {
            width: parent.width
            height: 36
            runtime: controls.runtime
            theme: controls.theme
            motion: controls.motion
            compact: true
            horizontalCompact: true
            title: controls.parameter ? controls.parameter.title.replace("Tint intensity", "Intensity").replace("Release speed", "Release") + " " + controls.parameterValue + "%" : "Reactive intensity"
            shortcut: controls.runtime.shellHint("ReactiveQuickControls.parameter")
            active: controls.editing
            onActivated: controls.selectParameter()
        }
        ShellSlider {
            id: parameterSlider
            width: parent.width
            height: 22
            theme: controls.theme
            motion: controls.motion
            enabled: !!controls.parameter
            from: controls.parameter?.minimum ?? 0
            to: controls.parameter?.maximum ?? 100
            value: controls.parameterValue
            handleSize: 14
            trackHeight: 6
            Accessible.role: Accessible.Slider
            Accessible.name: controls.parameter?.title || "Reactive parameter"
            onInteractionStarted: {
                controls.editing = true;
                controls.keyboardRequested();
            }
            onValueRequested: next => {
                if (controls.parameter)
                    controls.appearance.setReactiveParameter(controls.parameter.key, next / 100);
            }
        }
    }
}

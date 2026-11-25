pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "LogindInhibitors.js" as LogindInhibitors
import "ClockFormatting.js" as ClockFormatting
import "DesktopIcons.js" as DesktopIcons

// One capability at a time. Parameters and quick actions share their existing
// authoritative service owners, including Nix-default/user-override semantics.
Item {
    id: panel

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property AppearancePreferences appearance
    required property SceneState scenes
    required property NightLightState nightLight
    required property NotificationState notifications
    required property PowerProfileState powerProfile
    required property SystemState system
    required property SpectrumState spectrum
    required property bool wallpaperSpectrumEnabled
    required property bool musicReactiveEnabled
    required property bool barVisible
    required property bool frameVisible
    signal wallpaperSpectrumToggleRequested
    signal musicReactiveToggleRequested
    signal barToggleRequested
    signal frameToggleRequested
    signal nativeDisplayEditorRequested
    signal keyboardRequested
    signal parameterAdjustmentRequested(int index)
    signal revealSelection(real top, real bottom)

    property string kind: ""
    property bool open: false
    property int selectedIndex: 0
    property double clockMs: Date.now()
    readonly property bool inspectingInhibitors: open && kind === "stay"
    property var inhibitorEntries: []
    property string inhibitorStatus: ""
    function refreshInhibitors(): void {
        if (!inspectingInhibitors || inhibitorQuery.running)
            return;
        inhibitorEntries = [];
        inhibitorStatus = "Reading system inhibitors…";
        inhibitorQuery.exec([runtime.busctl, "--system", "--json=short", "--timeout=5s", "call", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "ListInhibitors"]);
    }
    onInspectingInhibitorsChanged: {
        if (inspectingInhibitors)
            refreshInhibitors();
        else {
            inhibitorEntries = [];
            inhibitorStatus = "";
        }
    }
    Process {
        id: inhibitorQuery
        stdout: StdioCollector {
            id: inhibitorOutput
        }
        onExited: (code, status) => {
            if (!panel.inspectingInhibitors)
                return;
            const entries = code === 0 ? LogindInhibitors.parseInhibitors(inhibitorOutput.text) : null;
            panel.inhibitorEntries = entries || [];
            panel.inhibitorStatus = entries === null ? "System inhibitors unavailable" : entries.length === 0 ? "No system inhibitor locks" : entries.length + (entries.length === 1 ? " active system lock" : " active system locks");
        }
    }
    Timer {
        interval: 1000
        running: panel.open && panel.kind === "stay" && panel.system.idleInhibited && panel.system.idleInhibitDeadline > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: panel.clockMs = Date.now()
    }
    readonly property string idleStatus: !system.idleInhibited ? "Idle allowed" : system.idleInhibitDeadline <= 0 ? "Inhibited until disabled" : Math.max(0, Math.ceil((system.idleInhibitDeadline - clockMs) / 60000)) + " min remaining"
    visible: open
    implicitWidth: kind === "displays" ? theme.controlsDetailWidth : reactiveTuning || spectrumTuning || kind === "alerts" || kind === "nightLight" || kind === "power" ? theme.richDetailWidth : theme.compactDetailWidth
    implicitHeight: content.implicitHeight

    readonly property bool hasMaster: ["windows", "glass", "nightLight", "alerts", "stay", "spectrum", "reactive", "bar", "frame", "motion"].includes(kind)
    readonly property bool hasBlur: ["windows", "glass"].includes(kind)
    readonly property bool reactiveTuning: kind === "reactive"
    readonly property bool spectrumTuning: kind === "spectrum"
    readonly property bool hasReset: hasBlur || spectrumTuning || reactiveTuning || kind === "alerts" || kind === "nightLight" || ["bar", "frame", "motion"].includes(kind)
    readonly property string titleText: ({
            windows: "Window transparency",
            glass: "Frosted glass",
            nightLight: "Night Light",
            alerts: "Notification controls",
            stay: "Stay awake",
            power: "Power profiles",
            spectrum: "Wallpaper spectrum",
            reactive: "Music-reactive shell",
            bar: "Desktop bar",
            frame: "Desktop frame",
            motion: "Animations",
            displays: "Displays",
            scenes: "Desktop scenes"
        })[kind] || "Settings"
    readonly property string subtitleText: ({
            windows: "Window opacity and compositor blur",
            glass: "Shell translucency and backdrop blur",
            nightLight: "Colour temperature and warm-light schedule",
            alerts: "Delivery, quiet hours and notification history",
            stay: "Idle inhibition and timeout",
            power: "Choose a system power profile",
            spectrum: "Shared visualizer response and wallpaper appearance",
            reactive: "Audio-driven tint and response",
            bar: "Desktop islands and bar layout",
            frame: "Connected desktop contour and thickness",
            motion: "Transition timing and reduced motion",
            displays: "Output layout, resolution and refresh rate",
            scenes: "Reversible session preferences"
        })[kind] || "Capability controls"
    readonly property bool masterState: {
        switch (kind) {
        case "windows":
            return appearance.windowTransparencyEnabled;
        case "glass":
            return appearance.shellGlassEnabled;
        case "nightLight":
            return nightLight.active;
        case "alerts":
            return !notifications.silent;
        case "stay":
            return system.idleInhibited;
        case "spectrum":
            return wallpaperSpectrumEnabled;
        case "reactive":
            return musicReactiveEnabled;
        case "bar":
            return barVisible;
        case "frame":
            return frameVisible;
        case "motion":
            return motion.enabled;
        default:
            return false;
        }
    }
    readonly property string capabilityIcon: DesktopIcons.capabilityGlyph(kind, {
        active: masterState,
        batteryAvailable: system.batteryAvailable,
        batteryLevelIcon: system.batteryLevelIcon
    })
    readonly property string foregroundRole: theme.capabilityRole(kind)
    readonly property bool displayOperationBusy: displayDetails.foregroundBusy
    readonly property bool foregroundBusy: kind === "displays" ? displayOperationBusy : kind === "nightLight" && nightLight.foregroundBusy
    readonly property bool masterAvailable: kind !== "nightLight" || nightLight.supported && !nightLight.busy
    readonly property var parameters: {
        if (kind === "bar")
            return [
                {
                    key: "barIslandHeight",
                    title: "Island height",
                    description: "Shared bar density",
                    minimum: runtime.constraints.appearance.barIslandHeight.min,
                    maximum: runtime.constraints.appearance.barIslandHeight.max,
                    step: 2,
                    suffix: " px"
                }
            ];
        if (kind === "frame")
            return [
                {
                    key: "frameThickness",
                    title: "Frame thickness",
                    description: "Shared edge geometry",
                    minimum: runtime.constraints.appearance.frameThickness.min,
                    maximum: runtime.constraints.appearance.frameThickness.max,
                    step: 2,
                    suffix: " px"
                }
            ];
        if (kind === "motion")
            return [
                {
                    key: "motionDuration",
                    title: "Transition duration",
                    description: "Shell transitions only; key-down remains immediate",
                    minimum: runtime.constraints.motion.durationMultiplier.min * 100,
                    maximum: runtime.constraints.motion.durationMultiplier.max * 100,
                    step: 5,
                    suffix: "%"
                }
            ];
        if (kind === "windows")
            return [
                {
                    key: "windowOpacity",
                    title: "Window opacity",
                    description: "Opacity of active and inactive windows",
                    minimum: runtime.constraints.appearance.windowOpacity.min * 100,
                    maximum: runtime.constraints.appearance.windowOpacity.max * 100,
                    step: 5,
                    suffix: "%"
                },
                {
                    key: "blurSize",
                    title: "Backdrop blur",
                    description: "Compositor-wide shared blur radius",
                    minimum: 5,
                    maximum: 25,
                    step: 1,
                    suffix: " px"
                }
            ];
        if (kind === "glass")
            return [
                {
                    key: "glassOpacity",
                    title: "Shell opacity",
                    description: "Translucency of shell surfaces",
                    minimum: runtime.constraints.appearance.glassOpacity.min * 100,
                    maximum: runtime.constraints.appearance.glassOpacity.max * 100,
                    step: 5,
                    suffix: "%"
                },
                {
                    key: "blurSize",
                    title: "Backdrop blur",
                    description: "Same effective blur radius as Windows",
                    minimum: 5,
                    maximum: 25,
                    step: 1,
                    suffix: " px"
                }
            ];
        if (reactiveTuning)
            return appearance.reactiveParameters;
        if (spectrumTuning)
            return [
                {
                    key: "spectrumSensitivity",
                    title: "Sensitivity",
                    description: "Visual amplitude without changing the reactive tint",
                    minimum: runtime.constraints.appearance.spectrumSensitivity.min * 100,
                    maximum: runtime.constraints.appearance.spectrumSensitivity.max * 100,
                    step: 5,
                    suffix: "%"
                },
                {
                    key: "spectrumAttack",
                    title: "Attack speed",
                    description: "Rise speed of visualizer bands",
                    minimum: runtime.constraints.appearance.spectrumAttack.min * 100,
                    maximum: runtime.constraints.appearance.spectrumAttack.max * 100,
                    step: 5,
                    suffix: "%"
                },
                {
                    key: "spectrumRelease",
                    title: "Release speed",
                    description: "Fall speed of visualizer bands",
                    minimum: runtime.constraints.appearance.spectrumRelease.min * 100,
                    maximum: runtime.constraints.appearance.spectrumRelease.max * 100,
                    step: 5,
                    suffix: "%"
                },
                {
                    key: "wallpaperSpectrumOpacity",
                    title: "Spectrum opacity",
                    description: "Strength of wallpaper spectrum bars",
                    minimum: runtime.constraints.appearance.wallpaperSpectrumOpacity.min * 100,
                    maximum: runtime.constraints.appearance.wallpaperSpectrumOpacity.max * 100,
                    step: 5,
                    suffix: "%"
                },
                {
                    key: "wallpaperSpectrumBars",
                    title: "Bar density",
                    description: "Number of spectrum bars",
                    minimum: runtime.constraints.appearance.wallpaperSpectrumBars.min,
                    maximum: runtime.constraints.appearance.wallpaperSpectrumBars.max,
                    step: 8,
                    suffix: " bars"
                }
            ];
        if (kind === "alerts")
            return [
                {
                    key: "quietStart",
                    title: "Quiet hours start",
                    description: "Local time",
                    minimum: 0,
                    maximum: 1425,
                    step: 15,
                    suffix: "time"
                },
                {
                    key: "quietEnd",
                    title: "Quiet hours end",
                    description: "Local time",
                    minimum: 0,
                    maximum: 1425,
                    step: 15,
                    suffix: "time"
                }
            ];
        if (kind === "nightLight") {
            const items = [
                {
                    key: "temperature",
                    title: "Colour temperature",
                    description: "Warmer at lower Kelvin values",
                    minimum: runtime.constraints.nightLight.temperature.min,
                    maximum: runtime.constraints.nightLight.temperature.max,
                    step: 100,
                    suffix: " K"
                }
            ];
            if (nightLight.mode === "custom")
                items.push({
                    key: "nightStart",
                    title: "Schedule start",
                    description: "Local time",
                    minimum: 0,
                    maximum: 1425,
                    step: 15,
                    suffix: "time"
                }, {
                    key: "nightEnd",
                    title: "Schedule end",
                    description: "Local time",
                    minimum: 0,
                    maximum: 1425,
                    step: 15,
                    suffix: "time"
                });
            if (nightLight.mode === "custom" || nightLight.mode === "solar")
                items.push({
                    key: "nightTransition",
                    title: "Transition duration",
                    description: "Gradual colour change",
                    minimum: runtime.constraints.nightLight.transitionMinutes.min,
                    maximum: runtime.constraints.nightLight.transitionMinutes.max,
                    step: 5,
                    suffix: " min"
                });
            return items;
        }
        return [];
    }

    function currentValue(key: string): real {
        if (key === "barIslandHeight" || key === "frameThickness")
            return appearance[key];
        if (key === "wallpaperSpectrumBars")
            return appearance.wallpaperSpectrumBars;
        if (key === "motionDuration")
            return Math.round(motion.durationMultiplier * 100);
        if (key.startsWith("musicReactive") || key.startsWith("spectrum") || key === "wallpaperSpectrumOpacity")
            return Math.round(appearance[key] * 100);
        if (key === "windowOpacity")
            return Math.round(appearance.windowOpacity * 100);
        if (key === "glassOpacity")
            return Math.round(appearance.glassOpacity * 100);
        if (key === "blurSize")
            return appearance.blurSize;
        if (key === "quietStart")
            return notifications.quietStart;
        if (key === "quietEnd")
            return notifications.quietEnd;
        if (key === "nightStart")
            return nightLight.startMinute;
        if (key === "nightEnd")
            return nightLight.endMinute;
        if (key === "nightTransition")
            return nightLight.transitionMinutes;
        if (key === "temperature")
            return nightLight.temperature;
        return 0;
    }

    function setValue(key: string, value: real): void {
        if (key === "barIslandHeight" || key === "frameThickness")
            appearance.setGeometryPreference(key, value);
        else if (key === "wallpaperSpectrumBars")
            appearance.setSpectrumBars(value);
        else if (key === "motionDuration")
            motion.setDurationMultiplier(value / 100);
        else if (key.startsWith("musicReactive") || key.startsWith("spectrum") || key === "wallpaperSpectrumOpacity")
            appearance.setVisualParameter(key, value / 100);
        else if (key === "windowOpacity")
            appearance.setWindowOpacity(value / 100);
        else if (key === "glassOpacity")
            appearance.setGlassOpacity(value / 100);
        else if (key === "blurSize")
            appearance.setBlurSize(value);
        else if (key === "quietStart" || key === "quietEnd")
            notifications.setQuietPreference(key === "quietStart" ? "startMinute" : "endMinute", Math.max(0, Math.min(1439, Math.round(value))));
        else if (key === "nightStart" || key === "nightEnd" || key === "nightTransition")
            nightLight.setScheduleField(key === "nightStart" ? "start" : key === "nightEnd" ? "end" : "transition", value);
        else if (key === "temperature" && nightLight.supported)
            nightLight.setTemperature(value);
    }

    function valueLabel(entry: var): string {
        const value = currentValue(entry.key);
        if (entry.suffix === "time")
            return ClockFormatting.minutesLabel(value);
        return value + entry.suffix;
    }

    function toggleMaster(): void {
        switch (kind) {
        case "windows":
            appearance.toggleWindowTransparency();
            break;
        case "glass":
            appearance.toggleShellGlass();
            break;
        case "nightLight":
            if (nightLight.supported && !nightLight.busy)
                nightLight.toggle();
            break;
        case "alerts":
            notifications.toggleSilent();
            break;
        case "stay":
            system.toggleIdleInhibited();
            break;
        case "spectrum":
            wallpaperSpectrumToggleRequested();
            break;
        case "reactive":
            musicReactiveToggleRequested();
            break;
        case "bar":
            barToggleRequested();
            break;
        case "frame":
            frameToggleRequested();
            break;
        case "motion":
            motion.toggle();
            break;
        }
    }

    function resetParameter(): void {
        if (!parameters.length)
            return;
        const key = parameters[selectedIndex].key;
        if (kind === "nightLight") {
            nightLight.change("reset-field", ({
                    temperature: "temperature",
                    nightStart: "startMinute",
                    nightEnd: "endMinute",
                    nightTransition: "transitionMinutes"
                })[key]);
        } else if (kind === "alerts") {
            notifications.resetQuietField(key === "quietStart" ? "startMinute" : "endMinute");
        } else if (key === "motionDuration") {
            motion.resetDurationMultiplier();
        } else {
            appearance.clearOverride(key);
            if (key === "windowOpacity")
                appearance.applyWindowTransparency();
            else if (key === "glassOpacity")
                appearance.applyShellGlass();
            else if (key === "blurSize")
                appearance.applyBlurSize();
        }
    }

    function resetAppearance(): void {
        if (kind === "bar" || kind === "frame") {
            appearance.clearOverride(kind === "bar" ? "barIslandHeight" : "frameThickness");
            appearance.clearOverride(kind === "bar" ? "barVisible" : "frameVisible");
            return;
        }
        if (kind === "motion") {
            motion.resetToDeclared();
            return;
        }
        if (kind === "nightLight") {
            nightLight.resetToDeclared();
            return;
        }
        if (kind === "alerts") {
            notifications.resetDeliveryPreferences();
            return;
        }
        if (reactiveTuning) {
            appearance.resetReactiveTuning();
            appearance.clearOverride("musicReactiveEnabled");
            return;
        }
        if (spectrumTuning) {
            appearance.resetSpectrumTuning();
            appearance.clearOverride("wallpaperSpectrumEnabled");
            return;
        }
        if (kind === "windows") {
            appearance.clearOverride("windowTransparencyEnabled");
            appearance.clearOverride("windowOpacity");
        } else if (kind === "glass") {
            appearance.clearOverride("shellGlassEnabled");
            appearance.clearOverride("glassOpacity");
        }
        if (hasBlur) {
            appearance.clearOverride("blurEnabled");
            appearance.clearOverride("blurSize");
            appearance.applyWindowTransparency();
            appearance.applyShellGlass();
            appearance.applyBlurSize();
        }
    }

    function activateNumber(number: int): bool {
        let repeater = null;
        let index = number - 1;
        if (kind === "nightLight") {
            if (number <= 4)
                repeater = nightModes;
            else if (number <= 7 && nightLight.mode === "custom") {
                repeater = nightDays;
                index -= 4;
            } else if (number >= 8 && nightLight.mode !== "off") {
                repeater = nightPauses;
                index -= 7;
            }
        } else if (kind === "alerts") {
            repeater = number <= 3 ? alertPauses : quietDays;
            if (number > 3)
                index -= 3;
        } else if (reactiveTuning) {
            repeater = number <= 3 ? reactivePresets : reactiveEmphases;
            if (number > 3)
                index -= 3;
        } else if (kind === "power") {
            repeater = powerProfiles;
        } else if (kind === "stay") {
            repeater = stayDurations;
        }
        const button = repeater ? (repeater.itemAt(index) as ShellAction) : null;
        if (!button)
            return false;
        button.trigger();
        return true;
    }

    onParametersChanged: selectedIndex = Math.max(0, Math.min(selectedIndex, parameters.length - 1))

    function selectParameter(index: int): void {
        if (parameters.length === 0)
            return;
        selectedIndex = (index + parameters.length) % parameters.length;
        keyboardRequested();
        const card = parameterRepeater.itemAt(selectedIndex);
        if (card) {
            const top = card.mapToItem(panel, 0, 0).y;
            revealSelection(top, top + card.height);
        }
    }

    function cancelNested(): bool {
        return kind === "displays" && displayDetails.cancelNested() || kind === "scenes" && sceneDetails.cancelNested();
    }

    function handleKey(key: int, modifiers: int, autoRepeat: bool): bool {
        if (kind === "displays")
            return displayDetails.handleKey(key, modifiers, autoRepeat);
        if (kind === "scenes")
            return sceneDetails.handleKey(key, modifiers, autoRepeat);
        if (kind === "stay" && runtime.shellMatchesHint("SettingsDetail.inhibitorsRefresh", key, modifiers)) {
            if (!autoRepeat)
                refreshInhibitorsAction.trigger();
            return true;
        }
        if (autoRepeat) {
            const repeatedAction = ["SettingsDetail.toggle", "SettingsDetail.blur", "SettingsDetail.reset", "SettingsDetail.resetParameter", "SettingsDetail.presentation", "SettingsDetail.history", "SettingsDetail.quietHours", "SettingsDetail.nightResume", "SettingsDetail.nightPauseUntil"].some(name => runtime.shellMatchesHint(name, key, modifiers));
            const choice = kind === "nightLight" ? runtime.shellChoiceIndex(key, modifiers, 9) : reactiveTuning ? runtime.shellChoiceIndex(key, modifiers, 7) : kind === "alerts" ? runtime.shellChoiceIndex(key, modifiers, 6) : kind === "power" ? runtime.shellChoiceIndex(key, modifiers, powerProfile.profiles.length) : kind === "stay" ? runtime.shellChoiceIndex(key, modifiers, 5) : -1;
            if (repeatedAction || choice >= 0)
                return true;
        }
        if (runtime.shellMatchesHint("SettingsDetail.toggle", key, modifiers) && hasMaster) {
            masterAction.trigger();
            return true;
        }
        if (runtime.shellMatchesHint("SettingsDetail.blur", key, modifiers) && hasBlur) {
            blurSwitch.trigger();
            return true;
        }
        if (runtime.shellMatchesHint("SettingsDetail.resetParameter", key, modifiers) && parameters.length > 1) {
            (parameterRepeater.itemAt(selectedIndex) as ParameterCard)?.triggerReset();
            return true;
        }
        if (runtime.shellMatchesHint("SettingsDetail.reset", key, modifiers) && hasReset) {
            appearanceReset.trigger();
            return true;
        }
        if (kind === "nightLight" && runtime.shellMatchesHint("SettingsDetail.nightResume", key, modifiers)) {
            resumeAction.trigger();
            return true;
        }
        if (kind === "nightLight" && runtime.shellMatchesHint("SettingsDetail.nightPauseUntil", key, modifiers)) {
            if (pauseUntilAction.visible)
                pauseUntilAction.trigger();
            return true;
        }
        if (kind === "alerts") {
            if (runtime.shellMatchesHint("SettingsDetail.quietHours", key, modifiers)) {
                quietHoursSwitch.trigger();
                return true;
            }
            if (runtime.shellMatchesHint("SettingsDetail.presentation", key, modifiers)) {
                presentationSwitch.trigger();
                return true;
            }
            if (runtime.shellMatchesHint("SettingsDetail.history", key, modifiers)) {
                historySwitch.trigger();
                return true;
            }
        }
        if (kind === "power" || kind === "stay" || kind === "alerts" || kind === "nightLight" || reactiveTuning) {
            const numberIndex = runtime.shellChoiceIndex(key, modifiers, kind === "nightLight" ? 9 : reactiveTuning ? 7 : kind === "alerts" ? 6 : kind === "power" ? powerProfile.profiles.length : 5);
            if (numberIndex >= 0)
                return activateNumber(numberIndex + 1);
        }
        if (parameters.length > 0) {
            if (key === runtime.shellKeyCode("controls", "Tab") || key === runtime.shellKeyCode("controls", "Backtab")) {
                selectParameter(selectedIndex + (key === runtime.shellKeyCode("controls", "Backtab") || runtime.shellModifier("controls", "Shift", modifiers) ? -1 : 1));
                return true;
            }
            if (runtime.shellNavigates("controls", "up", key)) {
                selectParameter(selectedIndex - 1);
                return true;
            }
            if (runtime.shellNavigates("controls", "down", key)) {
                selectParameter(selectedIndex + 1);
                return true;
            }
            if (runtime.shellNavigates("controls", "left", key) || runtime.shellNavigates("controls", "right", key)) {
                const entry = parameters[selectedIndex];
                if (entry) {
                    parameterAdjustmentRequested(selectedIndex);
                    setValue(entry.key, currentValue(entry.key) + (runtime.shellNavigates("controls", "left", key) ? -1 : 1) * entry.step);
                }
                return true;
            }
        }
        return false;
    }

    function openView(): void {
        selectedIndex = 0;
        open = true;
        keyboardRequested();
    }
    function closeView(): void {
        open = false;
    }

    Column {
        id: content
        width: parent.width
        spacing: panel.theme.spacing3

        Row {
            width: parent.width
            height: Math.max(44, heading.implicitHeight, masterAction.implicitHeight, appearanceReset.height, displayUtilities.height)
            spacing: panel.theme.spacing3

            Text {
                id: capabilityGlyph
                anchors.verticalCenter: parent.verticalCenter
                width: panel.theme.fontSize(26)
                text: panel.capabilityIcon
                font.family: "Symbols Nerd Font"
                font.pixelSize: panel.theme.fontSize(23)
                color: panel.theme.readableRoleColor(panel.foregroundRole)
                horizontalAlignment: Text.AlignHCenter
            }

            Column {
                id: heading
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(1, parent.width - capabilityGlyph.width - masterAction.width - appearanceReset.width - displayUtilities.width - (1 + (panel.hasMaster ? 1 : 0) + (appearanceReset.visible ? 1 : 0) + (displayUtilities.visible ? 1 : 0)) * parent.spacing)
                spacing: panel.theme.spacing1

                ShellText {
                    runtime: panel.runtime
                    theme: panel.theme
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: panel.titleText
                    font.pixelSize: panel.theme.fontDetailTitle
                    font.weight: Font.DemiBold
                }
                ShellText {
                    runtime: panel.runtime
                    theme: panel.theme
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: panel.subtitleText
                    color: panel.theme.textMuted
                    font.pixelSize: panel.theme.fontSupporting
                }
            }

            ShellAction {
                id: masterAction
                visible: panel.hasMaster
                width: visible ? implicitWidth : 0
                height: implicitHeight
                anchors.verticalCenter: parent.verticalCenter
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                iconOnly: true
                switchControl: true
                title: (panel.masterState ? "Disable " : "Enable ") + panel.titleText
                shortcut: panel.runtime.shellHint("SettingsDetail.toggle")
                active: panel.masterState
                activeColor: panel.theme.roleColor(panel.foregroundRole)
                enabled: panel.masterAvailable
                onActivated: panel.toggleMaster()
            }
            ShellUtilityAction {
                id: appearanceReset
                visible: panel.hasReset
                width: visible ? implicitWidth : 0
                height: visible ? implicitHeight : 0
                anchors.verticalCenter: parent.verticalCenter
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                icon: DesktopIcons.actionGlyph("reset")
                title: "Restore defaults"
                shortcut: panel.runtime.shellHint("SettingsDetail.reset")
                onActivated: panel.resetAppearance()
            }
            Row {
                id: displayUtilities
                visible: panel.kind === "displays"
                width: visible ? implicitWidth : 0
                height: visible ? implicitHeight : 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: panel.theme.spacing1
                ShellUtilityAction {
                    id: nativeDisplayAction
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    icon: DesktopIcons.actionGlyph("settings")
                    title: "Advanced display editor"
                    shortcut: panel.runtime.shellHint("DisplaySettings.native")
                    enabled: displayDetails.canOpenNative
                    onActivated: panel.nativeDisplayEditorRequested()
                }
                ShellUtilityAction {
                    id: refreshDisplayAction
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    icon: DesktopIcons.actionGlyph("refresh")
                    title: "Refresh display state"
                    shortcut: panel.runtime.shellHint("DisplaySettings.refresh")
                    enabled: displayDetails.canRefresh
                    onActivated: displayDetails.refresh()
                }
            }
        }

        ScenePanel {
            id: sceneDetails
            visible: panel.kind === "scenes"
            width: parent.width
            engaged: panel.open && visible
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            scenes: panel.scenes
            onKeyboardRequested: panel.keyboardRequested()
            onRevealSelection: (top, bottom) => panel.revealSelection(sceneDetails.y + top, sceneDetails.y + bottom)
        }

        DisplaySettings {
            id: displayDetails
            visible: panel.kind === "displays"
            width: parent.width
            engaged: panel.open && visible
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            onRefreshRequested: refreshDisplayAction.trigger()
            onNativeRequested: nativeDisplayAction.trigger()
        }

        Row {
            visible: panel.hasBlur
            width: parent.width
            height: visible ? Math.max(blurLabel.implicitHeight, blurSwitch.implicitHeight) : 0
            spacing: panel.theme.spacing2
            ShellText {
                id: blurLabel
                width: Math.max(1, parent.width - blurSwitch.width - parent.spacing)
                anchors.verticalCenter: parent.verticalCenter
                runtime: panel.runtime
                theme: panel.theme
                text: "Compositor blur"
                textRole: ShellText.Action
                wrapMode: Text.WordWrap
            }
            ShellAction {
                id: blurSwitch
                width: implicitWidth
                height: implicitHeight
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                iconOnly: true
                switchControl: true
                title: panel.appearance.blurEnabled ? "Disable compositor blur" : "Enable compositor blur"
                active: panel.appearance.blurEnabled
                shortcut: panel.runtime.shellHint("SettingsDetail.blur")
                onActivated: panel.appearance.toggleBlur()
            }
        }

        Column {
            visible: panel.reactiveTuning || panel.spectrumTuning
            width: parent.width
            spacing: panel.theme.spacing2

            ShellSurface {
                width: parent.width
                height: liveSignal.implicitHeight + panel.theme.spacing4 * 2
                theme: panel.theme
                motion: panel.motion
                surfaceLayer: ShellSurface.Group
                cornerRadius: panel.theme.radiusLarge
                fillColor: panel.theme.reactiveColor(panel.theme.groupBase, 0.5)
                Column {
                    id: liveSignal
                    width: parent.width - panel.theme.spacing4 * 2
                    anchors.centerIn: parent
                    spacing: panel.theme.spacing2
                    Row {
                        width: parent.width
                        ShellText {
                            runtime: panel.runtime
                            theme: panel.theme
                            text: panel.spectrum.connected ? panel.spectrum.hasEnergy ? "Live audio" : "Listening · silence" : "Analyser disconnected"
                            textRole: ShellText.Section
                        }
                    }
                    SpectrumBars {
                        width: parent.width
                        height: panel.theme.fontSize(76)
                        theme: panel.theme
                        spectrum: panel.spectrum
                        frequencyScale: SpectrumScale {
                            lowHz: panel.spectrum.lowHz
                            highHz: panel.spectrum.highHz
                        }
                    }
                    Row {
                        width: parent.width
                        spacing: panel.theme.spacing3
                        Repeater {
                            model: [
                                {
                                    name: "Bass",
                                    amount: panel.spectrum.bass
                                },
                                {
                                    name: "Mid",
                                    amount: panel.spectrum.mid
                                },
                                {
                                    name: "Treble",
                                    amount: panel.spectrum.high
                                }
                            ]
                            delegate: Column {
                                id: bandMetric
                                required property int index
                                required property var modelData
                                width: (liveSignal.width - panel.theme.spacing3 * 2) / 3
                                spacing: panel.theme.spacing1
                                ShellText {
                                    runtime: panel.runtime
                                    theme: panel.theme
                                    text: bandMetric.modelData.name
                                    textRole: ShellText.Utility
                                }
                                LevelTrack {
                                    width: parent.width
                                    height: panel.theme.standardTrack
                                    theme: panel.theme
                                    motion: panel.motion
                                    known: panel.spectrum.connected
                                    fraction: bandMetric.modelData.amount
                                    accentColor: panel.theme.spectrumColor(bandMetric.index / 2)
                                }
                            }
                        }
                    }
                }
            }

            ShellText {
                visible: panel.reactiveTuning
                runtime: panel.runtime
                theme: panel.theme
                text: "Preset · " + panel.appearance.musicReactivePreset
                color: panel.theme.textMuted
                font.pixelSize: panel.theme.fontSize(10)
            }

            Row {
                visible: panel.reactiveTuning
                width: parent.width
                height: visible ? 44 : 0
                spacing: Math.max(2, panel.theme.spacing1 / 2)
                Repeater {
                    id: reactivePresets
                    model: ["Subtle", "Default", "Energetic"]
                    delegate: ShellChoice {
                        required property int index
                        required property string modelData
                        width: (panel.width - Math.max(2, panel.theme.spacing1 / 2) * 2) / 3
                        height: 44
                        runtime: panel.runtime
                        theme: panel.theme
                        motion: panel.motion
                        title: modelData
                        shortcut: panel.runtime.shellChoiceHint(index)
                        compact: true
                        horizontalCompact: true
                        choices: reactivePresets
                        choiceIndex: index
                        activeColor: panel.theme.roleColor("reactive")
                        active: panel.appearance.musicReactivePreset === modelData
                        onActivated: panel.appearance.applyReactivePreset(modelData)
                    }
                }
            }

            ShellText {
                visible: panel.reactiveTuning
                runtime: panel.runtime
                theme: panel.theme
                text: "Frequency emphasis"
                color: panel.theme.textMuted
                font.pixelSize: panel.theme.fontSize(10)
            }

            Row {
                visible: panel.reactiveTuning
                width: parent.width
                height: visible ? 44 : 0
                spacing: Math.max(2, panel.theme.spacing1 / 2)
                Repeater {
                    id: reactiveEmphases
                    model: ["balanced", "bass", "mid", "treble"]
                    delegate: ShellChoice {
                        required property int index
                        required property string modelData
                        width: (panel.width - Math.max(2, panel.theme.spacing1 / 2) * 3) / 4
                        height: 44
                        runtime: panel.runtime
                        theme: panel.theme
                        motion: panel.motion
                        title: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                        shortcut: panel.runtime.shellChoiceHint(index + 3)
                        compact: true
                        horizontalCompact: true
                        choices: reactiveEmphases
                        choiceIndex: index
                        activeColor: panel.theme.roleColor("reactive")
                        active: panel.appearance.musicReactiveEmphasis === modelData
                        onActivated: panel.appearance.setReactiveEmphasis(modelData)
                    }
                }
            }
        }

        ScheduleBand {
            visible: panel.kind === "alerts" || panel.kind === "nightLight" && panel.nightLight.mode === "custom"
            width: parent.width
            height: visible ? implicitHeight : 0
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            label: panel.kind === "alerts" ? "Quiet hours" : "Night Light schedule"
            startMinute: panel.kind === "alerts" ? panel.notifications.quietStart : panel.nightLight.startMinute
            endMinute: panel.kind === "alerts" ? panel.notifications.quietEnd : panel.nightLight.endMinute
            scheduleEnabled: panel.kind === "alerts" ? panel.notifications.quietEnabled : panel.nightLight.mode === "custom"
            phaseColor: panel.theme.roleColor(panel.kind === "alerts" ? "schedule" : "warmth")
        }

        Flow {
            id: parameterFlow
            width: parent.width
            readonly property int columns: (panel.reactiveTuning || panel.spectrumTuning || panel.kind === "alerts" || panel.kind === "nightLight") && width >= panel.theme.fontSize(750) ? 2 : 1
            spacing: panel.theme.spacing3
            Repeater {
                id: parameterRepeater
                model: panel.parameters
                delegate: ParameterCard {
                    id: parameterCard
                    required property int index
                    required property var modelData
                    width: modelData.key === "temperature" || index === panel.parameters.length - 1 && panel.parameters.length % parameterFlow.columns === 1 ? parameterFlow.width : Math.floor((parameterFlow.width - (parameterFlow.columns - 1) * parameterFlow.spacing) / parameterFlow.columns)
                    height: implicitHeight
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    title: modelData.title
                    description: modelData.description
                    readback: panel.valueLabel(modelData)
                    from: modelData.minimum
                    to: modelData.maximum
                    value: panel.currentValue(modelData.key)
                    accentColor: panel.theme.readableRoleColor(modelData.suffix === "time" ? "schedule" : panel.foregroundRole)
                    temperatureTrack: modelData.key === "temperature" && panel.kind === "nightLight"
                    selectedParameter: panel.selectedIndex === index
                    adjustable: panel.kind !== "nightLight" || panel.nightLight.supported
                    adjustShortcut: panel.runtime.shellHint("SettingsDetail.adjust")
                    resetShortcut: panel.parameters.length > 1 ? panel.runtime.shellHint("SettingsDetail.resetParameter") : ""
                    onSelectedRequested: panel.selectParameter(index)
                    onValueRequested: next => panel.setValue(modelData.key, Math.round(next / modelData.step) * modelData.step)
                    onResetRequested: panel.resetParameter()
                    Connections {
                        target: panel
                        function onParameterAdjustmentRequested(index: int): void {
                            if (index === parameterCard.index)
                                parameterCard.beginKeyboardAdjustment();
                        }
                    }
                }
            }
        }

        Column {
            visible: panel.kind === "nightLight"
            width: parent.width
            spacing: panel.theme.spacing2
            ShellText {
                width: parent.width
                runtime: panel.runtime
                theme: panel.theme
                text: panel.nightLight.statusLabel
                color: panel.theme.textMuted
                wrapMode: Text.WordWrap
            }
            Row {
                width: parent.width
                height: 40
                spacing: Math.max(2, panel.theme.spacing1 / 2)
                Repeater {
                    id: nightModes
                    model: [
                        {
                            id: "off",
                            title: "Off"
                        },
                        {
                            id: "manual",
                            title: "Manual"
                        },
                        {
                            id: "custom",
                            title: "Schedule"
                        },
                        {
                            id: "solar",
                            title: "Sunset"
                        }
                    ]
                    delegate: ShellChoice {
                        required property int index
                        required property var modelData
                        width: (panel.width - Math.max(2, panel.theme.spacing1 / 2) * 3) / 4
                        height: 40
                        runtime: panel.runtime
                        theme: panel.theme
                        motion: panel.motion
                        compact: true
                        horizontalCompact: true
                        title: modelData.title
                        shortcut: panel.runtime.shellChoiceHint(index)
                        choices: nightModes
                        choiceIndex: index
                        activeColor: panel.theme.roleColor("warmth")
                        active: panel.nightLight.mode === modelData.id
                        enabled: panel.masterAvailable && (modelData.id !== "solar" || panel.nightLight.solarAvailable)
                        onActivated: panel.nightLight.setMode(modelData.id)
                    }
                }
            }
            ShellText {
                visible: !panel.nightLight.solarAvailable
                width: parent.width
                runtime: panel.runtime
                theme: panel.theme
                text: "Sunset mode requires explicit Night Light latitude and longitude in Nix."
                color: panel.theme.textMuted
                font.pixelSize: panel.theme.fontSize(10)
                wrapMode: Text.WordWrap
            }
            Row {
                visible: panel.nightLight.mode === "custom"
                width: parent.width
                height: visible ? 40 : 0
                spacing: Math.max(2, panel.theme.spacing1 / 2)
                Repeater {
                    id: nightDays
                    model: [
                        {
                            title: "Every day",
                            days: 127
                        },
                        {
                            title: "Weekdays",
                            days: 62
                        },
                        {
                            title: "Weekends",
                            days: 65
                        }
                    ]
                    delegate: ShellChoice {
                        required property int index
                        required property var modelData
                        width: (panel.width - Math.max(2, panel.theme.spacing1 / 2) * 2) / 3
                        height: 40
                        runtime: panel.runtime
                        theme: panel.theme
                        motion: panel.motion
                        compact: true
                        horizontalCompact: true
                        title: modelData.title
                        choices: nightDays
                        choiceIndex: index
                        activeColor: panel.theme.roleColor("schedule")
                        active: panel.nightLight.days === modelData.days
                        shortcut: panel.runtime.shellChoiceHint(index + 4)
                        enabled: panel.masterAvailable
                        onActivated: panel.nightLight.change("days", String(modelData.days))
                    }
                }
            }
            Row {
                width: parent.width
                height: 40
                spacing: panel.theme.spacing2
                Repeater {
                    id: nightPauses
                    model: [30, 60]
                    delegate: ShellAction {
                        required property int index
                        required property int modelData
                        width: (panel.width - panel.theme.spacing2 * 2) / 3
                        height: 40
                        runtime: panel.runtime
                        theme: panel.theme
                        motion: panel.motion
                        title: "Pause " + modelData + " min"
                        shortcut: panel.runtime.shellChoiceHint(index + 7)
                        compact: true
                        horizontalCompact: true
                        enabled: panel.masterAvailable && panel.nightLight.mode !== "off"
                        onActivated: panel.nightLight.change("pause", String(modelData))
                    }
                }
                ShellAction {
                    id: resumeAction
                    width: (panel.width - panel.theme.spacing2 * 2) / 3
                    height: 40
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    title: "Resume"
                    shortcut: panel.runtime.shellHint("SettingsDetail.nightResume")
                    compact: true
                    horizontalCompact: true
                    enabled: panel.masterAvailable && panel.nightLight.temporaryOverride.length > 0
                    onActivated: panel.nightLight.change("resume", "")
                }
            }
            ShellAction {
                id: pauseUntilAction
                visible: panel.nightLight.mode === "custom" || panel.nightLight.mode === "solar"
                width: implicitWidth
                height: visible ? implicitHeight : 0
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                title: "Pause until next transition"
                shortcut: panel.runtime.shellHint("SettingsDetail.nightPauseUntil")
                compact: true
                horizontalCompact: true
                enabled: panel.masterAvailable
                onActivated: panel.nightLight.change("pause", "0")
            }
        }

        Column {
            visible: panel.kind === "power"
            width: parent.width
            spacing: panel.theme.spacing2
            ShellSurface {
                id: batteryCard
                visible: panel.powerProfile.batteryAvailable
                width: parent.width
                height: visible ? batteryContent.implicitHeight + panel.theme.spacing4 * 2 : 0
                theme: panel.theme
                motion: panel.motion
                surfaceLayer: ShellSurface.Group
                cornerRadius: panel.theme.radiusLarge
                readonly property real charge: panel.powerProfile.batteryAvailable ? panel.powerProfile.battery.percentage : 0
                readonly property color chargeColor: charge <= 0.2 ? panel.theme.warning : panel.theme.positive
                fillColor: panel.theme.blend(panel.theme.groupBase, chargeColor, 0.09)
                Column {
                    id: batteryContent
                    width: parent.width - panel.theme.spacing4 * 2
                    anchors.centerIn: parent
                    spacing: panel.theme.spacing2
                    Row {
                        width: parent.width
                        spacing: panel.theme.spacing3
                        Item {
                            width: panel.theme.fontSize(112)
                            height: panel.theme.fontSize(52)
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle {
                                width: parent.width - panel.theme.spacing2
                                height: parent.height
                                radius: panel.theme.radiusSmall
                                color: panel.theme.layer3
                                border.color: batteryCard.chargeColor
                                border.width: panel.theme.borderThin
                                Rectangle {
                                    x: panel.theme.spacing1
                                    y: panel.theme.spacing1
                                    width: Math.max(0, (parent.width - panel.theme.spacing1 * 2) * batteryCard.charge)
                                    height: parent.height - panel.theme.spacing1 * 2
                                    radius: Math.max(0, parent.radius - panel.theme.spacing1)
                                    color: batteryCard.chargeColor
                                }
                            }
                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: panel.theme.spacing1
                                height: parent.height * 0.42
                                radius: width / 2
                                color: batteryCard.chargeColor
                            }
                        }
                        Column {
                            width: Math.max(1, parent.width - panel.theme.fontSize(112) - parent.spacing)
                            anchors.verticalCenter: parent.verticalCenter
                            ShellText {
                                runtime: panel.runtime
                                theme: panel.theme
                                text: Math.round(batteryCard.charge * 100) + "%"
                                textRole: ShellText.Display
                                color: batteryCard.chargeColor
                            }
                            ShellText {
                                width: parent.width
                                runtime: panel.runtime
                                theme: panel.theme
                                text: panel.powerProfile.batteryAvailable ? panel.powerProfile.onBattery ? "Battery power · " + panel.powerProfile.duration(panel.powerProfile.battery.timeToEmpty) + " remaining" : "External power" + (panel.powerProfile.battery.timeToFull > 0 ? " · " + panel.powerProfile.duration(panel.powerProfile.battery.timeToFull) + " to full" : "") : ""
                                textRole: ShellText.Supporting
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                    ShellText {
                        runtime: panel.runtime
                        theme: panel.theme
                        text: panel.powerProfile.batteryAvailable ? panel.powerProfile.battery.energy.toFixed(1) + " / " + panel.powerProfile.battery.energyCapacity.toFixed(1) + " Wh" : ""
                        textRole: ShellText.Supporting
                    }
                }
            }
            Repeater {
                model: panel.powerProfile.physicalBatteries
                delegate: ShellText {
                    required property var modelData
                    width: panel.width
                    runtime: panel.runtime
                    theme: panel.theme
                    text: (modelData.model || "Battery") + " · Health " + (modelData.healthSupported ? Math.round(modelData.healthPercentage) + "%" : "unavailable")
                    color: panel.theme.textMuted
                }
            }
            Flow {
                id: profileFlow
                width: parent.width
                spacing: panel.theme.spacing2
                readonly property int columns: width >= panel.theme.fontSize(360) ? Math.max(1, panel.powerProfile.profiles.length) : 1
                Repeater {
                    id: powerProfiles
                    model: panel.powerProfile.profiles
                    delegate: ShellChoice {
                        required property int index
                        required property string modelData
                        width: Math.floor((profileFlow.width - (profileFlow.columns - 1) * profileFlow.spacing) / profileFlow.columns)
                        height: Math.max(panel.theme.fontSize(82), implicitHeight)
                        runtime: panel.runtime
                        theme: panel.theme
                        motion: panel.motion
                        icon: DesktopIcons.powerProfileGlyph(modelData)
                        title: panel.powerProfile.label(modelData)
                        shortcut: panel.runtime.shellChoiceHint(index)
                        choices: powerProfiles
                        choiceIndex: index
                        joined: profileFlow.columns > 1
                        active: panel.powerProfile.current === modelData
                        activeColor: panel.theme.powerProfileColor(modelData)
                        enabled: panel.powerProfile.available && !panel.powerProfile.applying
                        onActivated: panel.powerProfile.setProfile(modelData)
                    }
                }
            }
            ShellText {
                visible: panel.powerProfile.performanceDegraded
                width: parent.width
                runtime: panel.runtime
                theme: panel.theme
                text: "Performance restricted · " + panel.powerProfile.degradation
                color: panel.theme.warning
                wrapMode: Text.WordWrap
            }
            Repeater {
                model: panel.powerProfile.holds
                delegate: ShellText {
                    required property var modelData
                    width: panel.width
                    runtime: panel.runtime
                    theme: panel.theme
                    text: "Profile held by " + modelData.applicationId + " · " + modelData.reason
                    color: panel.theme.textMuted
                    wrapMode: Text.WordWrap
                }
            }
        }

        Column {
            visible: panel.kind === "stay"
            width: parent.width
            spacing: panel.theme.spacing2
            ShellSurface {
                width: parent.width
                height: awakeContent.implicitHeight + panel.theme.spacing4 * 2
                theme: panel.theme
                motion: panel.motion
                surfaceLayer: ShellSurface.Group
                cornerRadius: panel.theme.radiusLarge
                fillColor: panel.theme.blend(panel.theme.groupBase, panel.theme.roleColor("inhibition"), panel.system.idleInhibited ? 0.13 : 0.04)
                Row {
                    id: awakeContent
                    width: parent.width - panel.theme.spacing4 * 2
                    anchors.centerIn: parent
                    spacing: panel.theme.spacing4
                    readonly property bool finite: panel.system.idleInhibited && panel.system.idleInhibitDeadline > 0 && panel.system.idleInhibitMinutes > 0
                    ResourceGauge {
                        id: countdown
                        visible: awakeContent.finite
                        width: visible ? panel.theme.fontSize(124) : 0
                        height: visible ? width : 0
                        anchors.verticalCenter: parent.verticalCenter
                        theme: panel.theme
                        motion: panel.motion
                        value: Math.max(0, (panel.system.idleInhibitDeadline - panel.clockMs) / Math.max(1, panel.system.idleInhibitMinutes * 60000))
                        accentColor: panel.theme.roleColor("inhibition")
                        readback: Math.max(0, Math.ceil((panel.system.idleInhibitDeadline - panel.clockMs) / 60000)) + "m"
                        label: "Remaining"
                    }
                    Column {
                        width: Math.max(1, awakeContent.width - countdown.width - (countdown.visible ? awakeContent.spacing : 0))
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: panel.theme.spacing2
                        ShellText {
                            width: parent.width
                            runtime: panel.runtime
                            theme: panel.theme
                            text: awakeContent.finite ? "Stay awake" : panel.idleStatus
                            textRole: ShellText.Display
                            color: panel.theme.readableRoleColor("inhibition")
                            wrapMode: Text.WordWrap
                        }
                        ShellText {
                            visible: awakeContent.finite
                            width: parent.width
                            runtime: panel.runtime
                            theme: panel.theme
                            text: "Ends at " + ClockFormatting.wallClock(new Date(panel.system.idleInhibitDeadline))
                            textRole: ShellText.Supporting
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
            ShellSection {
                runtime: panel.runtime
                theme: panel.theme
                title: "Duration"
                emphasized: true
                accentRole: "power"
                Flow {
                    id: durationFlow
                    width: parent.width
                    readonly property int columns: width >= panel.theme.fontSize(480) ? 4 : 2
                    spacing: panel.theme.spacing2
                    Repeater {
                        id: stayDurations
                        model: [15, 30, 60, 120, 0]
                        delegate: ShellChoice {
                            required property int index
                            required property int modelData
                            width: modelData === 0 ? durationFlow.width : Math.floor((durationFlow.width - (durationFlow.columns - 1) * durationFlow.spacing) / durationFlow.columns)
                            height: Math.max(panel.theme.fontSize(44), implicitHeight)
                            runtime: panel.runtime
                            theme: panel.theme
                            motion: panel.motion
                            compact: true
                            horizontalCompact: true
                            title: modelData === 0 ? "Until disabled" : modelData + " minutes"
                            shortcut: panel.runtime.shellChoiceHint(index)
                            joined: false
                            activeColor: panel.theme.roleColor("inhibition")
                            active: panel.system.idleInhibited && panel.system.idleInhibitMinutes === modelData
                            onActivated: panel.system.setIdleInhibitMinutes(modelData)
                        }
                    }
                }
            }
            ShellSection {
                runtime: panel.runtime
                theme: panel.theme
                title: "System inhibitor locks"
                ShellText {
                    width: parent.width
                    runtime: panel.runtime
                    theme: panel.theme
                    text: "Reported by systemd-logind; Wayland surface idle inhibition is separate."
                    textRole: ShellText.Supporting
                    wrapMode: Text.WordWrap
                }
                ShellAction {
                    id: refreshInhibitorsAction
                    width: parent.width
                    height: Math.max(panel.theme.fontSize(44), implicitHeight)
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    compact: true
                    horizontalCompact: true
                    icon: DesktopIcons.actionGlyph("refresh")
                    title: panel.inhibitorStatus
                    shortcut: panel.runtime.shellHint("SettingsDetail.inhibitorsRefresh")
                    enabled: panel.inspectingInhibitors && !inhibitorQuery.running
                    onActivated: panel.refreshInhibitors()
                }
                Repeater {
                    model: panel.inhibitorEntries
                    delegate: Column {
                        id: inhibitorEntry
                        required property var modelData
                        width: parent.width
                        spacing: panel.theme.spacing1
                        ShellText {
                            width: parent.width
                            runtime: panel.runtime
                            theme: panel.theme
                            textFormat: Text.PlainText
                            text: inhibitorEntry.modelData.who + " · " + inhibitorEntry.modelData.mode
                            wrapMode: Text.Wrap
                        }
                        ShellText {
                            width: parent.width
                            runtime: panel.runtime
                            theme: panel.theme
                            textFormat: Text.PlainText
                            text: inhibitorEntry.modelData.what + " · " + inhibitorEntry.modelData.why
                            textRole: ShellText.Supporting
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }

        Column {
            visible: panel.kind === "alerts"
            width: parent.width
            spacing: panel.theme.spacing2
            ShellText {
                runtime: panel.runtime
                theme: panel.theme
                text: panel.notifications.suppressionLabel
                color: panel.theme.textMuted
            }
            ShellSection {
                runtime: panel.runtime
                theme: panel.theme
                title: "Temporary silence"
                emphasized: true
                accentRole: "attention"
                Row {
                    width: parent.width
                    height: 40
                    spacing: panel.theme.spacing2
                    Repeater {
                        id: alertPauses
                        model: [15, 30, 60]
                        delegate: ShellAction {
                            required property int index
                            required property int modelData
                            width: (panel.width - panel.theme.spacing2 * 2) / 3
                            height: 40
                            runtime: panel.runtime
                            theme: panel.theme
                            motion: panel.motion
                            title: modelData + " min"
                            shortcut: panel.runtime.shellChoiceHint(index)
                            compact: true
                            horizontalCompact: true
                            onActivated: panel.notifications.silenceFor(modelData)
                        }
                    }
                }
            }
            ShellSection {
                runtime: panel.runtime
                theme: panel.theme
                title: "Quiet hours"
                emphasized: true
                accentRole: "attention"
                Row {
                    width: parent.width
                    spacing: panel.theme.spacing2
                    ShellText {
                        width: Math.max(1, parent.width - quietHoursSwitch.width - parent.spacing)
                        anchors.verticalCenter: parent.verticalCenter
                        runtime: panel.runtime
                        theme: panel.theme
                        text: "Quiet hours"
                        textRole: ShellText.Action
                        wrapMode: Text.WordWrap
                    }
                    ShellAction {
                        id: quietHoursSwitch
                        width: implicitWidth
                        height: implicitHeight
                        runtime: panel.runtime
                        theme: panel.theme
                        motion: panel.motion
                        compact: true
                        iconOnly: true
                        switchControl: true
                        title: (active ? "Disable " : "Enable ") + "quiet hours"
                        active: panel.notifications.quietEnabled
                        enabled: true
                        shortcut: panel.runtime.shellHint("SettingsDetail.quietHours")
                        onActivated: panel.notifications.setQuietPreference("enabled", !panel.notifications.quietEnabled)
                    }
                }
                Row {
                    width: parent.width
                    height: 40
                    spacing: Math.max(2, panel.theme.spacing1 / 2)
                    Repeater {
                        id: quietDays
                        model: [
                            {
                                title: "Every day",
                                days: 127
                            },
                            {
                                title: "Weekdays",
                                days: 62
                            },
                            {
                                title: "Weekends",
                                days: 65
                            }
                        ]
                        delegate: ShellChoice {
                            required property int index
                            required property var modelData
                            width: (panel.width - Math.max(2, panel.theme.spacing1 / 2) * 2) / 3
                            height: 40
                            runtime: panel.runtime
                            theme: panel.theme
                            motion: panel.motion
                            title: modelData.title
                            shortcut: panel.runtime.shellChoiceHint(index + 3)
                            compact: true
                            horizontalCompact: true
                            choices: quietDays
                            choiceIndex: index
                            activeColor: panel.theme.roleColor("schedule")
                            active: panel.notifications.quietDays === modelData.days
                            onActivated: panel.notifications.setQuietPreference("days", modelData.days)
                        }
                    }
                }
            }
            ShellSection {
                runtime: panel.runtime
                theme: panel.theme
                title: "Delivery and history"
                emphasized: true
                accentRole: "attention"
                Row {
                    width: parent.width
                    spacing: panel.theme.spacing2
                    ShellText {
                        width: Math.max(1, parent.width - presentationSwitch.width - parent.spacing)
                        anchors.verticalCenter: parent.verticalCenter
                        runtime: panel.runtime
                        theme: panel.theme
                        text: "Presentation mode"
                        textRole: ShellText.Action
                        wrapMode: Text.WordWrap
                    }
                    ShellAction {
                        id: presentationSwitch
                        width: implicitWidth
                        height: implicitHeight
                        runtime: panel.runtime
                        theme: panel.theme
                        motion: panel.motion
                        compact: true
                        iconOnly: true
                        switchControl: true
                        title: (active ? "Disable " : "Enable ") + "presentation mode"
                        active: panel.notifications.presentation
                        enabled: true
                        shortcut: panel.runtime.shellHint("SettingsDetail.presentation")
                        onActivated: panel.notifications.togglePresentation()
                    }
                }
                Row {
                    width: parent.width
                    spacing: panel.theme.spacing2
                    ShellText {
                        width: Math.max(1, parent.width - historySwitch.width - parent.spacing)
                        anchors.verticalCenter: parent.verticalCenter
                        runtime: panel.runtime
                        theme: panel.theme
                        text: "Save notification history"
                        textRole: ShellText.Action
                        wrapMode: Text.WordWrap
                    }
                    ShellAction {
                        id: historySwitch
                        width: implicitWidth
                        height: implicitHeight
                        runtime: panel.runtime
                        theme: panel.theme
                        motion: panel.motion
                        compact: true
                        iconOnly: true
                        switchControl: true
                        title: (active ? "Disable " : "Enable ") + "save notification history"
                        active: panel.notifications.historyEnabled
                        enabled: true
                        shortcut: panel.runtime.shellHint("SettingsDetail.history")
                        onActivated: panel.notifications.toggleHistory()
                    }
                }
            }
        }

        KeyHintStrip {
            visible: panel.parameters.length > 1
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            hints: [
                {
                    shortcut: panel.runtime.shellHint("SettingsDetail.select"),
                    label: "Select parameter"
                }
            ]
        }
    }
}

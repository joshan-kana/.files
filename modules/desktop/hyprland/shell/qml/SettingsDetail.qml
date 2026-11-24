pragma ComponentBehavior: Bound
import QtQuick

// One capability at a time. Parameters and quick actions share their existing
// authoritative service owners, including Nix-default/user-override semantics.
Item {
    id: panel

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property AppearancePreferences appearance
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
    signal keyboardRequested
    signal parameterAdjustmentRequested(int index)

    property string kind: ""
    property bool open: false
    property int selectedIndex: 0
    property double clockMs: Date.now()
    Timer {
        interval: 1000
        running: panel.open && panel.kind === "stay" && panel.system.idleInhibited && panel.system.idleInhibitDeadline > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: panel.clockMs = Date.now()
    }
    readonly property string idleStatus: !system.idleInhibited ? "Idle allowed" : system.idleInhibitDeadline <= 0 ? "Inhibited until disabled" : Math.max(0, Math.ceil((system.idleInhibitDeadline - clockMs) / 60000)) + " min remaining"
    visible: open
    implicitWidth: theme.controlsDetailWidth
    implicitHeight: content.implicitHeight

    readonly property bool hasMaster: ["windows", "glass", "nightLight", "alerts", "stay", "spectrum", "reactive", "bar", "frame", "motion"].includes(kind)
    readonly property bool hasBlur: ["windows", "glass"].includes(kind)
    readonly property bool reactiveTuning: kind === "reactive"
    readonly property bool spectrumTuning: kind === "spectrum"
    readonly property bool hasReset: hasBlur || spectrumTuning || kind === "alerts"
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
            motion: "Animations"
        })[kind] || "Settings"
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
    readonly property bool masterAvailable: kind !== "nightLight" || nightLight.supported && !nightLight.busy
    readonly property var parameters: {
        if (kind === "windows")
            return [
                {
                    key: "windowOpacity",
                    title: "Window opacity",
                    description: "Opacity of active and inactive windows",
                    minimum: 20,
                    maximum: 100,
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
                    minimum: 20,
                    maximum: 100,
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
            return [
                {
                    key: "musicReactiveSensitivity",
                    title: "Sensitivity",
                    description: "Response to quiet audio",
                    minimum: 40,
                    maximum: 300,
                    step: 5,
                    suffix: "%"
                },
                {
                    key: "musicReactiveAttack",
                    title: "Attack",
                    description: "Strength of beat transients",
                    minimum: 50,
                    maximum: 250,
                    step: 5,
                    suffix: "%"
                },
                {
                    key: "musicReactiveRelease",
                    title: "Release speed",
                    description: "Higher values settle sooner",
                    minimum: 40,
                    maximum: 250,
                    step: 5,
                    suffix: "%"
                },
                {
                    key: "musicReactiveSmoothing",
                    title: "Smoothing",
                    description: "Smooth the sustained envelope",
                    minimum: 0,
                    maximum: 90,
                    step: 5,
                    suffix: "%"
                },
                {
                    key: "musicReactiveIntensity",
                    title: "Tint intensity",
                    description: "Strength of the shared shell tint",
                    minimum: 25,
                    maximum: 200,
                    step: 5,
                    suffix: "%"
                }
            ];
        if (spectrumTuning)
            return [
                {
                    key: "wallpaperSpectrumOpacity",
                    title: "Spectrum opacity",
                    description: "Strength of wallpaper spectrum bars",
                    minimum: 20,
                    maximum: 100,
                    step: 5,
                    suffix: "%"
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
        if (kind === "nightLight")
            return [
                {
                    key: "temperature",
                    title: "Colour temperature",
                    description: "Warmer at lower Kelvin values",
                    minimum: 2500,
                    maximum: 6500,
                    step: 100,
                    suffix: " K"
                }
            ];
        return [];
    }

    function currentValue(key: string): real {
        if (key.startsWith("musicReactive") || key === "wallpaperSpectrumOpacity")
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
        if (key === "temperature")
            return nightLight.temperature;
        return 0;
    }

    function setValue(key: string, value: real): void {
        if (key.startsWith("musicReactive") || key === "wallpaperSpectrumOpacity")
            appearance.setReactiveParameter(key, value / 100);
        else if (key === "windowOpacity")
            appearance.setWindowOpacity(value / 100);
        else if (key === "glassOpacity")
            appearance.setGlassOpacity(value / 100);
        else if (key === "blurSize")
            appearance.setBlurSize(value);
        else if (key === "quietStart" || key === "quietEnd")
            notifications.setQuietPreference(key === "quietStart" ? "startMinute" : "endMinute", Math.max(0, Math.min(1439, Math.round(value))));
        else if (key === "temperature" && nightLight.supported)
            nightLight.setTemperature(value);
    }

    function valueLabel(entry: var): string {
        const value = currentValue(entry.key);
        if (entry.suffix === "time")
            return String(Math.floor(value / 60)).padStart(2, "0") + ":" + String(value % 60).padStart(2, "0");
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

    function resetAppearance(): void {
        if (kind === "alerts") {
            notifications.resetQuietHours();
            return;
        }
        if (reactiveTuning) {
            appearance.resetReactiveTuning();
            return;
        }
        if (spectrumTuning) {
            appearance.resetSpectrumTuning();
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
        if (kind === "alerts") {
            if (number >= 1 && number <= 3) {
                notifications.silenceFor([15, 30, 60][number - 1]);
                return true;
            }
            if (number >= 4 && number <= 6) {
                notifications.setQuietPreference("days", [127, 62, 65][number - 4]);
                return true;
            }
        }
        if (reactiveTuning) {
            if (number >= 1 && number <= 3) {
                appearance.applyReactivePreset(["Subtle", "Default", "Energetic"][number - 1]);
                return true;
            }
            if (number >= 4 && number <= 7) {
                appearance.setReactiveEmphasis(["balanced", "bass", "mid", "treble"][number - 4]);
                return true;
            }
        }
        if (kind === "power") {
            const profiles = powerProfile.profiles;
            if (number <= profiles.length) {
                powerProfile.setProfile(profiles[number - 1]);
                return true;
            }
        }
        if (kind === "stay") {
            const durations = [15, 30, 60, 120, 0];
            if (number <= durations.length) {
                system.setIdleInhibitMinutes(durations[number - 1]);
                return true;
            }
        }
        return false;
    }

    function selectParameter(index: int): void {
        if (parameters.length === 0)
            return;
        selectedIndex = (index + parameters.length) % parameters.length;
        keyboardRequested();
    }

    function handleKey(key: int, modifiers: int, autoRepeat: bool): bool {
        if (autoRepeat) {
            const repeatedAction = ["SettingsDetail.toggle", "SettingsDetail.blur", "SettingsDetail.reset", "SettingsDetail.presentation", "SettingsDetail.history", "SettingsDetail.quietHours"].some(name => runtime.shellMatchesHint(name, key, modifiers));
            const choice = reactiveTuning ? runtime.shellNumberIndex("controls", key, 7) : kind === "alerts" ? runtime.shellNumberIndex("controls", key, 6) : kind === "power" || kind === "stay" ? runtime.shellNumberIndex("controls", key, 5) : -1;
            if (repeatedAction || choice >= 0)
                return true;
        }
        if (runtime.shellMatchesHint("SettingsDetail.toggle", key, modifiers) && hasMaster) {
            if (masterAvailable)
                toggleMaster();
            return true;
        }
        if (runtime.shellMatchesHint("SettingsDetail.blur", key, modifiers) && hasBlur) {
            appearance.toggleBlur();
            return true;
        }
        if (runtime.shellMatchesHint("SettingsDetail.reset", key, modifiers) && hasReset) {
            resetAppearance();
            return true;
        }
        if (kind === "alerts") {
            if (runtime.shellMatchesHint("SettingsDetail.quietHours", key, modifiers)) {
                notifications.setQuietPreference("enabled", !notifications.quietEnabled);
                return true;
            }
            if (runtime.shellMatchesHint("SettingsDetail.presentation", key, modifiers)) {
                notifications.togglePresentation();
                return true;
            }
            if (runtime.shellMatchesHint("SettingsDetail.history", key, modifiers)) {
                notifications.toggleHistory();
                return true;
            }
        }
        if ((kind === "power" || kind === "stay" || kind === "alerts" || reactiveTuning) && modifiers === Qt.NoModifier) {
            const numberIndex = runtime.shellNumberIndex("controls", key, reactiveTuning ? 7 : kind === "alerts" ? 6 : 5);
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
            height: Math.max(44, heading.implicitHeight)
            spacing: panel.theme.spacing3

            Column {
                id: heading
                anchors.verticalCenter: parent.verticalCenter
                width: panel.hasMaster ? Math.max(1, parent.width - masterAction.width - parent.spacing) : parent.width
                spacing: panel.theme.spacing1

                ShellText {
                    runtime: panel.runtime
                    theme: panel.theme
                    text: panel.titleText
                    font.pixelSize: panel.theme.fontSize(14)
                    font.weight: Font.DemiBold
                }
                ShellText {
                    runtime: panel.runtime
                    theme: panel.theme
                    text: panel.kind === "power" ? panel.powerProfile.label(panel.powerProfile.current) : panel.kind === "nightLight" ? (panel.nightLight.active ? panel.nightLight.temperature + " K · enabled" : "Disabled · " + panel.nightLight.temperature + " K") : panel.hasMaster ? (panel.masterState ? "Enabled" : "Disabled") : "Current settings"
                    color: panel.theme.textMuted
                    font.pixelSize: panel.theme.fontSize(10)
                }
            }

            ShellAction {
                id: masterAction
                visible: panel.hasMaster
                width: visible ? 133 : 0
                height: 40
                anchors.verticalCenter: parent.verticalCenter
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                horizontalCompact: true
                icon: panel.masterState ? "󰈆" : "󰈅"
                title: panel.masterState ? "Disable" : "Enable"
                shortcut: panel.runtime.shellHint("SettingsDetail.toggle")
                active: panel.masterState
                enabled: panel.masterAvailable
                onActivated: panel.toggleMaster()
            }
        }

        Row {
            visible: panel.hasBlur
            width: parent.width
            height: visible ? 42 : 0
            spacing: panel.theme.spacing2
            ShellAction {
                width: Math.max(1, parent.width - resetButton.width - parent.spacing)
                height: 40
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                horizontalCompact: true
                icon: panel.appearance.blurEnabled ? "󰖨" : "󰖧"
                title: panel.appearance.blurEnabled ? "Blur enabled" : "Blur disabled"
                active: panel.appearance.blurEnabled
                shortcut: panel.runtime.shellHint("SettingsDetail.blur")
                onActivated: panel.appearance.toggleBlur()
            }
            ShellAction {
                id: resetButton
                width: 124
                height: 40
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                horizontalCompact: true
                icon: "󰑐"
                title: "Defaults"
                shortcut: panel.runtime.shellHint("SettingsDetail.reset")
                onActivated: panel.resetAppearance()
            }
        }

        Column {
            visible: panel.reactiveTuning || panel.spectrumTuning
            width: parent.width
            spacing: panel.theme.spacing2

            ShellText {
                runtime: panel.runtime
                theme: panel.theme
                text: !panel.spectrum.connected ? "Audio analyser disconnected" : !panel.spectrum.hasEnergy ? "Listening · no audio energy" : "Live audio · " + Math.round(panel.spectrum.rms * 100) + "% level"
                color: panel.theme.textMuted
                font.pixelSize: panel.theme.fontSize(11)
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
                spacing: panel.theme.spacing2
                Repeater {
                    model: ["Subtle", "Default", "Energetic"]
                    delegate: ShellAction {
                        required property int index
                        required property string modelData
                        width: (panel.width - panel.theme.spacing2 * 2) / 3
                        height: 44
                        runtime: panel.runtime
                        theme: panel.theme
                        motion: panel.motion
                        title: modelData
                        shortcut: panel.runtime.shellNumberHint("controls", index)
                        compact: true
                        horizontalCompact: true
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
                spacing: panel.theme.spacing2
                Repeater {
                    model: ["balanced", "bass", "mid", "treble"]
                    delegate: ShellAction {
                        required property int index
                        required property string modelData
                        width: (panel.width - panel.theme.spacing2 * 3) / 4
                        height: 44
                        runtime: panel.runtime
                        theme: panel.theme
                        motion: panel.motion
                        title: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                        shortcut: panel.runtime.shellNumberHint("controls", index + 3)
                        compact: true
                        horizontalCompact: true
                        active: panel.appearance.musicReactiveEmphasis === modelData
                        onActivated: panel.appearance.setReactiveEmphasis(modelData)
                    }
                }
            }

            ShellAction {
                visible: panel.spectrumTuning
                width: parent.width
                height: visible ? 42 : 0
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                horizontalCompact: true
                title: "Restore default opacity"
                shortcut: panel.runtime.shellHint("SettingsDetail.reset")
                onActivated: panel.resetAppearance()
            }
        }

        Grid {
            id: parameterGrid
            width: parent.width
            columns: panel.reactiveTuning && width >= 750 ? 2 : 1
            rowSpacing: panel.theme.spacing3
            columnSpacing: panel.theme.spacing3
            Repeater {
                id: parameterRepeater
                model: panel.parameters

                delegate: ShellSurface {
                    id: parameterCard
                    required property int index
                    required property var modelData
                    width: (parameterGrid.width - (parameterGrid.columns - 1) * parameterGrid.columnSpacing) / parameterGrid.columns
                    height: Math.max(104, panel.theme.fontSize(70) + panel.theme.spacing3 * 2)
                    Connections {
                        target: panel
                        function onParameterAdjustmentRequested(index: int): void {
                            if (index === parameterCard.index)
                                parameterSlider.pulseAdjustment();
                        }
                    }
                    theme: panel.theme
                    motion: panel.motion
                    surfaceLayer: ShellSurface.Control
                    cornerRadius: theme.radiusMedium
                    outlined: panel.selectedIndex === index
                    borderWidth: outlined ? panel.theme.borderFocus : 0
                    borderColor: outlined ? panel.theme.accent : "transparent"
                    fillColor: panel.theme.expressiveSurfaceStrong

                    Column {
                        anchors.fill: parent
                        anchors.margins: panel.theme.spacing3
                        spacing: panel.theme.spacing2

                        Row {
                            id: parameterHeading
                            width: parent.width
                            height: Math.max(37, panel.theme.fontSize(30))
                            spacing: panel.theme.spacing2
                            Column {
                                width: Math.max(1, parent.width - valueReadback.implicitWidth - parameterHint.implicitWidth - parameterHeading.spacing * 2)
                                spacing: panel.theme.spacing1
                                ShellText {
                                    runtime: panel.runtime
                                    theme: panel.theme
                                    text: parameterCard.modelData.title
                                    font.weight: Font.DemiBold
                                    font.pixelSize: panel.theme.fontSize(11)
                                }
                                ShellText {
                                    runtime: panel.runtime
                                    theme: panel.theme
                                    text: parameterCard.modelData.description
                                    color: panel.theme.textMuted
                                    font.pixelSize: panel.theme.fontSize(9)
                                    elide: Text.ElideRight
                                }
                            }
                            KeyHint {
                                id: parameterHint
                                visible: panel.selectedIndex === parameterCard.index
                                runtime: panel.runtime
                                theme: panel.theme
                                shortcut: panel.runtime.shellHint("SettingsDetail.adjust")
                                compact: true
                            }
                            ShellText {
                                id: valueReadback
                                runtime: panel.runtime
                                theme: panel.theme
                                text: panel.valueLabel(parameterCard.modelData)
                                font.pixelSize: panel.theme.fontSize(11)
                                font.weight: Font.DemiBold
                            }
                        }

                        ShellSlider {
                            id: parameterSlider
                            width: parent.width
                            height: 32
                            theme: panel.theme
                            motion: panel.motion
                            from: parameterCard.modelData.minimum
                            to: parameterCard.modelData.maximum
                            value: panel.currentValue(parameterCard.modelData.key)
                            enabled: parameterCard.modelData.key !== "temperature" || panel.nightLight.supported
                            Accessible.role: Accessible.Slider
                            Accessible.name: parameterCard.modelData.title + " " + panel.valueLabel(parameterCard.modelData)
                            onInteractionStarted: panel.selectParameter(parameterCard.index)
                            onValueRequested: next => panel.setValue(parameterCard.modelData.key, Math.round(next / parameterCard.modelData.step) * parameterCard.modelData.step)
                        }
                    }
                }
            }
        }

        ShellText {
            visible: panel.kind === "nightLight"
            runtime: panel.runtime
            theme: panel.theme
            text: "Manual control · temperature persists through the existing Night Light service"
            color: panel.theme.textMuted
            font.pixelSize: panel.theme.fontSize(10)
            wrapMode: Text.WordWrap
            width: parent.width
        }

        Column {
            visible: panel.kind === "power"
            width: parent.width
            spacing: panel.theme.spacing2
            Repeater {
                model: panel.powerProfile.profiles
                delegate: ShellAction {
                    required property int index
                    required property string modelData
                    width: panel.width
                    height: 44
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    compact: true
                    horizontalCompact: true
                    icon: "󰚥"
                    title: panel.powerProfile.label(modelData)
                    shortcut: panel.runtime.shellNumberHint("controls", index)
                    active: panel.powerProfile.current === modelData
                    enabled: panel.powerProfile.available && !panel.powerProfile.applying
                    onActivated: panel.powerProfile.setProfile(modelData)
                }
            }
        }

        Column {
            visible: panel.kind === "stay"
            width: parent.width
            spacing: panel.theme.spacing2
            ShellText {
                runtime: panel.runtime
                theme: panel.theme
                text: panel.idleStatus + " · Choose or replace the current duration:"
                color: panel.theme.textMuted
                font.pixelSize: panel.theme.fontSize(10)
            }
            Repeater {
                model: [15, 30, 60, 120, 0]
                delegate: ShellAction {
                    required property int index
                    required property int modelData
                    width: panel.width
                    height: 40
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    compact: true
                    horizontalCompact: true
                    title: modelData === 0 ? "Until disabled" : modelData + " minutes"
                    shortcut: panel.runtime.shellNumberHint("controls", index)
                    active: panel.system.idleInhibited && panel.system.idleInhibitMinutes === modelData
                    onActivated: panel.system.setIdleInhibitMinutes(modelData)
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
            Row {
                width: parent.width
                height: 40
                spacing: panel.theme.spacing2
                Repeater {
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
                        shortcut: panel.runtime.shellNumberHint("controls", index)
                        compact: true
                        horizontalCompact: true
                        onActivated: panel.notifications.silenceFor(modelData)
                    }
                }
            }
            ShellAction {
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                horizontalCompact: true
                width: parent.width
                height: 40
                title: "Quiet hours"
                active: panel.notifications.quietEnabled
                shortcut: panel.runtime.shellHint("SettingsDetail.quietHours")
                onActivated: panel.notifications.setQuietPreference("enabled", !panel.notifications.quietEnabled)
            }
            Row {
                width: parent.width
                height: 40
                spacing: panel.theme.spacing2
                Repeater {
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
                    delegate: ShellAction {
                        required property int index
                        required property var modelData
                        width: (panel.width - panel.theme.spacing2 * 2) / 3
                        height: 40
                        runtime: panel.runtime
                        theme: panel.theme
                        motion: panel.motion
                        title: modelData.title
                        shortcut: panel.runtime.shellNumberHint("controls", index + 3)
                        compact: true
                        horizontalCompact: true
                        active: panel.notifications.quietDays === modelData.days
                        onActivated: panel.notifications.setQuietPreference("days", modelData.days)
                    }
                }
            }
            ShellAction {
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                horizontalCompact: true
                width: parent.width
                height: 40
                title: "Restore quiet-hour defaults"
                shortcut: panel.runtime.shellHint("SettingsDetail.reset")
                onActivated: panel.notifications.resetQuietHours()
            }
            ShellAction {
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                horizontalCompact: true
                width: parent.width
                height: 44
                title: panel.notifications.presentation ? "Presentation mode on" : "Presentation mode off"
                active: panel.notifications.presentation
                shortcut: panel.runtime.shellHint("SettingsDetail.presentation")
                onActivated: panel.notifications.togglePresentation()
            }
            ShellAction {
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                horizontalCompact: true
                width: parent.width
                height: 44
                title: panel.notifications.historyEnabled ? "Save notification history" : "History disabled"
                active: panel.notifications.historyEnabled
                shortcut: panel.runtime.shellHint("SettingsDetail.history")
                onActivated: panel.notifications.toggleHistory()
            }
        }

        ShellText {
            visible: panel.parameters.length === 0 && panel.kind !== "power" && panel.kind !== "stay" && panel.kind !== "alerts"
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            text: "The direct action and its state are available here. Further settings are shown only when the backend supports them."
            color: panel.theme.textMuted
            wrapMode: Text.WordWrap
            font.pixelSize: panel.theme.fontSize(10)
        }
    }
}

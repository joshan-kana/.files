pragma ComponentBehavior: Bound
import QtQuick
import "DesktopIcons.js" as DesktopIcons

Item {
    id: panel

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property AppearancePreferences appearance

    signal keyboardRequested
    signal parameterAdjustmentRequested(int index)
    signal revealSelection(real top, real bottom)

    property bool open: false
    property int selectedIndex: 0
    visible: open
    implicitWidth: theme.controlsDetailWidth
    implicitHeight: content.implicitHeight

    readonly property var parameters: [
        {
            key: "vhsIntensity",
            title: "Intensity",
            description: "Overall signal degradation",
            minimum: runtime.constraints.appearance.vhsIntensity.min,
            maximum: runtime.constraints.appearance.vhsIntensity.max,
            step: 0.05,
            unit: "%"
        },
        {
            key: "vhsTracking",
            title: "Tracking",
            description: "Rolling tears and horizontal instability",
            minimum: runtime.constraints.appearance.vhsTracking.min,
            maximum: runtime.constraints.appearance.vhsTracking.max,
            step: 0.05,
            unit: "%"
        },
        {
            key: "vhsChroma",
            title: "Colour bleed",
            description: "Red and blue channel separation",
            minimum: runtime.constraints.appearance.vhsChroma.min,
            maximum: runtime.constraints.appearance.vhsChroma.max,
            step: 0.05,
            unit: "%"
        },
        {
            key: "vhsNoise",
            title: "Tape noise",
            description: "Moving grain and brightness flicker",
            minimum: runtime.constraints.appearance.vhsNoise.min,
            maximum: runtime.constraints.appearance.vhsNoise.max,
            step: 0.05,
            unit: "%"
        },
        {
            key: "vhsScanlines",
            title: "Scanlines",
            description: "Alternating horizontal line darkness",
            minimum: runtime.constraints.appearance.vhsScanlines.min,
            maximum: runtime.constraints.appearance.vhsScanlines.max,
            step: 0.05,
            unit: "%"
        },
        {
            key: "vhsDropouts",
            title: "Dropouts",
            description: "Irregular dark horizontal tape streaks",
            minimum: runtime.constraints.appearance.vhsDropouts.min,
            maximum: runtime.constraints.appearance.vhsDropouts.max,
            step: 0.05,
            unit: "%"
        },
        {
            key: "vhsSpeed",
            title: "Tape speed",
            description: "Rate of animated tracking and noise",
            minimum: runtime.constraints.appearance.vhsSpeed.min,
            maximum: runtime.constraints.appearance.vhsSpeed.max,
            step: 0.05,
            unit: "×"
        }
    ]

    function parameterValue(key: string): real {
        switch (key) {
        case "vhsIntensity":
            return appearance.vhsIntensity;
        case "vhsTracking":
            return appearance.vhsTracking;
        case "vhsChroma":
            return appearance.vhsChroma;
        case "vhsNoise":
            return appearance.vhsNoise;
        case "vhsDropouts":
            return appearance.vhsDropouts;
        case "vhsScanlines":
            return appearance.vhsScanlines;
        case "vhsSpeed":
            return appearance.vhsSpeed;
        }
        return 0;
    }

    function valueText(entry: var): string {
        const value = parameterValue(entry.key);
        return entry.unit === "×" ? value.toFixed(2) + "×" : Math.round(value * 100) + "%";
    }

    function setParameter(entry: var, next: real): void {
        if (entry.key === "vhsIntensity")
            appearance.setVhsIntensity(next);
        else
            appearance.setVhsParameter(entry.key, next);
    }

    function selectParameter(index: int): void {
        selectedIndex = Math.max(0, Math.min(parameters.length - 1, index));
        keyboardRequested();
        const card = parameterRepeater.itemAt(selectedIndex);
        if (card) {
            const top = card.mapToItem(panel, 0, 0).y;
            revealSelection(top, top + card.height);
        }
    }

    function adjustSelected(direction: int): void {
        const entry = parameters[selectedIndex];
        if (entry) {
            parameterAdjustmentRequested(selectedIndex);
            setParameter(entry, parameterValue(entry.key) + direction * entry.step);
        }
    }

    function handleKey(key: int, modifiers: int, autoRepeat: bool): bool {
        const presetIndex = runtime.shellChoiceIndex(key, modifiers, vhsPresets.count);
        if (presetIndex >= 0) {
            if (!autoRepeat)
                (vhsPresets.itemAt(presetIndex) as ShellAction)?.trigger();
            return true;
        }
        if (runtime.shellMatchesHint("VhsPanel.defaults", key, modifiers)) {
            if (!autoRepeat)
                defaultsButton.trigger();
            return true;
        }
        if (runtime.shellMatchesHint("VhsPanel.reset", key, modifiers)) {
            if (!autoRepeat)
                (parameterRepeater.itemAt(selectedIndex) as ParameterCard)?.triggerReset();
            return true;
        }
        if (key === runtime.shellKeyCode("controls", "Tab") || key === runtime.shellKeyCode("controls", "Backtab")) {
            const backward = key === runtime.shellKeyCode("controls", "Backtab") || runtime.shellModifier("controls", "Shift", modifiers);
            selectParameter((selectedIndex + parameters.length + (backward ? -1 : 1)) % parameters.length);
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
        if (runtime.shellNavigates("controls", "left", key)) {
            adjustSelected(-1);
            return true;
        }
        if (runtime.shellNavigates("controls", "right", key)) {
            adjustSelected(1);
            return true;
        }
        if (runtime.shellMatchesHint("VhsPanel.toggle", key, modifiers)) {
            if (!autoRepeat)
                toggleButton.trigger();
            return true;
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

        DetailHero {
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            glyph: DesktopIcons.glyphFor("vhs")
            glyphFont: "Symbols Nerd Font"
            glyphColor: panel.theme.roleColor("reactive")
            title: "VHS tape"
            detail: "Signal tuning · " + panel.appearance.vhsPreset
            actions: [
                ShellAction {
                    id: toggleButton
                    width: implicitWidth
                    height: implicitHeight
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    compact: true
                    iconOnly: true
                    switchControl: true
                    active: panel.appearance.vhsEnabled
                    title: active ? "Disable VHS effect" : "Enable VHS effect"
                    shortcut: panel.runtime.shellHint("VhsPanel.toggle")
                    onActivated: panel.appearance.toggleVhs()
                },
                ShellUtilityAction {
                    id: defaultsButton
                    width: implicitWidth
                    height: implicitHeight
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    icon: DesktopIcons.actionGlyph("reset")
                    title: "Restore defaults"
                    shortcut: panel.runtime.shellHint("VhsPanel.defaults")
                    onActivated: panel.appearance.resetVhs()
                }
            ]
        }

        Row {
            width: parent.width
            height: implicitHeight
            spacing: Math.max(2, panel.theme.spacing1 / 2)
            Repeater {
                id: vhsPresets
                model: panel.appearance.vhsPresetNames
                delegate: ShellChoice {
                    required property int index
                    required property string modelData
                    width: (panel.width - Math.max(2, panel.theme.spacing1 / 2) * (vhsPresets.count - 1)) / Math.max(1, vhsPresets.count)
                    height: Math.max(76, implicitHeight)
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    title: modelData
                    icon: ({
                            Subtle: "󰨛",
                            Analog: "󰕧",
                            Degraded: "󰓎",
                            Default: DesktopIcons.actionGlyph("reset")
                        })[modelData] ?? ""
                    shortcut: panel.runtime.shellChoiceHint(index)
                    compact: true
                    choices: vhsPresets
                    choiceIndex: index
                    active: panel.appearance.vhsPreset === modelData
                    onActivated: panel.appearance.applyVhsPreset(modelData)
                }
            }
        }

        Flow {
            id: parameterFlow
            width: parent.width
            readonly property int columns: width >= panel.theme.fontSize(750) ? 2 : 1
            spacing: panel.theme.spacing3
            Repeater {
                id: parameterRepeater
                model: panel.parameters
                delegate: ParameterCard {
                    id: parameterRow
                    required property int index
                    required property var modelData
                    width: index === panel.parameters.length - 1 && panel.parameters.length % parameterFlow.columns === 1 ? parameterFlow.width : Math.floor((parameterFlow.width - (parameterFlow.columns - 1) * parameterFlow.spacing) / parameterFlow.columns)
                    height: implicitHeight
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    title: modelData.title
                    description: modelData.description
                    readback: panel.valueText(modelData)
                    from: modelData.minimum
                    to: modelData.maximum
                    value: panel.parameterValue(modelData.key)
                    selectedParameter: panel.selectedIndex === index
                    adjustShortcut: panel.runtime.shellHint("VhsPanel.adjust")
                    resetShortcut: panel.runtime.shellHint("VhsPanel.reset")
                    resetAvailable: panel.appearance.hasOverride(modelData.key)
                    onSelectedRequested: panel.selectParameter(index)
                    onValueRequested: next => panel.setParameter(modelData, next)
                    onResetRequested: panel.appearance.resetVhsParameter(modelData.key)
                    Connections {
                        target: panel
                        function onParameterAdjustmentRequested(index: int): void {
                            if (index === parameterRow.index)
                                parameterRow.beginKeyboardAdjustment();
                        }
                    }
                }
            }
        }

        KeyHintStrip {
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            hints: [
                {
                    shortcut: panel.runtime.shellHint("VhsPanel.select"),
                    label: "Select parameter"
                }
            ]
        }
    }
}

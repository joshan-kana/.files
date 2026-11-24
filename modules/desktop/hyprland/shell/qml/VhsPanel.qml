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
            minimum: 0,
            maximum: 1,
            step: 0.05,
            unit: "%"
        },
        {
            key: "vhsTracking",
            title: "Tracking",
            description: "Rolling tears and horizontal instability",
            minimum: 0,
            maximum: 1,
            step: 0.05,
            unit: "%"
        },
        {
            key: "vhsChroma",
            title: "Colour bleed",
            description: "Red and blue channel separation",
            minimum: 0,
            maximum: 1,
            step: 0.05,
            unit: "%"
        },
        {
            key: "vhsNoise",
            title: "Tape noise",
            description: "Moving grain and brightness flicker",
            minimum: 0,
            maximum: 1,
            step: 0.05,
            unit: "%"
        },
        {
            key: "vhsScanlines",
            title: "Scanlines",
            description: "Alternating horizontal line darkness",
            minimum: 0,
            maximum: 1,
            step: 0.05,
            unit: "%"
        },
        {
            key: "vhsDropouts",
            title: "Dropouts",
            description: "Irregular dark horizontal tape streaks",
            minimum: 0,
            maximum: 1,
            step: 0.05,
            unit: "%"
        },
        {
            key: "vhsSpeed",
            title: "Tape speed",
            description: "Rate of animated tracking and noise",
            minimum: 0.25,
            maximum: 2.5,
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
    }

    function adjustSelected(direction: int): void {
        const entry = parameters[selectedIndex];
        if (entry) {
            parameterAdjustmentRequested(selectedIndex);
            setParameter(entry, parameterValue(entry.key) + direction * entry.step);
        }
    }

    function handleKey(key: int, modifiers: int, autoRepeat: bool): bool {
        const presetIndex = runtime.shellChoiceIndex(key, modifiers, 4);
        if (presetIndex >= 0) {
            if (!autoRepeat)
                appearance.applyVhsPreset(["Subtle", "Analog", "Degraded", "Default"][presetIndex]);
            return true;
        }
        if (runtime.shellMatchesHint("VhsPanel.defaults", key, modifiers)) {
            if (!autoRepeat)
                appearance.resetVhs();
            return true;
        }
        if (runtime.shellMatchesHint("VhsPanel.reset", key, modifiers)) {
            if (!autoRepeat)
                appearance.resetVhsParameter(parameters[selectedIndex].key);
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
                appearance.toggleVhs();
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

        Row {
            width: parent.width
            height: Math.max(46, toggleButton.implicitHeight)
            spacing: panel.theme.spacing3

            Text {
                id: capabilityGlyph
                anchors.verticalCenter: parent.verticalCenter
                width: panel.theme.fontSize(26)
                text: DesktopIcons.glyphFor("vhs")
                color: panel.theme.accent
                font.family: "Symbols Nerd Font"
                font.pixelSize: panel.theme.fontSize(23)
                horizontalAlignment: Text.AlignHCenter
            }

            Column {
                width: Math.max(1, parent.width - capabilityGlyph.width - toggleButton.width - defaultsButton.width - 3 * parent.spacing)
                anchors.verticalCenter: parent.verticalCenter
                spacing: panel.theme.spacing1

                Text {
                    text: "VHS tape"
                    color: panel.theme.textStrong
                    font.family: panel.runtime.fontSans
                    font.pixelSize: panel.theme.fontDetailTitle
                    font.weight: Font.DemiBold
                }

                Text {
                    text: "Signal tuning · " + panel.appearance.vhsPreset
                    color: panel.theme.textMuted
                    font.family: panel.runtime.fontSans
                    font.pixelSize: panel.theme.fontSupporting
                }
            }

            ShellAction {
                id: toggleButton
                width: implicitWidth
                height: implicitHeight
                anchors.verticalCenter: parent.verticalCenter
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
            }
            ShellAction {
                id: defaultsButton
                width: implicitWidth
                height: implicitHeight
                anchors.verticalCenter: parent.verticalCenter
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                horizontalCompact: true
                icon: DesktopIcons.actionGlyph("reset")
                title: "Restore defaults"
                shortcut: panel.runtime.shellHint("VhsPanel.defaults")
                onActivated: panel.appearance.resetVhs()
            }
        }

        Row {
            width: parent.width
            height: implicitHeight
            spacing: panel.theme.spacing1
            Repeater {
                model: ["Subtle", "Analog", "Degraded", "Default"]
                delegate: ShellAction {
                    required property int index
                    required property string modelData
                    width: (panel.width - panel.theme.spacing1 * 3) / 4
                    height: Math.max(76, implicitHeight)
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    title: modelData
                    icon: ["󰨛", "󰕧", "󰓎", DesktopIcons.actionGlyph("reset")][index]
                    shortcut: panel.runtime.shellChoiceHint(index)
                    compact: true
                    connectedGroup: true
                    activeColor: panel.theme.roleColor("reactive")
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
                    accentColor: panel.theme.roleColor("reactive")
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

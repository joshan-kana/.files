pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: panel

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property AppearancePreferences appearance

    signal keyboardRequested

    property bool open: false
    property int selectedIndex: 0
    visible: open
    implicitWidth: theme.controlsDetailWidth
    implicitHeight: content.implicitHeight

    readonly property var parameters: [
        { key: "vhsIntensity", title: "Intensity", description: "Overall signal degradation", minimum: 0, maximum: 1, step: 0.05, unit: "%" },
        { key: "vhsTracking", title: "Tracking", description: "Rolling tears and horizontal instability", minimum: 0, maximum: 1, step: 0.05, unit: "%" },
        { key: "vhsChroma", title: "Colour bleed", description: "Red and blue channel separation", minimum: 0, maximum: 1, step: 0.05, unit: "%" },
        { key: "vhsNoise", title: "Tape noise", description: "Grain, dropouts and brightness flicker", minimum: 0, maximum: 1, step: 0.05, unit: "%" },
        { key: "vhsScanlines", title: "Scanlines", description: "Alternating horizontal line darkness", minimum: 0, maximum: 1, step: 0.05, unit: "%" },
        { key: "vhsSpeed", title: "Tape speed", description: "Rate of animated tracking and noise", minimum: 0.25, maximum: 2.5, step: 0.05, unit: "×" }
    ]

    function parameterValue(key: string): real {
        switch (key) {
        case "vhsIntensity": return appearance.vhsIntensity;
        case "vhsTracking": return appearance.vhsTracking;
        case "vhsChroma": return appearance.vhsChroma;
        case "vhsNoise": return appearance.vhsNoise;
        case "vhsScanlines": return appearance.vhsScanlines;
        case "vhsSpeed": return appearance.vhsSpeed;
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
        if (entry)
            setParameter(entry, parameterValue(entry.key) + direction * entry.step);
    }

    function handleKey(key: int, modifiers: int): bool {
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
            height: 46
            spacing: panel.theme.spacing3

            Column {
                width: Math.max(1, parent.width - toggleButton.width - parent.spacing)
                anchors.verticalCenter: parent.verticalCenter
                spacing: panel.theme.spacing1

                Text {
                    text: "VHS TAPE"
                    color: panel.theme.textStrong
                    font.family: panel.runtime.fontSans
                    font.pixelSize: panel.theme.fontSize(14)
                    font.weight: Font.DemiBold
                }

                Text {
                    text: "Signal tuning"
                    color: panel.theme.textMuted
                    font.family: panel.runtime.fontSans
                    font.pixelSize: panel.theme.fontSize(10)
                }
            }

            Item {
                id: toggleButton
                width: 126
                height: 38
                anchors.verticalCenter: parent.verticalCenter

                StateLayer {
                    theme: panel.theme
                    motion: panel.motion
                    selected: panel.appearance.vhsEnabled
                    cornerRadius: panel.theme.radiusMedium
                    Accessible.role: Accessible.Button
                    Accessible.name: panel.appearance.vhsEnabled ? "Disable VHS effect" : "Enable VHS effect"
                    onActivated: panel.appearance.toggleVhs()
                }

                KeyHint {
                    anchors.centerIn: parent
                    runtime: panel.runtime
                    theme: panel.theme
                    shortcut: panel.runtime.shellHint("VhsPanel.toggle")
                    label: panel.appearance.vhsEnabled ? "Disable" : "Enable"
                    compact: true
                    emphasized: panel.appearance.vhsEnabled
                }
            }
        }

        Column {
            width: parent.width
            spacing: panel.theme.spacing1

            Repeater {
                model: panel.parameters

                delegate: ShellSurface {
                    id: parameterRow
                    required property int index
                    required property var modelData

                    width: parent.width
                    height: 80
                    theme: panel.theme
                    motion: panel.motion
                    surfaceLayer: ShellSurface.Control
                    outlined: panel.selectedIndex === index
                    borderWidth: outlined ? panel.theme.borderFocus : 0
                    borderColor: outlined ? panel.theme.roleColor("display") : "transparent"
                    fillColor: panel.theme.expressiveSurfaceStrong
                    hovered: rowHover.hovered

                    HoverHandler { id: rowHover }

                    Column {
                        anchors {
                            fill: parent
                            leftMargin: panel.theme.spacing3
                            rightMargin: panel.theme.spacing3
                            topMargin: panel.theme.spacing1
                            bottomMargin: panel.theme.spacing1
                        }
                        spacing: 0

                        Item {
                            width: parent.width
                            height: 36

                            StateLayer {
                                theme: panel.theme
                                motion: panel.motion
                                selected: panel.selectedIndex === parameterRow.index
                                cornerRadius: panel.theme.radiusSmall
                                Accessible.role: Accessible.Button
                                Accessible.name: "Select " + parameterRow.modelData.title + ", " + panel.valueText(parameterRow.modelData)
                                Accessible.description: parameterRow.modelData.description + (parameterRow.modelData.unit === "×" ? ", 0.25× to 2.50× in 0.05× steps" : ", 0 to 100% in 5% keyboard steps")
                                onActivated: panel.selectParameter(parameterRow.index)
                            }

                            Row {
                                anchors.fill: parent
                                spacing: panel.theme.spacing2

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: parameterRow.modelData.title
                                    color: panel.theme.textStrong
                                    font.family: panel.runtime.fontSans
                                    font.pixelSize: panel.theme.fontSize(11)
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(1, parent.width - parent.children[0].implicitWidth - valueLabel.implicitWidth - parent.spacing * 2)
                                    text: parameterRow.modelData.description
                                    elide: Text.ElideRight
                                    color: panel.theme.textMuted
                                    font.family: panel.runtime.fontSans
                                    font.pixelSize: panel.theme.fontSize(9)
                                }

                                Text {
                                    id: valueLabel
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: panel.valueText(parameterRow.modelData)
                                    color: panel.theme.roleColor("display")
                                    font.family: panel.runtime.fontMono
                                    font.pixelSize: panel.theme.fontSize(11)
                                    font.weight: Font.DemiBold
                                }
                            }
                        }

                        ShellSlider {
                            width: parent.width
                            height: 36
                            theme: panel.theme
                            motion: panel.motion
                            from: parameterRow.modelData.minimum
                            to: parameterRow.modelData.maximum
                            value: panel.parameterValue(parameterRow.modelData.key)
                            trackHeight: 6
                            handleSize: 18
                            accentColor: panel.theme.roleColor("display")
                            Accessible.role: Accessible.Slider
                            Accessible.name: parameterRow.modelData.title + ": " + panel.valueText(parameterRow.modelData)
                            Accessible.description: parameterRow.modelData.description + (parameterRow.modelData.unit === "×" ? ", 0.25× to 2.50× in 0.05× steps" : ", 0 to 100% in 5% keyboard steps")
                            onInteractionStarted: panel.selectParameter(parameterRow.index)
                            onValueRequested: next => panel.setParameter(parameterRow.modelData, next)
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
                { shortcut: panel.runtime.shellHint("VhsPanel.select"), label: "Select parameter" },
                { shortcut: panel.runtime.shellHint("VhsPanel.adjust"), label: "Adjust" }
            ]
        }
    }
}

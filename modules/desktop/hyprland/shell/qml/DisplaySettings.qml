pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "DesktopIcons.js" as DesktopIcons

Column {
    id: panel
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    property bool engaged: false
    readonly property bool canRefresh: !busy && !previewActive && !changed
    readonly property bool canOpenNative: canRefresh && runtime.displaySettings.length > 0
    signal refreshRequested
    signal nativeRequested
    property var monitors: []
    property int outputIndex: 0
    property var profiles: []
    property int profileIndex: 0
    readonly property var profile: profiles[profileIndex] || null
    readonly property bool profileActionsAvailable: !busy && !previewActive && !changed
    readonly property bool canSaveProfile: profileActionsAvailable && monitors.length > 0 && monitors.every(entry => entry.editable)
    readonly property var output: monitors[outputIndex] || null
    property string mode: ""
    property real scaleValue: 1
    property int orientation: 0
    property int positionX: 0
    property int positionY: 0
    property double deadline: 0
    property double clockMs: Date.now()
    readonly property bool previewActive: deadline > 0
    property string error: ""
    property string activeCommand: ""
    readonly property bool foregroundBusy: busy && activeCommand !== "status"
    readonly property bool busy: worker.running
    readonly property bool editable: !!output?.editable && !busy && !previewActive
    readonly property var modes: output ? [...new Set([output.currentMode, ...(output.availableModes || [])].filter(value => !!value))] : []
    readonly property var resolutions: [...new Set(modes.map(value => value.split("@")[0]))]
    readonly property var refreshModes: modes.filter(value => value.split("@")[0] === mode.split("@")[0])
    readonly property var openSelector: resolutionSelector.expanded ? resolutionSelector : refreshSelector.expanded ? refreshSelector : profileSelector.expanded ? profileSelector : null
    function formatRate(value: string): string {
        const rate = Number.parseFloat(value.split("@")[1]);
        return Number.isFinite(rate) ? Number(rate.toFixed(2)) + " Hz" : value;
    }
    readonly property var scales: {
        const dimensions = mode.split("@")[0].split("x").map(Number);
        const candidates = [1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 3];
        if (output && mode === output.currentMode)
            candidates.push(output.scale);
        return [...new Set(candidates)].filter(scale => {
            if (output && mode === output.currentMode && scale === output.scale)
                return true;
            return dimensions.length === 2 && dimensions.every(size => size > 0 && Math.abs(size / scale - Math.round(size / scale)) < 0.001);
        }).sort((a, b) => a - b);
    }
    readonly property bool changed: !!output && (mode !== output.currentMode || scaleValue !== output.scale || orientation !== output.transform || positionX !== output.x || positionY !== output.y)
    readonly property var logicalOutputs: monitors.filter(entry => !entry.disabled).map(entry => {
        const staged = entry.name === output?.name;
        const dimensions = (staged ? mode : entry.currentMode).split("@")[0].split("x").map(Number);
        const scale = Math.max(0.01, staged ? scaleValue : entry.scale);
        const rotated = (staged ? orientation : entry.transform) % 2 === 1;
        const rawWidth = dimensions[0] || entry.width;
        const rawHeight = dimensions[1] || entry.height;
        return {
            name: entry.name,
            x: staged ? positionX : entry.x,
            y: staged ? positionY : entry.y,
            width: (rotated ? rawHeight : rawWidth) / scale,
            height: (rotated ? rawWidth : rawHeight) / scale,
            selected: staged
        };
    })
    readonly property real layoutLeft: Math.min(0, ...logicalOutputs.map(entry => entry.x))
    readonly property real layoutTop: Math.min(0, ...logicalOutputs.map(entry => entry.y))
    readonly property real layoutRight: Math.max(1, ...logicalOutputs.map(entry => entry.x + entry.width))
    readonly property real layoutBottom: Math.max(1, ...logicalOutputs.map(entry => entry.y + entry.height))
    spacing: theme.spacing2

    onEngagedChanged: {
        if (engaged)
            refresh();
        else {
            resolutionSelector.cancel();
            refreshSelector.cancel();
            profileSelector.cancel();
            if (previewActive && !busy)
                run("rollback");
        }
    }

    Timer {
        interval: 250
        repeat: true
        running: panel.engaged && panel.previewActive
        onTriggered: {
            panel.clockMs = Date.now();
            if (panel.clockMs >= panel.deadline * 1000 && !panel.busy)
                panel.refresh();
        }
    }
    Process {
        id: worker
        stdout: StdioCollector {
            id: response
        }
        stderr: StdioCollector {
            id: errors
        }
        onExited: (code, status) => {
            if (code === 0) {
                try {
                    const data = JSON.parse(response.text);
                    const previous = panel.output?.name;
                    panel.monitors = data.monitors;
                    panel.profiles = data.profiles || [];
                    panel.profileIndex = Math.max(0, Math.min(panel.profileIndex, panel.profiles.length - 1));
                    const index = panel.monitors.findIndex(entry => entry.name === previous);
                    panel.outputIndex = index >= 0 ? index : 0;
                    panel.deadline = data.deadline;
                    panel.clockMs = Date.now();
                    panel.loadValues();
                    if (!panel.engaged && panel.previewActive)
                        Qt.callLater(() => panel.run("rollback"));
                } catch (_) {
                    panel.error = "Invalid display state";
                }
            } else {
                panel.error = errors.text.trim() || "Display operation failed";
                if (panel.activeCommand !== "status")
                    Qt.callLater(() => panel.refresh());
            }
        }
    }
    function run(action: string, args = []): void {
        if (busy || !runtime.displayControl)
            return;
        if (action !== "status")
            error = "";
        activeCommand = action;
        worker.exec([runtime.displayControl, action, ...args]);
    }
    function refresh(): void {
        run("status");
    }
    function loadValues(): void {
        if (!output)
            return;
        mode = output.currentMode;
        scaleValue = output.scale;
        orientation = output.transform;
        positionX = output.x;
        positionY = output.y;
    }
    function cycleOutput(): void {
        if (busy || previewActive || changed || monitors.length < 2)
            return;
        outputIndex = (outputIndex + 1) % monitors.length;
        loadValues();
    }
    function selectMode(value: string): void {
        if (!editable || !modes.includes(value))
            return;
        mode = value;
        if (!scales.includes(scaleValue))
            scaleValue = scales.reduce((best, entry) => Math.abs(entry - scaleValue) < Math.abs(best - scaleValue) ? entry : best, 1);
    }
    function selectResolution(index: int): void {
        const resolution = resolutions[index];
        const rate = Number.parseFloat(mode.split("@")[1]);
        const matching = modes.filter(value => value.split("@")[0] === resolution);
        if (matching.length)
            selectMode(matching.reduce((best, entry) => Math.abs(Number.parseFloat(entry.split("@")[1]) - rate) < Math.abs(Number.parseFloat(best.split("@")[1]) - rate) ? entry : best));
    }
    function cycleScale(delta: int): void {
        if (!editable || scales.length === 0)
            return;
        const next = Math.max(0, Math.min(scales.length - 1, scales.indexOf(scaleValue) + delta));
        scaleValue = scales[next];
    }
    function cycleOrientation(): void {
        (orientationChoices.itemAt((orientation + 1) % 4) as ShellAction)?.trigger();
    }
    function previewOrKeep(): void {
        if (previewActive) {
            run("keep");
        } else if (editable && changed) {
            run("preview", [output.name, mode, String(scaleValue), String(orientation), String(positionX), String(positionY)]);
        }
    }
    function cancelNested(): bool {
        if (openSelector)
            return openSelector.cancel();
        if (previewActive) {
            run("rollback");
            return true;
        }
        if (changed) {
            loadValues();
            return true;
        }
        return busy;
    }
    function handleKey(key: int, modifiers: int, autoRepeat: bool): bool {
        if (openSelector) {
            if (runtime.shellNavigates("controls", "up", key))
                openSelector.moveHighlight(-1);
            else if (runtime.shellNavigates("controls", "down", key))
                openSelector.moveHighlight(1);
            else if (runtime.shellMatchesHint("DisplaySettings.apply", key, modifiers) || (key === runtime.shellKeyCode("controls", "Enter") && modifiers === Qt.NoModifier)) {
                if (!autoRepeat)
                    openSelector.commit();
            } else if (runtime.shellMatchesHint("DisplaySettings.cancel", key, modifiers) || key === runtime.shellKeyCode("controls", "Escape")) {
                openSelector.cancel();
            } else if (!autoRepeat && runtime.shellMatchesHint("DisplaySettings.mode", key, modifiers)) {
                resolutionSelector.toggle();
            } else if (!autoRepeat && runtime.shellMatchesHint("DisplaySettings.refreshRate", key, modifiers)) {
                refreshSelector.toggle();
            } else if (!autoRepeat && runtime.shellMatchesHint("DisplaySettings.nextProfile", key, modifiers)) {
                profileSelector.toggle();
            }
            return true;
        }
        const actions = ["DisplaySettings.saveProfile", "DisplaySettings.nextProfile", "DisplaySettings.previewProfile", "DisplaySettings.deleteProfile", "DisplaySettings.apply", "DisplaySettings.cancel", "DisplaySettings.refresh", "DisplaySettings.native", "DisplaySettings.output", "DisplaySettings.mode", "DisplaySettings.refreshRate", "DisplaySettings.scale", "DisplaySettings.previousScale", "DisplaySettings.orientation", "DisplaySettings.moveLeft", "DisplaySettings.moveRight", "DisplaySettings.moveUp", "DisplaySettings.moveDown"];
        for (const id of actions) {
            const action = id.split(".")[1];
            if (!runtime.shellMatchesHint(id, key, modifiers) && !(action === "apply" && key === runtime.shellKeyCode("controls", "Enter") && modifiers === Qt.NoModifier))
                continue;
            if (autoRepeat && !action.startsWith("move"))
                return true;
            if (action === "saveProfile")
                saveProfileAction.trigger();
            else if (action === "nextProfile")
                profileSelector.toggle();
            else if (action === "previewProfile")
                loadProfileAction.trigger();
            else if (action === "deleteProfile")
                deleteProfileAction.trigger();
            else if (action === "apply")
                previewAction.trigger();
            else if (action === "cancel")
                cancelNested();
            else if (action === "refresh")
                refreshRequested();
            else if (action === "native")
                nativeRequested();
            else if (action === "output")
                cycleOutput();
            else if (action === "mode")
                resolutionSelector.toggle();
            else if (action === "refreshRate")
                refreshSelector.toggle();
            else if (action === "scale")
                scaleStepper.increase();
            else if (action === "previousScale")
                scaleStepper.decrease();
            else if (action === "orientation")
                cycleOrientation();
            else if (editable && monitors.length > 1) {
                if (action === "moveLeft")
                    positionX = Math.max(-32768, positionX - 100);
                else if (action === "moveRight")
                    positionX = Math.min(32768, positionX + 100);
                else if (action === "moveUp")
                    positionY = Math.max(-32768, positionY - 100);
                else if (action === "moveDown")
                    positionY = Math.min(32768, positionY + 100);
            }
            return true;
        }
        return false;
    }

    ShellText {
        visible: text.length > 0
        width: parent.width
        runtime: panel.runtime
        theme: panel.theme
        text: panel.error || (panel.previewActive ? "Keep the new layout within " + Math.max(0, Math.ceil(panel.deadline - panel.clockMs / 1000)) + " seconds; otherwise it reverts." : panel.busy ? "Reading compositor state…" : panel.output ? "" : "No outputs reported")
        color: panel.error || panel.previewActive ? panel.theme.warning : panel.theme.textMuted
        wrapMode: Text.WordWrap
    }
    ShellAction {
        visible: panel.monitors.length > 1
        width: parent.width
        height: implicitHeight
        runtime: panel.runtime
        theme: panel.theme
        motion: panel.motion
        compact: true
        horizontalCompact: true
        title: panel.output ? panel.output.name + " · " + (panel.outputIndex + 1) + "/" + panel.monitors.length : "No display"
        shortcut: panel.runtime.shellHint("DisplaySettings.output")
        enabled: panel.canRefresh && panel.monitors.length > 1
        onActivated: panel.cycleOutput()
    }
    ShellSurface {
        width: parent.width
        height: panel.theme.fontSize(panel.logicalOutputs.length > 1 ? 150 : 116)
        theme: panel.theme
        motion: panel.motion
        surfaceLayer: ShellSurface.Group
        cornerRadius: panel.theme.radiusMedium
        Item {
            id: displayMap
            anchors.fill: parent
            anchors.margins: panel.theme.spacing3
            readonly property real mapScale: Math.min(width / Math.max(1, panel.layoutRight - panel.layoutLeft), height / Math.max(1, panel.layoutBottom - panel.layoutTop))
            readonly property real offsetX: (width - (panel.layoutRight - panel.layoutLeft) * mapScale) / 2
            readonly property real offsetY: (height - (panel.layoutBottom - panel.layoutTop) * mapScale) / 2
            Repeater {
                model: panel.logicalOutputs
                delegate: ShellSurface {
                    id: outputShape
                    required property var modelData
                    x: displayMap.offsetX + (modelData.x - panel.layoutLeft) * displayMap.mapScale
                    y: displayMap.offsetY + (modelData.y - panel.layoutTop) * displayMap.mapScale
                    width: Math.max(2, modelData.width * displayMap.mapScale - 2)
                    height: Math.max(2, modelData.height * displayMap.mapScale - 2)
                    theme: panel.theme
                    motion: panel.motion
                    surfaceLayer: ShellSurface.Control
                    cornerRadius: Math.min(panel.theme.radiusSmall, Math.min(width, height) / 6)
                    outlined: modelData.selected
                    borderColor: modelData.selected ? panel.theme.focusColor : panel.theme.subtleBorder
                    borderWidth: modelData.selected ? panel.theme.borderFocus : panel.theme.borderThin
                    fillColor: modelData.selected ? panel.theme.choiceFill(panel.theme.choiceColor) : panel.theme.controlBase
                    Accessible.role: Accessible.StaticText
                    Accessible.name: modelData.name + (modelData.selected ? ", selected" : "") + ", " + Math.round(modelData.width) + " by " + Math.round(modelData.height) + " logical pixels"
                    ShellText {
                        anchors.centerIn: parent
                        width: parent.width - panel.theme.spacing2
                        visible: width > panel.theme.fontSize(45) && parent.height > implicitHeight
                        horizontalAlignment: Text.AlignHCenter
                        runtime: panel.runtime
                        theme: panel.theme
                        text: outputShape.modelData.name
                        textRole: ShellText.Action
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
    ShellText {
        visible: !!panel.output && !panel.output.editable
        width: parent.width
        runtime: panel.runtime
        theme: panel.theme
        text: "This layout cannot be saved here. Use the display editor."
        color: panel.theme.textMuted
        wrapMode: Text.WordWrap
    }
    ShellSurface {
        width: parent.width
        height: displayParameters.implicitHeight + panel.theme.spacing3 * 2
        theme: panel.theme
        motion: panel.motion
        surfaceLayer: ShellSurface.Group
        cornerRadius: panel.theme.radiusLarge
        Flow {
            id: displayParameters
            anchors.centerIn: parent
            width: Math.max(1, parent.width - panel.theme.spacing3 * 2)
            spacing: panel.theme.spacing2
            readonly property int columns: width >= panel.theme.fontSize(560) ? 2 : 1
            readonly property real fieldWidth: Math.floor((width - spacing * (columns - 1)) / columns)
            ShellValueSelector {
                id: resolutionSelector
                width: displayParameters.fieldWidth
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                title: "Resolution"
                shortcut: panel.runtime.shellHint("DisplaySettings.mode")
                confirmShortcut: panel.runtime.shellHint("DisplaySettings.apply")
                options: panel.resolutions.map(value => value.replace("x", " × "))
                selectedIndex: panel.resolutions.indexOf(panel.mode.split("@")[0])
                enabled: panel.editable
                onOpened: {
                    refreshSelector.cancel();
                    profileSelector.cancel();
                }
                onChosen: index => panel.selectResolution(index)
            }
            ShellValueSelector {
                id: refreshSelector
                width: displayParameters.fieldWidth
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                title: "Refresh rate"
                shortcut: panel.runtime.shellHint("DisplaySettings.refreshRate")
                confirmShortcut: panel.runtime.shellHint("DisplaySettings.apply")
                options: panel.refreshModes.map(value => panel.formatRate(value))
                selectedIndex: panel.refreshModes.indexOf(panel.mode)
                enabled: panel.editable
                onOpened: {
                    resolutionSelector.cancel();
                    profileSelector.cancel();
                }
                onChosen: index => panel.selectMode(panel.refreshModes[index])
            }
            ShellStepper {
                id: scaleStepper
                width: displayParameters.fieldWidth
                fillAvailableWidth: true
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                title: "Scale"
                readback: Math.round(panel.scaleValue * 100) + "%"
                decreaseShortcut: panel.runtime.shellHint("DisplaySettings.previousScale")
                increaseShortcut: panel.runtime.shellHint("DisplaySettings.scale")
                canDecrease: panel.editable && panel.scales.indexOf(panel.scaleValue) > 0
                canIncrease: panel.editable && panel.scales.indexOf(panel.scaleValue) < panel.scales.length - 1
                onDecreased: panel.cycleScale(-1)
                onIncreased: panel.cycleScale(1)
            }
            Column {
                width: displayParameters.fieldWidth
                spacing: panel.theme.spacing1
                Row {
                    width: parent.width
                    spacing: panel.theme.spacing2
                    ShellText {
                        runtime: panel.runtime
                        theme: panel.theme
                        text: "Orientation"
                        textRole: ShellText.Supporting
                    }
                    KeyHint {
                        runtime: panel.runtime
                        theme: panel.theme
                        shortcut: panel.runtime.shellHint("DisplaySettings.orientation")
                        label: "Next"
                        compact: true
                    }
                }
                Row {
                    width: parent.width
                    spacing: Math.max(2, panel.theme.spacing1 / 2)
                    Repeater {
                        id: orientationChoices
                        model: ["0°", "90°", "180°", "270°"]
                        delegate: ShellChoice {
                            required property int index
                            required property string modelData
                            width: (displayParameters.fieldWidth - 3 * Math.max(2, panel.theme.spacing1 / 2)) / 4
                            height: Math.max(panel.theme.fontSize(62), implicitHeight)
                            runtime: panel.runtime
                            theme: panel.theme
                            motion: panel.motion
                            compact: true
                            title: modelData
                            icon: DesktopIcons.glyphFor("displays")
                            iconRotation: index * 90
                            choices: orientationChoices
                            choiceIndex: index
                            active: panel.orientation === index
                            enabled: panel.editable
                            onActivated: panel.orientation = index
                        }
                    }
                }
            }
        }
    }
    ShellText {
        width: parent.width
        runtime: panel.runtime
        theme: panel.theme
        text: (panel.monitors.length > 1 ? "Position · " + panel.positionX + ", " + panel.positionY + " logical px · " : "") + "VRR " + (panel.output?.vrr ? "active" : "inactive") + " · " + (panel.output?.colorManagementPreset || "Colour mode unavailable")
        color: panel.theme.textMuted
    }
    Row {
        visible: panel.monitors.length > 1
        width: parent.width
        height: visible ? 40 : 0
        spacing: panel.theme.spacing2
        Repeater {
            model: [
                {
                    key: "moveLeft",
                    action: "DisplaySettings.moveLeft",
                    title: "← 100"
                },
                {
                    key: "moveDown",
                    action: "DisplaySettings.moveDown",
                    title: "↓ 100"
                },
                {
                    key: "moveUp",
                    action: "DisplaySettings.moveUp",
                    title: "↑ 100"
                },
                {
                    key: "moveRight",
                    action: "DisplaySettings.moveRight",
                    title: "→ 100"
                }
            ]
            delegate: ShellAction {
                id: moveAction
                required property var modelData
                width: (panel.width - 3 * panel.theme.spacing2) / 4
                height: 40
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                horizontalCompact: true
                title: moveAction.modelData.title
                shortcut: panel.runtime.shellHint(moveAction.modelData.action)
                enabled: panel.editable && panel.monitors.length > 1
                onActivated: {
                    if (moveAction.modelData.key === "moveLeft")
                        panel.positionX = Math.max(-32768, panel.positionX - 100);
                    else if (moveAction.modelData.key === "moveRight")
                        panel.positionX = Math.min(32768, panel.positionX + 100);
                    else if (moveAction.modelData.key === "moveUp")
                        panel.positionY = Math.max(-32768, panel.positionY - 100);
                    else
                        panel.positionY = Math.min(32768, panel.positionY + 100);
                }
            }
        }
    }
    Row {
        width: parent.width
        height: Math.max(transactionStatus.implicitHeight, previewAction.implicitHeight, discardAction.implicitHeight)
        spacing: panel.theme.spacing2
        ShellText {
            id: transactionStatus
            width: Math.max(1, parent.width - previewAction.width - discardAction.width - parent.spacing * 2)
            anchors.verticalCenter: parent.verticalCenter
            runtime: panel.runtime
            theme: panel.theme
            text: panel.previewActive ? "Confirm temporary layout" : panel.changed ? "Unapplied display changes" : "Current layout"
            textRole: ShellText.Supporting
            wrapMode: Text.WordWrap
        }
        ShellAction {
            id: discardAction
            width: implicitWidth
            height: implicitHeight
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            compact: true
            horizontalCompact: true
            quietAction: true
            icon: DesktopIcons.actionGlyph("cancel")
            title: panel.previewActive ? "Revert" : "Discard"
            activeColor: panel.theme.warning
            shortcut: panel.runtime.shellHint("DisplaySettings.cancel")
            enabled: !panel.busy && (panel.previewActive || panel.changed)
            onActivated: panel.cancelNested()
        }
        ShellAction {
            id: previewAction
            width: implicitWidth
            height: implicitHeight
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            compact: true
            horizontalCompact: true
            icon: DesktopIcons.actionGlyph("confirm")
            title: panel.previewActive ? "Keep layout" : "Preview layout"
            activeColor: panel.previewActive ? panel.theme.positive : panel.theme.commandColor
            shortcut: panel.runtime.shellHint("DisplaySettings.apply")
            prominentAction: enabled
            restingRadius: height / 2
            enabled: !panel.busy && (panel.previewActive || panel.editable && panel.changed)
            onActivated: panel.previewOrKeep()
        }
    }
    Row {
        width: parent.width
        spacing: panel.theme.spacing2
        ShellText {
            width: Math.max(1, parent.width - saveProfileAction.width - parent.spacing)
            anchors.verticalCenter: parent.verticalCenter
            runtime: panel.runtime
            theme: panel.theme
            text: "Saved layouts"
            textRole: ShellText.Section
        }
        ShellUtilityAction {
            id: saveProfileAction
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            icon: DesktopIcons.actionGlyph("save")
            title: "Save current layout"
            shortcut: panel.runtime.shellHint("DisplaySettings.saveProfile")
            enabled: panel.canSaveProfile
            onActivated: panel.run("save-profile")
        }
    }
    ShellText {
        visible: panel.profiles.length === 0
        width: parent.width
        runtime: panel.runtime
        theme: panel.theme
        text: "No saved layouts"
        textRole: ShellText.Supporting
    }
    Row {
        visible: panel.profiles.length > 0
        width: parent.width
        spacing: panel.theme.spacing2
        ShellValueSelector {
            id: profileSelector
            width: Math.max(1, parent.width - loadProfileAction.width - deleteProfileAction.width - parent.spacing * 2)
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            title: "Layout"
            shortcut: panel.runtime.shellHint("DisplaySettings.nextProfile")
            confirmShortcut: panel.runtime.shellHint("DisplaySettings.apply")
            options: panel.profiles.map(entry => entry.label + (entry.compatible ? "" : " · Different displays"))
            selectedIndex: panel.profileIndex
            enabled: panel.profileActionsAvailable && panel.profiles.length > 0
            onOpened: {
                resolutionSelector.cancel();
                refreshSelector.cancel();
            }
            onChosen: index => panel.profileIndex = index
        }
        ShellUtilityAction {
            id: loadProfileAction
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            icon: DesktopIcons.actionGlyph("confirm")
            title: "Preview saved layout"
            shortcut: panel.runtime.shellHint("DisplaySettings.previewProfile")
            enabled: panel.profileActionsAvailable && !!panel.profile?.compatible && !profileSelector.expanded
            onActivated: panel.run("preview-profile", [String(panel.profileIndex)])
        }
        ShellUtilityAction {
            id: deleteProfileAction
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            icon: DesktopIcons.actionGlyph("delete")
            title: "Remove selected layout"
            activeColor: panel.theme.critical
            shortcut: panel.runtime.shellHint("DisplaySettings.deleteProfile")
            enabled: panel.profileActionsAvailable && !!panel.profile && !profileSelector.expanded
            onActivated: panel.run("delete-profile", [String(panel.profileIndex)])
        }
    }
}

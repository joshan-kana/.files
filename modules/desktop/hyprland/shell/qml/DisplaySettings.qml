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
    signal nativeEditorRequested
    property var monitors: []
    property int outputIndex: 0
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
        else if (previewActive && !busy)
            run("rollback");
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
        if (busy || previewActive || monitors.length < 2)
            return;
        outputIndex = (outputIndex + 1) % monitors.length;
        loadValues();
    }
    function cycleMode(delta: int): void {
        if (!editable || modes.length === 0)
            return;
        mode = modes[(modes.indexOf(mode) + delta + modes.length) % modes.length];
        if (!scales.includes(scaleValue))
            scaleValue = scales.reduce((best, value) => Math.abs(value - scaleValue) < Math.abs(best - scaleValue) ? value : best, 1);
    }
    function cycleScale(delta: int): void {
        if (!editable || scales.length === 0)
            return;
        scaleValue = scales[(scales.indexOf(scaleValue) + delta + scales.length) % scales.length];
    }
    function cycleOrientation(): void {
        if (editable)
            orientation = (orientation + 1) % 4;
    }
    function previewOrKeep(): void {
        if (previewActive) {
            run("keep");
        } else if (editable && changed) {
            run("preview", [output.name, mode, String(scaleValue), String(orientation), String(positionX), String(positionY)]);
        }
    }
    function cancelNested(): bool {
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
        const actions = ["DisplaySettings.apply", "DisplaySettings.cancel", "DisplaySettings.refresh", "DisplaySettings.native", "DisplaySettings.output", "DisplaySettings.mode", "DisplaySettings.previousMode", "DisplaySettings.scale", "DisplaySettings.previousScale", "DisplaySettings.orientation", "DisplaySettings.moveLeft", "DisplaySettings.moveRight", "DisplaySettings.moveUp", "DisplaySettings.moveDown"];
        for (const id of actions) {
            const action = id.split(".")[1];
            if (!runtime.shellMatchesHint(id, key, modifiers) && !(action === "apply" && key === runtime.shellKeyCode("controls", "Enter") && modifiers === Qt.NoModifier))
                continue;
            if (autoRepeat && !action.startsWith("move"))
                return true;
            if (action === "apply")
                previewOrKeep();
            else if (action === "cancel")
                cancelNested();
            else if (action === "refresh" && !previewActive)
                refresh();
            else if (action === "native" && !busy && !previewActive)
                nativeEditorRequested();
            else if (action === "output")
                cycleOutput();
            else if (action === "mode" || action === "previousMode")
                cycleMode(action === "mode" ? 1 : -1);
            else if (action === "scale" || action === "previousScale")
                cycleScale(action === "scale" ? 1 : -1);
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
        width: parent.width
        runtime: panel.runtime
        theme: panel.theme
        text: panel.error || (panel.previewActive ? "Keep the new layout within " + Math.max(0, Math.ceil(panel.deadline - panel.clockMs / 1000)) + " seconds; otherwise it reverts." : panel.busy ? "Reading compositor state…" : panel.output ? panel.output.name + " · " + panel.output.width + "×" + panel.output.height + " @ " + panel.output.refreshRate.toFixed(1) + " Hz · scale " + panel.output.scale : "No outputs reported")
        color: panel.error || panel.previewActive ? panel.theme.warning : panel.theme.textMuted
        wrapMode: Text.WordWrap
    }
    Row {
        width: parent.width
        height: 42
        spacing: panel.theme.spacing2
        ShellAction {
            width: Math.max(1, (parent.width - displayRefresh.width - 2 * parent.spacing) / 2)
            height: parent.height
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            compact: true
            horizontalCompact: true
            title: panel.output ? panel.output.name + " · " + (panel.outputIndex + 1) + "/" + panel.monitors.length : "No display"
            shortcut: panel.runtime.shellHint("DisplaySettings.output")
            enabled: !panel.busy && !panel.previewActive && panel.monitors.length > 1
            onActivated: panel.cycleOutput()
        }
        ShellAction {
            id: displayRefresh
            width: implicitWidth
            height: parent.height
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            compact: true
            iconOnly: true
            inlineIconHint: true
            icon: DesktopIcons.actionGlyph("refresh")
            title: "Refresh"
            shortcut: panel.runtime.shellHint("DisplaySettings.refresh")
            enabled: !panel.busy && !panel.previewActive
            onActivated: panel.refresh()
        }
        ShellAction {
            width: Math.max(1, (parent.width - displayRefresh.width - 2 * parent.spacing) / 2)
            height: parent.height
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            compact: true
            horizontalCompact: true
            title: "Advanced display editor"
            shortcut: panel.runtime.shellHint("DisplaySettings.native")
            enabled: !panel.busy && !panel.previewActive && panel.runtime.displaySettings.length > 0
            onActivated: panel.nativeEditorRequested()
        }
    }
    ShellSurface {
        width: parent.width
        height: panel.theme.fontSize(panel.logicalOutputs.length > 1 ? 150 : 104)
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
                    borderColor: modelData.selected ? panel.theme.roleColor("display") : panel.theme.subtleBorder
                    borderWidth: modelData.selected ? panel.theme.borderFocus : panel.theme.borderThin
                    fillColor: modelData.selected ? panel.theme.selectedTabFill : panel.theme.controlBase
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
        text: "This layout is not a supported generated monitor rule. Use the native editor to configure it."
        color: panel.theme.textMuted
        wrapMode: Text.WordWrap
    }
    Grid {
        width: parent.width
        columns: 3
        rowSpacing: panel.theme.spacing2
        columnSpacing: panel.theme.spacing2
        Repeater {
            model: [
                {
                    title: panel.mode || "Mode unavailable",
                    key: "mode",
                    action: "DisplaySettings.mode",
                    alternate: "DisplaySettings.previousMode",
                    description: "Resolution / refresh"
                },
                {
                    title: panel.scaleValue.toFixed(2) + "×",
                    key: "scale",
                    action: "DisplaySettings.scale",
                    alternate: "DisplaySettings.previousScale",
                    description: "Scale"
                },
                {
                    title: ["Normal", "90°", "180°", "270°"][panel.orientation] || "Other",
                    key: "orientation",
                    action: "DisplaySettings.orientation",
                    alternate: "",
                    description: "Orientation"
                }
            ]
            delegate: Column {
                id: field
                required property var modelData
                width: (panel.width - 2 * panel.theme.spacing2) / 3
                spacing: panel.theme.spacing1
                ShellText {
                    width: parent.width
                    runtime: panel.runtime
                    theme: panel.theme
                    text: field.modelData.description
                    color: panel.theme.textMuted
                }
                ShellAction {
                    width: parent.width
                    height: 44
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    title: field.modelData.title
                    shortcut: panel.runtime.shellHint(field.modelData.action)
                    compact: true
                    horizontalCompact: true
                    enabled: panel.editable
                    onActivated: {
                        if (field.modelData.key === "mode")
                            panel.cycleMode(1);
                        else if (field.modelData.key === "scale")
                            panel.cycleScale(1);
                        else
                            panel.cycleOrientation();
                    }
                }
                ShellAction {
                    visible: field.modelData.alternate !== ""
                    width: parent.width
                    height: visible ? 36 : 0
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    title: "Previous"
                    shortcut: visible ? panel.runtime.shellHint(field.modelData.alternate) : ""
                    compact: true
                    horizontalCompact: true
                    enabled: panel.editable
                    onActivated: field.modelData.key === "mode" ? panel.cycleMode(-1) : panel.cycleScale(-1)
                }
            }
        }
    }
    ShellText {
        width: parent.width
        runtime: panel.runtime
        theme: panel.theme
        text: "Position · " + panel.positionX + ", " + panel.positionY + " logical px · VRR " + (panel.output?.vrr ? "active" : "inactive") + " · " + (panel.output?.colorManagementPreset || "Colour mode unavailable")
        color: panel.theme.textMuted
    }
    Row {
        width: parent.width
        height: 40
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
            iconOnly: true
            inlineIconHint: true
            quietAction: true
            icon: DesktopIcons.actionGlyph("cancel")
            title: panel.previewActive ? "Revert temporary layout" : "Discard edits"
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
            shortcut: panel.runtime.shellHint("DisplaySettings.apply")
            active: panel.previewActive || panel.changed
            enabled: !panel.busy && (panel.previewActive || panel.editable && panel.changed)
            onActivated: panel.previewOrKeep()
        }
    }
}

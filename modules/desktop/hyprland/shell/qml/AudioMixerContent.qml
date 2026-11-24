pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "DesktopIcons.js" as DesktopIcons

FocusScope {
    id: mixer

    required property SystemState system
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property bool compact: false
    property bool destinationBusy: false
    property bool foregroundOutlineVisible: false
    property bool active: false
    property int selectedIndex: 0
    property int selectedNodeId: -1
    property string selectedKind: "output"
    readonly property var streams: system.audioApplicationStreams.concat(system.audioCaptureStreams)
    readonly property var targets: [
        {
            kind: "output"
        },
    ].concat(compact || system.microphoneAvailable || system.audioCaptureStreams.length > 0 ? [
        {
            kind: "input"
        }
    ] : []).concat(compact ? [] : system.audioApplicationStreams.map(node => ({
                kind: "stream",
                node: node,
                capture: false
            }))).concat(compact ? [] : system.audioCaptureStreams.map(node => ({
                kind: "stream",
                node: node,
                capture: true
            })))
    readonly property int microphoneIndex: 1
    readonly property bool deviceChooserOpen: outputDevice.chooserOpen || inputDevice.chooserOpen || routeOpen || presetOpen
    readonly property int selectedStreamIndex: selectedTarget?.kind === "stream" ? streams.findIndex(node => node.id === selectedTarget.node.id) : -1
    readonly property var selectedTarget: targets[Math.max(0, Math.min(selectedIndex, targets.length - 1))] || null

    readonly property string foregroundRole: "audio"
    readonly property bool foregroundBusy: routeProcess.running || pendingRoute !== "" || effectsState.awaitingConfirmation || effectsState.requestedPreset !== null
    property bool presetOpen: false
    property int presetIndex: 0
    function togglePresetPicker(): void {
        if (presetOpen) {
            presetOpen = false;
            return;
        }
        if (effectsState.presetsKnown && !effectsState.presetBusy && effectsState.presets.length > 0) {
            presetIndex = Math.max(0, effectsState.presets.findIndex(entry => entry.name === effectsState.activePresets.output || entry.name === effectsState.activePresets.input));
            routeOpen = false;
            outputDevice.chooserOpen = false;
            inputDevice.chooserOpen = false;
            presetOpen = true;
        }
    }
    function chooseEffectPreset(index: int): void {
        const entry = effectsState.presets[index];
        if (entry)
            effectsState.choosePreset(entry.name);
        presetOpen = false;
    }

    property bool routeOpen: false
    property int routeIndex: 0
    property string routeError: ""
    property string pendingRoute: ""
    property int pendingStreamId: -1
    property bool pendingCapture: false
    readonly property var pendingStream: streams.find(stream => stream.id === pendingStreamId) || null
    readonly property var confirmedRoute: system.streamDevice(pendingStream, pendingCapture)
    readonly property var routeStream: selectedTarget?.kind === "stream" ? selectedTarget.node : null
    readonly property bool routeCapture: !!selectedTarget?.capture
    readonly property var routeDevices: routeCapture ? system.inputDevices : system.outputDevices
    readonly property var routedDevice: system.streamDevice(routeStream, routeCapture)
    readonly property var balanceNode: selectedTarget?.kind === "output" ? system.audioSink : selectedTarget?.kind === "input" ? system.audioSource : routeStream
    readonly property bool balanceAvailable: !!system.stereoIndices(balanceNode)
    readonly property real balancePosition: system.balance(balanceNode)
    onRouteStreamChanged: routeOpen = false
    onRouteDevicesChanged: {
        routeIndex = Math.max(0, Math.min(routeIndex, routeDevices.length - 1));
        if (!routeDevices.length)
            routeOpen = false;
    }

    Process {
        id: routeProcess
        stderr: StdioCollector {
            id: routeStderr
        }
        onExited: (code, status) => {
            if (code !== 0) {
                mixer.pendingRoute = "";
                mixer.routeError = routeStderr.text.trim() || "Could not request routing";
                routeTimeout.stop();
            }
        }
    }
    Timer {
        id: routeTimeout
        interval: 2500
        onTriggered: {
            if (mixer.pendingRoute !== "") {
                mixer.routeError = mixer.confirmedRoute?.name === mixer.pendingRoute ? "" : "Routing was not confirmed by PipeWire. Check EasyEffects or WirePlumber policy.";
                mixer.pendingRoute = "";
            }
        }
    }
    function selectRoute(index: int): void {
        const target = routeDevices[index];
        const stream = routeStream;
        if (!target || !stream || !runtime.pwMetadata || routeProcess.running || pendingRoute !== "")
            return;
        if (routedDevice?.id === target.id) {
            routeOpen = false;
            return;
        }
        pendingRoute = target.name;
        pendingStreamId = stream.id;
        pendingCapture = routeCapture;
        routeError = "";
        routeProcess.exec([runtime.pwMetadata, "-n", "default", String(stream.id), "target.object", target.name, "Spa:String"]);
        routeTimeout.restart();
        routeOpen = false;
    }
    function adjustBalance(delta: real): void {
        if (balanceAvailable) {
            balanceSlider.beginKeyboardAdjustment();
            system.setBalance(balanceNode, balancePosition + delta);
        }
    }

    signal closeRequested
    signal keyboardRequested
    signal expandRequested
    signal streamAdjustmentRequested(int index)

    EasyEffectsState {
        id: effectsState
        runtime: mixer.runtime
    }

    implicitWidth: compact ? 490 : 950
    readonly property real compactTopInset: Math.max(theme.spacing4, theme.spacing2 * 2 + theme.keycapHeight)
    implicitHeight: body.implicitHeight + (compact ? compactTopInset + theme.spacing3 : theme.spacing2 * 2)
    visible: active
    focus: active && !compact

    function selectIndex(index: int): void {
        selectedIndex = Math.max(0, Math.min(index, Math.max(0, targets.length - 1)));
        const target = targets[selectedIndex];
        selectedNodeId = target?.node ? target.node.id : -1;
        selectedKind = target?.kind || "output";
    }

    onTargetsChanged: {
        const index = selectedNodeId >= 0 ? targets.findIndex(target => target.node && target.node.id === selectedNodeId) : targets.findIndex(target => target.kind === selectedKind);
        selectIndex(index >= 0 ? index : 0);
    }

    onActiveChanged: {
        if (!active) {
            outputDevice.chooserOpen = false;
            inputDevice.chooserOpen = false;
            routeOpen = false;
            presetOpen = false;
            return;
        }
        selectIndex(selectedIndex);
        if (!compact)
            effectsState.refresh();
        if (!compact)
            Qt.callLater(() => {
                if (mixer.active)
                    mixer.keyboardRequested();
            });
    }

    function focusKeyboard(): void {
        if (active && !compact)
            keyboardRequested();
    }

    function selectedStream(): var {
        return selectedTarget?.kind === "stream" ? selectedTarget.node : null;
    }

    function selectStreamIndex(index: int): void {
        const node = streams[index];
        if (!node)
            return;
        const target = targets.findIndex(candidate => candidate.kind === "stream" && candidate.node.id === node.id);
        if (target >= 0)
            selectIndex(target);
    }

    function moveAudioSelection(delta: int): void {
        if (targets.length)
            selectIndex((selectedIndex + delta + targets.length) % targets.length);
    }

    function adjustSelected(delta: real): void {
        const target = selectedTarget;
        if (target?.kind === "output") {
            outputDevice.beginKeyboardAdjustment();
            system.adjustVolume(delta);
        } else if (target?.kind === "input") {
            inputDevice.beginKeyboardAdjustment();
            system.setMicrophoneVolume(system.microphoneVolume + delta);
        } else if (target?.node) {
            streamAdjustmentRequested(selectedStreamIndex);
            system.adjustStreamVolume(target.node, delta);
        }
    }

    function toggleSelectedMute(): void {
        const target = selectedTarget;
        if (target?.kind === "output")
            system.toggleMute();
        else if (target?.kind === "input")
            system.toggleMicrophoneMute();
        else if (target?.node)
            system.toggleStreamMute(target.node);
    }

    function toggleSelectedDeviceChooser(): void {
        const target = selectedTarget;
        if (target?.kind === "stream" && !compact) {
            routeOpen = !routeOpen && routeDevices.length > 0;
            routeIndex = Math.max(0, routeDevices.indexOf(routedDevice));
        } else if (target?.kind === "input")
            inputDevice.toggleDeviceChooser();
        else
            outputDevice.toggleDeviceChooser();
    }

    function handleKey(key: int, modifiers: int, autoRepeat: bool): bool {
        if (!active)
            return false;
        if (presetOpen) {
            if (key === runtime.shellKeyCode("mixer", "Escape") || runtime.shellMatchesHint("AudioMixerContent.effectsPresets", key, modifiers)) {
                if (!autoRepeat)
                    presetOpen = false;
            } else if (runtime.shellNavigates("mixer", "down", key)) {
                presetIndex = (presetIndex + 1) % effectsState.presets.length;
            } else if (runtime.shellNavigates("mixer", "up", key)) {
                presetIndex = (presetIndex + effectsState.presets.length - 1) % effectsState.presets.length;
            } else if (key === runtime.shellKeyCode("mixer", "Return") || key === runtime.shellKeyCode("mixer", "Enter")) {
                if (!autoRepeat)
                    chooseEffectPreset(presetIndex);
            } else {
                return false;
            }
            return true;
        }
        if (!compact && runtime.shellMatchesHint("AudioMixerContent.effectsPresets", key, modifiers)) {
            if (!autoRepeat)
                togglePresetPicker();
            return true;
        }
        if (routeOpen) {
            if (key === runtime.shellKeyCode("mixer", "Escape") || runtime.shellMatchesHint("AudioDeviceControl.chooser", key, modifiers)) {
                routeOpen = false;
            } else if (runtime.shellNavigates("mixer", "down", key)) {
                routeIndex = (routeIndex + 1) % routeDevices.length;
            } else if (runtime.shellNavigates("mixer", "up", key)) {
                routeIndex = (routeIndex + routeDevices.length - 1) % routeDevices.length;
            } else if (key === runtime.shellKeyCode("mixer", "Return") || key === runtime.shellKeyCode("mixer", "Enter")) {
                if (!autoRepeat)
                    selectRoute(routeIndex);
            } else {
                return false;
            }
            return true;
        }
        if (!compact && runtime.shellModifier("mixer", "Shift", modifiers) && runtime.shellNavigates("mixer", "left", key, "primary")) {
            adjustBalance(-0.1);
            return true;
        }
        if (!compact && runtime.shellModifier("mixer", "Shift", modifiers) && runtime.shellNavigates("mixer", "right", key, "primary")) {
            adjustBalance(0.1);
            return true;
        }
        if (!compact && runtime.shellMatchesHint("AudioMixerContent.balanceReset", key, modifiers)) {
            if (!autoRepeat && balanceAvailable)
                system.setBalance(balanceNode, 0);
            return true;
        }
        const picker = outputDevice.chooserOpen ? outputDevice : inputDevice.chooserOpen ? inputDevice : null;
        if (picker) {
            if (key === mixer.runtime.shellKeyCode("mixer", "Escape") || key === mixer.runtime.shellKeyCode("mixer", "Backspace") || key === mixer.runtime.shellKeyCode("mixer", "D")) {
                picker.chooserOpen = false;
            } else if (mixer.runtime.shellNavigates("mixer", "down", key)) {
                picker.moveDeviceSelection(1);
            } else if (mixer.runtime.shellNavigates("mixer", "up", key)) {
                picker.moveDeviceSelection(-1);
            } else if (key === mixer.runtime.shellKeyCode("mixer", "Return") || key === mixer.runtime.shellKeyCode("mixer", "Enter")) {
                picker.selectDevice(picker.chooserIndex);
            } else {
                return false;
            }
            return true;
        }
        if (!compact && mixer.runtime.shellMatchesHint("AudioMixerContent.effectsToggle", key, modifiers)) {
            if (!autoRepeat)
                effectsState.toggleBypass();
            return true;
        }
        if (!compact && mixer.runtime.shellMatchesHint("AudioMixerContent.effectsOpen", key, modifiers)) {
            if (!autoRepeat)
                effectsState.openEditor();
            return true;
        }
        if (!compact && mixer.runtime.shellMatchesHint("AudioMixerContent.effectsRefresh", key, modifiers)) {
            if (!autoRepeat)
                effectsState.refresh();
            return true;
        }
        if (key === mixer.runtime.shellKeyCode("mixer", "Escape") && !compact)
            closeRequested();
        else if (mixer.runtime.shellNavigates("mixer", "up", key) || mixer.runtime.shellNavigates("mixer", "down", key) || (!compact && (key === mixer.runtime.shellKeyCode("mixer", "Tab") || key === mixer.runtime.shellKeyCode("mixer", "Backtab")))) {
            const backwards = mixer.runtime.shellNavigates("mixer", "up", key) || key === mixer.runtime.shellKeyCode("mixer", "Backtab") || (key === mixer.runtime.shellKeyCode("mixer", "Tab") && (mixer.runtime.shellModifier("mixer", "Shift", modifiers)));
            moveAudioSelection(backwards ? -1 : 1);
        } else if (!compact && (key === mixer.runtime.shellKeyCode("mixer", "U") || key === mixer.runtime.shellKeyCode("mixer", "PageUp") || key === mixer.runtime.shellKeyCode("mixer", "D") || key === mixer.runtime.shellKeyCode("mixer", "PageDown"))) {
            const rows = Math.max(1, Math.floor(list.height / (compact ? 72 : 106)));
            selectIndex(Math.max(0, Math.min(targets.length - 1, selectedIndex + ((key === mixer.runtime.shellKeyCode("mixer", "D") || key === mixer.runtime.shellKeyCode("mixer", "PageDown")) ? rows : -rows))));
        } else if (mixer.runtime.shellNavigates("mixer", "left", key)) {
            adjustSelected(-0.05);
        } else if (mixer.runtime.shellNavigates("mixer", "right", key)) {
            adjustSelected(0.05);
        } else if (key === mixer.runtime.shellKeyCode("mixer", "M") || (!compact && (key === mixer.runtime.shellKeyCode("mixer", "Return") || key === mixer.runtime.shellKeyCode("mixer", "Enter")))) {
            if (!autoRepeat)
                toggleSelectedMute();
        } else if (key === mixer.runtime.shellKeyCode("mixer", "P")) {
            if (!autoRepeat)
                toggleSelectedDeviceChooser();
        } else if (key === mixer.runtime.shellKeyCode("mixer", "X")) {
            if (!autoRepeat)
                system.toggleMicrophoneMute();
        } else {
            return false;
        }
        return true;
    }

    StateLayer {
        id: mixerHit
        growOnHover: true
        feedbackParent: visualBody
        visible: mixer.compact
        enabled: mixer.compact && mixer.active
        theme: mixer.theme
        motion: mixer.motion
        stateColor: mixer.theme.roleColor("audio")
        hoverOpacity: 0.08
        pressOpacity: 0.13
        cornerRadius: mixer.theme.radiusLarge
        Accessible.role: Accessible.Button
        Accessible.name: "Open audio mixer"
        Accessible.onPressAction: mixer.expandRequested()
        onActivated: mixer.expandRequested()
    }

    Item {
        id: visualBody
        anchors.fill: parent
        scale: mixer.compact ? mixerHit.defaultEffectScale : 1
        ShellSurface {
            z: -1
            anchors.fill: parent
            visible: mixer.compact
            foregroundBusy: mixer.compact && mixer.foregroundOutlineVisible && (mixer.foregroundBusy || mixer.destinationBusy)
            foregroundColor: mixer.theme.roleColor("audio")
            theme: mixer.theme
            motion: mixer.motion
            surfaceLayer: ShellSurface.Group
            cornerRadius: mixer.theme.radiusLarge
            fillColor: mixer.theme.groupBase
        }

        Column {
            id: body
            z: 1
            x: mixer.compact ? mixer.theme.spacing4 : mixer.theme.spacing2
            y: mixer.compact ? mixer.compactTopInset : mixer.theme.spacing2
            width: Math.max(1, parent.width - (mixer.compact ? mixer.theme.spacing4 : mixer.theme.spacing2) * 2)
            spacing: mixer.theme.spacing3

            Item {
                width: parent.width
                height: 66
                visible: !mixer.compact

                DetailHero {
                    width: parent.width
                    height: parent.height
                    runtime: mixer.runtime
                    theme: mixer.theme
                    motion: mixer.motion
                    glyph: DesktopIcons.glyphFor("audioMixer")
                    glyphColor: mixer.theme.roleColor("audio")
                    eyebrow: "Audio / " + mixer.streams.length + (mixer.streams.length === 1 ? " active channel" : " active channels")
                    title: "Audio mixer"
                    detail: "Output, input and every application channel"
                }
            }

            Grid {
                id: deviceGrid
                width: parent.width
                columns: width >= (mixer.compact ? 440 : 600) && mixer.theme.textScale < 1.5 ? 2 : 1
                columnSpacing: mixer.compact ? mixer.theme.spacing5 : mixer.theme.spacing2
                rowSpacing: mixer.theme.spacing2
                readonly property real cellWidth: Math.max(1, (width - (columns - 1) * columnSpacing) / columns)

                AudioDeviceControl {
                    id: outputDevice
                    width: deviceGrid.cellWidth
                    height: implicitHeight
                    microphone: false
                    compact: mixer.compact
                    active: mixer.active
                    selected: mixer.selectedIndex === 0
                    system: mixer.system
                    runtime: mixer.runtime
                    theme: mixer.theme
                    motion: mixer.motion
                    onChooserOpenChanged: {
                        if (chooserOpen)
                            inputDevice.chooserOpen = false;
                    }
                    onSelectedRequested: mixer.selectIndex(0)
                }

                AudioDeviceControl {
                    id: inputDevice
                    visible: true
                    width: deviceGrid.cellWidth
                    height: implicitHeight
                    microphone: true
                    compact: mixer.compact
                    active: mixer.active
                    selected: mixer.selectedIndex === mixer.microphoneIndex
                    system: mixer.system
                    runtime: mixer.runtime
                    theme: mixer.theme
                    motion: mixer.motion
                    onChooserOpenChanged: {
                        if (chooserOpen)
                            outputDevice.chooserOpen = false;
                    }
                    onSelectedRequested: mixer.selectIndex(mixer.microphoneIndex)
                }
            }

            Column {
                id: postProcessing
                visible: !mixer.compact && effectsState.supported
                width: parent.width
                spacing: mixer.theme.spacing2

                Row {
                    width: parent.width
                    height: 20
                    spacing: mixer.theme.spacing2

                    ShellText {
                        anchors.verticalCenter: parent.verticalCenter
                        runtime: mixer.runtime
                        theme: mixer.theme
                        text: "POST-PROCESSING"
                        color: mixer.theme.readableRoleColor("audio")
                        font.pixelSize: mixer.theme.fontSize(10)
                        font.weight: Font.DemiBold
                    }

                    ShellText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(1, parent.width - x - parent.spacing)
                        runtime: mixer.runtime
                        theme: mixer.theme
                        text: effectsState.statusLabel
                        color: effectsState.error.length > 0 ? mixer.theme.warning : mixer.theme.textMuted
                        elide: Text.ElideRight
                        font.pixelSize: mixer.theme.fontSize(10)
                    }
                }

                Grid {
                    width: parent.width
                    columns: width >= 510 && mixer.theme.textScale < 1.5 ? 3 : 1
                    rowSpacing: mixer.theme.spacing2
                    columnSpacing: mixer.theme.spacing2
                    readonly property real cellWidth: Math.max(1, (width - (columns - 1) * columnSpacing) / columns)

                    ShellAction {
                        width: parent.cellWidth
                        height: 44
                        runtime: mixer.runtime
                        theme: mixer.theme
                        motion: mixer.motion
                        compact: true
                        horizontalCompact: true
                        icon: effectsState.bypassed ? "󰖁" : "󰕾"
                        title: effectsState.bypassed ? "Resume processing" : "Bypass effects"
                        shortcut: mixer.runtime.shellHint("AudioMixerContent.effectsToggle")
                        active: effectsState.known && effectsState.bypassed
                        enabled: effectsState.known && !effectsState.busy
                        onActivated: effectsState.toggleBypass()
                    }

                    ShellAction {
                        width: parent.cellWidth
                        height: 44
                        runtime: mixer.runtime
                        theme: mixer.theme
                        motion: mixer.motion
                        compact: true
                        horizontalCompact: true
                        icon: "󰍽"
                        title: "Open EasyEffects"
                        shortcut: mixer.runtime.shellHint("AudioMixerContent.effectsOpen")
                        onActivated: effectsState.openEditor()
                    }

                    ShellAction {
                        width: parent.cellWidth
                        height: 44
                        runtime: mixer.runtime
                        theme: mixer.theme
                        motion: mixer.motion
                        compact: true
                        horizontalCompact: true
                        icon: "󰑐"
                        title: "Refresh effects"
                        shortcut: mixer.runtime.shellHint("AudioMixerContent.effectsRefresh")
                        enabled: !effectsState.busy
                        onActivated: effectsState.refresh()
                    }
                }
                ShellText {
                    width: parent.width
                    runtime: mixer.runtime
                    theme: mixer.theme
                    text: effectsState.presetStatus
                    color: effectsState.presetError ? mixer.theme.warning : mixer.theme.textMuted
                    elide: Text.ElideRight
                    font.pixelSize: mixer.theme.fontSize(10)
                }
                ShellAction {
                    width: parent.width
                    height: 36
                    runtime: mixer.runtime
                    theme: mixer.theme
                    motion: mixer.motion
                    compact: true
                    horizontalCompact: true
                    title: effectsState.presetsKnown && effectsState.presets.length === 0 ? "No local presets · Create one in EasyEffects" : "Choose effects preset"
                    shortcut: mixer.runtime.shellHint("AudioMixerContent.effectsPresets")
                    active: mixer.presetOpen
                    enabled: effectsState.presetsKnown && !effectsState.presetBusy && effectsState.presets.length > 0
                    onActivated: mixer.togglePresetPicker()
                }
                ListView {
                    width: parent.width
                    height: mixer.presetOpen ? Math.min(4, effectsState.presets.length) * 38 : 0
                    visible: mixer.presetOpen
                    clip: true
                    model: effectsState.presets
                    currentIndex: mixer.presetIndex
                    onCurrentIndexChanged: if (currentIndex >= 0)
                        positionViewAtIndex(currentIndex, ListView.Contain)
                    delegate: ShellAction {
                        required property int index
                        required property var modelData
                        width: ListView.view.width
                        height: 36
                        runtime: mixer.runtime
                        theme: mixer.theme
                        motion: mixer.motion
                        compact: true
                        horizontalCompact: true
                        title: modelData.name + " · " + (modelData.input && modelData.output ? "Input + output" : modelData.input ? "Input" : "Output")
                        shortcut: index === mixer.presetIndex ? "↵" : ""
                        active: index === mixer.presetIndex
                        onActivated: mixer.chooseEffectPreset(index)
                    }
                }
            }

            Row {
                width: parent.width
                visible: !mixer.compact
                height: visible ? 20 : 0
                spacing: mixer.theme.spacing2
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(1, parent.width - channelCount.implicitWidth - parent.spacing)
                    text: mixer.compact ? "Application audio" : "Application channels"
                    color: mixer.theme.readableRoleColor("audio")
                    font.family: mixer.runtime.fontSans
                    font.pixelSize: mixer.theme.fontSize(10)
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.9
                }
                Text {
                    id: channelCount
                    anchors.verticalCenter: parent.verticalCenter
                    text: mixer.system.audioApplicationStreams.length + " PLAY · " + mixer.system.audioCaptureStreams.length + " REC"
                    color: mixer.theme.textMuted
                    font.family: mixer.runtime.fontSans
                    font.pixelSize: mixer.theme.fontSize(9)
                }
            }

            ListView {
                id: list
                width: parent.width
                height: !mixer.compact && mixer.streams.length > 0 ? Math.min(330, mixer.streams.length * 112 + 36) : 0
                visible: !mixer.compact && mixer.streams.length > 0
                model: mixer.compact ? 0 : mixer.streams.length
                orientation: ListView.Vertical
                spacing: mixer.theme.spacing1
                cacheBuffer: 90
                clip: true
                interactive: !mixer.compact && mixer.streams.length > 3
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: mixer.selectedStreamIndex
                onCurrentIndexChanged: {
                    if (currentIndex >= 0)
                        positionViewAtIndex(currentIndex, ListView.Contain);
                }

                delegate: Item {
                    id: streamRow
                    required property int index
                    readonly property var stream: mixer.streams[index] || null
                    readonly property bool capture: index >= mixer.system.audioApplicationStreams.length
                    readonly property bool sectionStart: index === 0 || index === mixer.system.audioApplicationStreams.length
                    readonly property bool inViewport: y + height > list.contentY && y < list.contentY + list.height
                    width: list.width
                    height: (mixer.compact ? 72 : 112) + (sectionStart && !mixer.compact ? 18 : 0)

                    Text {
                        visible: streamRow.sectionStart && !mixer.compact
                        height: visible ? 18 : 0
                        text: streamRow.capture ? "Capture" : "Playback"
                        color: mixer.theme.readableRoleColor("audio")
                        font.family: mixer.runtime.fontSans
                        font.pixelSize: mixer.theme.fontSize(9)
                    }

                    ShellSurface {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            topMargin: streamRow.sectionStart && !mixer.compact ? 18 : 0
                        }
                        height: mixer.compact ? 72 : 112
                        theme: mixer.theme
                        motion: mixer.motion
                        surfaceLayer: ShellSurface.Control
                        cornerRadius: mixer.theme.radiusMedium
                        fillColor: mixer.selectedStreamIndex === streamRow.index ? mixer.theme.expressiveSurfaceStrong : mixer.theme.expressiveSurface
                        borderColor: mixer.selectedStreamIndex === streamRow.index ? mixer.theme.roleColor("audio") : "transparent"
                        borderWidth: mixer.selectedStreamIndex === streamRow.index ? mixer.theme.borderFocus : 0

                        AudioStreamControl {
                            id: streamControl
                            Connections {
                                target: mixer
                                function onStreamAdjustmentRequested(index: int): void {
                                    if (index === streamRow.index)
                                        streamControl.beginKeyboardAdjustment();
                                }
                            }
                            anchors {
                                fill: parent
                                margins: mixer.theme.spacing2
                            }
                            compact: mixer.compact
                            selected: mixer.selectedStreamIndex === streamRow.index
                            stream: streamRow.stream
                            capture: streamRow.capture
                            system: mixer.system
                            runtime: mixer.runtime
                            theme: mixer.theme
                            motion: mixer.motion
                            monitoring: mixer.active && list.visible && streamRow.inViewport
                            onSelectedRequested: mixer.selectStreamIndex(streamRow.index)
                        }
                    }
                }
            }

            ShellSurface {
                width: parent.width
                height: mixer.compact ? 46 : 120
                visible: !mixer.compact && mixer.streams.length === 0
                theme: mixer.theme
                motion: mixer.motion
                surfaceLayer: ShellSurface.Control
                cornerRadius: mixer.theme.radiusMedium
                Text {
                    anchors.centerIn: parent
                    text: mixer.compact ? "No application audio" : "No application channels · Start playback or capture"
                    color: mixer.theme.textMuted
                    font.family: mixer.runtime.fontSans
                    font.pixelSize: mixer.theme.fontSize(11)
                }
            }

            Column {
                visible: !mixer.compact && mixer.routeStream !== null
                width: parent.width
                spacing: mixer.theme.spacing1
                ShellAction {
                    width: parent.width
                    height: 36
                    runtime: mixer.runtime
                    theme: mixer.theme
                    motion: mixer.motion
                    title: (mixer.routeCapture ? "Input: " : "Output: ") + (mixer.routedDevice?.description || mixer.routedDevice?.name || "Not connected")
                    shortcut: mixer.runtime.shellHint("AudioDeviceControl.chooser")
                    compact: true
                    horizontalCompact: true
                    enabled: mixer.routeDevices.length > 0 && mixer.runtime.pwMetadata !== "" && mixer.pendingRoute === ""
                    active: mixer.routeOpen
                    onActivated: mixer.toggleSelectedDeviceChooser()
                }
                ListView {
                    width: parent.width
                    height: mixer.routeOpen ? Math.min(4, mixer.routeDevices.length) * 38 : 0
                    visible: mixer.routeOpen
                    clip: true
                    model: mixer.routeDevices
                    currentIndex: mixer.routeIndex
                    onCurrentIndexChanged: if (currentIndex >= 0)
                        positionViewAtIndex(currentIndex, ListView.Contain)
                    delegate: ShellAction {
                        required property int index
                        required property var modelData
                        width: ListView.view.width
                        height: 36
                        runtime: mixer.runtime
                        theme: mixer.theme
                        motion: mixer.motion
                        compact: true
                        horizontalCompact: true
                        title: (modelData === mixer.routedDevice ? "✓ " : "") + (modelData.description || modelData.name)
                        shortcut: index === mixer.routeIndex ? "↵" : ""
                        active: index === mixer.routeIndex
                        onActivated: mixer.selectRoute(index)
                    }
                }
                ShellText {
                    visible: mixer.routeError !== "" || mixer.pendingRoute !== ""
                    width: parent.width
                    runtime: mixer.runtime
                    theme: mixer.theme
                    color: mixer.routeError !== "" ? mixer.theme.warning : mixer.theme.textMuted
                    text: mixer.routeError || "Waiting for PipeWire routing"
                    wrapMode: Text.WordWrap
                }
            }

            Row {
                visible: !mixer.compact && mixer.balanceAvailable
                width: parent.width
                height: 40
                spacing: mixer.theme.spacing2
                ShellText {
                    width: 90
                    anchors.verticalCenter: parent.verticalCenter
                    runtime: mixer.runtime
                    theme: mixer.theme
                    text: Math.abs(mixer.balancePosition) < 0.01 ? "Balanced" : (mixer.balancePosition < 0 ? "Left " : "Right ") + Math.round(Math.abs(mixer.balancePosition) * 100) + "%"
                }
                ShellSlider {
                    id: balanceSlider
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(1, parent.width - 200 - balanceKeys.implicitWidth - parent.spacing * 3)
                    theme: mixer.theme
                    motion: mixer.motion
                    value: (mixer.balancePosition + 1) / 2
                    Accessible.name: "Stereo balance"
                    onValueRequested: value => mixer.system.setBalance(mixer.balanceNode, value * 2 - 1)
                }
                KeyHint {
                    id: balanceKeys
                    anchors.verticalCenter: parent.verticalCenter
                    runtime: mixer.runtime
                    theme: mixer.theme
                    shortcut: mixer.runtime.shellHint("AudioMixerContent.balanceLeft") + " / " + mixer.runtime.shellHint("AudioMixerContent.balanceRight")
                }
                ShellAction {
                    width: 110
                    height: 36
                    runtime: mixer.runtime
                    theme: mixer.theme
                    motion: mixer.motion
                    compact: true
                    horizontalCompact: true
                    title: "Centre"
                    shortcut: mixer.runtime.shellHint("AudioMixerContent.balanceReset")
                    onActivated: mixer.system.setBalance(mixer.balanceNode, 0)
                }
            }

            KeyHintStrip {
                id: mixerHints
                visible: !mixer.compact
                width: parent.width
                runtime: mixer.runtime
                theme: mixer.theme
                hints: [
                    {
                        shortcut: mixer.runtime.shellHint("AudioMixerContent.select"),
                        label: "Select"
                    },
                    {
                        shortcut: mixer.runtime.shellHint("AudioMixerContent.level"),
                        label: "Level"
                    }
                ]
            }
        }

        TileKeyHint {
            z: 1
            primary: false
            visible: mixer.compact && shortcut.length > 0
            shortcut: mixer.runtime.shellHint("AudioMixerContent.open")
            runtime: mixer.runtime
            theme: mixer.theme
            motion: mixer.motion
        }
    }
}

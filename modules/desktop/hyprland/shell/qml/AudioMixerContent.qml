pragma ComponentBehavior: Bound
import QtQuick

FocusScope {
    id: mixer

    required property SystemState system
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property bool compact: false
    property bool active: false
    property int selectedIndex: 0
    property var selectedNode: null
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
    readonly property bool deviceChooserOpen: outputDevice.chooserOpen || inputDevice.chooserOpen
    readonly property int selectedStreamIndex: selectedTarget?.kind === "stream" ? streams.indexOf(selectedTarget.node) : -1
    readonly property var selectedTarget: targets[Math.max(0, Math.min(selectedIndex, targets.length - 1))] || null

    signal closeRequested
    signal keyboardRequested
    signal expandRequested

    implicitWidth: compact ? 490 : 950
    implicitHeight: body.implicitHeight + (compact ? theme.spacing4 * 2 : theme.spacing2 * 2)
    visible: active
    focus: active && !compact

    function selectIndex(index: int): void {
        selectedIndex = Math.max(0, Math.min(index, Math.max(0, targets.length - 1)));
        const target = targets[selectedIndex];
        selectedNode = target?.node || null;
        selectedKind = target?.kind || "output";
    }

    onTargetsChanged: {
        const index = selectedNode ? targets.findIndex(target => target.node === selectedNode) : targets.findIndex(target => target.kind === selectedKind);
        selectIndex(index >= 0 ? index : 0);
    }

    onActiveChanged: {
        if (!active) {
            outputDevice.chooserOpen = false;
            inputDevice.chooserOpen = false;
            return;
        }
        selectIndex(selectedIndex);
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
        const target = targets.findIndex(candidate => candidate.kind === "stream" && candidate.node === node);
        if (target >= 0)
            selectIndex(target);
    }

    function moveAudioSelection(delta: int): void {
        if (targets.length)
            selectIndex((selectedIndex + delta + targets.length) % targets.length);
    }

    function adjustSelected(delta: real): void {
        const target = selectedTarget;
        if (target?.kind === "output")
            system.adjustVolume(delta);
        else if (target?.kind === "input")
            system.setMicrophoneVolume(system.microphoneVolume + delta);
        else if (target?.node)
            system.adjustStreamVolume(target.node, delta);
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
        if (target?.kind === "input" || target?.capture)
            inputDevice.toggleDeviceChooser();
        else
            outputDevice.toggleDeviceChooser();
    }

    function handleKey(key: int, modifiers: int): bool {
        if (!active)
            return false;
        const picker = outputDevice.chooserOpen ? outputDevice : inputDevice.chooserOpen ? inputDevice : null;
        if (picker) {
            if (key === Qt.Key_Escape || key === Qt.Key_Backspace || key === Qt.Key_D) {
                picker.chooserOpen = false;
            } else if (key === Qt.Key_J || key === Qt.Key_Down) {
                picker.moveDeviceSelection(1);
            } else if (key === Qt.Key_K || key === Qt.Key_Up) {
                picker.moveDeviceSelection(-1);
            } else if (key === Qt.Key_Return || key === Qt.Key_Enter) {
                picker.selectDevice(picker.chooserIndex);
            } else {
                return false;
            }
            return true;
        }
        if (key === Qt.Key_Escape && !compact)
            closeRequested();
        else if (key === Qt.Key_Up || key === Qt.Key_K || key === Qt.Key_Down || key === Qt.Key_J || (!compact && (key === Qt.Key_Tab || key === Qt.Key_Backtab))) {
            const backwards = key === Qt.Key_Up || key === Qt.Key_K || key === Qt.Key_Backtab || (key === Qt.Key_Tab && (modifiers & Qt.ShiftModifier));
            moveAudioSelection(backwards ? -1 : 1);
        } else if (!compact && (key === Qt.Key_U || key === Qt.Key_PageUp || key === Qt.Key_D || key === Qt.Key_PageDown)) {
            const rows = Math.max(1, Math.floor(list.height / (compact ? 72 : 106)));
            selectIndex(Math.max(0, Math.min(targets.length - 1, selectedIndex + ((key === Qt.Key_D || key === Qt.Key_PageDown) ? rows : -rows))));
        } else if (key === Qt.Key_Left || key === Qt.Key_H) {
            adjustSelected(-0.05);
        } else if (key === Qt.Key_Right || key === Qt.Key_L) {
            adjustSelected(0.05);
        } else if (key === Qt.Key_M || (!compact && (key === Qt.Key_Return || key === Qt.Key_Enter))) {
            toggleSelectedMute();
        } else if (key === Qt.Key_P) {
            toggleSelectedDeviceChooser();
        } else if (key === Qt.Key_X) {
            system.toggleMicrophoneMute();
        } else {
            return false;
        }
        return true;
    }

    ShellSurface {
        anchors.fill: parent
        visible: mixer.compact
        theme: mixer.theme
        motion: mixer.motion
        surfaceLayer: ShellSurface.Group
        cornerRadius: mixer.theme.radiusLarge
        fillColor: mixer.theme.groupBase
    }

    StateLayer {
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
        onActivated: mixer.expandRequested()
    }

    Column {
        id: body
        x: mixer.compact ? mixer.theme.spacing4 : mixer.theme.spacing2
        y: mixer.compact ? Math.max(mixer.theme.spacing4, (mixer.height - implicitHeight) / 2) : mixer.theme.spacing2
        width: Math.max(1, parent.width - (mixer.compact ? mixer.theme.spacing4 : mixer.theme.spacing2) * 2)
        spacing: mixer.theme.spacing3

        Item {
            width: parent.width
            height: 66
            visible: !mixer.compact

            DetailHero {
                width: Math.max(260, parent.width - mixerHints.width - mixer.theme.spacing2)
                height: parent.height
                runtime: mixer.runtime
                theme: mixer.theme
                motion: mixer.motion
                glyph: "♫"
                glyphColor: mixer.theme.roleColor("audio")
                eyebrow: "Audio / " + mixer.streams.length + (mixer.streams.length === 1 ? " active channel" : " active channels")
                title: "Audio mixer"
                detail: "Output, input and every application channel"
            }

            KeyHintStrip {
                id: mixerHints
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                width: Math.min(440, parent.width * 0.5)
                runtime: mixer.runtime
                theme: mixer.theme
                hints: [
                    {
                        shortcut: "J/K",
                        label: "Select"
                    },
                    {
                        shortcut: "H/L",
                        label: "Level"
                    }
                ]
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

        Row {
            width: parent.width
            visible: !mixer.compact
            height: visible ? 20 : 0
            spacing: mixer.theme.spacing2
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(1, parent.width - channelCount.implicitWidth - parent.spacing)
                text: mixer.compact ? "APPLICATION AUDIO" : "APPLICATION CHANNELS"
                color: mixer.theme.readableRoleColor("audio")
                font.family: mixer.runtime.fontMono
                font.pixelSize: mixer.theme.fontSize(10)
                font.weight: Font.DemiBold
                font.letterSpacing: 0.9
            }
            Text {
                id: channelCount
                anchors.verticalCenter: parent.verticalCenter
                text: mixer.system.audioApplicationStreams.length + " PLAY · " + mixer.system.audioCaptureStreams.length + " REC"
                color: mixer.theme.textMuted
                font.family: mixer.runtime.fontMono
                font.pixelSize: mixer.theme.fontSize(9)
            }
        }

        ListView {
            id: list
            width: parent.width
            height: !mixer.compact && mixer.streams.length > 0 ? Math.min(330, mixer.streams.length * 102 + 36) : 0
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
                height: (mixer.compact ? 72 : 102) + (sectionStart && !mixer.compact ? 18 : 0)

                Text {
                    visible: streamRow.sectionStart && !mixer.compact
                    height: visible ? 18 : 0
                    text: streamRow.capture ? "CAPTURE" : "PLAYBACK"
                    color: mixer.theme.readableRoleColor("audio")
                    font.family: mixer.runtime.fontMono
                    font.pixelSize: mixer.theme.fontSize(9)
                }

                ShellSurface {
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        topMargin: streamRow.sectionStart && !mixer.compact ? 18 : 0
                    }
                    height: mixer.compact ? 72 : 102
                    theme: mixer.theme
                    motion: mixer.motion
                    surfaceLayer: ShellSurface.Control
                    cornerRadius: mixer.theme.radiusMedium
                    fillColor: mixer.selectedStreamIndex === streamRow.index ? mixer.theme.expressiveSurfaceStrong : mixer.theme.expressiveSurface
                    borderColor: mixer.selectedStreamIndex === streamRow.index ? mixer.theme.roleColor("audio") : "transparent"
                    borderWidth: mixer.selectedStreamIndex === streamRow.index ? mixer.theme.borderFocus : 0

                    AudioStreamControl {
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
                font.family: mixer.runtime.fontMono
                font.pixelSize: mixer.theme.fontSize(11)
            }
        }
    }
}

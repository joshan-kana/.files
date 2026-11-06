pragma ComponentBehavior: Bound
import QtQuick

FocusScope {
    id: mixer

    required property SystemState system
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property bool active: false
    property int selectedIndex: 0
    property var selectedNode: null
    readonly property var streams: (system.audioApplicationStreams || []).concat(system.audioCaptureStreams || [])

    signal closeRequested
    signal keyboardRequested

    implicitWidth: 730
    implicitHeight: header.implicitHeight + theme.spacing4 * 2 + (streams.length > 0 ? 318 : 148) + footer.implicitHeight
    visible: active
    focus: active

    // A PipeWire node can move in the model while remaining the same active
    // stream. Keep keyboard focus attached to its object identity.
    function selectIndex(index: int): void {
        selectedIndex = Math.max(0, Math.min(index, Math.max(0, streams.length - 1)));
        selectedNode = streams[selectedIndex] || null;
    }

    onStreamsChanged: {
        const current = streams.indexOf(selectedNode);
        selectIndex(current >= 0 ? current : selectedIndex);
    }
    onActiveChanged: {
        if (active) {
            selectIndex(selectedIndex);
            Qt.callLater(() => {
                if (mixer.active)
                    mixer.keyboardRequested();
            });
        }
    }

    function focusKeyboard(): void {
        if (active)
            keyboardRequested();
    }

    function selectedStream(): var {
        return streams.length > 0 ? streams[Math.max(0, Math.min(selectedIndex, streams.length - 1))] : null;
    }

    function adjustSelected(delta: real): void {
        const stream = selectedStream();
        if (stream)
            system.adjustStreamVolume(stream, delta);
    }

    function toggleSelectedMute(): void {
        const stream = selectedStream();
        if (stream)
            system.toggleStreamMute(stream);
    }

    DetailHero {
        id: header
        width: parent.width
        runtime: mixer.runtime
        theme: mixer.theme
        motion: mixer.motion
        glyph: "♫"
        glyphColor: mixer.theme.roleColor("audio")
        eyebrow: "Audio / " + mixer.streams.length + (mixer.streams.length === 1 ? " active source" : " active sources")
        title: "Application mixer"
        detail: "Live per-channel signal, volume and mute"
    }

    ListView {
        id: list
        anchors {
            top: header.bottom
            right: parent.right
            bottom: footer.top
            left: parent.left
            topMargin: mixer.theme.spacing4
            bottomMargin: mixer.theme.spacing4
        }
        model: mixer.streams.length
        orientation: ListView.Vertical
        spacing: mixer.theme.spacing3
        clip: true
        currentIndex: mixer.selectedIndex
        boundsBehavior: Flickable.StopAtBounds
        onCurrentIndexChanged: {
            if (currentIndex >= 0)
                positionViewAtIndex(currentIndex, ListView.Contain);
        }

        // Only delegates in the visible viewport (and the small ListView
        // cache) create PipeWire peak monitors. Large stream sets stay bounded.
        delegate: Item {
            id: streamRow
            required property int index
            readonly property var stream: mixer.streams[index] || null
            readonly property bool chosen: index === mixer.selectedIndex
            readonly property bool inViewport: y + height > list.contentY && y < list.contentY + list.height
            readonly property bool capture: index >= mixer.system.audioApplicationStreams.length
            readonly property bool sectionStart: index === 0 || index === mixer.system.audioApplicationStreams.length

            width: list.width
            height: 92 + (sectionStart ? 26 : 0)

            Text {
                visible: streamRow.sectionStart
                anchors {
                    top: parent.top
                    left: parent.left
                }
                height: 23
                text: streamRow.capture ? "CAPTURE · " + mixer.system.audioCaptureStreams.length : "PLAYBACK · " + mixer.system.audioApplicationStreams.length
                color: mixer.theme.readableRoleColor("audio")
                font.family: mixer.runtime.fontMono
                font.pixelSize: mixer.theme.fontSize(10)
                font.weight: Font.DemiBold
            }

            ShellSurface {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    topMargin: streamRow.sectionStart ? 26 : 0
                }
                height: 92
                theme: mixer.theme
                motion: mixer.motion
                cornerRadius: theme.radiusMedium
                surfaceLayer: ShellSurface.Group
                fillColor: streamRow.chosen ? theme.expressiveSurfaceStrong : theme.expressiveSurface
                borderColor: streamRow.chosen ? theme.roleColor("audio") : "transparent"
                borderWidth: streamRow.chosen ? theme.borderFocus : 0

                AudioStreamControl {
                    anchors {
                        fill: parent
                        margins: mixer.theme.spacing3
                    }
                    system: mixer.system
                    runtime: mixer.runtime
                    theme: mixer.theme
                    motion: mixer.motion
                    stream: streamRow.stream
                    selected: streamRow.chosen
                    capture: streamRow.capture
                    monitoring: mixer.active && list.visible && streamRow.inViewport
                    onSelectedRequested: mixer.selectIndex(streamRow.index)
                }
            }
        }
    }

    ShellSurface {
        anchors.centerIn: list
        width: list.width
        height: 120
        visible: mixer.streams.length === 0
        theme: mixer.theme
        motion: mixer.motion
        surfaceLayer: ShellSurface.Group
        cornerRadius: mixer.theme.radiusLarge
        fillColor: mixer.theme.expressiveSurface

        Column {
            anchors.centerIn: parent
            spacing: mixer.theme.spacing2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰎆"
                color: mixer.theme.roleColor("audio")
                font.family: "Symbols Nerd Font"
                font.pixelSize: mixer.theme.fontSize(32)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No application audio streams"
                color: mixer.theme.textStrong
                font.family: mixer.runtime.fontMono
                font.pixelSize: mixer.theme.fontSize(13)
                font.weight: Font.DemiBold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Active applications appear here automatically"
                color: mixer.theme.textMuted
                font.family: mixer.runtime.fontMono
                font.pixelSize: mixer.theme.fontSize(10)
            }
        }
    }

    Text {
        anchors.centerIn: list
        visible: false
        text: "No applications playing audio"
        color: mixer.theme.textStrong
        font.family: mixer.runtime.fontMono
        font.pixelSize: mixer.theme.fontSize(11)
    }

    KeyHintStrip {
        id: footer
        width: parent.width
        anchors.bottom: parent.bottom
        runtime: mixer.runtime
        theme: mixer.theme
        hints: [
            {
                shortcut: "TAB · J/K",
                label: "Select"
            },
            {
                shortcut: "PGUP/PGDN",
                label: "Page"
            },
            {
                shortcut: "H/L · ARROWS",
                label: "Volume"
            },
            {
                shortcut: "ESC",
                label: "Back"
            }
        ]
    }

    // One keyboard owner per hub. The parent FocusScope forwards local keys
    // here rather than racing a nested FocusScope for layer-shell focus.
    function handleKey(key: int, modifiers: int): bool {
        if (!active)
            return false;
        if (key === Qt.Key_Escape) {
            closeRequested();
        } else if (key === Qt.Key_Up || key === Qt.Key_K || key === Qt.Key_Down || key === Qt.Key_J || key === Qt.Key_Tab || key === Qt.Key_Backtab) {
            const backwards = key === Qt.Key_Up || key === Qt.Key_K || key === Qt.Key_Backtab || (key === Qt.Key_Tab && (modifiers & Qt.ShiftModifier));
            selectIndex(Math.max(0, Math.min(Math.max(0, streams.length - 1), selectedIndex + (backwards ? -1 : 1))));
        } else if (key === Qt.Key_U || key === Qt.Key_PageUp || key === Qt.Key_D || key === Qt.Key_PageDown) {
            const rowHeight = list.currentItem ? list.currentItem.height + list.spacing : 92;
            const rows = Math.max(1, Math.floor(list.height / Math.max(1, rowHeight)));
            selectIndex(Math.max(0, Math.min(Math.max(0, streams.length - 1), selectedIndex + ((key === Qt.Key_D || key === Qt.Key_PageDown) ? rows : -rows))));
        } else if (key === Qt.Key_Left || key === Qt.Key_H) {
            adjustSelected(-0.05);
        } else if (key === Qt.Key_Right || key === Qt.Key_L) {
            adjustSelected(0.05);
        } else if (key === Qt.Key_M || key === Qt.Key_Return || key === Qt.Key_Enter) {
            toggleSelectedMute();
        } else {
            return false;
        }
        return true;
    }
}

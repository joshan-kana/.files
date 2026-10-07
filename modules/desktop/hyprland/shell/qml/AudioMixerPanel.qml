import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: panel

    required property QtObject system
    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion

    property bool open: false
    property bool closing: false
    property int selectedIndex: 0

    readonly property var streams: system.audioStreams || []

    visible: open || closing
    color: "transparent"
    focusable: open
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    WlrLayershell.namespace: "linux-desktop-audio-mixer"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Timer {
        id: closeTimer
        interval: motion.fast
        onTriggered: panel.closing = false
    }

    onStreamsChanged: {
        selectedIndex = Math.max(0, Math.min(selectedIndex, Math.max(0, streams.length - 1)));
    }

    function selectedStream(): var {
        if (streams.length === 0)
            return null;

        return streams[Math.max(0, Math.min(selectedIndex, streams.length - 1))];
    }

    function show(): void {
        closeTimer.stop();
        closing = false;
        selectedIndex = Math.max(0, Math.min(selectedIndex, Math.max(0, streams.length - 1)));
        open = true;
        keySink.forceActiveFocus();
    }

    function hide(): void {
        open = false;

        if (motion.fast === 0)
            closing = false;
        else {
            closing = true;
            closeTimer.restart();
        }
    }

    function toggle(): void {
        if (open)
            hide();
        else
            show();
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

    Rectangle {
        anchors.fill: parent
        color: theme.scrim
        opacity: panel.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: motion.fast
                easing.type: panel.open ? motion.enterType : motion.exitType
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: panel.hide()
        }
    }

    SquircleSurface {
        id: card

        width: Math.min(panel.width - 120, 760)
        height: {
            const visibleRows = Math.min(Math.max(panel.streams.length, 1), 5);
            const rowsHeight = visibleRows * 92 + Math.max(0, visibleRows - 1) * theme.spacing3;
            const desired = theme.spacing5 * 2 + header.implicitHeight + theme.spacing4 * 2 + rowsHeight + footer.implicitHeight;
            return Math.min(panel.height - 140, Math.max(280, desired));
        }
        anchors.centerIn: parent

        exponent: theme.squircleExponent
        cornerRadius: theme.radiusPanel
        fillColor: theme.panelFill
        borderColor: theme.panelBorder
        borderWidth: theme.borderThin

        scale: panel.open ? 1 : theme.panelClosedScale
        opacity: panel.open ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: motion.normal
                easing.type: motion.enterType
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: motion.fast
            }
        }

        Item {
            anchors.fill: parent
            anchors.margins: theme.spacing5

            Column {
                id: header
                width: parent.width
                spacing: theme.spacing1

                Text {
                    text: "Audio · " + panel.streams.length + (panel.streams.length === 1 ? " active source" : " active sources")
                    color: theme.accent
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(12)
                    font.weight: Font.Medium
                }

                Text {
                    text: "Application mixer"
                    color: theme.textStrong
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontPanelTitle
                    font.weight: Font.DemiBold
                }

                Text {
                    text: "Per-application volume and mute"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(9)
                }
            }

            ListView {
                id: list

                anchors {
                    top: header.bottom
                    right: parent.right
                    bottom: footer.top
                    left: parent.left
                    topMargin: theme.spacing4
                    bottomMargin: theme.spacing4
                }

                model: panel.streams
                spacing: theme.spacing3
                clip: true
                currentIndex: panel.selectedIndex
                boundsBehavior: Flickable.StopAtBounds

                delegate: SquircleSurface {
                    id: streamRow

                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    height: 92
                    exponent: theme.squircleExponent
                    cornerRadius: theme.radiusMedium
                    fillColor: index === panel.selectedIndex ? theme.focusFill : theme.background
                    borderColor: index === panel.selectedIndex ? theme.accent : theme.outline
                    borderWidth: index === panel.selectedIndex ? theme.borderFocus : theme.borderThin

                    MouseArea {
                        anchors.fill: parent
                        onClicked: panel.selectedIndex = streamRow.index
                    }

                    Item {
                        anchors.fill: parent
                        anchors.margins: theme.spacing4

                        Row {
                            anchors {
                                top: parent.top
                                right: parent.right
                                left: parent.left
                            }

                            Column {
                                width: parent.width - volumeLabel.width - theme.spacing4
                                spacing: 3

                                Text {
                                    width: parent.width
                                    text: system.streamDisplayName(modelData)
                                    color: modelData.audio && modelData.audio.muted ? theme.warning : theme.textStrong
                                    font.family: runtime.fontMono
                                    font.pixelSize: theme.fontSize(14)
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: system.streamTechnicalName(modelData)
                                    color: theme.textMuted
                                    opacity: 0.70
                                    font.family: runtime.fontMono
                                    font.pixelSize: theme.fontSize(9)
                                    elide: Text.ElideMiddle
                                }
                            }

                            Text {
                                id: volumeLabel
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.audio ? (modelData.audio.muted ? "MUTED" : Math.round(modelData.audio.volume * 100) + "%") : "—"
                                color: modelData.audio && modelData.audio.muted ? theme.warning : theme.accent
                                font.family: runtime.fontMono
                                font.pixelSize: theme.fontSize(11)
                                font.weight: Font.DemiBold
                            }
                        }

                        Rectangle {
                            anchors {
                                right: parent.right
                                bottom: parent.bottom
                                left: parent.left
                            }

                            height: 6
                            radius: height / 2
                            color: theme.surfaceRaised

                            Rectangle {
                                height: parent.height
                                radius: parent.radius
                                width: modelData.audio ? parent.width * Math.max(0, Math.min(1, modelData.audio.volume)) : 0
                                color: modelData.audio && modelData.audio.muted ? theme.warning : theme.accent

                                Behavior on width {
                                    NumberAnimation {
                                        duration: motion.fast
                                        easing.type: motion.enterType
                                    }
                                }
                            }
                        }
                    }
                }

                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            }

            Text {
                anchors.centerIn: list
                visible: panel.streams.length === 0
                text: "Nothing is playing"
                color: theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(11)
                font.letterSpacing: 1.1
            }

            Row {
                id: footer

                anchors {
                    right: parent.right
                    bottom: parent.bottom
                }
                spacing: theme.spacing4

                Text {
                    text: "↑↓  STREAM"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(9)
                    font.letterSpacing: 1
                }

                Text {
                    text: "←/→  VOLUME"
                    color: theme.accent
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(9)
                    font.letterSpacing: 1
                }

                Text {
                    text: "M  MUTE"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(9)
                    font.letterSpacing: 1
                }

                Text {
                    text: "ESC  CLOSE"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(9)
                    font.letterSpacing: 1
                }
            }

            FocusScope {
                id: keySink
                anchors.fill: parent
                focus: panel.open

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        panel.hide();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        panel.selectedIndex = Math.max(0, panel.selectedIndex - 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down) {
                        panel.selectedIndex = Math.min(panel.streams.length - 1, panel.selectedIndex + 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Left) {
                        panel.adjustSelected(-0.05);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right) {
                        panel.adjustSelected(0.05);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_M) {
                        panel.toggleSelectedMute();
                        event.accepted = true;
                    }
                }
            }
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: panel

    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion
    required property QtObject system
    required property QtObject brightness

    property bool open: false
    property bool closing: false

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

    WlrLayershell.namespace: "linux-desktop-system"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Timer {
        id: closeTimer
        interval: motion.fast
        onTriggered: panel.closing = false
    }

    function show(): void {
        closeTimer.stop();
        closing = false;
        open = true;
        keyboardFocus.forceActiveFocus();
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

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.48)
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
        width: Math.min(panel.width - 70, 500)
        height: brightness.supported ? 530 : 430

        anchors {
            top: parent.top
            right: parent.right
            topMargin: 82
            rightMargin: 24
        }

        exponent: theme.squircleExponent
        cornerRadius: 36
        fillColor: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.985)
        borderColor: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.38)
        borderWidth: 1

        scale: panel.open ? 1 : 0.96
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
                id: content
                width: parent.width
                spacing: theme.spacing4

                Text {
                    text: "SYSTEM // LIVE"
                    color: theme.accent
                    font.family: runtime.fontMono
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.8
                }

                Text {
                    text: "Control centre"
                    color: theme.textStrong
                    font.family: runtime.fontSans
                    font.pixelSize: 27
                    font.weight: Font.DemiBold
                }

                SquircleSurface {
                    width: parent.width
                    height: 112
                    exponent: theme.squircleExponent
                    cornerRadius: theme.radiusLarge
                    fillColor: theme.background
                    borderColor: theme.outline
                    borderWidth: 1

                    Item {
                        anchors.fill: parent
                        anchors.margins: theme.spacing4

                        Row {
                            anchors {
                                top: parent.top
                                left: parent.left
                                right: parent.right
                            }

                            Text {
                                text: system.muted ? "AUDIO // MUTED" : "AUDIO // " + system.volumePercent + "%"
                                color: system.muted ? theme.warning : theme.textStrong
                                font.family: runtime.fontMono
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }

                            Item {
                                width: parent.width - parent.children[0].width - sinkName.width
                                height: 1
                            }

                            Text {
                                id: sinkName
                                width: Math.min(220, implicitWidth)
                                text: system.audioAvailable && system.audioSink ? (system.audioSink.description || system.audioSink.name) : "NO SINK"
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                                color: theme.textMuted
                                font.family: runtime.fontMono
                                font.pixelSize: 9
                            }
                        }

                        Rectangle {
                            anchors {
                                right: parent.right
                                bottom: parent.bottom
                                left: parent.left
                            }
                            height: 7
                            radius: height / 2
                            color: theme.surfaceRaised

                            Rectangle {
                                height: parent.height
                                radius: parent.radius
                                width: parent.width * Math.max(0, Math.min(1, system.volume))
                                color: system.muted ? theme.warning : theme.accent

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

                SquircleSurface {
                    width: parent.width
                    height: 82
                    visible: brightness.supported
                    exponent: theme.squircleExponent
                    cornerRadius: theme.radiusLarge
                    fillColor: theme.background
                    borderColor: theme.outline
                    borderWidth: 1

                    Item {
                        anchors.fill: parent
                        anchors.margins: theme.spacing4

                        Row {
                            anchors {
                                top: parent.top
                                left: parent.left
                                right: parent.right
                            }

                            Text {
                                text: "DISPLAY // " + brightness.percent + "%"
                                color: theme.textStrong
                                font.family: runtime.fontMono
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }

                            Item {
                                width: parent.width - parent.children[0].width - brightnessDevice.width
                                height: 1
                            }

                            Text {
                                id: brightnessDevice
                                width: Math.min(220, implicitWidth)
                                text: brightness.device
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                                color: theme.textMuted
                                font.family: runtime.fontMono
                                font.pixelSize: 9
                            }
                        }

                        Rectangle {
                            anchors {
                                right: parent.right
                                bottom: parent.bottom
                                left: parent.left
                            }
                            height: 7
                            radius: height / 2
                            color: theme.surfaceRaised

                            Rectangle {
                                height: parent.height
                                radius: parent.radius
                                width: parent.width * brightness.percent / 100
                                color: theme.positive

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

                Row {
                    width: parent.width
                    spacing: theme.spacing3

                    Repeater {
                        model: [
                            {
                                label: "NETWORK",
                                value: system.networkConnected ? system.networkName : "OFFLINE",
                                active: system.networkConnected
                            },
                            {
                                label: "BLUETOOTH",
                                value: system.bluetoothEnabled ? system.bluetoothConnectedCount + " CONNECTED" : "OFF",
                                active: system.bluetoothEnabled
                            }
                        ]

                        delegate: SquircleSurface {
                            required property var modelData

                            width: (content.width - theme.spacing3) / 2
                            height: 92
                            exponent: theme.squircleExponent
                            cornerRadius: theme.radiusLarge
                            fillColor: theme.background
                            borderColor: modelData.active ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.30) : theme.outline
                            borderWidth: 1

                            Column {
                                anchors {
                                    fill: parent
                                    margins: theme.spacing4
                                }
                                spacing: theme.spacing2

                                Text {
                                    text: modelData.label
                                    color: modelData.active ? theme.accent : theme.textMuted
                                    font.family: runtime.fontMono
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 1.2
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.value
                                    elide: Text.ElideRight
                                    color: theme.text
                                    font.family: runtime.fontSans
                                    font.pixelSize: 13
                                }
                            }
                        }
                    }
                }

                SquircleSurface {
                    width: parent.width
                    height: 64
                    visible: system.batteryAvailable
                    exponent: theme.squircleExponent
                    cornerRadius: theme.radiusMedium
                    fillColor: theme.background
                    borderColor: theme.outline
                    borderWidth: 1

                    Row {
                        anchors {
                            fill: parent
                            leftMargin: theme.spacing4
                            rightMargin: theme.spacing4
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "BATTERY"
                            color: theme.textMuted
                            font.family: runtime.fontMono
                            font.pixelSize: 10
                            font.letterSpacing: 1.2
                        }

                        Item {
                            width: parent.width - parent.children[0].width - batteryValue.width
                            height: 1
                        }

                        Text {
                            id: batteryValue
                            anchors.verticalCenter: parent.verticalCenter
                            text: system.batteryPercent + "%"
                            color: system.batteryPercent <= 20 ? theme.warning : theme.textStrong
                            font.family: runtime.fontMono
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            Row {
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                }
                spacing: theme.spacing4

                Text {
                    text: "←/→  VOLUME"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }

                Text {
                    text: "M  MUTE"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }

                Text {
                    visible: brightness.supported
                    text: "↑/↓  BRIGHTNESS"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }

                Text {
                    text: "ESC  CLOSE"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }
            }

            FocusScope {
                id: keyboardFocus
                anchors.fill: parent
                focus: panel.open

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        panel.hide();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Left) {
                        system.adjustVolume(-0.05);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right) {
                        system.adjustVolume(0.05);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_M) {
                        system.toggleMute();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up && brightness.supported) {
                        brightness.adjust(5);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down && brightness.supported) {
                        brightness.adjust(-5);
                        event.accepted = true;
                    }
                }
            }
        }
    }
}

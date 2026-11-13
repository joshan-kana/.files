pragma ComponentBehavior: Bound
import QtQuick
import "FeedbackSemantics.js" as FeedbackSemantics

Item {
    id: content
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property SystemState system
    required property KeyboardState keyboard
    required property BrightnessState brightness
    required property RecordingState recording
    property string modeName: "Normal"
    signal refreshRequested
    signal closeRequested

    implicitWidth: Math.max(340, theme.controlsDetailWidth - theme.spacing4 * 2)
    implicitHeight: heading.implicitHeight + stateGrid.implicitHeight + footer.implicitHeight + theme.spacing4 * 4

    Column {
        anchors {
            fill: parent
            margins: content.theme.spacing4
        }
        spacing: content.theme.spacing4

        Row {
            id: heading
            width: parent.width
            spacing: content.theme.spacing3
            Text {
                text: "󰋽"
                color: content.theme.roleColor("connectivity")
                font.family: "Symbols Nerd Font"
                font.pixelSize: content.theme.fontSize(23)
            }
            Column {
                width: Math.max(1, heading.width - content.theme.fontSize(23) - 2 * 44 - heading.spacing * 3)
                spacing: content.theme.spacing1
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: "System status"
                    color: content.theme.textStrong
                    font.family: content.runtime.fontMono
                    font.pixelSize: content.theme.fontSize(18)
                    font.weight: Font.Bold
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: content.keyboard.pending ? "Reading keyboard state…" : content.keyboard.stale ? "Keyboard state unavailable or stale" : content.keyboard.deviceName + " · Current device and interaction state"
                    color: content.theme.textMuted
                    font.family: content.runtime.fontMono
                    font.pixelSize: content.theme.fontSize(10)
                }
            }
            ShellAction {
                width: 44
                height: 40
                anchors.verticalCenter: parent.verticalCenter
                runtime: content.runtime
                theme: content.theme
                motion: content.motion
                iconOnly: true
                icon: "󰑐"
                title: "Refresh current status"
                onActivated: content.refreshRequested()
            }
            ShellAction {
                width: 44
                height: 40
                anchors.verticalCenter: parent.verticalCenter
                runtime: content.runtime
                theme: content.theme
                motion: content.motion
                iconOnly: true
                icon: "󰅖"
                title: "Close status"
                onActivated: content.closeRequested()
            }
        }

        Grid {
            id: stateGrid
            width: parent.width
            columns: width > 430 ? 2 : 1
            columnSpacing: content.theme.spacing2
            rowSpacing: content.theme.spacing2
            readonly property real tileWidth: (width - (columns - 1) * columnSpacing) / columns
            Repeater {
                model: [
                    {
                        label: "Caps Lock",
                        glyph: FeedbackSemantics.symbol("keyboard", false, 0, content.keyboard.stale ? "unknown" : content.keyboard.capsState),
                        value: content.keyboard.stale ? "Stale" : content.keyboard.description(content.keyboard.capsState)
                    },
                    {
                        label: "Num Lock",
                        glyph: FeedbackSemantics.symbol("keyboard", false, 0, content.keyboard.stale ? "unknown" : content.keyboard.numState),
                        value: content.keyboard.stale ? "Stale" : content.keyboard.description(content.keyboard.numState)
                    },
                    {
                        label: "Keyboard layout",
                        glyph: "󰌌",
                        value: content.keyboard.stale ? "Stale" : content.keyboard.layoutName
                    },
                    {
                        label: "Microphone",
                        glyph: content.system.microphoneAvailable ? FeedbackSemantics.symbol("microphone", content.system.microphoneMuted, content.system.microphoneVolumePercent, "") : "󰀨",
                        value: content.system.microphoneAvailable ? content.system.microphoneMuted ? "Muted" : content.system.microphoneVolumePercent + "%" : "Unavailable"
                    },
                    {
                        label: "Output",
                        glyph: content.system.audioAvailable ? FeedbackSemantics.symbol("volume", content.system.muted, content.system.volumePercent, "") : "󰀨",
                        value: content.system.audioAvailable ? content.system.muted ? "Muted" : content.system.volumePercent + "%" : "Unavailable"
                    },
                    {
                        label: "Brightness",
                        glyph: "󰃟",
                        value: content.brightness.supported ? content.brightness.percent + "%" : "Unavailable"
                    },
                    {
                        label: "Interaction",
                        glyph: "󰍉",
                        value: content.modeName
                    },
                    {
                        label: "Shell recording",
                        glyph: FeedbackSemantics.symbol("recording", false, 0, ""),
                        value: content.recording.capturing ? "Recording" : content.recording.finalising ? "Finalising" : "Inactive"
                    }
                ]
                delegate: ShellSurface {
                    required property var modelData
                    width: stateGrid.tileWidth
                    height: content.theme.fontSize(53)
                    theme: content.theme
                    motion: content.motion
                    surfaceLayer: ShellSurface.Group
                    cornerRadius: content.theme.radiusSmall
                    fillColor: content.theme.expressiveSurface
                    borderWidth: content.theme.borderThin
                    borderColor: content.theme.subtleBorder
                    Accessible.role: Accessible.StaticText
                    Accessible.name: modelData.label + ": " + modelData.value
                    Row {
                        anchors.centerIn: parent
                        width: parent.width - content.theme.spacing3 * 2
                        spacing: content.theme.spacing2
                        Text {
                            text: modelData.glyph
                            width: content.theme.fontSize(23)
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: content.theme.fontSize(19)
                            color: content.theme.roleColor("connectivity")
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - content.theme.fontSize(23) - parent.spacing
                            spacing: content.theme.spacing1
                            Text {
                                width: parent.width
                                text: modelData.label
                                color: content.theme.textMuted
                                font.family: content.runtime.fontMono
                                font.pixelSize: content.theme.fontSize(10)
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: modelData.value
                                color: content.theme.textStrong
                                font.family: content.runtime.fontMono
                                font.pixelSize: content.theme.fontSize(12)
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }

        KeyHintStrip {
            id: footer
            width: parent.width
            runtime: content.runtime
            theme: content.theme
            hints: [
                {
                    shortcut: "R",
                    label: "Refresh"
                },
                {
                    shortcut: "ESC",
                    label: "Close"
                }
            ]
        }
    }
}

pragma ComponentBehavior: Bound
import QtQuick
import "DesktopIcons.js" as DesktopIcons
import Quickshell.Io
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

    readonly property var statusEntries: [
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
    property bool copied: false
    function triggerCopy(): void {
        copyAction.trigger();
    }
    function triggerRefresh(): void {
        refreshAction.trigger();
    }
    function copyStatus(): void {
        if (!runtime.copyText)
            return;
        if (!copyProcess.running)
            copyProcess.exec([runtime.copyText, statusEntries.map(entry => entry.label + ": " + entry.value).join("\n")]);
    }
    Process {
        id: copyProcess
        onExited: (code, status) => {
            content.copied = code === 0;
            copyFeedback.restart();
        }
    }
    Timer {
        id: copyFeedback
        interval: 1800
        onTriggered: content.copied = false
    }

    implicitWidth: Math.max(340, theme.controlsDetailWidth - theme.spacing4 * 2)
    implicitHeight: heading.implicitHeight + stateGrid.implicitHeight + theme.spacing4 * 3 + theme.spacing3 * 2

    Column {
        anchors {
            fill: parent
            margins: content.theme.spacing4
        }
        spacing: content.theme.spacing4

        DetailHero {
            id: heading
            width: parent.width
            runtime: content.runtime
            theme: content.theme
            motion: content.motion
            glyph: DesktopIcons.glyphFor("status")
            glyphFont: "Symbols Nerd Font"
            glyphColor: content.theme.roleColor(content.theme.capabilityRole("status"))
            title: "System status"
            detail: content.keyboard.pending ? "Reading keyboard state…" : content.keyboard.stale ? "Keyboard state unavailable or stale" : content.keyboard.deviceName + " · Current device and interaction state"
            actions: [
                ShellUtilityAction {
                    id: copyAction
                    runtime: content.runtime
                    theme: content.theme
                    motion: content.motion
                    shortcut: content.runtime.shellHint("StatusContent.copy")
                    icon: content.copied ? "󰄬" : "󰆏"
                    title: content.copied ? "Copied" : "Copy status"
                    enabled: !!content.runtime.copyText
                    onActivated: content.copyStatus()
                },
                ShellUtilityAction {
                    id: refreshAction
                    runtime: content.runtime
                    theme: content.theme
                    motion: content.motion
                    shortcut: content.runtime.shellHint("StatusContent.refresh")
                    icon: DesktopIcons.actionGlyph("refresh")
                    title: "Refresh current status"
                    onActivated: content.refreshRequested()
                }
            ]
        }

        ShellSurface {
            width: parent.width
            height: stateGrid.implicitHeight + content.theme.spacing3 * 2
            theme: content.theme
            motion: content.motion
            surfaceLayer: ShellSurface.Group
            cornerRadius: content.theme.radiusMedium
            Grid {
                id: stateGrid
                width: parent.width - content.theme.spacing3 * 2
                anchors.centerIn: parent
                columns: width > 430 ? 2 : 1
                columnSpacing: content.theme.spacing2
                rowSpacing: content.theme.spacing2
                readonly property real tileWidth: (width - (columns - 1) * columnSpacing) / columns
                Repeater {
                    model: content.statusEntries
                    delegate: ShellSurface {
                        id: statusTile
                        required property var modelData
                        width: stateGrid.tileWidth
                        height: Math.max(content.theme.fontSize(48), statusText.implicitHeight + content.theme.spacing2 * 2)
                        theme: content.theme
                        motion: content.motion
                        surfaceLayer: ShellSurface.Group
                        cornerRadius: content.theme.radiusSmall
                        fillColor: "transparent"
                        borderWidth: 0
                        Accessible.role: Accessible.StaticText
                        Accessible.name: statusTile.modelData.label + ": " + statusTile.modelData.value
                        Row {
                            anchors.centerIn: parent
                            width: parent.width - content.theme.spacing3 * 2
                            spacing: content.theme.spacing2
                            Text {
                                text: statusTile.modelData.glyph
                                width: content.theme.fontSize(23)
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: content.theme.fontSize(19)
                                color: content.theme.readableRoleColor(["Unavailable", "Stale"].includes(statusTile.modelData.value) ? "warning" : statusTile.modelData.value === "Recording" ? "critical" : statusTile.modelData.label === "Brightness" ? "daylight" : statusTile.modelData.label === "Output" || statusTile.modelData.label === "Microphone" ? "audio" : "connectivity")
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Column {
                                id: statusText
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - content.theme.fontSize(23) - parent.spacing
                                spacing: content.theme.spacing1
                                Text {
                                    width: parent.width
                                    text: statusTile.modelData.label
                                    color: content.theme.textMuted
                                    font.family: content.runtime.fontSans
                                    font.pixelSize: content.theme.fontSupporting
                                    wrapMode: Text.WordWrap
                                }
                                Text {
                                    width: parent.width
                                    text: statusTile.modelData.value
                                    color: content.theme.textStrong
                                    font.family: content.runtime.fontSans
                                    font.pixelSize: content.theme.fontAction
                                    font.weight: Font.DemiBold
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

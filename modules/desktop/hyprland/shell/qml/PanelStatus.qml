pragma ComponentBehavior: Bound
import QtQuick

// A stable, semantic operation slot shared by detail views. Status stays by
// the owning content header, while local key guides and global Back stay below.
Item {
    id: status

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property string message: ""
    property string detail: ""
    property string phase: "idle" // idle, busy, success, warning, error
    property bool cancellable: false
    property string cancelShortcut: ""
    property string cancelLabel: "Cancel"
    property string idleMessage: ""
    readonly property bool busy: phase === "busy"
    readonly property bool hasMessage: message.length > 0 || idleMessage.length > 0
    readonly property string symbol: phase === "busy" ? "󰔟" : phase === "success" ? "󰄬" : phase === "warning" ? "󰀨" : phase === "error" ? "󰅙" : "󰋽"
    readonly property color semanticColor: phase === "error" ? theme.readableRoleColor("critical") : phase === "warning" ? theme.readableRoleColor("warning") : phase === "success" ? theme.readableRoleColor("positive") : theme.textMuted

    signal cancelRequested

    implicitHeight: Math.max(42, theme.fontSize(12) + (detail.length > 0 && message.length > 0 ? theme.fontSize(10) : 0) + theme.spacing3)
    Accessible.role: Accessible.StatusBar
    Accessible.name: hasMessage ? (message || idleMessage) : ""

    ShellSurface {
        anchors.fill: parent
        theme: status.theme
        motion: status.motion
        surfaceLayer: ShellSurface.Group
        cornerRadius: status.theme.radiusSmall
        fillColor: status.theme.expressiveSurface
        fillOpacity: status.hasMessage ? (status.theme.shellGlassEnabled ? status.theme.glassOpacity : 1) : 0
        borderWidth: status.hasMessage ? status.theme.borderThin : 0
        borderColor: status.theme.subtleBorder
    }

    Row {
        anchors {
            fill: parent
            leftMargin: status.theme.spacing3
            rightMargin: status.theme.spacing2
        }
        spacing: status.theme.spacing2
        visible: status.hasMessage

        Text {
            id: phaseIcon
            anchors.verticalCenter: parent.verticalCenter
            width: status.theme.fontSize(18)
            text: status.symbol
            horizontalAlignment: Text.AlignHCenter
            font.family: "Symbols Nerd Font"
            font.pixelSize: status.theme.fontSize(17)
            color: status.semanticColor

            NumberAnimation on rotation {
                running: status.busy && status.motion.enabled
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 1100
                onRunningChanged: {
                    if (!running)
                        phaseIcon.rotation = 0;
                }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(1, parent.width - phaseIcon.width - cancelAction.width - (cancelAction.visible ? parent.spacing : 0) - parent.spacing)
            spacing: status.theme.spacing1

            Text {
                width: parent.width
                text: status.message.length > 0 ? status.message : status.idleMessage
                elide: Text.ElideRight
                textFormat: Text.PlainText
                color: status.phase === "idle" ? status.theme.textMuted : status.semanticColor
                font.family: status.runtime.fontMono
                font.pixelSize: status.theme.fontSize(11)
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                visible: status.message.length > 0 && status.detail.length > 0
                text: status.detail
                elide: Text.ElideLeft
                textFormat: Text.PlainText
                color: status.theme.textMuted
                font.family: status.runtime.fontMono
                font.pixelSize: status.theme.fontSize(9)
            }
        }

        ShellAction {
            id: cancelAction
            anchors.verticalCenter: parent.verticalCenter
            visible: status.cancellable
            width: visible ? Math.max(110, status.theme.fontSize(86)) : 0
            height: 34
            compact: true
            horizontalCompact: true
            runtime: status.runtime
            theme: status.theme
            motion: status.motion
            icon: "󰜺"
            title: status.cancelLabel
            shortcut: status.cancelShortcut
            onActivated: status.cancelRequested()
        }
    }
}

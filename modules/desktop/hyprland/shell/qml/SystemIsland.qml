import QtQuick

Item {
    id: island

    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion
    required property QtObject system

    signal activated

    implicitWidth: statusRow.implicitWidth + theme.spacing4 * 2
    implicitHeight: 40

    ShellSurface {
        anchors.fill: parent

        theme: island.theme
        motion: island.motion
        surfaceLayer: ShellSurface.Pane
        cornerRadius: theme.radiusMedium

        Row {
            id: statusRow

            anchors.centerIn: parent
            spacing: theme.spacing2

            Row {
                id: volumeStatus
                spacing: theme.spacing1
                height: Math.max(volumeIcon.implicitHeight, volumeValue.implicitHeight)

                Text {
                    id: volumeIcon
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    text: system.muted ? "󰖁" : "󰕾"
                    color: system.muted ? theme.warning : theme.accent
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(12)
                }

                Text {
                    id: volumeValue
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    text: system.muted ? "Muted" : system.volumePercent + "%"
                    color: system.muted ? theme.warning : theme.text
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(11)
                    font.weight: Font.DemiBold
                }
            }

            Text {
                width: 108
                text: system.networkConnected ? system.networkName : "Offline"
                elide: Text.ElideRight
                color: system.networkConnected ? theme.text : theme.critical
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(11)
            }

            Row {
                id: bluetoothStatus
                visible: system.bluetoothEnabled
                spacing: theme.spacing1
                height: Math.max(bluetoothIcon.implicitHeight, bluetoothValue.implicitHeight)

                Text {
                    id: bluetoothIcon
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    text: "󰂯"
                    color: system.bluetoothConnectedCount > 0 ? theme.accent : theme.text
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(11)
                }

                Text {
                    id: bluetoothValue
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    visible: system.bluetoothConnectedCount > 0
                    text: system.bluetoothConnectedCount
                    color: theme.text
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(11)
                }
            }

            Row {
                id: batteryStatus
                visible: system.batteryAvailable
                spacing: theme.spacing1
                height: Math.max(batteryIcon.implicitHeight, batteryValue.implicitHeight)

                Text {
                    id: batteryIcon
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    text: "󰁹"
                    color: system.batteryPercent <= 20 ? theme.warning : theme.accent
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(12)
                }

                Text {
                    id: batteryValue
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    text: system.batteryPercent + "%"
                    color: system.batteryPercent <= 20 ? theme.warning : theme.text
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(11)
                    font.weight: Font.DemiBold
                }
            }
        }

        StateLayer {
            theme: island.theme
            motion: island.motion
            onActivated: island.activated()
        }
    }
}

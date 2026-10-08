import QtQuick

Item {
    id: island

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property SystemState system

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
            spacing: island.theme.spacing2

            Row {
                id: volumeStatus
                spacing: island.theme.spacing1
                height: Math.max(volumeIcon.implicitHeight, volumeValue.implicitHeight)

                Text {
                    id: volumeIcon
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    text: island.system.muted ? "󰖁" : "󰕾"
                    color: island.system.muted ? island.theme.warning : island.theme.accent
                    font.family: island.runtime.fontMono
                    font.pixelSize: island.theme.fontSize(12)
                }

                Text {
                    id: volumeValue
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    text: island.system.muted ? "Muted" : island.system.volumePercent + "%"
                    color: island.system.muted ? island.theme.warning : island.theme.text
                    font.family: island.runtime.fontMono
                    font.pixelSize: island.theme.fontSize(11)
                    font.weight: Font.DemiBold
                }
            }

            Text {
                width: 108
                text: island.system.networkConnected ? island.system.networkName : "Offline"
                elide: Text.ElideRight
                color: island.system.networkConnected ? island.theme.text : island.theme.critical
                font.family: island.runtime.fontMono
                font.pixelSize: island.theme.fontSize(11)
            }

            Row {
                id: bluetoothStatus
                visible: island.system.bluetoothEnabled
                spacing: island.theme.spacing1
                height: Math.max(bluetoothIcon.implicitHeight, bluetoothValue.implicitHeight)

                Text {
                    id: bluetoothIcon
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    text: "󰂯"
                    color: island.system.bluetoothConnectedCount > 0 ? island.theme.accent : island.theme.text
                    font.family: island.runtime.fontMono
                    font.pixelSize: island.theme.fontSize(11)
                }

                Text {
                    id: bluetoothValue
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    visible: island.system.bluetoothConnectedCount > 0
                    text: island.system.bluetoothConnectedCount
                    color: island.theme.text
                    font.family: island.runtime.fontMono
                    font.pixelSize: island.theme.fontSize(11)
                }
            }

            Row {
                id: batteryStatus
                visible: island.system.batteryAvailable
                spacing: island.theme.spacing1
                height: Math.max(batteryIcon.implicitHeight, batteryValue.implicitHeight)

                Text {
                    id: batteryIcon
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    text: "󰁹"
                    color: island.system.batteryPercent <= 20 ? island.theme.warning : island.theme.accent
                    font.family: island.runtime.fontMono
                    font.pixelSize: island.theme.fontSize(12)
                }

                Text {
                    id: batteryValue
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    text: island.system.batteryPercent + "%"
                    color: island.system.batteryPercent <= 20 ? island.theme.warning : island.theme.text
                    font.family: island.runtime.fontMono
                    font.pixelSize: island.theme.fontSize(11)
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

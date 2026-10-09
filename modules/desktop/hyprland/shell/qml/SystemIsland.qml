pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: island

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property SystemState system

    signal activated
    signal trayMenuRequested(int index)

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
            z: 1
            anchors.centerIn: parent
            spacing: island.theme.spacing3

            ResourceGauge {
                id: volumeStatus
                width: 30
                height: 30
                anchors.verticalCenter: parent.verticalCenter
                theme: island.theme
                motion: island.motion
                compact: true
                value: island.system.volume
                accentColor: island.system.muted ? island.theme.warning : island.theme.accent
                compactIcon: island.system.muted ? "󰖁" : island.system.volumePercent < 35 ? "󰕿" : "󰕾"
            }

            Text {
                visible: island.system.idleInhibited
                anchors.verticalCenter: parent.verticalCenter
                text: "󰅶"
                color: island.theme.positive
                font.family: "Symbols Nerd Font"
                font.pixelSize: island.theme.fontSize(15)
            }

            // end-4's contextual muted-input indicator, sharing the same PipeWire state.
            Text {
                visible: island.system.microphoneMuted
                anchors.verticalCenter: parent.verticalCenter
                text: "󰍭"
                color: island.theme.warning
                font.family: "Symbols Nerd Font"
                font.pixelSize: island.theme.fontSize(16)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: island.system.networkConnected ? (island.system.wifiConnected ? "󰤨" : "󰈀") : "󰖪"
                color: island.system.networkConnected ? island.theme.accent : island.theme.critical
                font.family: "Symbols Nerd Font"
                font.pixelSize: island.theme.fontSize(17)
            }

            Row {
                visible: island.system.bluetoothAvailable
                anchors.verticalCenter: parent.verticalCenter
                spacing: island.theme.spacing1

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: island.system.bluetoothEnabled ? "󰂯" : "󰂲"
                    color: island.system.bluetoothConnectedCount > 0 ? island.theme.accent : island.theme.textMuted
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: island.theme.fontSize(15)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: island.system.bluetoothConnectedCount > 0
                    text: island.system.bluetoothConnectedCount
                    color: island.theme.textStrong
                    font.family: island.runtime.fontMono
                    font.pixelSize: island.theme.fontSize(10)
                }
            }

            ResourceGauge {
                visible: island.system.batteryAvailable
                width: 30
                height: 30
                anchors.verticalCenter: parent.verticalCenter
                theme: island.theme
                motion: island.motion
                compact: true
                value: island.system.batteryPercent / 100
                accentColor: island.system.batteryPercent <= 20 ? island.theme.warning : island.theme.accent
                compactIcon: island.system.batteryPercent <= 20 ? "󰁺" : island.system.batteryPercent < 65 ? "󰁾" : "󰁹"
            }
        }

        StateLayer {
            theme: island.theme
            motion: island.motion
            cornerRadius: island.theme.radiusMedium
            onActivated: island.activated()
            onWheel: event => {
                if (event.angleDelta.y !== 0 && island.system.audioAvailable) {
                    island.system.adjustVolume((event.angleDelta.y > 0 ? 1 : -1) * 0.05);
                    event.accepted = true;
                }
            }
        }
    }
}

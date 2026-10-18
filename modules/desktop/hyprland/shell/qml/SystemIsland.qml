pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: island

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property SystemState system
    required property PowerProfileState powerProfile
    property bool compact: false

    signal activated
    signal trayMenuRequested(int index)

    implicitWidth: statusRow.implicitWidth + theme.spacing4 * 2
    implicitHeight: 50

    ShellSurface {
        anchors.fill: parent
        theme: island.theme
        motion: island.motion
        surfaceLayer: ShellSurface.Pane
        cornerRadius: theme.radiusIsland
        exponent: Math.min(4, theme.squircleExponent)
        elevated: true
        outlined: true
        fillColor: theme.paneBase

        Row {
            id: statusRow
            z: 1
            anchors {
                left: parent.left
                leftMargin: island.theme.spacing4
                verticalCenter: parent.verticalCenter
            }
            height: 38
            spacing: island.compact ? island.theme.spacing1 : island.theme.spacing3

            // Contextual statuses belong to this single background surface.
            Text {
                visible: !island.compact && island.system.idleInhibited
                anchors.verticalCenter: parent.verticalCenter
                text: "󰅶"
                color: island.theme.positive
                font.family: "Symbols Nerd Font"
                font.pixelSize: island.theme.fontSize(20)
            }

            Text {
                visible: !island.compact && island.system.microphoneMuted
                anchors.verticalCenter: parent.verticalCenter
                text: "󰍭"
                color: island.theme.warning
                font.family: "Symbols Nerd Font"
                font.pixelSize: island.theme.fontSize(16)
            }

            ResourceGauge {
                id: volumeStatus
                compactRingTuning: true
                visible: !island.compact
                width: 38
                height: 38
                anchors.verticalCenter: parent.verticalCenter
                theme: island.theme
                motion: island.motion
                compact: true
                value: island.system.volume
                accentColor: island.system.muted ? island.theme.warning : island.theme.roleColor("media")
                compactIconSize: 20
                compactIconOffsetX: 0
                compactIconOffsetY: -2
                compactIcon: island.system.muted ? "󰖁" : island.system.volumePercent < 35 ? "󰕿" : "󰕾"
            }

            Text {
                width: 38
                height: 38
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: island.system.networkConnected ? (island.system.wifiConnected ? "󰤨" : "󰈀") : "󰖪"
                color: island.system.networkConnected ? island.theme.roleColor("connectivity") : island.theme.critical
                font.family: "Symbols Nerd Font"
                font.pixelSize: island.theme.fontSize(24)
            }

            Row {
                visible: !island.compact && island.system.bluetoothAvailable
                anchors.verticalCenter: parent.verticalCenter
                spacing: island.theme.spacing1

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: island.system.bluetoothEnabled ? "󰂯" : "󰂲"
                    color: island.system.bluetoothConnectedCount > 0 ? island.theme.roleColor("connectivity") : island.theme.textMuted
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
                visible: !island.compact && island.system.batteryAvailable
                width: 38
                height: 38
                anchors.verticalCenter: parent.verticalCenter
                theme: island.theme
                motion: island.motion
                compact: true
                value: island.system.batteryPercent / 100
                accentColor: island.powerProfile.current === "power-saver" || island.system.batteryPercent <= 20 ? island.theme.warning : island.theme.accent
                compactIconSize: 20
                compactIcon: island.system.batteryPercent <= 20 ? "󰁺" : island.system.batteryPercent < 65 ? "󰁾" : "󰁹"
            }
            Text {
                visible: !island.compact
                width: 24
                height: 38
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "󰅀"
                color: island.theme.textMuted
                font.family: "Symbols Nerd Font"
                font.pixelSize: island.theme.fontSize(20)
            }
        }

        StateLayer {
            id: statusPress
            theme: island.theme
            motion: island.motion
            cornerRadius: island.theme.radiusIsland
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

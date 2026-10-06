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

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: island.activated()
    }

    SquircleSurface {
        anchors.fill: parent

        exponent: theme.squircleExponent
        cornerRadius: theme.radiusMedium
        fillColor: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.92)
        borderColor: theme.subtleBorder
        borderWidth: theme.borderThin

        Row {
            id: statusRow

            anchors.centerIn: parent
            spacing: theme.spacing2

            Text {
                text: system.muted ? "Muted" : system.volumePercent + "%"
                color: system.muted ? theme.warning : theme.text
                font.family: runtime.fontSans
                font.pixelSize: theme.fontSize(11)
                font.weight: Font.DemiBold
            }

            Text {
                text: "•"
                color: theme.outline
                font.family: runtime.fontSans
                font.pixelSize: theme.fontSize(10)
            }

            Text {
                width: 108
                text: system.networkConnected ? system.networkName : "Offline"
                elide: Text.ElideRight
                color: system.networkConnected ? theme.text : theme.critical
                font.family: runtime.fontSans
                font.pixelSize: theme.fontSize(11)
            }

            Text {
                visible: system.bluetoothEnabled
                text: "•  BT" + (system.bluetoothConnectedCount > 0 ? " " + system.bluetoothConnectedCount : "")
                color: system.bluetoothConnectedCount > 0 ? theme.text : theme.textMuted
                font.family: runtime.fontSans
                font.pixelSize: theme.fontSize(11)
            }

            Text {
                visible: system.batteryAvailable
                text: "•  " + system.batteryPercent + "%"
                color: system.batteryPercent <= 20 ? theme.warning : theme.textMuted
                font.family: runtime.fontSans
                font.pixelSize: theme.fontSize(11)
            }

            Text {
                visible: system.trayCount > 0
                text: "•••"
                color: theme.textMuted
                font.family: runtime.fontSans
                font.pixelSize: theme.fontSize(10)
                font.weight: Font.Bold
            }
        }
    }
}

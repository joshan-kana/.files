import QtQuick

Item {
    id: island

    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion
    required property QtObject system

    signal activated()

    implicitWidth: system.trayCount > 0 ? 440 : 382
    implicitHeight: 44

    MouseArea {
        anchors.fill: parent
        onClicked: island.activated()
    }

    SquircleSurface {
        anchors.fill: parent

        exponent: theme.squircleExponent
        cornerRadius: theme.radiusMedium
        fillColor: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.94)
        borderColor: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.76)
        borderWidth: theme.borderThin

        Row {
            anchors {
                fill: parent
                leftMargin: theme.spacing4
                rightMargin: theme.spacing4
            }
            spacing: theme.spacing3

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "SYS"
                color: theme.accent
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(11)
                font.weight: Font.Bold
                font.letterSpacing: 1.4
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 20
                color: theme.outline
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (system.muted ? "MUTE" : "VOL " + system.volumePercent)
                color: system.muted ? theme.warning : theme.text
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(10)
                font.weight: Font.DemiBold
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "//"
                color: theme.outline
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(10)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 116
                text: system.networkConnected ? system.networkName : "NET OFF"
                elide: Text.ElideRight
                color: system.networkConnected ? theme.text : theme.critical
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(10)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: system.bluetoothEnabled ? "BT " + system.bluetoothConnectedCount : "BT OFF"
                color: system.bluetoothEnabled ? theme.textMuted : theme.critical
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(10)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: system.batteryAvailable
                text: "BAT " + system.batteryPercent
                color: system.batteryPercent <= 20 ? theme.warning : theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(10)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: system.trayCount > 0
                text: "TRAY " + system.trayCount
                color: theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(10)
            }
        }
    }
}

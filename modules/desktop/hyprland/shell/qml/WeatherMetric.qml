import QtQuick

ShellSurface {
    id: metric

    property string icon: ""
    property string title: ""
    property string value: ""

    implicitWidth: 178
    implicitHeight: 72
    surfaceLayer: ShellSurface.Control
    cornerRadius: theme.radiusMedium

    Row {
        anchors.centerIn: parent
        spacing: metric.theme.spacing2

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: metric.icon
            color: metric.theme.roleColor("weather")
            font.family: "Symbols Nerd Font"
            font.pixelSize: metric.theme.fontSize(24)
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: metric.theme.spacing1

            Text {
                text: metric.title.toUpperCase()
                color: metric.theme.textMuted
                font.family: metric.theme.runtime.fontMono
                font.pixelSize: metric.theme.fontSize(10)
                font.weight: Font.DemiBold
            }

            Text {
                text: metric.value
                color: metric.theme.textStrong
                font.family: metric.theme.runtime.fontMono
                font.pixelSize: metric.theme.fontSize(15)
                font.weight: Font.DemiBold
            }
        }
    }
}

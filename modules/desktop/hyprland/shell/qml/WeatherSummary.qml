pragma ComponentBehavior: Bound
import QtQuick

ShellSurface {
    id: summary

    required property WeatherState weather
    signal forecastRequested

    implicitHeight: 102
    surfaceLayer: ShellSurface.Control
    cornerRadius: theme.radiusMedium

    Row {
        anchors {
            fill: parent
            leftMargin: summary.theme.spacing3
            rightMargin: summary.theme.spacing3
        }
        spacing: summary.theme.spacing3

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: summary.weather.icon
            color: summary.theme.accent
            font.family: "Symbols Nerd Font"
            font.pixelSize: summary.theme.fontSize(42)
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - 104)
            spacing: summary.theme.spacing1

            Text {
                text: summary.weather.available ? summary.weather.temperatureText(summary.weather.temperature) + "  " + summary.weather.description : summary.weather.status
                color: summary.theme.textStrong
                font.family: summary.theme.runtime.fontMono
                font.pixelSize: summary.theme.fontSize(15)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                text: summary.weather.city || "Your location"
                color: summary.theme.textMuted
                font.family: summary.theme.runtime.fontMono
                font.pixelSize: summary.theme.fontSize(11)
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                text: "F · FORECAST  ↗"
                color: summary.theme.accent
                font.family: summary.theme.runtime.fontMono
                font.pixelSize: summary.theme.fontSize(11)
                font.weight: Font.DemiBold
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: summary.forecastRequested()
    }
}

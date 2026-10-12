pragma ComponentBehavior: Bound
import QtQuick

ShellSurface {
    id: summary

    required property WeatherState weather
    signal forecastRequested

    implicitHeight: 160
    surfaceLayer: ShellSurface.Group
    luminous: true
    luminousColor: theme.accent
    fillColor: Qt.tint(theme.surfaceRaised, Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.15))
    cornerRadius: theme.radiusMedium

    Column {
        anchors {
            fill: parent
            margins: summary.theme.spacing4
        }
        spacing: summary.theme.spacing1

        Text {
            text: (summary.weather.city || "YOUR LOCATION").toUpperCase() + " · WEATHER"
            color: summary.theme.accent
            font.family: summary.theme.runtime.fontMono
            font.pixelSize: summary.theme.fontPanelEyebrow
            font.weight: Font.DemiBold
        }

        Row {
            width: parent.width
            height: 82
            spacing: summary.theme.spacing4

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: summary.weather.available ? summary.weather.temperatureText(summary.weather.temperature) : "--°"
                color: summary.theme.textStrong
                font.family: summary.theme.runtime.fontMono
                font.pixelSize: summary.theme.fontSize(42)
                font.weight: Font.DemiBold
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: summary.weather.icon
                color: summary.theme.accent
                font.family: "Symbols Nerd Font"
                font.pixelSize: summary.theme.fontSize(48)
            }
        }

        Text {
            width: parent.width
            text: (summary.weather.available ? summary.weather.description : summary.weather.status) + "  ·  F Forecast ↗"
            color: summary.theme.text
            font.family: summary.theme.runtime.fontMono
            font.pixelSize: summary.theme.fontSize(11)
            elide: Text.ElideRight
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: summary.forecastRequested()
    }
}

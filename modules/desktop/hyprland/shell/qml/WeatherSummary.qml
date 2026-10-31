pragma ComponentBehavior: Bound
import QtQuick

ShellSurface {
    id: summary

    required property WeatherState weather
    signal forecastRequested

    implicitHeight: theme.textScale >= 1.5 ? 238 : 202
    surfaceLayer: ShellSurface.Group
    luminous: false
    fillColor: theme.blend(theme.materialTertiaryContainer, theme.roleColor("weather"), theme.dark ? 0.13 : 0.09)
    cornerRadius: theme.radiusLarge
    clip: true

    Text {
        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: summary.theme.spacing1
            bottomMargin: -summary.theme.spacing4
        }
        text: summary.weather.icon
        font.family: "Symbols Nerd Font"
        font.pixelSize: summary.theme.fontSize(124)
        color: summary.theme.roleColor("weather")
        opacity: 0.19
    }

    Column {
        anchors {
            fill: parent
            margins: summary.theme.spacing4
        }
        spacing: summary.theme.spacing3

        Text {
            width: parent.width
            text: (summary.weather.city || "YOUR LOCATION").toUpperCase() + " · WEATHER"
            color: summary.theme.readableRoleColor("weather")
            opacity: 0.89
            font.family: summary.theme.runtime.fontMono
            font.pixelSize: summary.theme.fontPanelEyebrow
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            text: summary.weather.available ? summary.weather.temperatureText(summary.weather.temperature) : "--°"
            color: summary.theme.textStrong
            font.family: summary.theme.runtime.fontMono
            font.pixelSize: summary.theme.fontSize(68)
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            text: summary.weather.available ? summary.weather.description + "  ·  F Forecast ↗" : summary.weather.status + "  ·  F Forecast ↗"
            color: summary.theme.textStrong
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

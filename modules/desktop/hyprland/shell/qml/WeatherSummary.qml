pragma ComponentBehavior: Bound
import QtQuick

ShellSurface {
    id: summary

    required property WeatherState weather
    signal forecastRequested

    implicitHeight: theme.textScale >= 1.5 ? 238 : 202
    surfaceLayer: ShellSurface.Group
    luminous: true
    luminousColor: theme.textStrong
    lightIntensity: 1.35
    fillColor: Qt.tint(theme.surfaceRaised, Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.66))
    cornerRadius: theme.radiusLarge

    Text {
        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: -summary.theme.spacing3
            bottomMargin: -summary.theme.spacing5
        }
        text: summary.weather.icon
        font.family: "Symbols Nerd Font"
        font.pixelSize: summary.theme.fontSize(139)
        color: summary.theme.background
        opacity: 0.22
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
            color: summary.theme.background
            opacity: 0.82
            font.family: summary.theme.runtime.fontMono
            font.pixelSize: summary.theme.fontPanelEyebrow
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            text: summary.weather.available ? summary.weather.temperatureText(summary.weather.temperature) : "--°"
            color: summary.theme.background
            font.family: summary.theme.runtime.fontMono
            font.pixelSize: summary.theme.fontSize(68)
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            text: summary.weather.available ? summary.weather.description + "  ·  F Forecast ↗" : summary.weather.status + "  ·  F Forecast ↗"
            color: summary.theme.background
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

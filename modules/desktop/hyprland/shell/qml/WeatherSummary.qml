pragma ComponentBehavior: Bound
import QtQuick

ShellSurface {
    id: summary

    required property WeatherState weather
    signal forecastRequested

    implicitHeight: theme.textScale >= 1.5 ? 238 : 202
    surfaceLayer: ShellSurface.Group
    luminous: true
    hovered: forecastHit.pointerHovered || forecastHit.activeFocus
    luminousColor: theme.textStrong
    lightIntensity: 1.35
    fillColor: theme.blend(theme.groupBase, theme.roleColor("weather"), theme.dark ? 0.15 : 0.08)
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

        Row {
            width: parent.width
            spacing: summary.theme.spacing2

            Text {
                width: Math.max(1, parent.width - forecastHint.width - parent.spacing)
                anchors.verticalCenter: parent.verticalCenter
                text: (summary.weather.city || "YOUR LOCATION").toUpperCase() + " · WEATHER"
                color: summary.theme.readableRoleColor("weather")
                opacity: 0.89
                font.family: summary.theme.runtime.fontMono
                font.pixelSize: summary.theme.fontPanelEyebrow
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            KeyHint {
                id: forecastHint
                anchors.verticalCenter: parent.verticalCenter
                runtime: summary.theme.runtime
                theme: summary.theme
                compact: true
                shortcut: "F"
                label: "Forecast"
            }
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
            text: summary.weather.available ? summary.weather.description : summary.weather.status
            color: summary.theme.textStrong
            font.family: summary.theme.runtime.fontMono
            font.pixelSize: summary.theme.fontSize(11)
            elide: Text.ElideRight
        }
    }

    StateLayer {
        id: forecastHit
        theme: summary.theme
        motion: summary.motion
        keyboardFocusable: true
        cornerRadius: summary.cornerRadius
        stateColor: summary.theme.roleColor("weather")
        Accessible.role: Accessible.Button
        Accessible.name: "Open detailed weather forecast"
        Accessible.onPressAction: summary.forecastRequested()
        onActivated: summary.forecastRequested()
    }
}

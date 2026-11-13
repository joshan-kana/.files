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

    MouseArea {
        id: forecastHit
        anchors.fill: parent
        activeFocusOnTab: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: "Open detailed weather forecast"
        Accessible.onPressAction: summary.forecastRequested()
        onClicked: summary.forecastRequested()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                summary.forecastRequested();
                event.accepted = true;
            }
        }
    }

    SquircleSurface {
        anchors.fill: parent
        visible: forecastHit.activeFocus
        cornerRadius: summary.cornerRadius
        exponent: summary.theme.squircleExponent
        fillColor: "transparent"
        borderColor: summary.theme.accent
        borderWidth: summary.theme.borderFocus
    }
}

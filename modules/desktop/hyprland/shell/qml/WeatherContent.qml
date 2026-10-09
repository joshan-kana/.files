pragma ComponentBehavior: Bound
import QtQuick

FocusScope {
    id: panel

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property WeatherState weather
    property bool engaged: false
    property int selectedDay: 0

    signal closeRequested
    signal calendarRequested

    implicitWidth: 612
    implicitHeight: content.implicitHeight
    focus: engaged

    onEngagedChanged: {
        if (engaged) {
            selectedDay = 0;
            Qt.callLater(() => keys.forceActiveFocus());
        }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                panel.closeRequested();
                event.accepted = true;
            } else if (event.key === Qt.Key_R) {
                panel.weather.refresh();
                event.accepted = true;
            } else if (event.key === Qt.Key_C || event.key === Qt.Key_Backspace) {
                panel.calendarRequested();
                event.accepted = true;
            } else if (event.key === Qt.Key_J || event.key === Qt.Key_Right) {
                panel.selectedDay = Math.min(6, panel.selectedDay + 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_K || event.key === Qt.Key_Left) {
                panel.selectedDay = Math.max(0, panel.selectedDay - 1);
                event.accepted = true;
            }
        }
    }

    Column {
        id: content
        width: parent.width
        spacing: panel.theme.spacing3

        Row {
            width: parent.width
            spacing: panel.theme.spacing3

            Column {
                width: parent.width - refreshButton.width - panel.theme.spacing3
                spacing: panel.theme.spacing1

                Text {
                    text: "WEATHER / " + (panel.weather.city || "YOUR LOCATION").toUpperCase()
                    color: panel.theme.accent
                    font.family: panel.runtime.fontMono
                    font.pixelSize: panel.theme.fontPanelEyebrow
                    font.weight: Font.DemiBold
                }

                Text {
                    text: Qt.formatDate(new Date(), "dddd, d MMMM")
                    color: panel.theme.textStrong
                    font.family: panel.runtime.fontMono
                    font.pixelSize: panel.theme.fontPanelTitle
                    font.weight: Font.DemiBold
                }
            }

            ShellSurface {
                id: refreshButton

                width: 38
                height: 38
                anchors.verticalCenter: parent.verticalCenter
                theme: panel.theme
                motion: panel.motion
                surfaceLayer: ShellSurface.Control
                cornerRadius: panel.theme.radiusMedium

                Text {
                    anchors.centerIn: parent
                    text: "󰑐"
                    color: panel.theme.accent
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: panel.theme.fontSize(20)
                    opacity: panel.weather.loading ? 0.4 : 1
                }

                StateLayer {
                    theme: panel.theme
                    motion: panel.motion
                    cornerRadius: panel.theme.radiusMedium
                    disabled: panel.weather.loading
                    onActivated: panel.weather.refresh()
                }
            }
        }

        ShellSurface {
            width: parent.width
            height: 124
            theme: panel.theme
            motion: panel.motion
            surfaceLayer: ShellSurface.Control
            cornerRadius: panel.theme.radiusLarge
            fillColor: panel.theme.layer3

            Row {
                anchors.centerIn: parent
                spacing: panel.theme.spacing5

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.weather.icon
                    color: panel.theme.accent
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: panel.theme.fontSize(75)
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: panel.theme.spacing1

                    Text {
                        text: panel.weather.available ? panel.weather.temperatureText(panel.weather.temperature) : "--°"
                        color: panel.theme.textStrong
                        font.family: panel.runtime.fontMono
                        font.pixelSize: panel.theme.fontSize(46)
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: panel.weather.available ? panel.weather.description : panel.weather.status
                        color: panel.theme.text
                        font.family: panel.runtime.fontMono
                        font.pixelSize: panel.theme.fontSize(14)
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: panel.theme.spacing2

            WeatherMetric {
                width: (parent.width - 2 * panel.theme.spacing2) / 3
                theme: panel.theme
                motion: panel.motion
                icon: "󰔏"
                title: "Feels like"
                value: panel.weather.available ? panel.weather.temperatureText(panel.weather.feelsLike) : "--°"
            }

            WeatherMetric {
                width: (parent.width - 2 * panel.theme.spacing2) / 3
                theme: panel.theme
                motion: panel.motion
                icon: "󰖎"
                title: "Humidity"
                value: panel.weather.available ? panel.weather.humidity + "%" : "--%"
            }

            WeatherMetric {
                width: (parent.width - 2 * panel.theme.spacing2) / 3
                theme: panel.theme
                motion: panel.motion
                icon: "󰖝"
                title: "Wind"
                value: panel.weather.available ? Math.round(panel.weather.windSpeed) + " km/h" : "-- km/h"
            }
        }

        Row {
            width: parent.width
            spacing: panel.theme.spacing2

            WeatherMetric {
                width: (parent.width - panel.theme.spacing2) / 2
                theme: panel.theme
                motion: panel.motion
                icon: "󰖜"
                title: "Sunrise"
                value: panel.weather.available ? panel.weather.timeText(panel.weather.sunrise) : "--:--"
            }

            WeatherMetric {
                width: (parent.width - panel.theme.spacing2) / 2
                theme: panel.theme
                motion: panel.motion
                icon: "󰖛"
                title: "Sunset"
                value: panel.weather.available ? panel.weather.timeText(panel.weather.sunset) : "--:--"
            }
        }

        Text {
            text: "7-DAY FORECAST"
            color: panel.theme.textStrong
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(12)
            font.weight: Font.DemiBold
        }

        Row {
            id: forecastRow
            width: parent.width
            spacing: panel.theme.spacing2

            Repeater {
                model: panel.weather.forecast

                delegate: WeatherDay {
                    required property var modelData

                    theme: panel.theme
                    motion: panel.motion
                    weather: panel.weather
                    day: modelData
                    active: panel.selectedDay === index
                    onActivated: panel.selectedDay = index
                }
            }
        }

        Text {
            text: panel.weather.status || ("Updated " + panel.weather.updatedAt + " · J/K days · C calendar · R refresh")
            color: panel.theme.textMuted
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(11)
        }
    }
}

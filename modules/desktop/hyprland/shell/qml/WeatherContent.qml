pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "DesktopIcons.js" as DesktopIcons

FocusScope {
    id: panel

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property WeatherState weather
    readonly property bool foregroundBusy: weather.loading && weather.foregroundLoading
    readonly property string foregroundRole: "weather"
    property bool engaged: false
    property int selectedDay: 0
    property bool locationEditing: false
    function editLocation(): void {
        locationEditing = true;
        locationField.text = weather.preferredLocation;
        locationField.forceActiveFocus();
        locationField.selectAll();
    }
    function finishLocation(apply: bool): void {
        if (apply)
            weather.setLocation(locationField.text);
        locationEditing = false;
        keys.forceActiveFocus();
    }

    signal closeRequested
    signal calendarRequested

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    implicitWidth: 612
    implicitHeight: content.implicitHeight
    focus: engaged

    onEngagedChanged: {
        if (engaged) {
            selectedDay = 0;
            Qt.callLater(() => keys.forceActiveFocus());
        } else {
            locationEditing = false;
        }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === panel.runtime.shellKeyCode("weather", "Escape")) {
                panel.closeRequested();
                event.accepted = true;
            } else if (panel.runtime.shellMatchesHint("WeatherContent.location", event.key, event.modifiers)) {
                if (!event.isAutoRepeat)
                    panel.editLocation();
                event.accepted = true;
            } else if (panel.runtime.shellMatchesHint("WeatherContent.units", event.key, event.modifiers)) {
                if (!event.isAutoRepeat)
                    panel.weather.toggleUnits();
                event.accepted = true;
            } else if (panel.runtime.shellMatchesHint("WeatherContent.reset", event.key, event.modifiers)) {
                if (!event.isAutoRepeat) {
                    panel.weather.resetLocation();
                    panel.weather.resetUnits();
                }
                event.accepted = true;
            } else if (panel.runtime.shellMatchesHint("WeatherContent.refresh", event.key, event.modifiers)) {
                if (!event.isAutoRepeat)
                    panel.weather.refresh(true);
                event.accepted = true;
            } else if (event.key === panel.runtime.shellKeyCode("weather", "C") || event.key === panel.runtime.shellKeyCode("weather", "Backspace")) {
                panel.calendarRequested();
                event.accepted = true;
            } else if (panel.runtime.shellNavigates("weather", "down", event.key) || panel.runtime.shellNavigates("weather", "right", event.key)) {
                panel.selectedDay = Math.min(6, panel.selectedDay + 1);
                event.accepted = true;
            } else if (panel.runtime.shellNavigates("weather", "up", event.key) || panel.runtime.shellNavigates("weather", "left", event.key)) {
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
                    color: panel.theme.readableRoleColor("weather")
                    font.family: panel.runtime.fontSans
                    font.pixelSize: panel.theme.fontPanelEyebrow
                    font.weight: Font.DemiBold
                }

                Text {
                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                    color: panel.theme.textStrong
                    font.family: panel.runtime.fontSans
                    font.pixelSize: panel.theme.fontPanelTitle
                    font.weight: Font.DemiBold
                }
            }

            ShellAction {
                id: refreshButton
                width: Math.max(48, implicitWidth)
                height: Math.max(42, implicitHeight)
                anchors.verticalCenter: parent.verticalCenter
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                iconOnly: true
                iconHint: true
                inlineIconHint: true
                icon: "󰑐"
                shortcut: panel.runtime.shellHint("WeatherContent.refresh")
                title: "Refresh forecast"
                enabled: !panel.weather.loading
                onActivated: panel.weather.refresh(true)
            }
        }

        Row {
            width: parent.width
            height: 40
            spacing: panel.theme.spacing2
            ShellAction {
                width: Math.max(1, parent.width - unitsButton.width - defaultsButton.width - 2 * parent.spacing)
                height: parent.height
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                horizontalCompact: true
                title: panel.weather.preferredLocation || "Approximate location"
                shortcut: panel.runtime.shellHint("WeatherContent.location")
                active: panel.locationEditing
                onActivated: panel.editLocation()
            }
            ShellAction {
                id: unitsButton
                width: 105
                height: parent.height
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                horizontalCompact: true
                title: panel.weather.units === "metric" ? "°C / km/h" : "°F / mph"
                shortcut: panel.runtime.shellHint("WeatherContent.units")
                onActivated: panel.weather.toggleUnits()
            }
            ShellAction {
                id: defaultsButton
                width: implicitWidth
                height: parent.height
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                iconOnly: true
                inlineIconHint: true
                icon: DesktopIcons.actionGlyph("reset")
                title: "Restore weather defaults"
                shortcut: panel.runtime.shellHint("WeatherContent.reset")
                onActivated: {
                    panel.weather.resetLocation();
                    panel.weather.resetUnits();
                }
            }
        }

        SearchFieldSurface {
            visible: panel.locationEditing
            width: parent.width
            height: visible ? 42 : 0
            theme: panel.theme
            motion: panel.motion
            fieldFocused: locationField.activeFocus
            TextInput {
                id: locationField
                anchors {
                    fill: parent
                    leftMargin: panel.theme.spacing3
                    rightMargin: applyLocation.width + panel.theme.spacing3 * 2
                }
                verticalAlignment: TextInput.AlignVCenter
                color: panel.theme.textStrong
                selectionColor: panel.theme.accent
                font.family: panel.runtime.fontSans
                font.pixelSize: panel.theme.fontSize(12)
                maximumLength: 128
                Accessible.name: "Weather city or latitude,longitude"
                Keys.onPressed: event => {
                    if (event.key === panel.runtime.shellKeyCode("weather", "Escape")) {
                        panel.finishLocation(false);
                        event.accepted = true;
                    } else if (event.key === panel.runtime.shellKeyCode("weather", "Return") || event.key === panel.runtime.shellKeyCode("weather", "Enter")) {
                        if (!event.isAutoRepeat)
                            panel.finishLocation(true);
                        event.accepted = true;
                    }
                }
            }
            ShellText {
                anchors.fill: locationField
                verticalAlignment: Text.AlignVCenter
                visible: locationField.text.length === 0
                runtime: panel.runtime
                theme: panel.theme
                color: panel.theme.textMuted
                text: "City or latitude,longitude; empty uses approximate location"
                elide: Text.ElideRight
            }
            ShellAction {
                id: applyLocation
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: implicitWidth
                height: implicitHeight
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                iconOnly: true
                inlineIconHint: true
                icon: DesktopIcons.actionGlyph("confirm")
                title: "Apply location"
                shortcut: panel.runtime.shellHint("WeatherContent.applyLocation")
                onActivated: panel.finishLocation(true)
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
                    color: panel.theme.roleColor("weather")
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
                        font.family: panel.runtime.fontSans
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
                value: panel.weather.available ? panel.weather.windText(panel.weather.windSpeed) : "-- km/h"
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
            font.family: panel.runtime.fontSans
            font.pixelSize: panel.theme.fontSize(12)
            font.weight: Font.DemiBold
        }

        Grid {
            id: forecastRow
            width: parent.width
            columns: panel.theme.textScale >= 1.5 || width < 480 ? 4 : 7
            rowSpacing: panel.theme.spacing2
            columnSpacing: panel.theme.spacing2

            Repeater {
                model: panel.weather.forecast

                delegate: WeatherDay {
                    required property var modelData

                    width: (forecastRow.width - (forecastRow.columns - 1) * forecastRow.columnSpacing) / forecastRow.columns
                    theme: panel.theme
                    motion: panel.motion
                    weather: panel.weather
                    day: modelData
                    active: panel.selectedDay === index
                    onActivated: panel.selectedDay = index
                }
            }
        }

        ShellText {
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            text: panel.weather.forecast[panel.selectedDay] ? Qt.formatDate(new Date(panel.weather.forecast[panel.selectedDay].date + "T12:00:00"), "dddd, d MMMM") + " · " + panel.weather.conditionFor(panel.weather.forecast[panel.selectedDay].code) + " · " + Math.round(panel.weather.forecast[panel.selectedDay].rain ?? 0) + "% chance of precipitation" : "No forecast for selected day"
            color: panel.theme.textMuted
            wrapMode: Text.WordWrap
        }

        Text {
            text: panel.weather.status || ("Updated " + panel.weather.updatedAt)
            color: panel.theme.textMuted
            font.family: panel.runtime.fontSans
            font.pixelSize: panel.theme.fontSize(11)
        }

        KeyHintStrip {
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            hints: [
                {
                    shortcut: panel.runtime.shellHint("WeatherContent.days"),
                    label: "Days"
                },
                {
                    shortcut: panel.runtime.shellHint("WeatherContent.calendar"),
                    label: "Calendar"
                }
            ]
        }
    }
}

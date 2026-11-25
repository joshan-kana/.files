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
    readonly property var todayForecast: weather.forecast.length > 0 ? weather.forecast[0] : null
    readonly property bool stackedOutlook: width < 560 || theme.textScale >= 1.4
    property bool engaged: false
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

    function navigateBack(): void {
        if (locationEditing)
            finishLocation(false);
        else
            closeRequested();
    }

    signal closeRequested

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    implicitWidth: 612
    implicitHeight: content.implicitHeight
    focus: engaged

    onEngagedChanged: {
        if (engaged) {
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
                if (!event.isAutoRepeat)
                    panel.navigateBack();
                event.accepted = true;
            } else if (panel.runtime.shellMatchesHint("WeatherContent.location", event.key, event.modifiers)) {
                if (!event.isAutoRepeat)
                    locationButton.trigger();
                event.accepted = true;
            } else if (panel.runtime.shellMatchesHint("WeatherContent.units", event.key, event.modifiers)) {
                if (!event.isAutoRepeat)
                    unitsButton.trigger();
                event.accepted = true;
            } else if (panel.runtime.shellMatchesHint("WeatherContent.reset", event.key, event.modifiers)) {
                if (!event.isAutoRepeat)
                    defaultsButton.trigger();
                event.accepted = true;
            } else if (panel.runtime.shellMatchesHint("WeatherContent.refresh", event.key, event.modifiers)) {
                if (!event.isAutoRepeat)
                    refreshButton.trigger();
                event.accepted = true;
            }
        }
    }

    Column {
        id: content
        width: parent.width
        spacing: panel.theme.spacing3

        DetailHero {
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            glyph: DesktopIcons.glyphFor("weather")
            glyphFont: "Symbols Nerd Font"
            glyphColor: panel.theme.roleColor("weather")
            title: "Weather · " + (panel.weather.city || "Your location")
            detail: Qt.formatDateTime(clock.date, "dddd, d MMMM")
            actions: [
                ShellUtilityAction {
                    id: defaultsButton
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    icon: DesktopIcons.actionGlyph("reset")
                    title: "Restore weather defaults"
                    shortcut: panel.runtime.shellHint("WeatherContent.reset")
                    onActivated: {
                        panel.weather.resetLocation();
                        panel.weather.resetUnits();
                    }
                },
                ShellUtilityAction {
                    id: refreshButton
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    icon: DesktopIcons.actionGlyph("refresh")
                    shortcut: panel.runtime.shellHint("WeatherContent.refresh")
                    title: "Refresh forecast"
                    enabled: !panel.weather.loading
                    onActivated: panel.weather.refresh(true)
                }
            ]
        }

        Row {
            width: parent.width
            height: 40
            spacing: panel.theme.spacing2
            ShellAction {
                id: locationButton
                width: Math.max(1, parent.width - unitsButton.width - parent.spacing)
                height: parent.height
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                horizontalCompact: true
                icon: "󰍎"
                title: panel.weather.preferredLocation || "Approximate location"
                shortcut: panel.runtime.shellHint("WeatherContent.location")
                active: panel.locationEditing
                onActivated: panel.editLocation()
            }
            ShellAction {
                id: unitsButton
                width: implicitWidth
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
                selectionColor: panel.theme.selectionFill
                font.family: panel.runtime.fontSans
                font.pixelSize: panel.theme.fontSize(12)
                maximumLength: 128
                Accessible.name: "Weather city or latitude,longitude"
                Keys.onPressed: event => {
                    if (event.key === panel.runtime.shellKeyCode("weather", "Escape")) {
                        if (!event.isAutoRepeat)
                            panel.navigateBack();
                        event.accepted = true;
                    } else if (event.key === panel.runtime.shellKeyCode("weather", "Return") || event.key === panel.runtime.shellKeyCode("weather", "Enter")) {
                        if (!event.isAutoRepeat)
                            applyLocation.trigger();
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
            height: panel.theme.fontSize(panel.stackedOutlook && panel.todayForecast ? 235 : 166)
            theme: panel.theme
            motion: panel.motion
            surfaceLayer: ShellSurface.Control
            cornerRadius: panel.theme.radiusLarge
            fillColor: panel.theme.blend(panel.theme.groupBase, panel.theme.weatherColor(panel.weather.weatherCode, panel.weather.isDay), panel.theme.dark ? 0.15 : 0.09)
            Accessible.role: Accessible.StaticText
            Accessible.name: panel.weather.description + ", " + panel.weather.temperatureText(panel.weather.temperature) + (panel.todayForecast ? ", low " + panel.weather.temperatureText(panel.todayForecast.low) + ", high " + panel.weather.temperatureText(panel.todayForecast.high) + ", " + Math.round(panel.todayForecast.rain ?? 0) + "% chance of rain" : "")

            Grid {
                anchors.fill: parent
                anchors.margins: panel.theme.spacing4
                columns: panel.stackedOutlook ? 1 : 3
                rowSpacing: panel.theme.spacing3
                columnSpacing: panel.theme.spacing3

                Row {
                    id: currentConditions
                    width: panel.stackedOutlook ? parent.width : parent.width * 0.38
                    height: panel.stackedOutlook && panel.todayForecast ? (parent.height - parent.rowSpacing) * 0.53 : parent.height
                    spacing: panel.theme.spacing3

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: panel.weather.icon
                        color: panel.theme.weatherColor(panel.weather.weatherCode, panel.weather.isDay)
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: panel.theme.fontSize(70)
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: panel.theme.spacing1

                        Text {
                            text: panel.weather.available ? panel.weather.temperatureText(panel.weather.temperature) : "--°"
                            color: panel.theme.textStrong
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(43)
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: panel.weather.available ? panel.weather.description : panel.weather.status
                            color: panel.theme.text
                            font.family: panel.runtime.fontSans
                            font.pixelSize: panel.theme.fontSize(13)
                        }
                    }
                }

                Rectangle {
                    id: outlookDivider
                    visible: panel.todayForecast !== null && !panel.stackedOutlook
                    width: visible ? 1 : 0
                    height: parent.height * 0.63
                    color: panel.theme.subtleBorder
                }

                Row {
                    id: todayMetrics
                    visible: panel.todayForecast !== null
                    width: panel.stackedOutlook ? parent.width : Math.max(1, parent.width - currentConditions.width - outlookDivider.width - parent.columnSpacing * 2)
                    height: panel.stackedOutlook ? parent.height - currentConditions.height - parent.rowSpacing : parent.height
                    spacing: panel.theme.spacing2

                    Repeater {
                        model: panel.todayForecast ? [
                            {
                                title: "Low",
                                value: panel.weather.temperatureText(panel.todayForecast.low),
                                role: "cold",
                                icon: "↓",
                                iconFont: panel.runtime.fontSans
                            },
                            {
                                title: "High",
                                value: panel.weather.temperatureText(panel.todayForecast.high),
                                role: "temperature",
                                icon: "↑",
                                iconFont: panel.runtime.fontSans
                            },
                            {
                                title: "Rain chance",
                                value: Math.round(panel.todayForecast.rain ?? 0) + "%",
                                role: "precipitation",
                                icon: "󰖗",
                                iconFont: "Symbols Nerd Font"
                            }
                        ] : []

                        delegate: Column {
                            id: todayMetric
                            required property var modelData
                            width: (todayMetrics.width - todayMetrics.spacing * 2) / 3
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: panel.theme.spacing2

                            Row {
                                spacing: panel.theme.spacing1
                                Text {
                                    text: todayMetric.modelData.icon
                                    color: panel.theme.readableRoleColor(todayMetric.modelData.role)
                                    font.family: todayMetric.modelData.iconFont
                                    font.pixelSize: panel.theme.fontSize(16)
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: todayMetric.modelData.title
                                    color: panel.theme.textMuted
                                    font.family: panel.runtime.fontSans
                                    font.pixelSize: panel.theme.fontSize(12)
                                }
                            }

                            Text {
                                text: todayMetric.modelData.value
                                color: panel.theme.readableRoleColor(todayMetric.modelData.role)
                                font.family: panel.runtime.fontMono
                                font.pixelSize: panel.theme.fontPanelTitle
                                font.weight: Font.DemiBold
                            }
                        }
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
                role: "temperature"
                value: panel.weather.available ? panel.weather.temperatureText(panel.weather.feelsLike) : "--°"
            }

            WeatherMetric {
                width: (parent.width - 2 * panel.theme.spacing2) / 3
                theme: panel.theme
                motion: panel.motion
                icon: "󰖎"
                title: "Humidity"
                role: "precipitation"
                value: panel.weather.available ? panel.weather.humidity + "%" : "--%"
            }

            WeatherMetric {
                width: (parent.width - 2 * panel.theme.spacing2) / 3
                theme: panel.theme
                motion: panel.motion
                icon: "󰖝"
                title: "Wind"
                role: "wind"
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
                role: "daylight"
                value: panel.weather.available ? panel.weather.timeText(panel.weather.sunrise) : "--:--"
            }

            WeatherMetric {
                width: (parent.width - panel.theme.spacing2) / 2
                theme: panel.theme
                motion: panel.motion
                icon: "󰖛"
                title: "Sunset"
                role: "night"
                value: panel.weather.available ? panel.weather.timeText(panel.weather.sunset) : "--:--"
            }
        }

        Text {
            text: "7-day forecast"
            color: panel.theme.textStrong
            font.family: panel.runtime.fontSans
            font.pixelSize: panel.theme.fontSize(12)
            font.weight: Font.DemiBold
        }

        Grid {
            id: forecastRow
            width: parent.width
            columns: 1
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
                    lowBound: Math.min(...panel.weather.forecast.map(item => item.low))
                    highBound: Math.max(...panel.weather.forecast.map(item => item.high))
                }
            }
        }

        Text {
            text: panel.weather.status || ("Updated " + panel.weather.updatedAt)
            color: panel.theme.textMuted
            font.family: panel.runtime.fontSans
            font.pixelSize: panel.theme.fontSize(11)
        }
    }
}

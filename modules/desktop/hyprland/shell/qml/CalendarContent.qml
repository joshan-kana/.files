pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "calendar_layout.js" as CalendarLayout

FocusScope {
    id: calendar

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property WeatherState weather
    property bool engaged: false
    property int monthShift: 0
    property int selectedDay: 0
    readonly property var selectedDate: selectedDay > 0 ? new Date(viewingDate.getFullYear(), viewingDate.getMonth(), selectedDay) : viewingDate
    readonly property string selectedDateKey: Qt.formatDate(selectedDate, "yyyy-MM-dd")
    readonly property var viewingDate: CalendarLayout.getDateInXMonthsTime(monthShift, clock.date)
    readonly property var calendarLayout: CalendarLayout.getCalendarLayout(viewingDate, monthShift === 0)
    property var outgoingLayout: []
    property int slideDirection: 1
    property real slideProgress: 1
    property bool sliding: false
    property bool calendarPickerOpen: false
    property int calendarPickerIndex: 0

    function toggleCalendarAt(index: int): void {
        if (index < 0 || index >= agenda.calendars.length)
            return;
        const source = agenda.calendars[index];
        agenda.setCalendarEnabled(source.id, !source.enabled);
    }

    signal closeRequested
    signal forecastRequested

    implicitWidth: 780
    implicitHeight: content.implicitHeight
    // Wider dates and compact rows use the whole calendar card without
    // inflating Home. Selection becomes a deliberate horizontal pill.
    readonly property real daySize: Math.min(38, Math.max(23, (leftColumn.width - 126 - theme.spacing4 * 2 - theme.spacing1 * 6) / 7))
    readonly property real dayHeight: Math.min(35, Math.max(27, 29 * theme.textScale))
    focus: engaged

    onEngagedChanged: {
        if (engaged) {
            calendarPickerOpen = false;
            // Reopen directly on today; only deliberate month changes should slide.
            monthAnimation.stop();
            sliding = false;
            slideProgress = 1;
            monthShift = 0;
            selectedDay = 0;
            Qt.callLater(() => keySink.forceActiveFocus());
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    AgendaState {
        id: agenda
        runtime: calendar.runtime
        active: calendar.engaged
        startDate: calendar.selectedDateKey
    }

    NumberAnimation {
        id: monthAnimation
        target: calendar
        property: "slideProgress"
        from: 0
        to: 1
        duration: calendar.motion.spatialNormal
        easing.type: calendar.motion.spatialType
        easing.bezierCurve: calendar.motion.spatialCurve
        onFinished: calendar.sliding = false
    }

    function browseMonths(amount: int): void {
        if (amount === 0)
            return;

        monthAnimation.stop();
        outgoingLayout = calendarLayout;
        slideDirection = amount > 0 ? 1 : -1;
        slideProgress = 0;
        selectedDay = 0;
        monthShift += amount;
        sliding = motion.enabled;

        if (sliding)
            monthAnimation.start();
        else
            slideProgress = 1;
    }

    function browseDays(amount: int): void {
        const currentDay = selectedDay > 0 ? selectedDay : (monthShift === 0 ? clock.date.getDate() : 1);
        const monthDays = new Date(viewingDate.getFullYear(), viewingDate.getMonth() + 1, 0).getDate();
        const targetDay = currentDay + amount;
        if (targetDay < 1) {
            browseMonths(-1);
            selectedDay = new Date(viewingDate.getFullYear(), viewingDate.getMonth() + 1, 0).getDate();
        } else if (targetDay > monthDays) {
            browseMonths(1);
            selectedDay = 1;
        } else {
            selectedDay = targetDay;
        }
    }

    function today(): void {
        if (monthShift !== 0) {
            browseMonths(-monthShift);
        } else {
            monthAnimation.stop();
            sliding = false;
            slideProgress = 1;
            selectedDay = 0;
        }
    }

    function chooseDate(cellIndex: int): void {
        const row = Math.floor(cellIndex / 7);
        const column = cellIndex % 7;
        const day = calendarLayout[row][column];
        if (day.today === -1) {
            browseMonths(cellIndex < 14 ? -1 : 1);
            return;
        }
        selectedDay = day.day;
    }

    Item {
        id: keySink
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (calendar.calendarPickerOpen) {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_C) {
                    calendar.calendarPickerOpen = false;
                } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
                    calendar.calendarPickerIndex = Math.min(agenda.calendars.length - 1, calendar.calendarPickerIndex + 1);
                } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
                    calendar.calendarPickerIndex = Math.max(0, calendar.calendarPickerIndex - 1);
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    calendar.toggleCalendarAt(calendar.calendarPickerIndex);
                } else {
                    return;
                }
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_C && agenda.calendars.length > 0) {
                calendar.calendarPickerIndex = 0;
                calendar.calendarPickerOpen = true;
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                calendar.closeRequested();
                event.accepted = true;
            } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up || event.key === Qt.Key_PageUp) {
                calendar.browseMonths(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down || event.key === Qt.Key_PageDown) {
                calendar.browseMonths(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
                calendar.browseDays(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
                calendar.browseDays(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_U || event.key === Qt.Key_D) {
                agendaView.scrollEvents(event.key === Qt.Key_U ? -1 : 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_R) {
                agenda.refresh();
                event.accepted = true;
            } else if (event.key === Qt.Key_T) {
                calendar.today();
                event.accepted = true;
            } else if (event.key === Qt.Key_F || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                calendar.forecastRequested();
                event.accepted = true;
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: event => {
            if (event.angleDelta.y !== 0)
                calendar.browseMonths(event.angleDelta.y > 0 ? -1 : 1);
            event.accepted = true;
        }
    }

    Column {
        id: content
        width: parent.width
        spacing: calendar.theme.spacing3

        Row {
            width: parent.width
            spacing: calendar.theme.spacing3

            Column {
                width: parent.width
                spacing: calendar.theme.spacing1

                Text {
                    text: Qt.formatDate(clock.date, "dddd · d MMMM yyyy").toUpperCase()
                    color: calendar.theme.accent
                    font.family: calendar.runtime.fontMono
                    font.pixelSize: calendar.theme.fontPanelEyebrow
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.7
                }
                Text {
                    text: clock.date.getHours() < 12 ? "Good morning." : clock.date.getHours() < 17 ? "Good afternoon." : "Good evening."
                    color: calendar.theme.textStrong
                    font.family: calendar.runtime.fontMono
                    font.pixelSize: calendar.theme.fontPanelTitle
                    font.weight: Font.DemiBold
                }
            }
        }

        Row {
            id: featured
            width: parent.width
            spacing: calendar.theme.spacing3

            Column {
                id: leftColumn
                width: (featured.width - featured.spacing) * 0.47
                spacing: calendar.theme.spacing3
                WeatherSummary {
                    width: parent.width
                    theme: calendar.theme
                    motion: calendar.motion
                    weather: calendar.weather
                    height: 174
                    onForecastRequested: calendar.forecastRequested()
                }

                ShellSurface {
                    width: parent.width
                    height: Math.max(240, monthViewport.height + calendar.theme.spacing4 * 2 + 30)
                    theme: calendar.theme
                    motion: calendar.motion
                    surfaceLayer: ShellSurface.Group
                    cornerRadius: calendar.theme.radiusLarge

                    Row {
                        id: monthContents
                        anchors {
                            fill: parent
                            margins: calendar.theme.spacing4
                        }
                        spacing: calendar.theme.spacing3

                        Column {
                            width: Math.min(112, parent.width * 0.31)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: calendar.theme.spacing2

                            Text {
                                width: parent.width
                                text: Qt.formatDate(calendar.viewingDate, "MMMM yyyy")
                                wrapMode: Text.WordWrap
                                color: calendar.theme.textStrong
                                font.family: calendar.runtime.fontMono
                                font.pixelSize: calendar.theme.fontSize(22)
                                font.weight: Font.DemiBold
                            }

                            Row {
                                spacing: calendar.theme.spacing2
                                CalendarNavButton {
                                    id: previous
                                    theme: calendar.theme
                                    motion: calendar.motion
                                    icon: ""
                                    onActivated: calendar.browseMonths(-1)
                                }
                                CalendarNavButton {
                                    id: next
                                    theme: calendar.theme
                                    motion: calendar.motion
                                    icon: ""
                                    onActivated: calendar.browseMonths(1)
                                }
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: calendar.theme.spacing1

                            Grid {
                                id: weekdayRow
                                columns: 7
                                spacing: calendar.theme.spacing1
                                Repeater {
                                    model: CalendarLayout.weekDays
                                    delegate: CalendarDay {
                                        required property var modelData
                                        width: calendar.daySize
                                        height: calendar.dayHeight
                                        theme: calendar.theme
                                        motion: calendar.motion
                                        header: true
                                        day: 0
                                        heading: modelData.day
                                    }
                                }
                            }

                            Item {
                                id: monthViewport
                                width: weekdayRow.implicitWidth
                                height: 6 * calendar.dayHeight + 5 * calendar.theme.spacing1
                                clip: true
                                CalendarMonthGrid {
                                    id: incomingMonth
                                    theme: calendar.theme
                                    motion: calendar.motion
                                    spacing: calendar.theme.spacing1
                                    daySize: calendar.daySize
                                    cellHeight: calendar.dayHeight
                                    monthLayout: calendar.calendarLayout
                                    selectedDay: calendar.selectedDay
                                    y: calendar.sliding ? calendar.slideDirection * monthViewport.height * (1 - calendar.slideProgress) : 0
                                    onDayActivated: cellIndex => calendar.chooseDate(cellIndex)
                                }
                                CalendarMonthGrid {
                                    id: departingMonth
                                    visible: calendar.sliding
                                    interactive: false
                                    theme: calendar.theme
                                    motion: calendar.motion
                                    spacing: calendar.theme.spacing1
                                    daySize: calendar.daySize
                                    cellHeight: calendar.dayHeight
                                    monthLayout: calendar.outgoingLayout
                                    y: -calendar.slideDirection * monthViewport.height * calendar.slideProgress
                                }
                            }
                        }
                    }
                }
            }

            AgendaList {
                id: agendaView
                width: (featured.width - featured.spacing) * 0.53
                runtime: calendar.runtime
                theme: calendar.theme
                motion: calendar.motion
                agenda: agenda
                startDate: calendar.selectedDateKey
                featured: true
                onCalendarsRequested: {
                    calendar.calendarPickerIndex = 0;
                    calendar.calendarPickerOpen = !calendar.calendarPickerOpen;
                }
            }
        }

        Row {
            width: parent.width

            Row {
                id: calendarHints
                spacing: calendar.theme.spacing2
                Repeater {
                    model: [
                        {
                            shortcut: "J/K",
                            label: "Months"
                        },
                        {
                            shortcut: "H/L",
                            label: "Days"
                        },
                        {
                            shortcut: "U/D",
                            label: "Events"
                        },
                        {
                            shortcut: "C",
                            label: "Calendars"
                        }
                    ]
                    delegate: KeyHint {
                        required property var modelData
                        shortcut: modelData.shortcut
                        label: modelData.label
                        runtime: calendar.runtime
                        theme: calendar.theme
                    }
                }
            }

            Item {
                width: Math.max(0, parent.width - calendarHints.implicitWidth - resetButton.implicitWidth)
                height: 1
            }

            ShellAction {
                id: resetButton
                width: 36
                height: 30
                iconOnly: true
                icon: "󰃰"
                title: "Today"
                shortcut: "T"
                iconHint: true
                runtime: calendar.runtime
                theme: calendar.theme
                motion: calendar.motion
                onActivated: calendar.today()
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 10
        visible: calendar.calendarPickerOpen
        onClicked: calendar.calendarPickerOpen = false
    }

    ShellSurface {
        id: calendarPicker
        z: 11
        visible: calendar.calendarPickerOpen && agenda.calendars.length > 0
        x: Math.max(0, parent.width - width - calendar.theme.spacing2)
        y: featured.y + calendar.theme.spacing4
        width: Math.min(350, parent.width - calendar.theme.spacing3 * 2)
        height: pickerItems.implicitHeight + calendar.theme.spacing3 * 2
        theme: calendar.theme
        motion: calendar.motion
        surfaceLayer: ShellSurface.Pane
        cornerRadius: calendar.theme.radiusLarge
        fillColor: calendar.theme.layer0
        elevated: true
        outlined: true

        Column {
            id: pickerItems
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: calendar.theme.spacing3
            }
            spacing: calendar.theme.spacing2

            Row {
                width: parent.width
                spacing: calendar.theme.spacing2
                Text {
                    text: "CALENDARS"
                    font.family: calendar.runtime.fontMono
                    font.pixelSize: calendar.theme.fontPanelEyebrow
                    font.weight: Font.DemiBold
                    color: calendar.theme.accent
                }
                Item {
                    width: Math.max(0, parent.width - parent.children[0].implicitWidth - enabledLabel.implicitWidth - parent.spacing * 2)
                    height: 1
                }
                Text {
                    id: enabledLabel
                    text: agenda.calendars.filter(source => source.enabled).length + " / " + agenda.calendars.length + " ON"
                    font.family: calendar.runtime.fontMono
                    font.pixelSize: calendar.theme.fontSize(10)
                    color: calendar.theme.textMuted
                }
            }

            Repeater {
                model: agenda.calendars
                delegate: ShellSurface {
                    id: sourceRow
                    required property var modelData
                    required property int index
                    readonly property bool highlighted: calendar.calendarPickerIndex === index
                    width: pickerItems.width
                    height: 40
                    theme: calendar.theme
                    motion: calendar.motion
                    surfaceLayer: ShellSurface.Group
                    cornerRadius: calendar.theme.radiusMedium
                    fillColor: highlighted ? calendar.theme.selectedTabFill : calendar.theme.expressiveSurface

                    Row {
                        anchors {
                            fill: parent
                            leftMargin: calendar.theme.spacing2
                            rightMargin: calendar.theme.spacing2
                        }
                        spacing: calendar.theme.spacing2
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: sourceRow.modelData.enabled ? "󰄲" : "󰄱"
                            color: sourceRow.modelData.enabled ? calendar.theme.accent : calendar.theme.textMuted
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: calendar.theme.fontSize(17)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - calendar.theme.spacing2 - 34
                            elide: Text.ElideRight
                            text: sourceRow.modelData.name
                            color: sourceRow.modelData.enabled ? calendar.theme.textStrong : calendar.theme.textMuted
                            font.family: calendar.runtime.fontMono
                            font.pixelSize: calendar.theme.fontSize(12)
                        }
                    }
                    StateLayer {
                        anchors.fill: parent
                        theme: calendar.theme
                        motion: calendar.motion
                        cornerRadius: calendar.theme.radiusMedium
                        Accessible.role: Accessible.CheckBox
                        Accessible.name: sourceRow.modelData.name
                        Accessible.checked: sourceRow.modelData.enabled
                        onActivated: {
                            calendar.calendarPickerIndex = sourceRow.index;
                            calendar.toggleCalendarAt(sourceRow.index);
                        }
                    }
                }
            }

            Row {
                spacing: calendar.theme.spacing2
                Repeater {
                    model: [
                        {
                            shortcut: "J/K",
                            label: "Select"
                        },
                        {
                            shortcut: "SPACE",
                            label: "Toggle"
                        },
                        {
                            shortcut: "ESC",
                            label: "Close"
                        }
                    ]
                    delegate: KeyHint {
                        required property var modelData
                        shortcut: modelData.shortcut
                        label: modelData.label
                        runtime: calendar.runtime
                        theme: calendar.theme
                    }
                }
            }
        }
    }
}

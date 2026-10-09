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

    signal closeRequested
    signal forecastRequested

    implicitWidth: 356
    implicitHeight: content.implicitHeight
    focus: engaged

    onEngagedChanged: {
        if (engaged) {
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
            if (event.key === Qt.Key_Escape) {
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
            spacing: calendar.theme.spacing2

            Column {
                width: parent.width - previous.width - next.width - calendar.theme.spacing2 * 2
                spacing: calendar.theme.spacing1

                Text {
                    text: Qt.formatDate(calendar.viewingDate, "MMMM yyyy")
                    color: calendar.theme.textStrong
                    font.family: calendar.runtime.fontMono
                    font.pixelSize: calendar.theme.fontSize(22)
                    font.weight: Font.DemiBold
                }
            }

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

        Grid {
            id: weekdayRow
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 7
            spacing: calendar.theme.spacing2

            Repeater {
                model: CalendarLayout.weekDays

                delegate: CalendarDay {
                    required property var modelData

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
            anchors.horizontalCenter: parent.horizontalCenter
            width: weekdayRow.implicitWidth
            height: 6 * 42 + 5 * calendar.theme.spacing2
            clip: true

            CalendarMonthGrid {
                id: incomingMonth
                theme: calendar.theme
                motion: calendar.motion
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
                monthLayout: calendar.outgoingLayout
                y: -calendar.slideDirection * monthViewport.height * calendar.slideProgress
            }
        }

        WeatherSummary {
            width: parent.width
            theme: calendar.theme
            motion: calendar.motion
            weather: calendar.weather
            onForecastRequested: calendar.forecastRequested()
        }

        AgendaList {
            id: agendaView
            width: parent.width
            runtime: calendar.runtime
            theme: calendar.theme
            motion: calendar.motion
            agenda: agenda
            startDate: calendar.selectedDateKey
        }

        Row {
            width: parent.width

            Text {
                id: dateCaption
                text: calendar.selectedDay > 0 ? Qt.formatDate(new Date(calendar.viewingDate.getFullYear(), calendar.viewingDate.getMonth(), calendar.selectedDay), "ddd d MMMM") : "J/K months · H/L days · U/D events"
                color: calendar.theme.textStrong
                opacity: 0.85
                font.family: calendar.runtime.fontMono
                font.pixelSize: calendar.theme.fontSize(11)
            }

            Item {
                width: Math.max(0, parent.width - dateCaption.implicitWidth - resetButton.implicitWidth)
                height: 1
            }

            Text {
                id: resetButton
                text: "TODAY ↗"
                color: calendar.theme.accent
                font.family: calendar.runtime.fontMono
                font.pixelSize: calendar.theme.fontSize(11)
                font.weight: Font.DemiBold

                StateLayer {
                    theme: calendar.theme
                    motion: calendar.motion
                    cornerRadius: calendar.theme.radiusSmall
                    onActivated: calendar.today()
                }
            }
        }
    }
}

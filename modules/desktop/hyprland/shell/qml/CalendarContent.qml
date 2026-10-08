pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "calendar_layout.js" as CalendarLayout

FocusScope {
    id: calendar

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    property bool engaged: false
    property int monthShift: 0
    property int selectedDay: 0
    readonly property var viewingDate: CalendarLayout.getDateInXMonthsTime(monthShift, clock.date)
    readonly property var calendarLayout: CalendarLayout.getCalendarLayout(viewingDate, monthShift === 0)
    property var outgoingLayout: []
    property int slideDirection: 1
    property real slideProgress: 1
    property bool sliding: false

    signal closeRequested

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
            } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up || event.key === Qt.Key_PageUp || event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                calendar.browseMonths(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down || event.key === Qt.Key_PageDown || event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                calendar.browseMonths(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_T) {
                calendar.today();
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
                    text: "CALENDAR"
                    color: calendar.theme.accent
                    font.family: calendar.runtime.fontMono
                    font.pixelSize: calendar.theme.fontPanelEyebrow
                    font.weight: Font.DemiBold
                }

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

        Row {
            width: parent.width

            Text {
                id: dateCaption
                text: calendar.selectedDay > 0 ? Qt.formatDate(new Date(calendar.viewingDate.getFullYear(), calendar.viewingDate.getMonth(), calendar.selectedDay), "ddd d MMMM") : "J / K · months · T today"
                color: calendar.theme.textMuted
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

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: calendar.today()
                }
            }
        }
    }
}

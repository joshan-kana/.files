pragma ComponentBehavior: Bound
import QtQuick

Grid {
    id: monthGrid

    required property Theme theme
    required property Motion motion
    required property var monthLayout
    property int selectedDay: 0
    property real daySize: 42
    property bool interactive: true

    signal dayActivated(int cellIndex)

    columns: 7
    spacing: theme.spacing2

    Repeater {
        // The outgoing grid is deliberately empty until the first transition.
        model: monthGrid.monthLayout && monthGrid.monthLayout.length === 6 ? 42 : 0

        delegate: CalendarDay {
            required property int index

            readonly property int week: Math.floor(index / 7)
            readonly property int weekday: index % 7
            readonly property var dateInfo: monthGrid.monthLayout[week][weekday]

            theme: monthGrid.theme
            motion: monthGrid.motion
            width: monthGrid.daySize
            height: monthGrid.daySize
            day: dateInfo.day
            dayState: dateInfo.today
            picked: monthGrid.selectedDay > 0 && monthGrid.selectedDay === day && dayState !== -1
            enabled: monthGrid.interactive
            onActivated: monthGrid.dayActivated(index)
        }
    }
}

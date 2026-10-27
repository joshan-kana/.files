pragma ComponentBehavior: Bound
import QtQuick

Column {
    id: panel

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property AgendaState agenda
    required property string startDate
    property int firstEventIndex: 0
    property bool featured: false
    readonly property int pageSize: featured ? 6 : 4
    readonly property int visibleStart: Math.min(firstEventIndex, Math.max(0, agenda.events.length - pageSize))
    readonly property int visibleEnd: Math.min(agenda.events.length, visibleStart + pageSize)
    signal calendarsRequested

    width: parent.width
    spacing: theme.spacing2
    onStartDateChanged: firstEventIndex = 0
    onAgendaChanged: firstEventIndex = 0

    function scrollEvents(amount: int): void {
        firstEventIndex = Math.max(0, Math.min(firstEventIndex + amount, Math.max(0, agenda.events.length - pageSize)));
    }

    ShellSurface {
        id: body
        width: parent.width
        height: (panel.agenda.events.length > 0 && panel.agenda.configured && panel.agenda.errorMessage.length === 0 ? Math.min(panel.pageSize, panel.agenda.events.length) * 67 + panel.theme.spacing2 : (panel.featured ? 169 : 72)) + header.height + panel.theme.spacing2
        theme: panel.theme
        motion: panel.motion
        surfaceLayer: ShellSurface.Group
        cornerRadius: panel.featured ? panel.theme.radiusLarge : panel.theme.radiusMedium
        fillColor: panel.featured ? panel.theme.blend(panel.theme.groupBase, panel.theme.roleColor("calendar"), panel.theme.dark ? 0.055 : 0.035) : panel.theme.expressiveSurface
        luminous: panel.featured
        luminousColor: panel.theme.roleColor("calendar")
        clip: true

        Row {
            id: header
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: panel.theme.spacing3
            }
            spacing: panel.theme.spacing2

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "AGENDA · NEXT 7 DAYS"
                color: panel.theme.roleColor("calendar")
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontPanelEyebrow
                font.weight: Font.DemiBold
            }
            Item {
                width: Math.max(0, header.width - header.children[0].implicitWidth - count.implicitWidth - calendarButton.width - header.spacing * 3)
                height: 1
            }
            Text {
                id: count
                anchors.verticalCenter: parent.verticalCenter
                text: panel.agenda.loading ? "SYNCING" : panel.agenda.configured ? panel.agenda.events.length + " EVENTS" : "SET UP"
                color: panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(10)
            }
            ShellAction {
                id: calendarButton
                width: panel.agenda.calendars.length > 0 ? 32 : 0
                height: 30
                visible: width > 0
                iconOnly: true
                icon: "󰃀"
                title: "Choose calendars (C)"
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                onActivated: panel.calendarsRequested()
            }
        }

        Column {
            anchors {
                fill: parent
                margins: panel.theme.spacing2 / 2
                topMargin: header.height + panel.theme.spacing3
            }
            visible: panel.agenda.configured && panel.agenda.errorMessage.length === 0
            spacing: 0

            Repeater {
                model: panel.agenda.events.slice(panel.visibleStart, panel.visibleEnd)
                delegate: Item {
                    id: eventRow
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: 67

                    Column {
                        anchors {
                            fill: parent
                            leftMargin: panel.theme.spacing3
                            rightMargin: panel.theme.spacing3
                            topMargin: panel.theme.spacing2
                        }
                        spacing: 5
                        Text {
                            width: parent.width
                            text: eventRow.modelData.title
                            color: panel.theme.textStrong
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(12)
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Row {
                            id: eventMeta
                            width: parent.width
                            spacing: panel.theme.spacing2
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: (eventRow.modelData.dateKind ? eventRow.modelData.dateKind + " " : "") + (eventRow.modelData.date === panel.startDate ? "TODAY" : eventRow.modelData.date.slice(5)) + (eventRow.modelData.time ? " · " + eventRow.modelData.time : "")
                                color: panel.theme.roleColor("calendar")
                                font.family: panel.runtime.fontMono
                                font.pixelSize: panel.theme.fontSize(10)
                            }
                            Item {
                                width: Math.max(0, eventMeta.width - eventMeta.children[0].implicitWidth - eventSource.implicitWidth - eventMeta.spacing * 2)
                                height: 1
                            }
                            Text {
                                id: eventSource
                                anchors.verticalCenter: parent.verticalCenter
                                text: eventRow.modelData.calendar || "Local"
                                color: panel.theme.textMuted
                                font.family: panel.runtime.fontMono
                                font.pixelSize: panel.theme.fontSize(10)
                                maximumLineCount: 1
                                elide: Text.ElideRight
                            }
                        }
                    }
                    Rectangle {
                        visible: panel.visibleStart + eventRow.index < panel.agenda.events.length - 1
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                            leftMargin: panel.theme.spacing3
                            rightMargin: panel.theme.spacing3
                        }
                        height: 1
                        color: panel.theme.subtleBorder
                        opacity: 0.65
                    }
                }
            }
        }

        Column {
            visible: panel.agenda.events.length === 0 || !panel.agenda.configured || panel.agenda.errorMessage.length > 0
            anchors.centerIn: parent
            width: parent.width - panel.theme.spacing4 * 2
            spacing: panel.theme.spacing2
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: panel.agenda.errorMessage || (panel.agenda.loading ? "Reading calendar…" : panel.agenda.configured ? "No upcoming events" : "Set up local calendar")
                color: panel.theme.textStrong
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(panel.featured ? 15 : 11)
                wrapMode: Text.WordWrap
            }
        }

        StateLayer {
            visible: !panel.agenda.configured && !panel.agenda.loading
            theme: panel.theme
            motion: panel.motion
            cornerRadius: panel.theme.radiusMedium
            Accessible.role: Accessible.Button
            Accessible.name: "Create local calendar"
            onActivated: panel.agenda.setup()
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: event => {
                if (event.angleDelta.y !== 0) {
                    panel.scrollEvents(event.angleDelta.y > 0 ? -1 : 1);
                    event.accepted = true;
                }
            }
        }
    }

    Text {
        visible: panel.agenda.events.length > panel.pageSize
        text: (panel.visibleStart + 1) + "–" + panel.visibleEnd + " / " + panel.agenda.events.length + ""
        color: panel.theme.textMuted
        font.family: panel.runtime.fontMono
        font.pixelSize: panel.theme.fontSize(10)
    }
}

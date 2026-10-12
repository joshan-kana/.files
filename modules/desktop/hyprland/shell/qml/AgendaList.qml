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
    readonly property int visibleStart: Math.min(firstEventIndex, Math.max(0, agenda.events.length - 4))
    readonly property int visibleEnd: Math.min(agenda.events.length, visibleStart + 4)

    function scrollEvents(amount: int): void {
        firstEventIndex = Math.max(0, Math.min(firstEventIndex + amount, Math.max(0, agenda.events.length - 4)));
    }

    onStartDateChanged: firstEventIndex = 0

    spacing: theme.spacing2
    width: parent.width

    Row {
        width: parent.width

        Text {
            text: "AGENDA / NEXT 7 DAYS"
            color: panel.theme.accent
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontPanelEyebrow
            font.weight: Font.DemiBold
        }
        Item {
            width: Math.max(0, parent.width - parent.children[0].implicitWidth - status.implicitWidth)
            height: 1
        }
        Text {
            id: status
            text: panel.agenda.loading ? "UPDATING" : (panel.agenda.configured ? panel.agenda.events.length + " EVENTS" : "NOT CONFIGURED")
            color: panel.theme.textStrong
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(10)
        }
    }

    ShellSurface {
        width: parent.width
        height: panel.agenda.events.length > 0 && panel.agenda.configured && panel.agenda.errorMessage.length === 0 ? Math.min(4, panel.agenda.events.length) * 54 + panel.theme.spacing2 : (panel.featured ? 169 : 72)
        theme: panel.theme
        motion: panel.motion
        surfaceLayer: ShellSurface.Group
        cornerRadius: panel.featured ? panel.theme.radiusLarge : panel.theme.radiusMedium
        fillColor: panel.featured ? panel.theme.blend(panel.theme.groupBase, panel.theme.accent, panel.theme.dark ? 0.055 : 0.035) : panel.theme.expressiveSurface
        luminous: panel.featured
        luminousColor: panel.theme.accent

        Text {
            visible: panel.featured && panel.agenda.events.length === 0
            anchors {
                right: parent.right
                bottom: parent.bottom
                margins: panel.theme.spacing3
            }
            text: "󰃰"
            color: panel.theme.accent
            opacity: 0.19
            font.family: "Symbols Nerd Font"
            font.pixelSize: panel.theme.fontSize(75)
        }

        Column {
            anchors {
                left: parent.left
                top: parent.top
                right: parent.right
                margins: panel.theme.spacing4
            }
            visible: panel.featured && panel.agenda.events.length === 0
            spacing: panel.theme.spacing2

            Text {
                text: "Today"
                color: panel.theme.textStrong
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(27)
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                text: panel.agenda.loading ? "Reading calendar…" : panel.agenda.configured ? "No upcoming events" : "Set up local calendar ↗"
                color: panel.theme.text
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(11)
                wrapMode: Text.WordWrap
            }
        }

        Text {
            anchors.centerIn: parent
            visible: !panel.featured && (panel.agenda.events.length === 0 || !panel.agenda.configured || panel.agenda.errorMessage.length > 0)
            width: parent.width - panel.theme.spacing4 * 2
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: panel.agenda.errorMessage || (panel.agenda.loading ? "Reading calendar…" : (panel.agenda.configured ? "No upcoming events" : "󰃰  Create local calendar  ↗"))
            color: panel.theme.textStrong
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(11)
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

        Column {
            anchors {
                fill: parent
                margins: panel.theme.spacing1
            }
            visible: panel.agenda.configured && panel.agenda.errorMessage.length === 0
            spacing: 0

            Repeater {
                model: panel.agenda.events.slice(panel.visibleStart, panel.visibleEnd)
                delegate: Item {
                    id: eventRow
                    required property var modelData
                    width: parent.width
                    height: 54

                    Row {
                        anchors {
                            fill: parent
                            leftMargin: panel.theme.spacing2
                            rightMargin: panel.theme.spacing2
                        }
                        spacing: panel.theme.spacing3
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 80
                            text: eventRow.modelData.date === panel.startDate ? (eventRow.modelData.time || "ALL DAY") : (eventRow.modelData.date.slice(5) + (eventRow.modelData.time ? " " + eventRow.modelData.time : ""))
                            color: panel.theme.accent
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(10)
                            font.weight: Font.DemiBold
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 80 - panel.theme.spacing3
                            spacing: panel.theme.spacing1
                            Text {
                                width: parent.width
                                text: eventRow.modelData.title
                                color: panel.theme.textStrong
                                font.family: panel.runtime.fontMono
                                font.pixelSize: panel.theme.fontSize(12)
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                            Text {
                                visible: eventRow.modelData.location.length > 0
                                width: parent.width
                                text: eventRow.modelData.location
                                color: panel.theme.textStrong
                                opacity: 0.85
                                font.family: panel.runtime.fontMono
                                font.pixelSize: panel.theme.fontSize(10)
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }

    Text {
        visible: panel.agenda.events.length > 4
        text: "Events " + (panel.visibleStart + 1) + "–" + panel.visibleEnd + " of " + panel.agenda.events.length + " · U/D scroll"
        color: panel.theme.textStrong
        font.family: panel.runtime.fontMono
        font.pixelSize: panel.theme.fontSize(10)
    }
}

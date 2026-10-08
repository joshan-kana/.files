pragma ComponentBehavior: Bound
import QtQuick

Column {
    id: panel

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property AgendaState agenda
    required property string startDate

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
            color: panel.theme.textMuted
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(10)
        }
    }

    ShellSurface {
        width: parent.width
        height: panel.agenda.events.length > 0 && panel.agenda.configured && panel.agenda.errorMessage.length === 0 ? Math.min(4, panel.agenda.events.length) * 54 + panel.theme.spacing2 : 72
        theme: panel.theme
        motion: panel.motion
        surfaceLayer: ShellSurface.Group
        cornerRadius: panel.theme.radiusMedium

        Text {
            anchors.centerIn: parent
            visible: panel.agenda.events.length === 0 || !panel.agenda.configured || panel.agenda.errorMessage.length > 0
            width: parent.width - panel.theme.spacing4 * 2
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: panel.agenda.errorMessage || (panel.agenda.loading ? "Reading calendar…" : (panel.agenda.configured ? "No upcoming events" : "Configure a local khal calendar to show events"))
            color: panel.theme.textMuted
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(11)
        }

        Column {
            anchors {
                fill: parent
                margins: panel.theme.spacing1
            }
            visible: panel.agenda.configured && panel.agenda.errorMessage.length === 0
            spacing: 0

            Repeater {
                model: panel.agenda.events.slice(0, 4)
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
                                color: panel.theme.textMuted
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
        text: "+ " + (panel.agenda.events.length - 4) + " more events"
        color: panel.theme.textMuted
        font.family: panel.runtime.fontMono
        font.pixelSize: panel.theme.fontSize(10)
    }
}

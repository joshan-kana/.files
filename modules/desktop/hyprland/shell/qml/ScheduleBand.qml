pragma ComponentBehavior: Bound
import QtQuick
import "ClockFormatting.js" as ClockFormatting

ShellSurface {
    id: band
    required property RuntimeConfig runtime
    required property int startMinute
    required property int endMinute
    property string label: "Schedule"
    property bool scheduleEnabled: true
    property color phaseColor: theme.roleColor("schedule")
    surfaceLayer: ShellSurface.Group
    cornerRadius: theme.radiusMedium
    implicitHeight: content.implicitHeight + theme.spacing3 * 2
    Accessible.role: Accessible.StaticText
    Accessible.name: label + ", " + ClockFormatting.minutesLabel(startMinute) + " to " + ClockFormatting.minutesLabel(endMinute)

    Column {
        id: content
        width: parent.width - band.theme.spacing3 * 2
        anchors.centerIn: parent
        spacing: band.theme.spacing2
        Row {
            width: parent.width
            spacing: band.theme.spacing2
            Column {
                width: (parent.width - parent.spacing) / 2
                ShellText {
                    runtime: band.runtime
                    theme: band.theme
                    text: "Starts"
                    textRole: ShellText.Supporting
                }
                ShellText {
                    runtime: band.runtime
                    theme: band.theme
                    text: ClockFormatting.minutesLabel(band.startMinute)
                    textRole: ShellText.Readback
                }
            }
            Column {
                width: (parent.width - parent.spacing) / 2
                ShellText {
                    runtime: band.runtime
                    theme: band.theme
                    text: "Ends"
                    textRole: ShellText.Supporting
                }
                ShellText {
                    runtime: band.runtime
                    theme: band.theme
                    text: ClockFormatting.minutesLabel(band.endMinute)
                    textRole: ShellText.Readback
                }
            }
        }
        Rectangle {
            width: parent.width
            height: band.theme.prominentTrack
            radius: height / 2
            color: band.theme.layer3
            Repeater {
                model: band.startMinute > band.endMinute ? [[0, band.endMinute], [band.startMinute, 1440]] : [[band.startMinute, band.endMinute]]
                delegate: Rectangle {
                    required property var modelData
                    x: parent.width * modelData[0] / 1440
                    width: parent.width * Math.max(0, modelData[1] - modelData[0]) / 1440
                    height: parent.height
                    radius: height / 2
                    color: band.phaseColor
                    opacity: band.scheduleEnabled ? 1 : 0.35
                }
            }
        }
        Item {
            width: parent.width
            height: band.theme.fontSize(18)
            Repeater {
                model: ["12 AM", "6 AM", "12 PM", "6 PM", "12 AM"]
                delegate: ShellText {
                    required property int index
                    required property string modelData
                    width: implicitWidth
                    x: index === 0 ? 0 : index === 4 ? parent.width - width : parent.width * index / 4 - width / 2
                    runtime: band.runtime
                    theme: band.theme
                    text: modelData
                    textRole: ShellText.Utility
                }
            }
        }
    }
}

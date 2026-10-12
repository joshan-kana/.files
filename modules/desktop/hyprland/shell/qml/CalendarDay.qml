import QtQuick

ShellSurface {
    id: cell

    property int day: 1
    property string heading: ""
    property int dayState: 0
    property bool picked: false
    property bool header: false

    signal activated

    implicitWidth: 42
    implicitHeight: 42
    surfaceLayer: ShellSurface.Control
    selected: false
    cornerRadius: theme.radiusMedium
    borderColor: picked ? (dayState === 1 ? theme.textStrong : theme.accent) : "transparent"
    borderWidth: picked ? theme.borderFocus : 0

    fillColor: dayState === 1 ? theme.accent : (hover.hovered && !header ? theme.layer3 : "transparent")

    Text {
        anchors.centerIn: parent
        text: cell.header ? cell.heading : String(cell.day)
        color: cell.dayState === 1 ? cell.theme.background : (cell.picked ? cell.theme.accent : (cell.dayState === -1 ? cell.theme.textMuted : cell.theme.textStrong))
        opacity: cell.dayState === -1 ? 0.48 : 1
        font.family: cell.theme.runtime.fontMono
        font.pixelSize: cell.theme.fontSize(cell.header ? 10 : cell.width < 36 ? 11 : 14)
        font.weight: cell.header || cell.picked || cell.dayState === 1 ? Font.DemiBold : Font.Medium
    }

    HoverHandler {
        id: hover
        enabled: !cell.header
    }

    MouseArea {
        anchors.fill: parent
        enabled: !cell.header
        cursorShape: Qt.PointingHandCursor
        onClicked: cell.activated()
    }
}

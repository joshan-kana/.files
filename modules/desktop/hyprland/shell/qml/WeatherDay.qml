pragma ComponentBehavior: Bound
import QtQuick

ShellSurface {
    id: dayCard

    required property WeatherState weather
    required property var day
    required property int index
    property bool active: false

    signal activated

    implicitWidth: 74
    implicitHeight: 134
    surfaceLayer: ShellSurface.Control
    cornerRadius: theme.radiusMedium
    fillColor: active ? theme.selectionFill : theme.layer2
    outlined: active

    Column {
        anchors.centerIn: parent
        spacing: dayCard.theme.spacing2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: dayCard.index === 0 ? "TODAY" : Qt.formatDate(new Date(dayCard.day.date + "T12:00:00"), "ddd").toUpperCase()
            color: dayCard.active ? dayCard.theme.accent : dayCard.theme.textStrong
            font.family: dayCard.theme.runtime.fontMono
            font.pixelSize: dayCard.theme.fontSize(12)
            font.weight: Font.DemiBold
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: dayCard.weather.symbolFor(dayCard.day.code, true)
            color: dayCard.theme.accent
            font.family: "Symbols Nerd Font"
            font.pixelSize: dayCard.theme.fontSize(30)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(dayCard.day.high) + "°  " + Math.round(dayCard.day.low) + "°"
            color: dayCard.theme.textStrong
            font.family: dayCard.theme.runtime.fontMono
            font.pixelSize: dayCard.theme.fontSize(13)
            font.weight: Font.DemiBold
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(dayCard.day.rain ?? 0) + "% rain"
            color: dayCard.theme.accent
            font.family: dayCard.theme.runtime.fontMono
            font.pixelSize: dayCard.theme.fontSize(11)
            font.weight: Font.DemiBold
        }
    }

    StateLayer {
        theme: dayCard.theme
        motion: dayCard.motion
        selected: dayCard.active
        cornerRadius: dayCard.theme.radiusMedium
        onActivated: dayCard.activated()
    }
}

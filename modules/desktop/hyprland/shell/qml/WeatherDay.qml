pragma ComponentBehavior: Bound
import QtQuick

ShellSurface {
    id: dayCard

    required property WeatherState weather
    required property var day
    required property int index
    property real lowBound: day.low
    property real highBound: day.high
    readonly property real span: Math.max(1, highBound - lowBound)

    implicitWidth: 74
    implicitHeight: Math.max(38, theme.fontSize(42))
    surfaceLayer: ShellSurface.Control
    fillColor: index === 0 ? theme.blend(theme.controlBase, theme.roleColor("weather"), theme.dark ? 0.09 : 0.05) : theme.layer2

    Accessible.role: Accessible.StaticText
    Accessible.name: Qt.formatDate(new Date(day.date + "T12:00:00"), "dddd, d MMMM") + ", " + weather.conditionFor(day.code) + ", " + Math.round(day.rain ?? 0) + "% chance of precipitation, " + weather.temperatureText(day.low) + " to " + weather.temperatureText(day.high)

    Row {
        anchors.fill: parent
        anchors.leftMargin: dayCard.theme.spacing3
        anchors.rightMargin: dayCard.theme.spacing3
        spacing: dayCard.theme.spacing2
        Text {
            width: dayCard.theme.fontSize(56)
            anchors.verticalCenter: parent.verticalCenter
            text: dayCard.index === 0 ? "Today" : Qt.formatDate(new Date(dayCard.day.date + "T12:00:00"), "ddd")
            color: dayCard.theme.textStrong
            font.family: dayCard.theme.runtime.fontSans
            font.pixelSize: dayCard.theme.fontAction
            font.weight: Font.DemiBold
        }
        Text {
            width: dayCard.theme.fontSize(30)
            anchors.verticalCenter: parent.verticalCenter
            text: dayCard.weather.symbolFor(dayCard.day.code, true)
            color: dayCard.theme.weatherColor(dayCard.day.code, true)
            font.family: "Symbols Nerd Font"
            font.pixelSize: dayCard.theme.fontSize(24)
        }
        Text {
            id: rain
            width: implicitWidth
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(dayCard.day.rain ?? 0) + "%"
            color: dayCard.theme.readableRoleColor("precipitation")
            font.family: dayCard.theme.runtime.fontMono
            font.pixelSize: dayCard.theme.fontSupporting
        }
        Text {
            id: lowLabel
            width: dayCard.theme.fontSize(48)
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
            text: dayCard.weather.temperatureText(dayCard.day.low)
            color: dayCard.theme.readableRoleColor("cold")
            font.family: dayCard.theme.runtime.fontMono
            font.pixelSize: dayCard.theme.fontAction
        }
        Rectangle {
            width: Math.max(1, parent.width - dayCard.theme.fontSize(56 + 30 + 48 + 48) - rain.width - parent.spacing * 5)
            height: dayCard.theme.standardTrack
            anchors.verticalCenter: parent.verticalCenter
            radius: height / 2
            color: dayCard.theme.layer3
            Rectangle {
                x: parent.width * Math.max(0, (dayCard.day.low - dayCard.lowBound) / dayCard.span)
                width: Math.max(2, parent.width * (dayCard.day.high - dayCard.day.low) / dayCard.span)
                height: parent.height
                radius: height / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: dayCard.theme.roleColor("cold")
                    }
                    GradientStop {
                        position: 1
                        color: dayCard.theme.roleColor("temperature")
                    }
                }
            }
        }
        Text {
            width: dayCard.theme.fontSize(48)
            anchors.verticalCenter: parent.verticalCenter
            text: dayCard.weather.temperatureText(dayCard.day.high)
            color: dayCard.theme.readableRoleColor("temperature")
            font.family: dayCard.theme.runtime.fontMono
            font.pixelSize: dayCard.theme.fontAction
            font.weight: Font.DemiBold
        }
    }
}

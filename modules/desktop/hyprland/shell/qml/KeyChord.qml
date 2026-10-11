import QtQuick
import QtQuick.Layouts
import "KeyGlyphs.js" as KeyGlyphs

Item {
    id: root

    required property string shortcut
    required property string fontFamily
    property color textColor: "white"
    property real fontSize: 16
    property int fontWeight: Font.DemiBold
    property real modifierScale: 1.3
    property real chordSpacing: 5

    readonly property var parts: KeyGlyphs.parts(shortcut)

    implicitWidth: chord.implicitWidth
    implicitHeight: chord.implicitHeight

    RowLayout {
        id: chord
        anchors.centerIn: parent
        spacing: root.parts.modifiers.length > 0 && root.parts.key.length > 0 ? root.chordSpacing : 0

        Text {
            visible: root.parts.modifiers.length > 0
            text: root.parts.modifiers
            color: root.textColor
            font.family: root.fontFamily
            font.pixelSize: Math.round(root.fontSize * root.modifierScale)
            font.weight: root.fontWeight
            Layout.alignment: Qt.AlignBaseline
        }

        Text {
            visible: root.parts.key.length > 0
            text: root.parts.key
            color: root.textColor
            font.family: root.fontFamily
            font.pixelSize: root.fontSize
            font.weight: root.fontWeight
            Layout.alignment: Qt.AlignBaseline
        }
    }
}

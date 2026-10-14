import QtQuick

// Present one visible shortcut and its action on the same optical centreline.
// The parent controls placement; this component owns all keycap geometry.
Item {
    id: hint
    required property RuntimeConfig runtime
    required property Theme theme
    required property string shortcut
    property string label: ""
    property bool showLabel: label.length > 0
    property bool compact: false
    property bool emphasized: false
    property bool available: true

    implicitWidth: cap.width + (showLabel ? theme.keyHintGap + caption.implicitWidth : 0)
    implicitHeight: Math.max(cap.height, showLabel ? caption.implicitHeight : 0)
    opacity: available ? 1 : 0.55

    Rectangle {
        id: cap
        height: hint.compact ? Math.max(20, hint.theme.keycapHeight - 5) : hint.theme.keycapHeight
        width: chord.implicitWidth + (hint.compact ? Math.max(8, hint.theme.keycapInset * 2 - 4) : hint.theme.keycapInset * 2)
        radius: Math.min(9, height / 3)
        anchors.verticalCenter: parent.verticalCenter
        color: hint.emphasized ? hint.theme.selectionFill : hint.theme.controlBase
        border.width: hint.emphasized ? hint.theme.borderFocus : hint.theme.borderThin
        border.color: hint.emphasized ? hint.theme.accent : hint.theme.subtleBorder

        KeyChord {
            id: chord
            anchors.centerIn: parent
            shortcut: hint.shortcut
            fontFamily: hint.runtime.fontMono
            fontSize: hint.compact ? hint.theme.fontSize(9) : hint.theme.fontKeyHint
            modifierScale: 1
            textColor: hint.emphasized ? hint.theme.accent : hint.theme.textStrong
        }
    }

    Text {
        id: caption
        x: cap.width + hint.theme.keyHintGap
        anchors.verticalCenter: parent.verticalCenter
        visible: hint.showLabel
        text: hint.label
        color: hint.theme.textMuted
        font.family: hint.runtime.fontMono
        font.pixelSize: hint.theme.fontKeyHint
        font.weight: Font.Medium
    }
}

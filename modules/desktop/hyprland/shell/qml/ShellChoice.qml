import QtQuick

// A mutually exclusive choice, not a command. Its owner supplies confirmed
// selection; activation never changes selection optimistically.
ShellAction {
    id: choice
    property Repeater choices: null
    property int choiceIndex: -1
    property bool joined: true
    activeColor: theme.choiceColor
    connectedGroup: joined
    actionFill: active ? theme.choiceFill(activeColor) : theme.expressiveSurfaceStrong
    actionForeground: active ? theme.choiceForeground(activeColor) : theme.textStrong
    labelAlignment: joined ? Text.AlignHCenter : Text.AlignLeft
    restingRadius: active && joined ? height / 2 : joined && choices !== null && choiceIndex > 0 && choiceIndex < choices.count - 1 ? theme.spacing2 : theme.radiusMedium
    neighborPressed: joined && choices !== null && ((choices.itemAt(choiceIndex - 1) as ShellAction)?.visualPressed === true || (choices.itemAt(choiceIndex + 1) as ShellAction)?.visualPressed === true)
    Accessible.role: Accessible.RadioButton
    Accessible.checkable: true
    Accessible.checked: active
}

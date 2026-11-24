pragma ComponentBehavior: Bound
import QtQuick
import "DesktopIcons.js" as DesktopIcons

Row {
    id: stepper
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property string title
    required property string readback
    required property string decreaseShortcut
    required property string increaseShortcut
    property bool canDecrease: true
    property bool canIncrease: true
    property real readbackWidth: theme.fontSize(78)
    signal decreased
    signal increased
    spacing: theme.spacing1
    function decrease(): void {
        down.trigger();
    }
    function increase(): void {
        up.trigger();
    }
    ShellAction {
        id: down
        width: implicitWidth
        height: implicitHeight
        anchors.verticalCenter: parent.verticalCenter
        runtime: stepper.runtime
        theme: stepper.theme
        motion: stepper.motion
        iconOnly: true
        inlineIconHint: true
        compact: true
        icon: DesktopIcons.actionGlyph("decrease")
        title: "Decrease " + stepper.title.toLowerCase()
        shortcut: stepper.decreaseShortcut
        enabled: stepper.canDecrease
        onActivated: stepper.decreased()
    }
    Column {
        width: Math.max(stepper.readbackWidth, valueText.implicitWidth, titleText.implicitWidth)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        ShellText {
            id: titleText
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            runtime: stepper.runtime
            theme: stepper.theme
            text: stepper.title
            textRole: ShellText.Utility
        }
        ShellText {
            id: valueText
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            runtime: stepper.runtime
            theme: stepper.theme
            text: stepper.readback
            textRole: ShellText.Readback
        }
    }
    ShellAction {
        id: up
        width: implicitWidth
        height: implicitHeight
        anchors.verticalCenter: parent.verticalCenter
        runtime: stepper.runtime
        theme: stepper.theme
        motion: stepper.motion
        iconOnly: true
        inlineIconHint: true
        compact: true
        icon: DesktopIcons.actionGlyph("increase")
        title: "Increase " + stepper.title.toLowerCase()
        shortcut: stepper.increaseShortcut
        enabled: stepper.canIncrease
        onActivated: stepper.increased()
    }
}

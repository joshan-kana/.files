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
    property bool fillAvailableWidth: false
    property real readbackWidth: theme.fontSize(78)
    signal decreased
    signal increased
    spacing: Math.max(2, theme.spacing1 / 2)
    function decrease(): void {
        down.trigger();
    }
    function increase(): void {
        up.trigger();
    }
    ShellAction {
        id: down
        width: Math.max(implicitWidth, stepper.fillAvailableWidth ? stepper.theme.fontSize(72) : 0)
        height: readbackSurface.height
        anchors.verticalCenter: parent.verticalCenter
        runtime: stepper.runtime
        theme: stepper.theme
        motion: stepper.motion
        iconOnly: true
        inlineIconHint: true
        compact: true
        connectedGroup: true
        restingRadius: height / 2
        neighborPressed: up.visualPressed
        icon: DesktopIcons.actionGlyph("decrease")
        title: "Decrease " + stepper.title.toLowerCase()
        shortcut: stepper.decreaseShortcut
        enabled: stepper.canDecrease
        onActivated: stepper.decreased()
    }
    ShellSurface {
        id: readbackSurface
        width: Math.max(stepper.readbackWidth, valueText.implicitWidth + stepper.theme.spacing2 * 2, titleText.implicitWidth + stepper.theme.spacing2 * 2, stepper.fillAvailableWidth ? stepper.width - down.width - up.width - stepper.spacing * 2 : 0)
        height: Math.max(down.implicitHeight, up.implicitHeight, labels.implicitHeight + stepper.theme.spacing2 * 2)
        anchors.verticalCenter: parent.verticalCenter
        theme: stepper.theme
        motion: stepper.motion
        surfaceLayer: ShellSurface.Control
        fillColor: stepper.theme.layer1
        cornerRadius: stepper.theme.spacing2
        Accessible.role: Accessible.StaticText
        Accessible.name: stepper.title + ", " + stepper.readback
        Column {
            id: labels
            anchors.centerIn: parent
            width: Math.max(1, readbackSurface.width - stepper.theme.spacing2 * 2)
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
    }
    ShellAction {
        id: up
        width: Math.max(implicitWidth, stepper.fillAvailableWidth ? stepper.theme.fontSize(72) : 0)
        height: readbackSurface.height
        anchors.verticalCenter: parent.verticalCenter
        runtime: stepper.runtime
        theme: stepper.theme
        motion: stepper.motion
        iconOnly: true
        inlineIconHint: true
        compact: true
        connectedGroup: true
        restingRadius: height / 2
        neighborPressed: down.visualPressed
        icon: DesktopIcons.actionGlyph("increase")
        title: "Increase " + stepper.title.toLowerCase()
        shortcut: stepper.increaseShortcut
        enabled: stepper.canIncrease
        onActivated: stepper.increased()
    }
}

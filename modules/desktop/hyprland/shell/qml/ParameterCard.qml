pragma ComponentBehavior: Bound
import QtQuick
import "DesktopIcons.js" as DesktopIcons

ShellSurface {
    id: card
    required property RuntimeConfig runtime
    required property string title
    property string description: ""
    required property string readback
    required property real from
    required property real to
    required property real value
    property color accentColor: theme.accent
    property bool adjustable: true
    property bool temperatureTrack: false
    property bool resetAvailable: true
    property string adjustShortcut: ""
    property string resetShortcut: ""
    property bool selectedParameter: false
    signal selectedRequested
    signal valueRequested(real next)
    signal resetRequested
    function beginKeyboardAdjustment(): void {
        parameterSlider.beginKeyboardAdjustment();
    }

    implicitHeight: parameterContent.implicitHeight + theme.spacing3 * 2
    surfaceLayer: ShellSurface.Control
    cornerRadius: theme.radiusMedium
    outlined: selectedParameter
    borderWidth: outlined ? theme.borderFocus : 0
    borderColor: outlined ? theme.accent : "transparent"
    fillColor: theme.expressiveSurfaceStrong

    HoverHandler {
        id: cardHover
    }
    StateLayer {
        theme: card.theme
        motion: card.motion
        selected: card.selectedParameter
        manualHover: cardHover.hovered
        effectScaleX: 1
        effectScaleY: 1
        cornerRadius: card.cornerRadius
        Accessible.role: Accessible.Button
        Accessible.name: "Select " + card.title
        Accessible.onPressAction: card.selectedRequested()
        onActivated: card.selectedRequested()
    }

    Column {
        id: parameterContent
        width: parent.width - card.theme.spacing3 * 2
        anchors.centerIn: parent
        spacing: card.theme.spacing2

        Row {
            id: parameterHeading
            width: parent.width
            height: Math.max(parameterCopy.implicitHeight, valueReadback.implicitHeight, parameterHint.implicitHeight, resetSlot.height)
            spacing: card.theme.spacing2

            Item {
                id: parameterCopy
                width: Math.max(1, parent.width - valueReadback.implicitWidth - parameterHint.implicitWidth - resetSlot.width - parameterHeading.spacing * 3)
                implicitHeight: copy.implicitHeight
                height: parent.height
                Column {
                    id: copy
                    width: parent.width
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: card.theme.spacing1
                    ShellText {
                        width: parent.width
                        runtime: card.runtime
                        theme: card.theme
                        text: card.title
                        textRole: ShellText.Action
                        wrapMode: Text.WordWrap
                    }
                    ShellText {
                        visible: card.description.length > 0
                        width: parent.width
                        runtime: card.runtime
                        theme: card.theme
                        text: card.description
                        textRole: ShellText.Supporting
                        wrapMode: Text.WordWrap
                    }
                }
            }
            KeyHint {
                id: parameterHint
                opacity: card.selectedParameter ? 1 : 0
                anchors.verticalCenter: parent.verticalCenter
                runtime: card.runtime
                theme: card.theme
                shortcut: card.adjustShortcut
                compact: true
            }
            ShellText {
                id: valueReadback
                anchors.verticalCenter: parent.verticalCenter
                runtime: card.runtime
                theme: card.theme
                text: card.readback
                textRole: ShellText.Readback
                color: card.accentColor
            }
            Item {
                id: resetSlot
                width: card.resetShortcut.length > 0 ? resetAction.implicitWidth : 0
                height: card.resetShortcut.length > 0 ? resetAction.implicitHeight : 0
                anchors.verticalCenter: parent.verticalCenter
                ShellAction {
                    id: resetAction
                    visible: card.selectedParameter && card.resetShortcut.length > 0
                    enabled: visible && card.resetAvailable
                    width: implicitWidth
                    height: implicitHeight
                    runtime: card.runtime
                    theme: card.theme
                    motion: card.motion
                    compact: true
                    iconOnly: true
                    inlineIconHint: true
                    quietAction: true
                    icon: DesktopIcons.actionGlyph("reset")
                    title: "Restore " + card.title.toLowerCase()
                    shortcut: card.resetShortcut
                    onActivated: card.resetRequested()
                }
            }
        }

        ShellSlider {
            id: parameterSlider
            width: parent.width
            height: Math.max(32, implicitHeight)
            theme: card.theme
            motion: card.motion
            from: card.from
            to: card.to
            value: card.value
            enabled: card.adjustable
            accentColor: card.accentColor
            temperatureTrack: card.temperatureTrack
            density: card.temperatureTrack ? ShellSlider.Prominent : ShellSlider.Standard
            Accessible.role: Accessible.Slider
            Accessible.name: card.title + ": " + card.readback
            Accessible.description: card.description
            onInteractionStarted: card.selectedRequested()
            onValueRequested: next => card.valueRequested(next)
        }
    }
}

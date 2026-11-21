pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: help

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property bool open: false
    property string title: "Controls"
    property var bindings: []
    property real backdropRadius: theme.radiusLarge
    property Item contentArea: null
    property bool keyboardScroll: false

    function scrollHints(rows: int): void {
        if (!open)
            return;
        const limit = Math.max(0, hintsViewport.contentHeight - hintsViewport.height);
        hintsViewport.contentY = Math.max(0, Math.min(limit, hintsViewport.contentY + rows * (30 + theme.spacing3)));
    }

    onOpenChanged: {
        if (open)
            hintsViewport.contentY = 0;
    }

    signal dismissed

    z: 200
    visible: opacity > 0.01
    opacity: open ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: help.motion.fast
            easing.type: help.open ? help.motion.enterType : help.motion.exitType
            easing.bezierCurve: help.open ? help.motion.enterCurve : help.motion.exitCurve
        }
    }

    // Use one consistent wash across the hub, so the blurred viewport's
    // card and clipping edges cannot leave separate rectangular bands.
    SquircleSurface {
        anchors.fill: parent
        exponent: help.theme.squircleExponent
        cornerRadius: help.backdropRadius
        fillColor: Qt.rgba(help.theme.background.r, help.theme.background.g, help.theme.background.b, help.theme.shellGlassEnabled ? 0.36 : 0.70)
        borderColor: "transparent"
        borderWidth: 0
    }

    MouseArea {
        anchors.fill: parent
        enabled: help.open
        onClicked: help.dismissed()
    }

    ShellSurface {
        id: helpCard

        width: Math.min((help.contentArea ? help.contentArea.width : parent.width) - theme.spacing5 * 2, 480)
        height: Math.min((help.contentArea ? help.contentArea.height : parent.height) - theme.spacing5 * 2, Math.max(180, content.implicitHeight + theme.spacing5 * 2))
        x: help.contentArea ? help.contentArea.mapToItem(help, 0, 0).x + (help.contentArea.width - width) / 2 : (parent.width - width) / 2
        y: help.contentArea ? help.contentArea.mapToItem(help, 0, 0).y + (help.contentArea.height - height) / 2 : (parent.height - height) / 2
        theme: help.theme
        motion: help.motion
        surfaceLayer: ShellSurface.Group
        cornerRadius: theme.radiusLarge
        elevated: true

        MouseArea {
            anchors.fill: parent
            onClicked: mouse => mouse.accepted = true
        }

        Flickable {
            id: hintsViewport
            anchors {
                fill: parent
                margins: help.theme.spacing5
            }
            contentWidth: width
            contentHeight: content.implicitHeight
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Column {
                id: content
                width: hintsViewport.width
                spacing: help.theme.spacing3

                Text {
                    width: parent.width
                    text: help.title
                    color: help.theme.textStrong
                    font.family: help.runtime.fontMono
                    font.pixelSize: help.theme.fontSize(19)
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: help.theme.subtleBorder
                }

                Repeater {
                    model: help.bindings

                    delegate: Row {
                        id: helpBinding
                        required property var modelData

                        width: content.width
                        spacing: help.theme.spacing3

                        Item {
                            id: shortcutCell
                            width: Math.min(helpBinding.width - 110, Math.max(180, shortcutHint.implicitWidth))
                            height: 34

                            KeyHint {
                                id: shortcutHint
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                runtime: help.runtime
                                theme: help.theme
                                shortcut: helpBinding.modelData.key
                            }
                        }

                        Text {
                            width: parent.width - shortcutCell.width - parent.spacing
                            anchors.verticalCenter: shortcutCell.verticalCenter
                            text: helpBinding.modelData.action
                            color: help.theme.text
                            font.family: help.runtime.fontMono
                            font.pixelSize: help.theme.fontSize(12)
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: help.keyboardScroll ? help.runtime.shellHint("ShellExpansionHost.helpDown") + "/" + help.runtime.shellHint("ShellExpansionHost.helpUp") + " scroll · " + help.runtime.shellHint("ShellExpansionHost.helpPageUp") + "/" + help.runtime.shellHint("ShellExpansionHost.helpPageDown") + " page · " + help.runtime.shellHint("HubTabs.help") + "/" + help.runtime.shellHint("ShellExpansionHost.back") + " return" : help.runtime.shellHint("HubTabs.help") + " or " + help.runtime.shellHint("ShellExpansionHost.back") + " to return"
                    horizontalAlignment: Text.AlignRight
                    color: help.theme.textMuted
                    font.family: help.runtime.fontMono
                    font.pixelSize: help.theme.fontSize(10)
                }
            }
        }
    }
}

pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

Item {
    id: help

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property bool open: false
    property string title: "Controls"
    property var bindings: []
    property real backdropRadius: theme.radiusLarge
    // Sample the hub beneath the translucent Help card, not the wallpaper
    // behind its Wayland layer or the Help overlay itself.
    property Item blurSource: null
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

    SquircleSurface {
        anchors.fill: parent
        exponent: help.theme.squircleExponent
        cornerRadius: help.backdropRadius
        // One panel-shaped scrim across the whole hub, not a rectangle that
        // abruptly stops below the header and above the footer.
        fillColor: Qt.rgba(help.theme.background.r, help.theme.background.g, help.theme.background.b, 0.56)
        borderColor: "transparent"
        borderWidth: 0

        MouseArea {
            anchors.fill: parent
            enabled: help.open
            // The owner binds `open` to its helpOpen state. Do not assign to
            // `open` here: imperative assignment destroys that QML binding.
            onClicked: help.dismissed()
        }
    }

    // Blur only the modal glass itself. The full-hub scrim stays uniform;
    // sampling the entire content viewport made a rectangular blur boundary.
    Item {
        id: glassBackdrop
        visible: help.open && help.theme.shellGlassEnabled && help.blurSource !== null
        x: helpCard.x
        y: helpCard.y
        width: helpCard.width
        height: helpCard.height
        clip: true

        ShaderEffectSource {
            id: blurTexture
            anchors.fill: parent
            sourceItem: help.blurSource
            sourceRect: help.blurSource ? Qt.rect(glassBackdrop.x - help.blurSource.x, glassBackdrop.y - help.blurSource.y, glassBackdrop.width, glassBackdrop.height) : Qt.rect(0, 0, 0, 0)
            live: help.open
            visible: false
        }

        SquircleSurface {
            id: blurMask
            anchors.fill: parent
            cornerRadius: helpCard.cornerRadius
            exponent: help.theme.squircleExponent
            fillColor: "white"
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: blurTexture
            blurEnabled: true
            blurMax: 32
            blur: 0.75
            maskEnabled: true
            maskSource: blurMask
        }
    }

    ShellSurface {
        id: helpCard

        width: Math.min((help.blurSource ? help.blurSource.width : parent.width) - theme.spacing5 * 2, 430)
        height: Math.min((help.blurSource ? help.blurSource.height : parent.height) - theme.spacing5 * 2, Math.max(180, content.implicitHeight + theme.spacing5 * 2))
        x: help.blurSource ? help.blurSource.x + (help.blurSource.width - width) / 2 : (parent.width - width) / 2
        y: help.blurSource ? help.blurSource.y + (help.blurSource.height - height) / 2 : (parent.height - height) / 2
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
                            width: 138
                            height: 34

                            KeyHint {
                                anchors.centerIn: parent
                                runtime: help.runtime
                                theme: help.theme
                                shortcut: helpBinding.modelData.key
                            }
                        }

                        Text {
                            width: parent.width - parent.children[0].width - parent.spacing
                            anchors.verticalCenter: parent.children[0].verticalCenter
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

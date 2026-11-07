pragma ComponentBehavior: Bound
import QtQuick

ShellSurface {
    id: card

    required property MediaState media
    required property RuntimeConfig runtime
    property bool active: false

    signal fullRequested

    readonly property real heroSize: 64
    implicitHeight: media.available ? 178 : 152
    surfaceLayer: ShellSurface.Group
    cornerRadius: theme.radiusLarge
    fillColor: media.available ? theme.blend(theme.groupBase, theme.roleColor("media"), theme.dark ? 0.075 : 0.045) : theme.groupBase

    StateLayer {
        theme: card.theme
        motion: card.motion
        stateColor: card.theme.roleColor("media")
        hoverOpacity: 0.08
        pressOpacity: 0.13
        cornerRadius: card.theme.radiusLarge
        Accessible.role: Accessible.Button
        Accessible.name: "Open Now Playing"
        onActivated: card.fullRequested()
    }

    Timer {
        interval: 1000
        repeat: true
        running: card.active && card.visible && card.media.playing
        onTriggered: card.media.refreshPosition()
    }

    Column {
        anchors {
            fill: parent
            margins: card.theme.spacing3
        }
        spacing: card.theme.spacing2

        Row {
            width: parent.width
            height: card.heroSize
            spacing: card.theme.spacing3

            ShellSurface {
                width: card.heroSize
                height: card.heroSize
                theme: card.theme
                motion: card.motion
                surfaceLayer: ShellSurface.Control
                cornerRadius: card.theme.radiusMedium
                clip: true

                Image {
                    anchors.fill: parent
                    source: card.media.artUrl
                    asynchronous: true
                    cache: true
                    fillMode: Image.PreserveAspectCrop
                    visible: card.media.artUrl.length > 0
                }
                Text {
                    anchors.centerIn: parent
                    visible: card.media.artUrl.length === 0
                    text: "󰎆"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: card.theme.fontSize(27)
                    color: card.theme.roleColor("media")
                }
            }

            Column {
                width: Math.max(1, parent.width - card.heroSize - parent.spacing)
                anchors.verticalCenter: parent.verticalCenter
                spacing: card.theme.spacing1

                Text {
                    width: parent.width
                    text: card.media.available ? card.media.identity : "MEDIA"
                    color: card.theme.readableRoleColor("media")
                    font.family: card.runtime.fontMono
                    font.pixelSize: card.theme.fontSize(10)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                MarqueeText {
                    width: parent.width
                    text: card.media.available ? card.media.title : "No active player"
                    color: card.theme.textStrong
                    font.family: card.runtime.fontMono
                    font.pixelSize: card.theme.fontSize(15)
                    font.weight: Font.DemiBold
                }
                MarqueeText {
                    width: parent.width
                    text: card.media.available ? card.media.artist : "No playback"
                    color: card.theme.textMuted
                    font.family: card.runtime.fontMono
                    font.pixelSize: card.theme.fontSize(11)
                }
            }
        }

        ShellSlider {
            width: parent.width
            height: card.media.available ? 24 : 0
            visible: card.media.available
            theme: card.theme
            motion: card.motion
            value: card.media.length > 0 ? Math.max(0, Math.min(1, card.media.position / card.media.length)) : 0
            enabled: card.media.seekable && card.media.length > 0
            accentColor: card.theme.roleColor("media")
            trackHeight: 7
            handleSize: 16
            Accessible.role: Accessible.Slider
            Accessible.name: "Playback position"
            onInteractionFinished: fraction => card.media.seekTo(card.media.length * fraction)
        }

        Row {
            width: parent.width
            height: 46
            spacing: card.theme.spacing2

            MediaTransport {
                width: implicitWidth
                visible: card.media.available
                anchors.verticalCenter: parent.verticalCenter
                media: card.media
                runtime: card.runtime
                theme: card.theme
                motion: card.motion
                compact: true
                minimal: true
                simple: true
            }

            Item {
                width: Math.max(0, parent.width - (card.media.available ? parent.children[0].implicitWidth : 0) - openHint.implicitWidth - parent.spacing * (card.media.available ? 2 : 1))
                height: 1
            }

            KeyHint {
                id: openHint
                anchors.verticalCenter: parent.verticalCenter
                runtime: card.runtime
                theme: card.theme
                compact: true
                shortcut: "N"
                label: "Open"
            }
        }
    }
}

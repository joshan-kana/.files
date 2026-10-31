pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: chip
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    property string title: ""
    property string icon: ""
    property string shortcut: ""
    property bool active: false
    property color activeColor: theme.accent
    signal activated

    implicitHeight: 104
    Accessible.role: Accessible.Button
    Accessible.name: title

    // Native rounded rectangles avoid SVG tessellation failures when many
    // compact controls simultaneously change their active tone.
    Rectangle {
        id: tile
        anchors.fill: parent
        radius: chip.active ? chip.theme.radiusLarge : chip.theme.radiusMedium
        color: chip.active ? chip.theme.blend(chip.theme.materialPrimaryContainer, chip.activeColor, chip.theme.dark ? 0.36 : 0.25) : chip.theme.blend(chip.theme.materialContainerHigh, chip.theme.textStrong, chip.theme.dark ? 0.16 : 0.065)
        border.color: chip.active ? Qt.rgba(chip.activeColor.r, chip.activeColor.g, chip.activeColor.b, 0.48) : "transparent"
        border.width: chip.active ? chip.theme.borderThin : 0
        Behavior on radius {
            Anim {
                motion: chip.motion
                type: Anim.FastSpatial
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: chip.motion.effectsFast
                easing.type: chip.motion.effectsType
                easing.bezierCurve: chip.motion.effectsCurve
            }
        }

        Rectangle {
            id: symbolContainer
            width: 44
            height: 44
            anchors {
                left: parent.left
                top: parent.top
                margins: chip.theme.spacing3
            }
            radius: chip.active ? 22 : chip.theme.radiusSmall
            color: chip.active ? chip.activeColor : chip.theme.materialContainerHigh
            Behavior on radius {
                Anim {
                    motion: chip.motion
                    type: Anim.FastSpatial
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: chip.motion.effectsFast
                }
            }
            Text {
                anchors.centerIn: parent
                text: chip.icon
                font.family: "Symbols Nerd Font"
                font.pixelSize: chip.theme.fontSize(23)
                color: chip.active ? chip.theme.background : chip.activeColor
            }
        }

        KeyHint {
            visible: chip.shortcut.length > 0
            anchors {
                right: parent.right
                top: parent.top
                margins: chip.theme.spacing3
            }
            shortcut: chip.shortcut
            compact: true
            runtime: chip.runtime
            theme: chip.theme
            emphasized: chip.active
            emphasisColor: chip.activeColor
        }

        Text {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: chip.theme.spacing3
            }
            height: paintedHeight
            verticalAlignment: Text.AlignBottom
            horizontalAlignment: Text.AlignLeft
            text: chip.title
            textFormat: Text.PlainText
            color: chip.theme.textStrong
            font.family: chip.runtime.fontMono
            font.pixelSize: chip.theme.fontSize(14)
            font.weight: chip.active ? Font.Bold : Font.DemiBold
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }

    StateLayer {
        theme: chip.theme
        motion: chip.motion
        selected: false
        stateColor: chip.activeColor
        cornerRadius: tile.radius
        onActivated: chip.activated()
    }
}

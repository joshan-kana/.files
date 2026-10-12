pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    property string currentTab: ""
    readonly property int selectedIndex: currentTab === "home" ? 0 : currentTab === "activity" ? 2 : 1
    signal tabRequested(string destination)

    implicitHeight: 46

    ShellSurface {
        id: track
        width: parent.width
        height: 42
        anchors.horizontalCenter: parent.horizontalCenter
        theme: root.theme
        motion: root.motion
        surfaceLayer: ShellSurface.Control
        cornerRadius: root.theme.radiusLarge
        fillColor: root.theme.expressiveSurface

        SquircleSurface {
            id: slidingSelection
            x: root.theme.spacing1 + (track.width - 2 * root.theme.spacing1) / 3 * root.selectedIndex
            y: root.theme.spacing1
            width: (track.width - 2 * root.theme.spacing1) / 3
            height: track.height - 2 * root.theme.spacing1
            exponent: root.theme.squircleExponent
            cornerRadius: root.theme.radiusLarge
            fillColor: root.theme.blend(root.theme.controlBase, root.theme.accent, root.theme.dark ? 0.52 : 0.34)
            lightColor: root.theme.accent
            lightStrength: 0.14

            Behavior on x {
                Anim {
                    motion: root.motion
                    type: Anim.FastSpatial
                }
            }
        }

        Row {
            anchors {
                fill: parent
                margins: root.theme.spacing1
            }
            spacing: 0

            Repeater {
                model: [
                    {
                        label: "Home",
                        destination: "home"
                    },
                    {
                        label: "Controls",
                        destination: "controls"
                    },
                    {
                        label: "Activity",
                        destination: "activity"
                    }
                ]

                delegate: Item {
                    id: tab
                    required property var modelData
                    required property int index
                    readonly property bool chosen: root.selectedIndex === index
                    width: parent.width / 3
                    height: parent.height
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.label

                    Text {
                        anchors.centerIn: parent
                        text: tab.modelData.label
                        color: tab.chosen ? root.theme.textStrong : root.theme.textMuted
                        font.family: root.runtime.fontMono
                        font.pixelSize: root.theme.fontSize(12)
                        font.weight: tab.chosen ? Font.DemiBold : Font.Medium
                        Behavior on color {
                            ColorAnimation {
                                duration: root.motion.effectsFast
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.tabRequested(tab.modelData.destination)
                    }
                }
            }
        }
    }
}

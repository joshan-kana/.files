pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates

Item {
    id: root

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    property string currentTab: ""

    readonly property int selectedIndex: currentTab === "home" ? 0 : 1

    signal tabRequested(string destination)

    implicitHeight: 48

    TabBar {
        id: tabs
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        implicitHeight: 40
        currentIndex: root.selectedIndex
        background: null

        contentItem: RowLayout {
            spacing: 0

            Repeater {
                model: tabs.contentModel
            }
        }

        Repeater {
            model: [
                {
                    text: "HOME",
                    name: "home"
                },
                {
                    text: "CONTROLS",
                    name: "controls"
                }
            ]

            delegate: TabButton {
                id: tab
                required property var modelData
                readonly property bool chosen: tabs.currentIndex === TabBar.index

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 40
                background: null

                contentItem: Item {
                    ShellSurface {
                        anchors.fill: parent
                        theme: root.theme
                        motion: root.motion
                        surfaceLayer: ShellSurface.Control
                        cornerRadius: root.theme.radiusMedium
                        fillColor: tab.hovered ? root.theme.layer3 : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: tab.modelData.text
                        color: tab.chosen ? root.theme.accent : root.theme.textMuted
                        font.family: root.runtime.fontMono
                        font.pixelSize: root.theme.fontSize(11)
                        font.weight: tab.chosen ? Font.DemiBold : Font.Medium
                    }
                }

                onClicked: root.tabRequested(modelData.name)
            }
        }
    }

    Item {
        id: indicator
        anchors.top: tabs.bottom
        anchors.topMargin: root.theme.spacing1
        width: tabs.width / 2
        height: 3
        x: tabs.width / 2 * root.selectedIndex

        Behavior on x {
            Anim {
                motion: root.motion
                type: Anim.FastSpatial
            }
        }

        SquircleSurface {
            anchors.fill: parent
            cornerRadius: 2
            exponent: root.theme.squircleExponent
            fillColor: root.theme.accent
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Variants {
    id: bars

    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion
    required property QtObject media
    required property QtObject spectrum
    required property QtObject system

    signal mediaRequested
    signal systemRequested

    model: Quickshell.screens

    delegate: PanelWindow {
        id: bar

        required property var modelData

        screen: modelData

        readonly property QtObject runtime: bars.runtime
        readonly property QtObject theme: bars.theme
        readonly property QtObject motion: bars.motion
        readonly property QtObject media: bars.media
        readonly property QtObject spectrum: bars.spectrum
        readonly property QtObject system: bars.system
        readonly property var hyprMonitor: Hyprland.monitorFor(modelData)

        implicitHeight: 56
        color: "transparent"
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 56

        anchors {
            top: true
            left: true
            right: true
        }

        WlrLayershell.namespace: "linux-desktop-bar"

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        readonly property int focusedWorkspaceId: hyprMonitor && hyprMonitor.activeWorkspace ? hyprMonitor.activeWorkspace.id : 1
        readonly property var normalWorkspaces: Hyprland.workspaces.values.filter(workspace => workspace.id > 0).sort((a, b) => a.id - b.id)

        Item {
            anchors.fill: parent
            anchors {
                leftMargin: 14
                rightMargin: 14
                topMargin: 8
                bottomMargin: 8
            }

            SquircleSurface {
                id: workspaceIsland

                width: workspaceRow.implicitWidth + theme.spacing3 * 2
                height: parent.height
                anchors.left: parent.left

                exponent: theme.squircleExponent
                cornerRadius: theme.radiusMedium
                fillColor: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.92)
                borderColor: theme.subtleBorder
                borderWidth: theme.borderThin

                Row {
                    id: workspaceRow
                    anchors.centerIn: parent
                    spacing: 6

                    Repeater {
                        model: bar.normalWorkspaces

                        delegate: Item {
                            id: workspace
                            required property var modelData

                            readonly property int number: modelData.id
                            readonly property bool active: bar.focusedWorkspaceId === number

                            width: active ? 28 : 16
                            height: 28

                            MouseArea {
                                anchors.fill: parent
                                z: 1
                                cursorShape: Qt.PointingHandCursor
                                onClicked: workspace.modelData.activate()
                            }

                            SquircleSurface {
                                anchors.centerIn: parent
                                width: workspace.active ? 28 : 8
                                height: workspace.active ? 28 : 8

                                exponent: theme.squircleExponent
                                cornerRadius: workspace.active ? 9 : 4
                                fillColor: workspace.active ? theme.accent : Qt.rgba(theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 0.55)
                                borderColor: workspace.active ? Qt.rgba(theme.textStrong.r, theme.textStrong.g, theme.textStrong.b, 0.16) : "transparent"
                                borderWidth: workspace.active ? 1 : 0

                                Behavior on width {
                                    NumberAnimation {
                                        duration: motion.fast
                                        easing.type: motion.enterType
                                    }
                                }

                                Behavior on height {
                                    NumberAnimation {
                                        duration: motion.fast
                                        easing.type: motion.enterType
                                    }
                                }

                                Behavior on fillColor {
                                    ColorAnimation {
                                        duration: motion.fast
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: workspace.active
                                    text: workspace.number
                                    color: theme.background
                                    font.family: runtime.fontSans
                                    font.pixelSize: theme.fontSize(11)
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }
            }

            NowPlayingIsland {
                id: mediaIsland

                anchors {
                    left: workspaceIsland.right
                    leftMargin: theme.spacing3
                    verticalCenter: parent.verticalCenter
                }

                runtime: bar.runtime
                theme: bar.theme
                motion: bar.motion
                media: bar.media
                spectrum: bar.spectrum
                onActivated: bars.mediaRequested()
            }

            SquircleSurface {
                id: clockIsland

                width: 184
                height: parent.height
                anchors.horizontalCenter: parent.horizontalCenter

                exponent: theme.squircleExponent
                cornerRadius: theme.radiusMedium
                fillColor: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.92)
                borderColor: theme.subtleBorder
                borderWidth: theme.borderThin

                Row {
                    anchors.centerIn: parent
                    spacing: theme.spacing2

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(clock.date, "ddd d MMM")
                        color: theme.textMuted
                        font.family: runtime.fontSans
                        font.pixelSize: theme.fontSize(11)
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4
                        height: 4
                        radius: 2
                        color: theme.accent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        color: theme.textStrong
                        font.family: runtime.fontSans
                        font.pixelSize: theme.fontSize(13)
                        font.weight: Font.DemiBold
                    }
                }
            }

            SystemIsland {
                id: systemIsland

                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

                runtime: bar.runtime
                theme: bar.theme
                motion: bar.motion
                system: bar.system
                onActivated: bars.systemRequested()
            }
        }
    }
}

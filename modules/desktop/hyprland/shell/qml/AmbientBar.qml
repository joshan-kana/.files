import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: bar

    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion
    required property QtObject media
    required property QtObject system

    signal mediaRequested()
    signal systemRequested()

    implicitHeight: 64
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 64

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

    readonly property int focusedWorkspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    Item {
        anchors.fill: parent
        anchors {
            leftMargin: 14
            rightMargin: 14
            topMargin: 10
            bottomMargin: 10
        }

        SquircleSurface {
            id: workspaceIsland

            width: 348
            height: parent.height
            anchors.left: parent.left

            exponent: theme.squircleExponent
            cornerRadius: theme.radiusMedium
            fillColor: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.94)
            borderColor: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.76)
            borderWidth: theme.borderThin

            Row {
                anchors.centerIn: parent
                spacing: 5

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "WS"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.5
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 20
                    color: theme.outline
                }

                Repeater {
                    model: 10

                    delegate: Item {
                        id: workspace
                        required property int index

                        readonly property int number: index + 1
                        readonly property bool active: bar.focusedWorkspaceId === number

                        width: 24
                        height: 28

                        SquircleSurface {
                            anchors.centerIn: parent
                            width: workspace.active ? 24 : 9
                            height: workspace.active ? 24 : 9

                            exponent: theme.squircleExponent
                            cornerRadius: workspace.active ? 8 : 4.5
                            fillColor: workspace.active ? theme.accent : theme.outline
                            borderColor: workspace.active ? Qt.rgba(theme.textStrong.r, theme.textStrong.g, theme.textStrong.b, 0.18) : "transparent"
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
                                font.family: runtime.fontMono
                                font.pixelSize: 11
                                font.weight: Font.Bold
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
            onActivated: bar.mediaRequested()
        }

        SquircleSurface {
            id: clockIsland

            width: 236
            height: parent.height
            anchors.horizontalCenter: parent.horizontalCenter

            exponent: theme.squircleExponent
            cornerRadius: theme.radiusMedium
            fillColor: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.94)
            borderColor: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.76)
            borderWidth: theme.borderThin

            Row {
                anchors.centerIn: parent
                spacing: theme.spacing2

                Text {
                    text: Qt.formatDateTime(clock.date, "ddd dd MMM").toUpperCase()
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: 11
                    font.letterSpacing: 1.1
                }

                Text {
                    text: "//"
                    color: theme.accent
                    font.family: runtime.fontMono
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }

                Text {
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: theme.textStrong
                    font.family: runtime.fontMono
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
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
            onActivated: bar.systemRequested()
        }

    }
}

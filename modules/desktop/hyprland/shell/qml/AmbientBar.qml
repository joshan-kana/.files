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

    property bool shown: true
    property var origins: ({})

    signal mediaRequested(var screen, var origin)
    signal systemRequested(var screen, var origin)

    function screenKey(screen: var): string {
        return screen && screen.name ? String(screen.name) : "";
    }

    function setOrigin(screen: var, name: string, center: real, width: real, height: real): void {
        const key = screenKey(screen);
        if (key.length === 0)
            return;

        const next = Object.assign({}, origins);
        const screenOrigins = Object.assign({}, next[key] || {});
        screenOrigins[name] = {
            center: center,
            width: width,
            height: height
        };
        next[key] = screenOrigins;
        origins = next;
    }

    function originFor(screen: var, name: string): var {
        const key = screenKey(screen);
        const value = key.length > 0 && origins[key] ? origins[key][name] : null;
        if (value)
            return value;

        return {
            center: screen ? screen.width / 2 : 0,
            width: 40,
            height: 40
        };
    }

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

        function publishOrigins(): void {
            if (!barContent || !mediaIsland || !systemIsland)
                return;

            bars.setOrigin(modelData, "media", barContent.x + mediaIsland.x + mediaIsland.width / 2, mediaIsland.width, mediaIsland.height);
            bars.setOrigin(modelData, "system", barContent.x + systemIsland.x + systemIsland.width / 2, systemIsland.width, systemIsland.height);
        }

        Component.onCompleted: Qt.callLater(publishOrigins)
        onWidthChanged: Qt.callLater(publishOrigins)

        visible: bars.shown
        implicitHeight: 56
        color: "transparent"
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: bars.shown ? 56 : 0

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
            id: barContent

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
                                    font.family: runtime.fontMono
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
                onXChanged: Qt.callLater(bar.publishOrigins)
                onWidthChanged: Qt.callLater(bar.publishOrigins)
                onActivated: bars.mediaRequested(bar.modelData, bars.originFor(bar.modelData, "media"))
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
                        color: theme.accent
                        font.family: runtime.fontMono
                        font.pixelSize: theme.fontSize(13)
                        font.weight: Font.Medium
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4
                        height: 4
                        radius: 2
                        color: theme.warning
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(clock.date, "h:mm AP")
                        color: theme.textStrong
                        font.family: runtime.fontMono
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
                onXChanged: Qt.callLater(bar.publishOrigins)
                onWidthChanged: Qt.callLater(bar.publishOrigins)
                onActivated: bars.systemRequested(bar.modelData, bars.originFor(bar.modelData, "system"))
            }
        }
    }
}

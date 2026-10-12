pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Variants {
    id: bars

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property MediaState media
    required property SpectrumState spectrum
    required property SystemState system
    required property PowerProfileState powerProfile
    required property NotificationState notificationState

    property bool shown: true

    onShownChanged: {
        if (!shown)
            system.idleInhibited = false;
    }
    property var origins: ({})

    signal mediaRequested(var screen, var origin)
    signal systemRequested(var screen, var origin)
    signal trayMenuRequested(var screen, var origin, int index)
    signal calendarRequested(var screen, var origin)
    signal notificationsRequested(var screen, var origin)

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
        readonly property NotificationState notificationState: bars.notificationState
        readonly property var hyprMonitor: Hyprland.monitorFor(modelData)

        function publishOrigins(): void {
            if (!barContent || !mediaIsland || !systemIsland)
                return;

            bars.setOrigin(modelData, "media", barContent.x + mediaIsland.x + mediaIsland.width / 2, mediaIsland.width, mediaIsland.height);
            bars.setOrigin(modelData, "system", barContent.x + systemIsland.x + systemIsland.width / 2, systemIsland.width, systemIsland.height);
            bars.setOrigin(modelData, "calendar", barContent.x + clockIsland.x + clockIsland.width / 2, clockIsland.width, clockIsland.height);
            bars.setOrigin(modelData, "activity", barContent.x + notificationIsland.x + notificationIsland.width / 2, notificationIsland.width, notificationIsland.height);
        }

        Component.onCompleted: Qt.callLater(publishOrigins)
        onWidthChanged: Qt.callLater(publishOrigins)

        visible: bars.shown
        implicitHeight: 62
        color: "transparent"
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: bars.shown ? 62 : 0

        anchors {
            top: true
            left: true
            right: true
        }

        WlrLayershell.namespace: "linux-desktop-bar"

        // Wayland manages the inhibitor with the existing bar surface's lifetime.
        IdleInhibitor {
            window: bar
            enabled: bars.system.idleInhibited && bar.visible
        }

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        readonly property int focusedWorkspaceId: hyprMonitor && hyprMonitor.activeWorkspace ? hyprMonitor.activeWorkspace.id : 1
        readonly property var normalWorkspaces: Hyprland.workspaces.values.filter(workspace => workspace.id > 0).sort((a, b) => a.id - b.id)
        // Workspace pills lose detail before competing with the centred clock.
        // Display only real workspaces. Hyprland creates workspace objects
        // for occupied or currently active workspaces; do not manufacture slots.
        readonly property var workspaceIds: normalWorkspaces.map(workspace => workspace.id)
        readonly property real fullWorkspaceWidth: workspaceIds.length > 0 ? 37 + Math.max(0, workspaceIds.length - 1) * 31 + bars.theme.spacing3 * 2 : 0

        Item {
            id: barContent

            anchors.fill: parent
            anchors {
                leftMargin: 17
                rightMargin: 17
                topMargin: 14
                bottomMargin: 8
            }

            ShellSurface {
                id: workspaceIsland

                width: workspaceRow.implicitWidth + theme.spacing3 * 2
                height: parent.height
                anchors.left: parent.left

                theme: (bar.theme as Theme)
                motion: (bar.motion as Motion)
                surfaceLayer: ShellSurface.Pane
                cornerRadius: theme.radiusIsland
                exponent: Math.min(4, theme.squircleExponent)
                luminous: true
                luminousColor: theme.accent
                hovered: workspaceHover.hovered

                HoverHandler {
                    id: workspaceHover
                }
                StateLayer {
                    theme: bars.theme
                    motion: bars.motion
                    cornerRadius: bars.theme.radiusIsland
                    manualHover: workspaceHover.hovered
                    onActivated: {
                        if (bar.hyprMonitor && bar.hyprMonitor.activeWorkspace)
                            bar.hyprMonitor.activeWorkspace.activate();
                    }
                }

                Row {
                    id: workspaceRow
                    z: 1
                    anchors.centerIn: parent
                    spacing: 6

                    Repeater {
                        model: bar.fullWorkspaceWidth <= clockIsland.x - bars.theme.spacing3 ? bar.workspaceIds : [bar.focusedWorkspaceId]

                        delegate: Item {
                            id: workspace
                            required property var modelData

                            readonly property int number: modelData
                            readonly property bool active: bar.focusedWorkspaceId === number

                            width: active ? 37 : 25
                            height: 28

                            MouseArea {
                                anchors.fill: parent
                                z: 1
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Hyprland.dispatch('hl.dsp.focus({ workspace = "' + workspace.number + '" })')
                            }

                            SquircleSurface {
                                anchors.centerIn: parent
                                width: workspace.active ? 37 : 23
                                height: 28

                                exponent: bars.theme.squircleExponent
                                cornerRadius: workspace.active ? 12 : 10
                                fillColor: workspace.active ? bars.theme.accent : "transparent"
                                borderColor: "transparent"
                                borderWidth: 0

                                Behavior on width {
                                    NumberAnimation {
                                        duration: bars.motion.fast
                                        easing.type: bars.motion.enterType
                                        easing.bezierCurve: bars.motion.enterCurve
                                    }
                                }

                                Behavior on height {
                                    NumberAnimation {
                                        duration: bars.motion.fast
                                        easing.type: bars.motion.enterType
                                        easing.bezierCurve: bars.motion.enterCurve
                                    }
                                }

                                Behavior on fillColor {
                                    ColorAnimation {
                                        duration: bars.motion.fast
                                        easing.type: bars.motion.effectsType
                                        easing.bezierCurve: bars.motion.effectsCurve
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: true
                                    text: workspace.number
                                    color: workspace.active ? bars.theme.background : bars.theme.textMuted
                                    font.family: bars.runtime.fontMono
                                    font.pixelSize: bars.theme.fontSize(11)
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }
            }

            NowPlayingIsland {
                id: mediaIsland

                maximumWidth: Math.max(0, clockIsland.x - bars.theme.spacing3 - x)

                anchors {
                    left: workspaceIsland.right
                    leftMargin: theme.spacing3
                    verticalCenter: parent.verticalCenter
                }

                runtime: (bar.runtime as RuntimeConfig)
                theme: (bar.theme as Theme)
                motion: (bar.motion as Motion)
                media: (bar.media as MediaState)
                spectrum: (bar.spectrum as SpectrumState)
                onXChanged: Qt.callLater(bar.publishOrigins)
                onWidthChanged: Qt.callLater(bar.publishOrigins)
                onActivated: bars.mediaRequested(bar.modelData, bars.originFor(bar.modelData, "media"))
            }

            ShellSurface {
                id: clockIsland

                width: Math.min(parent.width, Math.max(184, clockRow.implicitWidth + bars.theme.spacing3 * 2))
                height: parent.height
                anchors.horizontalCenter: parent.horizontalCenter

                theme: (bar.theme as Theme)
                motion: (bar.motion as Motion)
                surfaceLayer: ShellSurface.Pane
                cornerRadius: theme.radiusIsland
                exponent: Math.min(4, theme.squircleExponent)
                luminous: true
                luminousColor: theme.accent
                hovered: clockPress.containsMouse

                Row {
                    id: clockRow
                    anchors.centerIn: parent
                    spacing: bars.theme.spacing2

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(clock.date, "ddd d MMM")
                        color: bars.theme.accent
                        font.family: bars.runtime.fontMono
                        font.pixelSize: bars.theme.fontSize(13)
                        font.weight: Font.Medium
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✳"
                        color: bars.theme.accent
                        font.family: bars.runtime.fontMono
                        font.pixelSize: bars.theme.fontSize(14)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(clock.date, "h:mm AP")
                        color: bars.theme.textStrong
                        font.family: bars.runtime.fontMono
                        font.pixelSize: bars.theme.fontSize(13)
                        font.weight: Font.DemiBold
                    }
                }

                StateLayer {
                    id: clockPress
                    theme: bars.theme
                    motion: bars.motion
                    cornerRadius: bars.theme.radiusIsland
                    onActivated: bars.calendarRequested(bar.modelData, bars.originFor(bar.modelData, "calendar"))
                }
            }

            ShellSurface {
                id: notificationIsland

                // Notification history remains reachable through Activity when space is tight.
                visible: barContent.width - (clockIsland.x + clockIsland.width) >= systemIsland.width + width + bars.theme.spacing3 * 2
                width: notificationRow.implicitWidth + bars.theme.spacing3 * 2
                height: parent.height
                anchors {
                    right: systemIsland.left
                    rightMargin: bars.theme.spacing3
                    verticalCenter: parent.verticalCenter
                }

                theme: (bar.theme as Theme)
                motion: (bar.motion as Motion)
                surfaceLayer: ShellSurface.Pane
                cornerRadius: bars.theme.radiusIsland
                onXChanged: Qt.callLater(bar.publishOrigins)
                onWidthChanged: Qt.callLater(bar.publishOrigins)

                Row {
                    id: notificationRow
                    anchors.centerIn: parent
                    spacing: bars.theme.spacing2

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: bar.notificationState.silent ? "󰂛" : "󰂚"
                        color: bars.theme.textStrong
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: bars.theme.fontSize(19)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: bar.notificationState.count > 0
                        text: bar.notificationState.count > 99 ? "99+" : String(bar.notificationState.count)
                        color: bars.theme.accent
                        font.family: bars.runtime.fontMono
                        font.pixelSize: bars.theme.fontSize(11)
                        font.weight: Font.DemiBold
                    }
                }

                StateLayer {
                    id: notificationPress
                    theme: bars.theme
                    motion: bars.motion
                    cornerRadius: bars.theme.radiusIsland
                    onActivated: bars.notificationsRequested(bar.modelData, bars.originFor(bar.modelData, "activity"))
                }
            }

            SystemIsland {
                id: systemIsland

                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

                runtime: (bar.runtime as RuntimeConfig)
                theme: (bar.theme as Theme)
                motion: (bar.motion as Motion)
                system: (bar.system as SystemState)
                powerProfile: (bars.powerProfile as PowerProfileState)
                compact: barContent.width - (clockIsland.x + clockIsland.width) < 260
                onXChanged: Qt.callLater(bar.publishOrigins)
                onWidthChanged: Qt.callLater(bar.publishOrigins)
                onActivated: bars.systemRequested(bar.modelData, bars.originFor(bar.modelData, "system"))
                onTrayMenuRequested: index => bars.trayMenuRequested(bar.modelData, bars.originFor(bar.modelData, "system"), index)
            }
        }
    }
}

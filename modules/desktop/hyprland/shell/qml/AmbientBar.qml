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
        readonly property real fullWorkspaceWidth: normalWorkspaces.length > 0 ? 28 + Math.max(0, normalWorkspaces.length - 1) * 22 + bars.theme.spacing3 * 2 : 0

        Item {
            id: barContent

            anchors.fill: parent
            anchors {
                leftMargin: 14
                rightMargin: 14
                topMargin: 8
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
                cornerRadius: theme.radiusMedium

                HoverHandler {
                    id: workspaceHover
                }
                StateLayer {
                    theme: bars.theme
                    motion: bars.motion
                    cornerRadius: bars.theme.radiusMedium
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
                        model: bar.fullWorkspaceWidth <= clockIsland.x - bars.theme.spacing3 ? bar.normalWorkspaces : bar.normalWorkspaces.filter(workspace => workspace.id === bar.focusedWorkspaceId)

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

                                exponent: bars.theme.squircleExponent
                                cornerRadius: workspace.active ? 9 : 4
                                fillColor: workspace.active ? bars.theme.accent : Qt.rgba(bars.theme.textMuted.r, bars.theme.textMuted.g, bars.theme.textMuted.b, 0.55)
                                borderColor: "transparent"
                                borderWidth: 0

                                Behavior on width {
                                    NumberAnimation {
                                        duration: bars.motion.fast
                                        easing.type: bars.motion.enterType
                                    }
                                }

                                Behavior on height {
                                    NumberAnimation {
                                        duration: bars.motion.fast
                                        easing.type: bars.motion.enterType
                                    }
                                }

                                Behavior on fillColor {
                                    ColorAnimation {
                                        duration: bars.motion.fast
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: workspace.active
                                    text: workspace.number
                                    color: bars.theme.background
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
                cornerRadius: theme.radiusMedium

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

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4
                        height: 4
                        radius: 2
                        color: bars.theme.warning
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
                    theme: bars.theme
                    motion: bars.motion
                    cornerRadius: bars.theme.radiusMedium
                    onActivated: bars.calendarRequested(bar.modelData, bars.originFor(bar.modelData, "calendar"))
                }
            }

            Row {
                id: statusHints
                spacing: bars.theme.spacing2
                anchors {
                    right: systemIsland.left
                    rightMargin: implicitWidth > 0 ? bars.theme.spacing3 : 0
                    verticalCenter: parent.verticalCenter
                }
                visible: !systemIsland.compact

                Text {
                    visible: bars.system.idleInhibited
                    text: "󰅶"
                    color: bars.theme.positive
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: bars.theme.fontSize(15)
                }

                Text {
                    visible: bars.system.microphoneMuted
                    text: "󰍭"
                    color: bars.theme.warning
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: bars.theme.fontSize(16)
                }
            }

            ShellSurface {
                id: notificationIsland

                // Notification history remains reachable through Activity when space is tight.
                visible: barContent.width - (clockIsland.x + clockIsland.width) >= systemIsland.width + statusHints.implicitWidth + width + bars.theme.spacing3 * 3
                width: notificationRow.implicitWidth + bars.theme.spacing3 * 2
                height: parent.height
                anchors {
                    right: statusHints.left
                    rightMargin: bars.theme.spacing3
                    verticalCenter: parent.verticalCenter
                }

                theme: (bar.theme as Theme)
                motion: (bar.motion as Motion)
                surfaceLayer: ShellSurface.Pane
                cornerRadius: bars.theme.radiusMedium
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
                    theme: bars.theme
                    motion: bars.motion
                    cornerRadius: bars.theme.radiusMedium
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

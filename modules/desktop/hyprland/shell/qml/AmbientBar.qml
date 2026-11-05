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
    required property RecordingState recordingState

    property bool shown: true
    property bool controlsExpanded: false
    property real clockReveal: 1
    property bool frameVisible: false

    onShownChanged: {
        if (!shown)
            system.idleInhibited = false;
    }
    property var origins: ({})
    property var frameIslands: ({})

    signal mediaRequested(var screen, var origin)
    signal systemRequested(var screen, var origin)
    signal trayMenuRequested(var screen, var origin, int index)
    signal calendarRequested(var screen, var origin)
    signal notificationsRequested(var screen, var origin)
    signal recordingStopRequested

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

    function setFrameIslands(screen: var, surfaces: var): void {
        const key = screenKey(screen);
        if (!key)
            return;
        const next = Object.assign({}, frameIslands);
        next[key] = surfaces;
        frameIslands = next;
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
        readonly property RecordingState recordingState: bars.recordingState
        readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
        readonly property bool fullscreen: hyprMonitor?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false
        // A compositor reservation reduces the bar panel's usable width.
        // Restore its real screen-space inset, instead of assuming its size.
        readonly property real screenOffset: Math.max(0, (modelData.width - bar.width) / 2)
        // frameIslandInset is a *screen-space* contour limit. Layer-shell's
        // frame reservation already consumes screenOffset on each side;
        // subtract it before applying the inset inside this bar window.
        readonly property real frameLocalInset: Math.max(0, bars.theme.frameIslandInset - screenOffset)
        // Animate the *island layout* alongside the shared frame's outline.
        // Hyprland still owns reserved space immediately; this interpolates
        // only internal QML margins, so window gaps remain compositor-driven.
        property real frameBlend: bars.frameVisible ? 1 : 0
        Behavior on frameBlend {
            NumberAnimation {
                duration: bar.motion.morph
                easing.type: bar.motion.morphType
                easing.bezierCurve: bar.motion.morphCurve
            }
        }
        onFrameBlendChanged: Qt.callLater(publishOrigins)
        onScreenOffsetChanged: Qt.callLater(publishOrigins)
        onFullscreenChanged: Qt.callLater(publishOrigins)

        function publishOrigins(): void {
            if (!barContent || !mediaIsland || !systemIsland)
                return;

            bars.setOrigin(modelData, "media", bar.screenOffset + barContent.x + mediaIsland.x + mediaIsland.width / 2, mediaIsland.width, mediaIsland.height);
            bars.setOrigin(modelData, "system", bar.screenOffset + barContent.x + clockIsland.x + clockIsland.width / 2, clockIsland.width, clockIsland.height);
            bars.setOrigin(modelData, "calendar", bar.screenOffset + barContent.x + clockIsland.x + clockIsland.width / 2, clockIsland.width, clockIsland.height);
            bars.setOrigin(modelData, "activity", bar.screenOffset + barContent.x + notificationIsland.x + notificationIsland.width / 2, notificationIsland.width, notificationIsland.height);
            const surfaces = [workspaceIsland, mediaIsland, clockIsland, notificationIsland, recordingIsland, systemIsland];
            const islands = [];
            for (const item of surfaces.filter(item => bar.visible && item.visible && (!bars.controlsExpanded || item !== clockIsland) && item.width > 2)) {
                const x = bar.screenOffset + barContent.x + item.x;
                const y = barContent.y + item.y;
                if (item === mediaIsland) {
                    // Adjacent equal-depth sections preserve one frame notch,
                    // while the hover/press contour is divided at the real
                    // main/playback hit boundary.
                    const mainWidth = item.width - item.playbackWidth;
                    islands.push({
                        x,
                        y,
                        width: mainWidth,
                        height: item.height,
                        hovered: item.mainHover,
                        pressed: item.mainPressed,
                        interactionGroup: "media",
                        visible: true
                    }, {
                        x: x + mainWidth,
                        y,
                        width: item.playbackWidth,
                        height: item.height,
                        hovered: item.playbackHover,
                        pressed: item.playbackPressed,
                        interactionGroup: "media",
                        visible: true
                    });
                    continue;
                }
                islands.push({
                    x,
                    y,
                    width: item.width,
                    height: item.height,
                    hovered: item === workspaceIsland ? false : item === clockIsland ? clockPress.pointerHovered : item === notificationIsland ? notificationPress.pointerHovered : item === recordingIsland ? recordingPress.pointerHovered : item === systemIsland ? item.frameHover : false,
                    pressed: item === workspaceIsland ? false : item === clockIsland ? clockPress.visualPressed : item === notificationIsland ? notificationPress.visualPressed : item === recordingIsland ? recordingPress.visualPressed : item === systemIsland ? item.framePressed : false,
                    visible: true
                });
            }
            bars.setFrameIslands(modelData, islands);
        }

        Component.onCompleted: Qt.callLater(publishOrigins)
        onWidthChanged: Qt.callLater(publishOrigins)
        Connections {
            target: bars
            function onControlsExpandedChanged(): void {
                Qt.callLater(bar.publishOrigins);
            }
            function onShownChanged(): void {
                Qt.callLater(bar.publishOrigins);
            }
        }

        visible: bars.shown && !bar.fullscreen
        implicitHeight: bars.theme.barHeight
        color: "transparent"
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: bar.visible ? bars.theme.barHeight : 0

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
        readonly property var visibleWorkspaceIds: workspaceIds.length === 0 ? [focusedWorkspaceId] : fullWorkspaceWidth <= clockIsland.x - bars.theme.spacing3 ? workspaceIds : [focusedWorkspaceId]
        readonly property int workspaceCellWidth: 42
        readonly property int workspaceCellGap: 6
        readonly property real fullWorkspaceWidth: workspaceIds.length > 0 ? workspaceIds.length * workspaceCellWidth + Math.max(0, workspaceIds.length - 1) * workspaceCellGap + bars.theme.spacing3 * 2 : 0

        Item {
            id: barContent

            onXChanged: Qt.callLater(bar.publishOrigins)
            onYChanged: Qt.callLater(bar.publishOrigins)
            onWidthChanged: Qt.callLater(bar.publishOrigins)
            onHeightChanged: Qt.callLater(bar.publishOrigins)
            anchors.fill: parent
            anchors {
                // The bar's compositor reservation accounts for frameThickness.
                // Keep island hit targets beyond the outer squircle's shoulder
                // without adding that reservation to their local coordinates.
                leftMargin: bars.theme.spacing3 + (bar.frameLocalInset - bars.theme.spacing3) * bar.frameBlend
                rightMargin: bars.theme.spacing3 + (bar.frameLocalInset - bars.theme.spacing3) * bar.frameBlend
                // The inner contour begins at frameThickness, so controls
                // must never begin above it. Keep the actual hit regions,
                // blue workspace selection and icon row within the recess.
                topMargin: bars.theme.barInsetTop + (bars.theme.frameThickness - bars.theme.barInsetTop) * bar.frameBlend
                bottomMargin: bars.theme.barInsetBottom + (Math.max(0, bars.theme.barHeight - bars.theme.frameThickness - bars.theme.barIslandHeight) - bars.theme.barInsetBottom) * bar.frameBlend
            }

            ShellSurface {
                id: workspaceIsland
                reactiveSurface: true
                frameConnected: bars.frameVisible
                onXChanged: Qt.callLater(bar.publishOrigins)
                onYChanged: Qt.callLater(bar.publishOrigins)
                onWidthChanged: Qt.callLater(bar.publishOrigins)
                onHeightChanged: Qt.callLater(bar.publishOrigins)
                onVisibleChanged: Qt.callLater(bar.publishOrigins)

                width: Math.max(bar.workspaceCellWidth, workspaceTrack.implicitWidth) + theme.spacing3 * 2
                height: bars.theme.barIslandHeight
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }

                theme: (bar.theme as Theme)
                motion: (bar.motion as Motion)
                surfaceLayer: ShellSurface.Pane
                cornerRadius: theme.radiusIsland
                exponent: Math.min(4, theme.squircleExponent)
                elevated: false
                outlined: false
                fillColor: theme.background

                Item {
                    id: workspaceTrack
                    z: 1
                    anchors.centerIn: parent
                    // Repeater children can be materialised before Row reports
                    // their implicit width. Using Row.implicitWidth gave this
                    // 42px pill a 24px island and clipped the frame contour.
                    implicitWidth: Math.max(1, bar.visibleWorkspaceIds.length) * bar.workspaceCellWidth + Math.max(0, bar.visibleWorkspaceIds.length - 1) * bar.workspaceCellGap
                    implicitHeight: bars.theme.barIslandHeight - 2 * bars.theme.barSelectionInset
                    // Keep the selection inside the island when an unused
                    // workspace vanishes and the track contracts.
                    clip: true

                    readonly property int activeIndex: Math.max(0, bar.visibleWorkspaceIds.indexOf(bar.focusedWorkspaceId))
                    property var previousIds: []
                    property int previousFocus: -1
                    property bool settled: false

                    function syncPosition(): void {
                        const ids = bar.visibleWorkspaceIds.slice();
                        const focused = bar.focusedWorkspaceId;
                        // A newly focused, empty workspace can arrive before
                        // Hyprland publishes its slot. Wait for the actual
                        // workspace, rather than teleporting the pill to zero.
                        if (!ids.includes(focused))
                            return;
                        const index = ids.indexOf(focused);
                        const destination = index * (bar.workspaceCellWidth + bar.workspaceCellGap);
                        const slide = settled && ids.length >= previousIds.length && ids.includes(previousFocus) && focused !== previousFocus && bars.motion.enabled;

                        workspaceAnimation.stop();
                        if (slide && workspaceSelection.x !== destination) {
                            workspaceAnimation.from = workspaceSelection.x;
                            workspaceAnimation.to = destination;
                            workspaceAnimation.start();
                        } else {
                            workspaceSelection.x = destination;
                        }
                        previousIds = ids;
                        previousFocus = focused;
                        settled = true;
                    }

                    Component.onCompleted: Qt.callLater(syncPosition)
                    onActiveIndexChanged: Qt.callLater(syncPosition)
                    onImplicitWidthChanged: Qt.callLater(syncPosition)
                    Connections {
                        target: bar
                        function onVisibleWorkspaceIdsChanged(): void {
                            Qt.callLater(workspaceTrack.syncPosition);
                        }
                    }

                    NumberAnimation {
                        id: workspaceAnimation
                        target: workspaceSelection
                        property: "x"
                        duration: bars.motion.enabled ? 135 : 0
                        easing.type: bars.motion.spatialType
                        easing.bezierCurve: bars.motion.spatialCurve
                    }

                    SquircleSurface {
                        id: workspaceSelection
                        x: 0
                        y: 0
                        width: bar.workspaceCellWidth
                        height: bars.theme.barIslandHeight - 2 * bars.theme.barSelectionInset
                        exponent: bars.theme.squircleExponent
                        cornerRadius: bars.theme.radiusSmall
                        fillColor: bars.theme.accent
                        lightColor: bars.theme.accent
                        lightStrength: 0.035
                        visible: bar.visibleWorkspaceIds.length > 0
                    }

                    Row {
                        id: workspaceRow
                        spacing: bar.workspaceCellGap

                        Repeater {
                            model: bar.visibleWorkspaceIds

                            delegate: Item {
                                id: workspace
                                required property var modelData
                                required property int index
                                readonly property int number: modelData
                                readonly property bool active: bar.focusedWorkspaceId === number

                                width: bar.workspaceCellWidth
                                height: bars.theme.barIslandHeight - 2 * bars.theme.barSelectionInset

                                Text {
                                    z: 1
                                    anchors.centerIn: parent
                                    text: workspace.number
                                    // Make the ink follow the sliding pill,
                                    // not the destination before it arrives.
                                    color: Math.abs(workspaceSelection.x - workspace.index * (bar.workspaceCellWidth + bar.workspaceCellGap)) < 21 ? bars.theme.background : bars.theme.textMuted
                                    font.family: bars.runtime.fontMono
                                    font.pixelSize: bars.theme.fontSize(12)
                                    font.weight: Font.DemiBold
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: bars.motion.effectsFast
                                        }
                                    }
                                }

                                StateLayer {
                                    theme: bars.theme
                                    motion: bars.motion
                                    cornerRadius: bars.theme.radiusSmall
                                    exponent: Math.min(4, bars.theme.squircleExponent)
                                    stateColor: bars.theme.textStrong
                                    Accessible.role: Accessible.Button
                                    Accessible.name: "Switch to workspace " + workspace.number
                                    onActivated: Hyprland.dispatch('hl.dsp.focus({ workspace = "' + workspace.number + '" })')
                                }
                            }
                        }
                    }
                }
            }

            NowPlayingIsland {
                id: mediaIsland
                onYChanged: Qt.callLater(bar.publishOrigins)
                onHeightChanged: Qt.callLater(bar.publishOrigins)
                onMainHoverChanged: bar.publishOrigins()
                onPlaybackHoverChanged: bar.publishOrigins()
                onMainPressedChanged: bar.publishOrigins()
                onPlaybackPressedChanged: bar.publishOrigins()
                onVisibleChanged: Qt.callLater(bar.publishOrigins)

                maximumWidth: Math.max(0, clockIsland.x - bars.theme.spacing3 - x)

                anchors {
                    left: workspaceIsland.right
                    leftMargin: theme.spacing3 + (bars.theme.frameIslandGap - theme.spacing3) * bar.frameBlend
                    verticalCenter: parent.verticalCenter
                }

                runtime: (bar.runtime as RuntimeConfig)
                theme: (bar.theme as Theme)
                motion: (bar.motion as Motion)
                media: (bar.media as MediaState)
                spectrum: (bar.spectrum as SpectrumState)
                frameConnected: bars.frameVisible
                onXChanged: Qt.callLater(bar.publishOrigins)
                onWidthChanged: Qt.callLater(bar.publishOrigins)
                onActivated: bars.mediaRequested(bar.modelData, bars.originFor(bar.modelData, "media"))
            }

            ShellSurface {
                id: clockIsland
                reactiveSurface: true
                frameConnected: bars.frameVisible
                onXChanged: Qt.callLater(bar.publishOrigins)
                onYChanged: Qt.callLater(bar.publishOrigins)
                onWidthChanged: Qt.callLater(bar.publishOrigins)
                onHeightChanged: Qt.callLater(bar.publishOrigins)
                onVisibleChanged: Qt.callLater(bar.publishOrigins)
                // The hub immediately takes ownership of the centred island.
                // An independent fade would draw clock text over its opening
                // squircle, while the shared contour is already expanding.
                visible: bars.clockReveal > 0.001
                opacity: bars.clockReveal

                width: Math.min(parent.width, Math.max(206, clockRow.implicitWidth + bars.theme.spacing4 * 2))
                height: bars.theme.barIslandHeight
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }

                theme: (bar.theme as Theme)
                motion: (bar.motion as Motion)
                surfaceLayer: ShellSurface.Pane
                cornerRadius: theme.radiusIsland
                exponent: Math.min(4, theme.squircleExponent)
                elevated: false
                outlined: false
                fillColor: theme.background

                Row {
                    id: clockRow
                    anchors.centerIn: parent
                    spacing: bars.theme.spacing2

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(clock.date, "ddd d MMM")
                        color: bars.theme.textMuted
                        font.family: bars.runtime.fontMono
                        font.pixelSize: bars.theme.fontSize(13)
                        font.weight: Font.Medium
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✳"
                        color: bars.theme.warning
                        font.family: bars.runtime.fontMono
                        font.pixelSize: bars.theme.fontSize(14)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(clock.date, "h:mm AP")
                        color: bars.theme.textStrong
                        font.family: bars.runtime.fontMono
                        font.pixelSize: bars.theme.fontSize(16)
                        font.weight: Font.DemiBold
                    }
                }

                StateLayer {
                    id: clockPress
                    showHover: !bars.frameVisible
                    onContainsMouseChanged: Qt.callLater(bar.publishOrigins)
                    onPressedChanged: bar.publishOrigins()
                    theme: bars.theme
                    motion: bars.motion
                    cornerRadius: bars.theme.radiusIsland
                    exponent: Math.min(4, bars.theme.squircleExponent)
                    stateColor: bars.theme.accent
                    hoverOpacity: 0.05
                    pressOpacity: 0.11
                    onActivated: bars.calendarRequested(bar.modelData, bars.originFor(bar.modelData, "calendar"))
                }
            }

            ShellSurface {
                id: notificationIsland
                reactiveSurface: true
                frameConnected: bars.frameVisible
                onXChanged: Qt.callLater(bar.publishOrigins)
                onYChanged: Qt.callLater(bar.publishOrigins)
                onWidthChanged: Qt.callLater(bar.publishOrigins)
                onHeightChanged: Qt.callLater(bar.publishOrigins)
                onVisibleChanged: Qt.callLater(bar.publishOrigins)

                // Notification history remains reachable through Activity when space is tight.
                visible: barContent.width - (clockIsland.x + clockIsland.width) >= systemIsland.width + (recordingIsland.visible ? recordingIsland.width + bars.theme.spacing3 : 0) + width + bars.theme.spacing3 * 2
                width: notificationRow.implicitWidth + bars.theme.spacing3 * 2
                height: bars.theme.barIslandHeight
                anchors {
                    right: recordingIsland.visible ? recordingIsland.left : systemIsland.left
                    rightMargin: bars.theme.spacing3 + (bars.theme.frameIslandGap - bars.theme.spacing3) * bar.frameBlend
                    verticalCenter: parent.verticalCenter
                }

                theme: (bar.theme as Theme)
                motion: (bar.motion as Motion)
                surfaceLayer: ShellSurface.Pane
                cornerRadius: bars.theme.radiusIsland
                elevated: false
                outlined: false
                fillColor: theme.background

                Row {
                    id: notificationRow
                    anchors.centerIn: parent
                    height: bars.theme.barIslandHeight
                    spacing: bars.theme.spacing2

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38
                        height: 38
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: bar.notificationState.silent ? "󰂛" : "󰂚"
                        color: bar.notificationState.hasCriticalUnread ? bars.theme.critical : bar.notificationState.unreadCount > 0 ? bars.theme.readableRoleColor("notifications") : bars.theme.textStrong
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: bars.theme.fontSize(27)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: bar.notificationState.unreadCount > 0
                        height: 38
                        verticalAlignment: Text.AlignVCenter
                        text: bar.notificationState.unreadCount > 99 ? "99+" : String(bar.notificationState.unreadCount)
                        color: bars.theme.readableRoleColor(bar.notificationState.hasCriticalUnread ? "critical" : "notifications")
                        font.family: bars.runtime.fontMono
                        font.pixelSize: bars.theme.fontSize(11)
                        font.weight: Font.DemiBold
                    }
                }

                StateLayer {
                    id: notificationPress
                    showHover: !bars.frameVisible
                    onContainsMouseChanged: Qt.callLater(bar.publishOrigins)
                    onPressedChanged: bar.publishOrigins()
                    theme: bars.theme
                    motion: bars.motion
                    cornerRadius: bars.theme.radiusIsland
                    exponent: Math.min(4, bars.theme.squircleExponent)
                    onActivated: bars.notificationsRequested(bar.modelData, bars.originFor(bar.modelData, "activity"))
                }
            }

            ShellSurface {
                id: recordingIsland
                reactiveSurface: true
                frameConnected: bars.frameVisible
                onXChanged: Qt.callLater(bar.publishOrigins)
                onYChanged: Qt.callLater(bar.publishOrigins)
                onWidthChanged: Qt.callLater(bar.publishOrigins)
                onHeightChanged: Qt.callLater(bar.publishOrigins)
                onVisibleChanged: Qt.callLater(bar.publishOrigins)
                visible: bar.recordingState.visibleInBar
                width: recordingContent.implicitWidth + bars.theme.spacing4 * 2
                height: bars.theme.barIslandHeight
                anchors {
                    right: systemIsland.left
                    rightMargin: bars.theme.spacing3 + (bars.theme.frameIslandGap - bars.theme.spacing3) * bar.frameBlend
                    verticalCenter: parent.verticalCenter
                }
                theme: (bar.theme as Theme)
                motion: (bar.motion as Motion)
                surfaceLayer: ShellSurface.Pane
                cornerRadius: bars.theme.radiusIsland
                elevated: false
                outlined: false
                fillColor: theme.background

                Row {
                    id: recordingContent
                    anchors.centerIn: parent
                    spacing: bars.theme.spacing2
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "●"
                        color: bar.recordingState.phase === "completed" ? bars.theme.positive : bar.recordingState.phase === "failed" ? bars.theme.critical : bars.theme.warning
                        font.family: bars.runtime.fontMono
                        font.pixelSize: bars.theme.fontSize(15)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: bar.recordingState.capturing ? "REC " + bar.recordingState.elapsedLabel : bar.recordingState.finalising ? "SAVING" : bar.recordingState.phase === "completed" ? "SAVED" : "FAILED"
                        color: bars.theme.textStrong
                        font.family: bars.runtime.fontMono
                        font.pixelSize: bars.theme.fontSize(11)
                        font.weight: Font.DemiBold
                    }
                }
                StateLayer {
                    id: recordingPress
                    showHover: !bars.frameVisible
                    onContainsMouseChanged: Qt.callLater(bar.publishOrigins)
                    onPressedChanged: bar.publishOrigins()
                    theme: bars.theme
                    motion: bars.motion
                    cornerRadius: bars.theme.radiusIsland
                    disabled: !bar.recordingState.capturing
                    exponent: Math.min(4, bars.theme.squircleExponent)
                    onActivated: bars.recordingStopRequested()
                }
            }

            SystemIsland {
                id: systemIsland
                onFrameHoverChanged: Qt.callLater(bar.publishOrigins)
                onFramePressedChanged: bar.publishOrigins()
                onYChanged: Qt.callLater(bar.publishOrigins)
                onHeightChanged: Qt.callLater(bar.publishOrigins)
                onVisibleChanged: Qt.callLater(bar.publishOrigins)

                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

                runtime: (bar.runtime as RuntimeConfig)
                theme: (bar.theme as Theme)
                motion: (bar.motion as Motion)
                system: (bar.system as SystemState)
                powerProfile: (bars.powerProfile as PowerProfileState)
                frameConnected: bars.frameVisible
                compact: barContent.width - (clockIsland.x + clockIsland.width) < 260
                onXChanged: Qt.callLater(bar.publishOrigins)
                onWidthChanged: Qt.callLater(bar.publishOrigins)
                onActivated: bars.systemRequested(bar.modelData, bars.originFor(bar.modelData, "system"))
                onTrayMenuRequested: index => bars.trayMenuRequested(bar.modelData, bars.originFor(bar.modelData, "system"), index)
            }
        }
    }
}

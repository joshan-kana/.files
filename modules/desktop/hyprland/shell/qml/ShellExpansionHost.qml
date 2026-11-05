pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "FrameGeometry.js" as FrameGeometry

PanelWindow {
    id: host

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property ShellExpansionState expansionState
    property var barWindows: []

    property Component mediaComponent: null
    property Component systemComponent: null
    property Component calendarComponent: null
    property Component weatherComponent: null
    property Component activityComponent: null
    property bool contentExpanded: false
    property bool closing: false
    property int transitionEpoch: 0
    // The measured center island remains the single docking target for all
    // hub pages, regardless of the island that originally opened the page.
    property var dockOrigin: ({
            center: 0,
            width: 0,
            height: 0
        })
    property real closeWidth: 0
    property real closeHeight: 0
    property real closeStartWidth: 0
    property real closeStartHeight: 0
    property real closeLayoutWidth: 0
    property real closeLayoutHeight: 0
    // One shared visibility track for Controls and every detail gallery.
    property real chromeOpacity: expansionState.hasCurrent && contentExpanded ? 1 : 0
    Behavior on chromeOpacity {
        Anim {
            motion: host.motion
            type: Anim.FastEffects
        }
    }
    property bool themeTerminalActive: false
    property bool frameEnabled: true
    property bool barVisible: true
    readonly property var frameBounds: ({
            x: (screen ? (screen.width - viewportWidth) / 2 : 0) + shellSurface.x,
            y: topOffset + shellSurface.y,
            width: shellSurface.width,
            height: shellSurface.height,
            visible: (expansionState.hasCurrent || closing) && shellSurface.opacity > 0.01
        })
    readonly property real topOffset: frameVisible ? theme.frameThickness : barVisible ? theme.barInsetTop : theme.spacing4
    readonly property bool frameVisible: frameEnabled && !(Hyprland.monitorFor(screen)?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false)
    // The clock's reveal is driven by the actual contraction, not the
    // outgoing page's implicitWidth (Activity and Now Playing differ).
    readonly property real clockReveal: {
        if (!barVisible)
            return 0;
        if (expansionState.hasCurrent)
            return 0;
        if (!closing)
            return 1;
        const widthSpan = Math.max(1, closeStartWidth - closeWidth);
        const heightSpan = Math.max(1, closeStartHeight - closeHeight);
        const widthProgress = Math.max(0, Math.min(1, (closeStartWidth - shellSurface.width) / widthSpan));
        const heightProgress = Math.max(0, Math.min(1, (closeStartHeight - shellSurface.height) / heightSpan));
        const progress = Math.min(widthProgress, heightProgress);
        const reveal = Math.max(0, Math.min(1, (progress - 0.65) / 0.35));
        return reveal * reveal * (3 - 2 * reveal);
    }
    property bool keyboardFocusReady: false
    // Hyprland returns focus to workspace clients on a workspace change,
    // even if a persistent layer-shell popup is still visible.
    property bool restoringWorkspaceFocus: false
    // The same visual bottom inset for every hub tab. Controls may exceed
    // the viewport, but that must scroll its content, not move navigation.
    readonly property real footerBottomClearance: theme.spacing6 + theme.spacing2
    // A tall connected hub is clipped at the frame's rounded bottom corner.
    // The footer must clear that contour, not the unclipped backing rectangle.
    readonly property real visibleFooterBottom: frameVisible && screen ? Math.max(1, Math.min(shellSurface.height, FrameGeometry.hubBottomLimit(screen.width, screen.height, theme.frameThickness, theme.frameRounding) - topOffset)) : shellSurface.height

    // Precreate each hub view before its first invocation, including Media and
    // Weather. No destination evicts another or constructs on the keypress.
    property int activeSlot: -1
    readonly property Loader activeLoader: activeSlot === 0 ? contentLoaderA : activeSlot === 1 ? contentLoaderB : activeSlot === 2 ? contentLoaderC : activeSlot === 3 ? contentLoaderD : activeSlot === 4 ? contentLoaderE : null
    readonly property Item loadedContent: activeLoader ? activeLoader.item as Item : null
    readonly property SystemContent systemContent: expansionState.currentName === "system" ? loadedContent as SystemContent : null
    readonly property bool themeOperationVisible: !!systemContent && systemContent.themeOperationRunning && expansionState.hasCurrent
    readonly property bool wallpaperOperationVisible: !!systemContent && systemContent.wallpaperOperationRunning && expansionState.hasCurrent
    readonly property bool captureEditorRequestVisible: !!systemContent && systemContent.captureEditorRequestRunning && expansionState.hasCurrent
    readonly property bool maintenanceOperationVisible: !!systemContent && systemContent.maintenanceOperationRunning && expansionState.hasCurrent
    readonly property bool loadingOperationVisible: themeOperationVisible || wallpaperOperationVisible || captureEditorRequestVisible || maintenanceOperationVisible
    readonly property MediaContent mediaContent: expansionState.currentName === "media" ? loadedContent as MediaContent : null
    readonly property bool helpVisible: systemContent ? systemContent.helpOpen : (mediaContent ? mediaContent.helpOpen : false)
    readonly property bool tabShortcutsEnabled: expansionState.hasCurrent && !detailVisible && !helpVisible && !(systemContent && (systemContent.resetConfirmPending || systemContent.audioChooserOpen))
    readonly property string escapeHintLabel: systemContent && systemContent.resetConfirmPending ? "Cancel" : helpVisible || detailVisible || (systemContent && (systemContent.audioChooserOpen || systemContent.selectedSlider.length > 0)) ? "Back" : "Close"
    // Hub scrolling is a fallback only for views without their own paging
    // owner. Calendar, Activity, and open details consume PageUp/Down locally.
    readonly property bool hostPageShortcutsEnabled: expansionState.hasCurrent && !helpVisible && (expansionState.currentName === "weather" || expansionState.currentName === "media" || (expansionState.currentName === "system" && !detailVisible))
    readonly property bool detailVisible: !!systemContent && (systemContent.trayMenuOpen || systemContent.networkOpen || systemContent.bluetoothOpen || systemContent.themeOpen || systemContent.wallpaperOpen || systemContent.sessionOpen || systemContent.resourcesOpen || systemContent.recordingsOpen || systemContent.mixerOpen)
    readonly property string helpCaption: systemContent ? systemContent.helpTitle : "Now Playing controls"
    readonly property var helpKeys: systemContent ? systemContent.helpBindings : (mediaContent ? mediaContent.helpBindings : [])

    function presentComponent(next: Component): void {
        if (!next) {
            contentEnter.stop();
            if (activeLoader)
                activeLoader.opacity = 0;
            activeSlot = -1;
            return;
        }

        if (activeLoader && activeLoader.sourceComponent === next)
            return;

        const incoming = next === calendarComponent ? contentLoaderA : next === systemComponent ? contentLoaderB : next === activityComponent ? contentLoaderC : next === mediaComponent ? contentLoaderD : contentLoaderE;
        const previous = activeLoader;
        const outgoing = contentExpanded && !closing && expansionState.hasCurrent ? previous : null;
        contentEnter.stop();
        incoming.opacity = 0;
        // Enable the destination before constructing its FocusScope. Its
        // onEngagedChanged requests keyboard focus during instantiation.
        activeSlot = incoming === contentLoaderA ? 0 : incoming === contentLoaderB ? 1 : incoming === contentLoaderC ? 2 : incoming === contentLoaderD ? 3 : 4;
        incoming.sourceComponent = next;
        contentViewport.contentY = 0;
        if (!outgoing && previous)
            previous.opacity = 0;
        if (outgoing) {
            // Overlap just the tails of the fades: a fully sequential handoff
            // leaves an empty squircle for a frame, while a full crossfade
            // ghosts two readable pages over the morph.
            outgoing.opacity = 0;
            if (motion.enabled)
                contentEnter.restart();
            else
                incoming.opacity = 1;
        } else {
            incoming.opacity = 1;
        }
        geometryUpdate.restart();
        // A tab switch may displace the destination's nested keyboard sink.
        // Do not defer this work on a closed-to-open transition: the view's
        // FocusScope already requests focus when it becomes engaged.
        if (outgoing) {
            Qt.callLater(() => {
                if (host.expansionState.hasCurrent && host.currentComponent === next && host.loadedContent)
                    host.loadedContent.forceActiveFocus();
            });
        }
    }

    function onLoaderReady(loader: Loader): void {
        geometryUpdate.restart();
        if (contentLoaderA.item && contentLoaderB.item && contentLoaderC.item)
            (contentLoaderB.item as SystemContent).prewarmDetails();
        if (activeLoader !== loader || !expansionState.hasCurrent)
            return;
        Qt.callLater(() => {
            if (host.expansionState.hasCurrent && host.activeLoader === loader && loader.item)
                (loader.item as Item).forceActiveFocus();
        });
    }

    onCurrentComponentChanged: presentComponent(currentComponent)
    Component.onCompleted: {
        presentComponent(currentComponent);
        // Prepare every hub destination during shell startup; their instances
        // persist across closure, rather than constructing on the first key.
        Qt.callLater(() => {
            contentLoaderA.sourceComponent = calendarComponent;
            contentLoaderB.sourceComponent = systemComponent;
            contentLoaderC.sourceComponent = activityComponent;
            contentLoaderD.sourceComponent = mediaComponent;
            contentLoaderE.sourceComponent = weatherComponent;
        });
    }

    // Begin the incoming fade within one or two frames of the outgoing fade.
    // A longer sequential wait strands otherwise-ready Home/Controls/Activity
    // content behind an empty surface, especially after reopening another tab.
    Timer {
        id: contentEnter
        interval: Math.max(1, Math.round(host.motion.effectsFast * 0.20))
        repeat: false
        onTriggered: {
            if (host.activeLoader)
                host.activeLoader.opacity = 1;
        }
    }

    readonly property Component currentComponent: {
        switch (expansionState.currentName) {
        case "media":
            return mediaComponent;
        case "system":
            return systemComponent;
        case "calendar":
            return calendarComponent;
        case "weather":
            return weatherComponent;
        case "activity":
            return activityComponent;
        default:
            return null;
        }
    }
    readonly property string currentTab: expansionState.currentName === "activity" ? "activity" : expansionState.currentName === "calendar" || expansionState.currentName === "weather" ? "home" : "controls"
    // Keep the last valid dimensions while Loader replaces one tab with another.
    // Otherwise the inner squircle briefly shrinks to the bar origin before the
    // new tab's dimensions are ready.
    property real measuredContentWidth: 0
    property real measuredContentHeight: 0
    // Derive the destination geometry from the live view, not only the cache:
    // a temporary initial implicitHeight can otherwise strand the host at
    // the height of a previously loaded detail panel.
    readonly property real contentWidth: loadedContent && loadedContent.implicitWidth > 0 ? Math.max(loadedContent.implicitWidth, 600) + theme.spacing4 * 2 : (measuredContentWidth > 0 ? measuredContentWidth : expansionState.originWidth)
    readonly property real contentHeight: loadedContent && loadedContent.implicitHeight > 0 ? loadedContent.implicitHeight + tabs.implicitHeight + hubFooter.implicitHeight + theme.spacing3 + footerBottomClearance + theme.spacing4 * 2 : (measuredContentHeight > 0 ? measuredContentHeight : expansionState.originHeight)

    function updateContentGeometry(): void {
        if (!loadedContent || loadedContent.implicitWidth <= 0 || loadedContent.implicitHeight <= 0)
            return;
        measuredContentWidth = Math.max(loadedContent.implicitWidth, 600) + theme.spacing4 * 2;
        measuredContentHeight = loadedContent.implicitHeight + tabs.implicitHeight + hubFooter.implicitHeight + theme.spacing3 + footerBottomClearance + theme.spacing4 * 2;
    }

    Timer {
        id: geometryUpdate
        interval: 0
        repeat: false
        onTriggered: host.updateContentGeometry()
    }

    Connections {
        target: host.systemContent
        function onRevealContent(top: real, bottom: real): void {
            host.revealContent(top, bottom);
        }
        function onThemeTerminalActiveChanged(active: bool): void {
            host.themeTerminalActive = active;
        }
    }

    Connections {
        target: host.loadedContent
        function onImplicitWidthChanged(): void {
            geometryUpdate.restart();
        }
        function onImplicitHeightChanged(): void {
            geometryUpdate.restart();
        }
    }
    // One terminal silhouette per visual mode. Never derive the closing
    // endpoint from the outgoing tab's dimensions or its original trigger.
    readonly property real compactWidth: barVisible ? Math.max(1, dockOrigin.width || expansionState.originWidth || 40) : frameVisible ? Math.max(64, theme.radiusPanel * 2) : 64
    readonly property real compactHeight: barVisible ? Math.max(1, dockOrigin.height || expansionState.originHeight || 40) : frameVisible ? Math.max(2, theme.frameThickness * 0.6) : 32
    readonly property real targetWidth: contentExpanded ? Math.max(contentWidth, expansionState.originWidth) : closing ? closeWidth : barVisible ? Math.max(1, expansionState.originWidth) : compactWidth
    readonly property real targetHeight: contentExpanded ? Math.max(contentHeight, expansionState.originHeight) : closing ? closeHeight : barVisible ? Math.max(1, expansionState.originHeight) : compactHeight
    // Keep the layer as small as the hub's compositor-safe viewport.
    // A fullscreen transparent backing needlessly multiplies blur work
    // when Frosted Glass is enabled, especially on high-DPI displays.
    // Keep the detail viewport stable across the gallery's inner morph;
    // the top inset still follows the frame/bar visibility policy.
    readonly property real viewportWidth: screen ? Math.max(1, Math.min(screen.width - theme.spacing4 * 2, theme.controlsDetailWidth + theme.spacing4 * 2)) : 1
    readonly property real viewportHeight: screen ? Math.max(1, screen.height - topOffset - theme.spacing4) : 1
    // Match the bar's measured source when it lies inside our compositor-safe
    // viewport. Off-viewport islands start at the nearest visible edge, rather
    // than forcing a new full-width Wayland surface or compositor relayout.
    readonly property real originHalfWidth: Math.min(viewportWidth / 2, Math.max(1, expansionState.originWidth / 2))
    readonly property real localOriginCenter: screen ? expansionState.originCenter - (screen.width - viewportWidth) / 2 : viewportWidth / 2
    readonly property real boundedOriginCenter: Math.max(originHalfWidth, Math.min(viewportWidth - originHalfWidth, localOriginCenter))
    // Floating modes have no clickable source island to drift toward. The
    // center also remains fixed during close, so the width/height easing does
    // not compete with horizontal translation.
    property real animatedSurfaceCenter: contentExpanded || closing || !barVisible ? viewportWidth / 2 : boundedOriginCenter

    Behavior on animatedSurfaceCenter {
        enabled: host.contentExpanded || host.closing
        NumberAnimation {
            duration: host.motion.morph
            easing.type: host.motion.morphType
            easing.bezierCurve: host.motion.morphCurve
        }
    }

    screen: expansionState.screen || Quickshell.screens[0]
    visible: true
    updatesEnabled: true
    color: "transparent"
    focusable: expansionState.hasCurrent && !themeTerminalActive
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: Math.max(1, viewportWidth)
    implicitHeight: Math.max(1, viewportHeight)

    anchors {
        top: true
        left: true
    }

    margins {
        top: host.topOffset
        left: screen ? (screen.width - viewportWidth) / 2 : 0
    }

    WlrLayershell.namespace: "linux-desktop-expansion"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: expansionState.hasCurrent && !themeTerminalActive ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    PopupSurfaceLifecycle {
        id: surfaceLifecycle
        prewarm: true
        popup: host
        exposed: host.expansionState.hasCurrent || host.closing
        interactiveItem: shellSurface
        fullWidth: Math.max(1, host.viewportWidth)
        fullHeight: Math.max(1, host.viewportHeight)
    }
    mask: surfaceLifecycle.inputRegion

    function navigate(destination: string): void {
        const next = destination === "home" ? "calendar" : destination === "activity" ? "activity" : "system";
        if (next === expansionState.currentName) {
            if (next === "system" && detailVisible) {
                expansionState.navigate(next);
            }
            return;
        }

        expansionState.navigate(next);
    }

    function cycleTab(direction: int): void {
        const destinations = ["home", "controls", "activity"];
        const index = destinations.indexOf(currentTab);
        navigate(destinations[(index + direction + destinations.length) % destinations.length]);
    }

    function pageContent(direction: int): void {
        const limit = Math.max(0, contentViewport.contentHeight - contentViewport.height);
        contentViewport.contentY = Math.max(0, Math.min(limit, contentViewport.contentY + direction * Math.max(1, contentViewport.height * 0.8)));
    }

    function revealContent(top: real, bottom: real): void {
        const limit = Math.max(0, contentViewport.contentHeight - contentViewport.height);
        const margin = theme.spacing3;
        const nextY = bottom + margin > contentViewport.contentY + contentViewport.height ? bottom + margin - contentViewport.height : top - margin < contentViewport.contentY ? top - margin : contentViewport.contentY;
        contentViewport.contentY = Math.max(0, Math.min(limit, nextY));
    }

    Shortcut {
        sequence: "Shift+Esc"
        context: Qt.ApplicationShortcut
        enabled: host.expansionState.hasCurrent
        onActivated: host.expansionState.close()
    }

    // QQuickItem can consume Backtab while moving focus among children before
    // Controls sees a key press. Bind reverse slider traversal on the hub's
    // owning window instead; it remains disabled in every other view/detail.
    Shortcut {
        sequence: "Shift+Tab"
        context: Qt.WindowShortcut
        autoRepeat: false
        enabled: !!host.systemContent && host.systemContent.sliderNavigationEnabled
        onActivated: host.systemContent.cycleSlider(-1)
    }

    Shortcut {
        sequence: "PgDown"
        context: Qt.ApplicationShortcut
        enabled: host.hostPageShortcutsEnabled && contentViewport.contentHeight > contentViewport.height
        onActivated: host.pageContent(1)
    }

    Shortcut {
        sequence: "PgUp"
        context: Qt.ApplicationShortcut
        enabled: host.hostPageShortcutsEnabled && contentViewport.contentHeight > contentViewport.height
        onActivated: host.pageContent(-1)
    }

    // I/O cycle the three hub destinations; nested detail views keep their
    // own text and action shortcuts (including I for network details and O for clips).
    Shortcut {
        sequence: "I"
        context: Qt.ApplicationShortcut
        enabled: host.tabShortcutsEnabled
        onActivated: host.cycleTab(-1)
    }

    Shortcut {
        sequence: "O"
        context: Qt.ApplicationShortcut
        enabled: host.tabShortcutsEnabled
        onActivated: host.cycleTab(1)
    }

    // The Controls root keeps U/D half-page navigation as well as PageUp/Down.
    // Never intercept D in the captures detail, where it requests deletion.
    Shortcut {
        sequence: "U"
        context: Qt.ApplicationShortcut
        enabled: host.expansionState.currentName === "system" && !host.detailVisible && !host.helpVisible && contentViewport.contentHeight > contentViewport.height
        onActivated: host.pageContent(-1)
    }

    Shortcut {
        sequence: "D"
        context: Qt.ApplicationShortcut
        enabled: host.expansionState.currentName === "system" && !host.detailVisible && !host.helpVisible && contentViewport.contentHeight > contentViewport.height
        onActivated: host.pageContent(1)
    }

    function restoreKeyboardAfterWorkspace(): void {
        if (!expansionState.hasCurrent || themeTerminalActive)
            return;
        focusGrabLost.stop();
        restoringWorkspaceFocus = true;
        keyboardFocusReady = false;
        // Release and reacquire the compositor's keyboard grab AFTER the
        // workspace switch; re-focusing a QML child alone cannot restore a
        // Wayland keyboard focus that Hyprland moved to a workspace client.
        workspaceFocusRestart.restart();
    }

    Timer {
        id: focusGrabLost
        interval: 170
        repeat: false
        onTriggered: {
            if (host.expansionState.hasCurrent && !host.restoringWorkspaceFocus && !host.themeTerminalActive)
                host.expansionState.close();
        }
    }

    Timer {
        id: workspaceFocusRestart
        interval: 35
        repeat: false
        onTriggered: {
            if (!host.expansionState.hasCurrent || host.themeTerminalActive) {
                host.restoringWorkspaceFocus = false;
                return;
            }
            host.restoringWorkspaceFocus = false;
            Qt.callLater(() => {
                if (host.expansionState.hasCurrent && host.loadedContent)
                    host.loadedContent.forceActiveFocus();
            });
        }
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged(): void {
            host.restoreKeyboardAfterWorkspace();
        }
    }

    // Focus only the expansion surface at first. Hyprland may otherwise
    // select the non-keyboard-focusable bar when a grab initially registers
    // multiple committed surfaces. Admit the bar after this window acquires
    // focus so clicks can still switch tabs without dismissing the hub.
    Connections {
        target: host.contentItem ? host.contentItem.Window.window : null

        function onActiveChanged(): void {
            if (host.contentItem.Window.window.active && host.expansionState.hasCurrent)
                host.keyboardFocusReady = true;
        }
    }

    HyprlandFocusGrab {
        active: host.expansionState.hasCurrent && host.backingWindowVisible && !host.themeTerminalActive && !host.restoringWorkspaceFocus
        windows: host.keyboardFocusReady && host.barVisible ? [host].concat(host.barWindows) : [host]
        onCleared: {
            if (!host.themeTerminalActive && !host.restoringWorkspaceFocus)
                focusGrabLost.restart();
        }
    }

    function finishCloseIfSettled(): void {
        if (expansionState.hasCurrent || !closing)
            return;
        // QML animations may be interrupted by rendering stalls or mode
        // changes. Check the actual silhouette before releasing the frame.
        const widthGoal = Math.min(viewportWidth, closeWidth);
        const heightGoal = Math.min(viewportHeight, closeHeight);
        if (Math.abs(shellSurface.width - widthGoal) > 0.75 || Math.abs(shellSurface.height - heightGoal) > 0.75) {
            closeTimer.interval = 16;
            closeTimer.restart();
            return;
        }
        closing = false;
        expansionState.finishClose();
        measuredContentWidth = 0;
        measuredContentHeight = 0;
    }

    Timer {
        id: closeTimer
        interval: host.motion.morph
        repeat: false
        onTriggered: host.finishCloseIfSettled()
    }

    Connections {
        target: host.expansionState

        function onHasCurrentChanged(): void {
            const epoch = ++host.transitionEpoch;
            host.keyboardFocusReady = false;
            if (!host.expansionState.hasCurrent) {
                workspaceFocusRestart.stop();
                focusGrabLost.stop();
                host.restoringWorkspaceFocus = false;
            }
            if (host.expansionState.hasCurrent) {
                const reversingClose = host.closing;
                closeTimer.stop();
                host.closing = false;
                host.themeTerminalActive = false;
                // Reversals expand directly from the geometry on screen;
                // toggling through the compact target introduces a snap.
                host.contentExpanded = reversingClose;
                if (!reversingClose) {
                    geometryUpdate.restart();
                    Qt.callLater(() => {
                        if (host.transitionEpoch === epoch && host.expansionState.hasCurrent)
                            host.contentExpanded = true;
                    });
                }
            } else if (host.visible) {
                host.closeStartWidth = shellSurface.width;
                host.closeStartHeight = shellSurface.height;
                host.closeLayoutWidth = shellSurface.contentLayoutWidth;
                host.closeLayoutHeight = shellSurface.contentLayoutHeight;
                // Freeze these endpoint dimensions before content can change
                // while the exit geometry is already in flight.
                host.closeWidth = Math.max(1, host.compactWidth);
                host.closeHeight = Math.max(1, host.compactHeight);
                host.closing = true;
                host.contentExpanded = false;
                closeTimer.interval = host.motion.morph;
                closeTimer.restart();
            }
        }
    }

    ShellSurface {
        id: shellSurface

        // The centre moves independently of width so the two morph curves do
        // not repeatedly restart each other as the target's width changes.
        x: Math.max(0, Math.min(host.viewportWidth - width, host.animatedSurfaceCenter - width / 2))
        y: 0
        width: Math.min(host.viewportWidth, host.targetWidth)
        height: Math.min(host.viewportHeight, host.targetHeight)
        // The clipping silhouette morphs, but the content is laid out at
        // its destination size rather than reflowing on every frame.
        contentLayoutWidth: Math.max(1, Math.min(host.viewportWidth, host.closing ? host.closeLayoutWidth : Math.max(host.contentWidth, host.expansionState.originWidth)))
        contentLayoutHeight: Math.max(1, Math.min(host.viewportHeight, host.closing ? host.closeLayoutHeight : Math.max(host.contentHeight, host.expansionState.originHeight)))
        clip: true
        // Keep the backing surface visible until the closing geometry finishes.
        opacity: host.expansionState.hasCurrent || (host.closing && (host.frameVisible || host.barVisible)) ? 1 : host.closing ? Math.max(0, Math.min(1, (width - host.closeWidth) / Math.max(1, host.closeStartWidth - host.closeWidth) * 2)) : 0

        Behavior on width {
            NumberAnimation {
                duration: host.motion.morph
                easing.type: host.motion.morphType
                easing.bezierCurve: host.motion.morphCurve
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: host.motion.morph
                easing.type: host.motion.morphType
                easing.bezierCurve: host.motion.morphCurve
            }
        }

        Behavior on opacity {
            Anim {
                motion: host.motion
                type: Anim.FastEffects
            }
        }

        theme: host.theme
        motion: host.motion
        surfaceLayer: ShellSurface.Pane
        frameConnected: host.frameVisible
        // The same background colour in both modes prevents a visible dark
        // flash when the connected frame is toggled around an open panel.
        // The frame outline and this attached surface share one background.
        // Its fill fades with the frame connection, so the frame alone owns
        // the tint and blur once the contour joins up.
        fillColor: host.theme.background
        luminous: false
        luminousColor: host.theme.textStrong
        lightIntensity: 0.22
        elevated: true
        // The old double-offset silhouette produced grey corner blobs on
        // light backgrounds. The panel already has a continuous contour.
        shadowStrength: 0
        cornerRadius: host.contentExpanded ? host.theme.radiusPanel : Math.min(host.theme.radiusPanel, (host.closing ? host.closeHeight : host.barVisible ? host.expansionState.originHeight : host.compactHeight) / 2)
        borderColor: Qt.rgba(host.theme.textStrong.r, host.theme.textStrong.g, host.theme.textStrong.b, 0.14)
        borderWidth: host.frameVisible ? 0 : host.theme.borderThin

        Behavior on cornerRadius {
            enabled: host.contentExpanded || host.closing

            NumberAnimation {
                duration: host.motion.morph
                easing.type: host.motion.morphType
                easing.bezierCurve: host.motion.morphCurve
            }
        }

        // The prewarmed page grows with the viewport, including Themes and
        // Wallpaper. Do not wait until the outer squircle is nearly full size.
        readonly property real contentReveal: {
            const fraction = Math.min(width / Math.max(1, host.closing ? host.closeLayoutWidth : host.contentWidth), height / Math.max(1, host.closing ? host.closeLayoutHeight : host.contentHeight));
            return host.chromeOpacity * Math.max(0, Math.min(1, (fraction - 0.18) / 0.72));
        }

        HubTabs {
            id: tabs
            opacity: shellSurface.contentReveal
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: host.theme.spacing4
                rightMargin: host.theme.spacing4
                topMargin: host.theme.spacing3
            }
            runtime: host.runtime
            theme: host.theme
            motion: host.motion
            currentTab: host.currentTab
            onTabRequested: destination => host.navigate(destination)
        }

        // The same raised material as Controls groups keeps footer key hints
        // readable without leaving them on the darker frame backing. This is
        // a static fill, not another blurred or animated layer.
        Rectangle {
            id: footerSurface
            opacity: shellSurface.contentReveal
            x: hubFooter.x + (hubFooter.width - width) / 2
            y: hubFooter.y - host.theme.spacing2
            width: Math.min(hubFooter.width, Math.max(1, Math.max(footerHints.implicitWidth, hubFooter.scrollHintsVisible ? footerScrollHints.implicitWidth : 0) + host.theme.spacing4 * 2))
            height: hubFooter.height + host.theme.spacing2 * 2
            radius: host.theme.radiusMedium
            color: host.theme.expressiveSurface
            border.width: host.theme.borderThin
            border.color: host.theme.subtleBorder
        }

        Column {
            id: hubFooter
            opacity: shellSurface.contentReveal
            width: Math.max(1, parent.width - host.theme.spacing3 * 2)
            height: implicitHeight
            anchors.horizontalCenter: parent.horizontalCenter
            // Anchor to the *painted* silhouette, never the cached content
            // layout: Controls can exceed the screen and get clipped. The
            // navigation pill needs exactly the same visible bottom gap as
            // the shorter Home, Now Playing and Activity panels.
            y: Math.max(0, host.visibleFooterBottom - height - host.footerBottomClearance)
            spacing: host.theme.spacing1

            // Global navigation lives here; local widget hints remain
            // next to their controls in each view.
            readonly property real scrollBudget: Math.max(1, host.viewportHeight - tabs.implicitHeight - host.theme.spacing4 * 2 - host.theme.spacing3 * 3 - host.footerBottomClearance - footerHints.implicitHeight)
            readonly property bool scrollHintsVisible: host.loadedContent && host.loadedContent.implicitHeight > scrollBudget

            Row {
                id: footerHints
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: host.theme.keyHintGroupGap

                Repeater {
                    model: (host.tabShortcutsEnabled ? [
                            {
                                shortcut: "I",
                                label: "Previous"
                            },
                            {
                                shortcut: "O",
                                label: "Next"
                            }
                        ] : []).concat([
                        {
                            shortcut: "ESC",
                            label: host.escapeHintLabel
                        },
                        {
                            shortcut: "SHIFT+ESC",
                            label: "Close all"
                        }
                    ])
                    delegate: KeyHint {
                        required property var modelData
                        shortcut: modelData.shortcut
                        label: modelData.label
                        runtime: host.runtime
                        theme: host.theme
                        compact: true
                    }
                }
            }

            Row {
                id: footerScrollHints
                visible: hubFooter.scrollHintsVisible
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: host.theme.spacing2
                KeyChord {
                    visible: host.expansionState.currentName === "system" && !host.detailVisible
                    anchors.verticalCenter: parent.verticalCenter
                    shortcut: "U/D"
                    fontFamily: host.runtime.fontMono
                    textColor: host.theme.textStrong
                    fontSize: host.theme.fontKeyHint
                }
                KeyChord {
                    anchors.verticalCenter: parent.verticalCenter
                    shortcut: "PGUP/PGDN"
                    fontFamily: host.runtime.fontMono
                    textColor: host.theme.textStrong
                    fontSize: host.theme.fontKeyHint
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Scroll"
                    color: host.theme.textMuted
                    font.family: host.runtime.fontMono
                    font.pixelSize: host.theme.fontKeyHint
                }
            }
        }

        Flickable {
            id: contentViewport
            opacity: shellSurface.contentReveal
            anchors {
                top: tabs.bottom
                left: parent.left
                right: parent.right
                bottom: hubFooter.top
                topMargin: host.theme.spacing3
                leftMargin: host.theme.spacing4
                rightMargin: host.theme.spacing4
                // Keep Controls content comfortably separated from global
                // navigation, including when the tray is the last row.
                bottomMargin: host.theme.spacing3 + (host.expansionState.currentName === "system" && !host.detailVisible ? host.theme.spacing4 : 0)
            }
            clip: true
            // Retain the last two views while the hub is open, so returning to
            // Home or Controls does not reconstruct their expensive models.
            // Scaling only compensates while the animated viewport narrows.
            contentWidth: width
            contentHeight: Math.max(height, host.activeLoader ? host.activeLoader.height * host.activeLoader.scale : 0)
            boundsBehavior: Flickable.StopAtBounds
            // Nested detail galleries and the Activity/Calendar pages own
            // their own scrolling. The host Flickable must not steal their
            // mouse grabs or cancel hover while the pointer crosses tiles.
            interactive: contentHeight > height && !host.detailVisible && host.expansionState.currentName !== "activity" && host.expansionState.currentName !== "calendar"

            Loader {
                id: contentLoaderA
                asynchronous: true
                readonly property Item contentItem: item as Item
                width: Math.max(1, Math.min(host.viewportWidth - host.theme.spacing4 * 2, Math.max(600, contentItem ? contentItem.implicitWidth : 600)))
                height: Math.max(1, contentItem ? contentItem.implicitHeight : 0)
                transformOrigin: Item.TopLeft
                scale: Math.min(1, contentViewport.width / Math.max(1, width))
                x: (contentViewport.width - width * scale) / 2
                opacity: 0
                enabled: host.activeSlot === 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: host.activeSlot === 0 ? host.motion.contentFade : host.motion.effectsFast
                        easing.type: host.motion.enterType
                        easing.bezierCurve: host.activeSlot === 0 ? host.motion.enterCurve : host.motion.exitCurve
                    }
                }
                onLoaded: host.onLoaderReady(contentLoaderA)
            }

            Loader {
                id: contentLoaderB
                asynchronous: true
                readonly property Item contentItem: item as Item
                width: Math.max(1, Math.min(host.viewportWidth - host.theme.spacing4 * 2, Math.max(600, contentItem ? contentItem.implicitWidth : 600)))
                height: Math.max(1, contentItem ? contentItem.implicitHeight : 0)
                transformOrigin: Item.TopLeft
                scale: Math.min(1, contentViewport.width / Math.max(1, width))
                x: (contentViewport.width - width * scale) / 2
                opacity: 0
                enabled: host.activeSlot === 1
                Behavior on opacity {
                    NumberAnimation {
                        duration: host.activeSlot === 1 ? host.motion.contentFade : host.motion.effectsFast
                        easing.type: host.motion.enterType
                        easing.bezierCurve: host.activeSlot === 1 ? host.motion.enterCurve : host.motion.exitCurve
                    }
                }
                onLoaded: host.onLoaderReady(contentLoaderB)
            }

            Loader {
                id: contentLoaderC
                asynchronous: true
                readonly property Item contentItem: item as Item
                width: Math.max(1, Math.min(host.viewportWidth - host.theme.spacing4 * 2, Math.max(600, contentItem ? contentItem.implicitWidth : 600)))
                height: Math.max(1, contentItem ? contentItem.implicitHeight : 0)
                transformOrigin: Item.TopLeft
                scale: Math.min(1, contentViewport.width / Math.max(1, width))
                x: (contentViewport.width - width * scale) / 2
                opacity: 0
                enabled: host.activeSlot === 2
                Behavior on opacity {
                    NumberAnimation {
                        duration: host.activeSlot === 2 ? host.motion.contentFade : host.motion.effectsFast
                        easing.type: host.motion.enterType
                        easing.bezierCurve: host.activeSlot === 2 ? host.motion.enterCurve : host.motion.exitCurve
                    }
                }
                onLoaded: host.onLoaderReady(contentLoaderC)
            }

            Loader {
                id: contentLoaderD
                asynchronous: true
                readonly property Item contentItem: item as Item
                width: Math.max(1, Math.min(host.viewportWidth - host.theme.spacing4 * 2, Math.max(600, contentItem ? contentItem.implicitWidth : 600)))
                height: Math.max(1, contentItem ? contentItem.implicitHeight : 0)
                transformOrigin: Item.TopLeft
                scale: Math.min(1, contentViewport.width / Math.max(1, width))
                x: (contentViewport.width - width * scale) / 2
                opacity: 0
                enabled: host.activeSlot === 3
                Behavior on opacity {
                    NumberAnimation {
                        duration: host.activeSlot === 3 ? host.motion.contentFade : host.motion.effectsFast
                        easing.type: host.motion.enterType
                        easing.bezierCurve: host.activeSlot === 3 ? host.motion.enterCurve : host.motion.exitCurve
                    }
                }
                onLoaded: host.onLoaderReady(contentLoaderD)
            }

            Loader {
                id: contentLoaderE
                asynchronous: true
                readonly property Item contentItem: item as Item
                width: Math.max(1, Math.min(host.viewportWidth - host.theme.spacing4 * 2, Math.max(600, contentItem ? contentItem.implicitWidth : 600)))
                height: Math.max(1, contentItem ? contentItem.implicitHeight : 0)
                transformOrigin: Item.TopLeft
                scale: Math.min(1, contentViewport.width / Math.max(1, width))
                x: (contentViewport.width - width * scale) / 2
                opacity: 0
                enabled: host.activeSlot === 4
                Behavior on opacity {
                    NumberAnimation {
                        duration: host.activeSlot === 4 ? host.motion.contentFade : host.motion.effectsFast
                        easing.type: host.motion.enterType
                        easing.bezierCurve: host.activeSlot === 4 ? host.motion.enterCurve : host.motion.exitCurve
                    }
                }
                onLoaded: host.onLoaderReady(contentLoaderE)
            }
        }

        Connections {
            target: host.systemContent
            function onHelpScrollRequested(steps: int): void {
                scopedHelp.scrollHints(steps);
            }
        }

        Connections {
            target: host.mediaContent
            function onHelpScrollRequested(steps: int): void {
                scopedHelp.scrollHints(steps);
            }
        }

        Item {
            z: 200
            anchors.fill: parent
            opacity: shellSurface.contentReveal

            WidgetHelp {
                id: scopedHelp
                keyboardScroll: true
                anchors.fill: parent
                runtime: host.runtime
                theme: host.theme
                motion: host.motion
                open: host.helpVisible
                title: host.helpCaption
                bindings: host.helpKeys
                backdropRadius: host.theme.radiusPanel
                onDismissed: {
                    if (host.systemContent)
                        host.systemContent.helpOpen = false;
                    else if (host.mediaContent)
                        host.mediaContent.helpOpen = false;
                }
            }
        }

        LoadingOutline {
            anchors.fill: parent
            surface: shellSurface
            active: !host.frameVisible && host.loadingOperationVisible
            motionEnabled: host.motion.enabled
            highlightColor: host.wallpaperOperationVisible ? host.theme.roleColor("wallpaper") : host.captureEditorRequestVisible ? host.theme.roleColor("screenshot") : host.systemContent && host.systemContent.maintenanceOperationRole.length > 0 ? host.theme.roleColor(host.systemContent.maintenanceOperationRole) : host.theme.accent
            lineWidth: 3
        }
    }
}

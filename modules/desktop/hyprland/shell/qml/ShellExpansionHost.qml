pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

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
    // The bar clock returns as the hub retracts into its source island,
    // rather than appearing abruptly when closeTimer completes.
    readonly property real clockReveal: {
        if (expansionState.hasCurrent)
            return 0;
        if (!closing)
            return 1;
        const span = Math.max(1, Math.max(contentWidth, expansionState.originWidth) - expansionState.originWidth);
        const progress = Math.max(0, Math.min(1, (Math.max(contentWidth, expansionState.originWidth) - shellSurface.width) / span));
        const reveal = Math.max(0, Math.min(1, (progress - 0.55) / 0.45));
        return reveal * reveal * (3 - 2 * reveal);
    }
    property bool keyboardFocusReady: false

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
    readonly property real contentHeight: loadedContent && loadedContent.implicitHeight > 0 ? loadedContent.implicitHeight + tabs.implicitHeight + hubFooter.implicitHeight + theme.spacing3 * 2 + theme.spacing4 * 2 : (measuredContentHeight > 0 ? measuredContentHeight : expansionState.originHeight)

    function updateContentGeometry(): void {
        if (!loadedContent || loadedContent.implicitWidth <= 0 || loadedContent.implicitHeight <= 0)
            return;
        measuredContentWidth = Math.max(loadedContent.implicitWidth, 600) + theme.spacing4 * 2;
        measuredContentHeight = loadedContent.implicitHeight + tabs.implicitHeight + hubFooter.implicitHeight + theme.spacing3 * 2 + theme.spacing4 * 2;
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
    // With neither frame nor bar, the floating hub opens at its natural size.
    // That shortcut must NOT apply while closing: it prevented the normal
    // width/height animations from receiving a smaller target at all.
    readonly property bool floatingOpen: !frameVisible && !barVisible && !closing
    readonly property real targetWidth: floatingOpen || contentExpanded ? Math.max(contentWidth, expansionState.originWidth) : expansionState.originWidth
    readonly property real targetHeight: floatingOpen || contentExpanded ? Math.max(contentHeight, expansionState.originHeight) : expansionState.originHeight
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
    // The visible close morph must shrink in place, not simultaneously drift
    // toward the bar island. Reset its source centre only after fading out.
    property real animatedSurfaceCenter: contentExpanded || closing ? viewportWidth / 2 : boundedOriginCenter

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

    Shortcut {
        sequence: "PgDown"
        context: Qt.ApplicationShortcut
        enabled: host.expansionState.hasCurrent && contentViewport.contentHeight > contentViewport.height
        onActivated: host.pageContent(1)
    }

    Shortcut {
        sequence: "PgUp"
        context: Qt.ApplicationShortcut
        enabled: host.expansionState.hasCurrent && contentViewport.contentHeight > contentViewport.height
        onActivated: host.pageContent(-1)
    }

    Shortcut {
        sequence: "Z"
        context: Qt.ApplicationShortcut
        enabled: host.expansionState.hasCurrent
        onActivated: host.cycleTab(1)
    }

    Shortcut {
        sequence: "Shift+Z"
        context: Qt.ApplicationShortcut
        enabled: host.expansionState.hasCurrent
        onActivated: host.cycleTab(-1)
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
        active: host.expansionState.hasCurrent && host.backingWindowVisible && !host.themeTerminalActive
        windows: host.keyboardFocusReady && host.barVisible ? [host].concat(host.barWindows) : [host]
        onCleared: {
            if (!host.themeTerminalActive)
                host.expansionState.close();
        }
    }

    Timer {
        id: closeTimer
        interval: host.motion.morph
        repeat: false
        onTriggered: {
            host.closing = false;
            host.expansionState.finishClose();
            host.measuredContentWidth = 0;
            host.measuredContentHeight = 0;
        }
    }

    Connections {
        target: host.expansionState

        function onHasCurrentChanged(): void {
            const epoch = ++host.transitionEpoch;
            host.keyboardFocusReady = false;
            if (host.expansionState.hasCurrent) {
                if (!host.closing)
                    geometryUpdate.restart();
                closeTimer.stop();
                host.closing = false;
                host.themeTerminalActive = false;
                host.contentExpanded = false;
                Qt.callLater(() => {
                    if (host.transitionEpoch === epoch && host.expansionState.hasCurrent)
                        host.contentExpanded = true;
                });
            } else if (host.visible) {
                host.closing = true;
                host.contentExpanded = false;
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
        clip: true
        // Keep the backing surface visible until the closing geometry finishes.
        opacity: host.expansionState.hasCurrent || host.closing ? 1 : 0

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
        // The same background colour in both modes prevents a visible dark
        // flash when the connected frame is toggled around an open panel.
        // The frame outline and this attached surface share one background.
        // Keep its fill across frame toggles so the fade cannot expose an
        // empty, flickering rectangle between the two Wayland layers.
        fillColor: host.theme.musicReactiveBackground
        luminous: false
        luminousColor: host.theme.textStrong
        lightIntensity: 0.22
        elevated: true
        // The old double-offset silhouette produced grey corner blobs on
        // light backgrounds. The panel already has a continuous contour.
        shadowStrength: 0
        cornerRadius: host.contentExpanded ? host.theme.radiusPanel : Math.min(host.theme.radiusPanel, host.expansionState.originHeight / 2)
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
            const fraction = Math.min(width / Math.max(1, host.contentWidth), height / Math.max(1, host.contentHeight));
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

        Column {
            id: hubFooter
            opacity: shellSurface.contentReveal
            width: Math.max(1, parent.width - host.theme.spacing3 * 2)
            height: implicitHeight
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                bottomMargin: host.theme.spacing3
            }
            spacing: host.theme.spacing1

            // Tab/back/scroll navigation belongs in the shared footer, while
            // action mnemonics stay on controls. Centre the group as one line;
            // optional scrolling gets a separate, non-crowded second line.
            readonly property real scrollBudget: Math.max(1, host.viewportHeight - tabs.implicitHeight - host.theme.spacing4 * 2 - host.theme.spacing3 * 4 - host.theme.fontKeyHint * 2)
            readonly property bool scrollHintsVisible: host.loadedContent && host.loadedContent.implicitHeight > scrollBudget
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: host.theme.keyHintGroupGap

                Repeater {
                    model: [
                        {
                            shortcut: "Z",
                            label: "Next"
                        },
                        {
                            shortcut: "SHIFT+Z",
                            label: "Previous"
                        },
                    ].concat(host.detailVisible ? [] : [
                        {
                            shortcut: "ESC",
                            label: "Close"
                        }
                    ]).concat([
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
                    }
                }
            }

            Row {
                visible: hubFooter.scrollHintsVisible
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: host.theme.spacing2
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
                bottomMargin: host.theme.spacing3
            }
            clip: true
            // Retain the last two views while the hub is open, so returning to
            // Home or Controls does not reconstruct their expensive models.
            // Scaling only compensates while the animated viewport narrows.
            contentWidth: width
            contentHeight: Math.max(height, host.activeLoader ? host.activeLoader.height * host.activeLoader.scale : 0)
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

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

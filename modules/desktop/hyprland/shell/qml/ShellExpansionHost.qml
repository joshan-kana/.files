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
    property bool themeTerminalActive: false
    property bool keyboardFocusReady: false

    // Precreate each hub view before its first invocation, including Media and
    // Weather. No destination evicts another or constructs on the keypress.
    property int activeSlot: -1
    readonly property Loader activeLoader: activeSlot === 0 ? contentLoaderA : activeSlot === 1 ? contentLoaderB : activeSlot === 2 ? contentLoaderC : activeSlot === 3 ? contentLoaderD : activeSlot === 4 ? contentLoaderE : null
    readonly property Item loadedContent: activeLoader ? activeLoader.item as Item : null
    readonly property SystemContent systemContent: expansionState.currentName === "system" ? loadedContent as SystemContent : null
    readonly property bool themeOperationVisible: !!systemContent && systemContent.themeOperationRunning && expansionState.hasCurrent
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
    readonly property real targetWidth: contentExpanded ? Math.max(expansionState.originWidth, contentWidth) : expansionState.originWidth
    readonly property real targetHeight: contentExpanded ? Math.max(expansionState.originHeight, contentHeight) : expansionState.originHeight
    // Keep the layer as small as the hub's compositor-safe viewport.
    // A fullscreen transparent backing needlessly multiplies blur work
    // when Frosted Glass is enabled, especially on high-DPI displays.
    readonly property real viewportWidth: screen ? Math.min(screen.width - theme.spacing4 * 2, 960) : 1
    readonly property real viewportHeight: screen ? Math.max(1, screen.height - (theme.barHeight + theme.spacing1) - theme.spacing4) : 1
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
    updatesEnabled: surfaceLifecycle.needsRendering
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
        top: theme.barHeight + theme.spacing1
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
        windows: host.keyboardFocusReady ? [host].concat(host.barWindows) : [host]
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
            host.keyboardFocusReady = false;
            if (host.expansionState.hasCurrent) {
                if (!host.closing)
                    geometryUpdate.restart();
                closeTimer.stop();
                host.closing = false;
                host.themeTerminalActive = false;
                host.contentExpanded = false;
                Qt.callLater(() => host.contentExpanded = true);
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
        opacity: host.contentExpanded && host.expansionState.hasCurrent ? 1 : 0

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
        fillColor: host.theme.panelBase
        luminous: true
        luminousColor: host.theme.textStrong
        lightIntensity: 0.22
        elevated: true
        // The old double-offset silhouette produced grey corner blobs on
        // light backgrounds. The panel already has a continuous contour.
        shadowStrength: 0
        cornerRadius: host.contentExpanded ? host.theme.radiusPanel : Math.min(host.theme.radiusPanel, host.expansionState.originHeight / 2)
        borderColor: Qt.rgba(host.theme.textStrong.r, host.theme.textStrong.g, host.theme.textStrong.b, 0.14)
        borderWidth: host.theme.borderThin

        Behavior on cornerRadius {
            enabled: host.contentExpanded || host.closing

            NumberAnimation {
                duration: host.motion.morph
                easing.type: host.motion.morphType
                easing.bezierCurve: host.motion.morphCurve
            }
        }

        HubTabs {
            id: tabs
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

        LoadingOutline {
            anchors.fill: parent
            surface: shellSurface
            active: host.themeOperationVisible
            motionEnabled: host.motion.enabled
            highlightColor: host.theme.accent
            lineWidth: 3
        }
    }
}

pragma ComponentBehavior: Bound
import QtQuick
import "KeyGlyphs.js" as KeyGlyphs
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

    // Keep the outgoing component alive while the new view enters. Replacing
    // one Loader destroys the old view instantly, causing a hard content cut
    // even though the surrounding surface continues to morph.
    property int activeSlot: -1
    readonly property Loader activeLoader: activeSlot === 0 ? contentLoaderA : activeSlot === 1 ? contentLoaderB : null
    readonly property Item loadedContent: activeLoader ? activeLoader.item as Item : null
    readonly property SystemContent systemContent: expansionState.currentName === "system" ? loadedContent as SystemContent : null

    function presentComponent(next: Component): void {
        if (!next) {
            contentTransition.stop();
            contentLoaderA.sourceComponent = null;
            contentLoaderB.sourceComponent = null;
            activeSlot = -1;
            return;
        }

        if (activeLoader && activeLoader.sourceComponent === next)
            return;

        const incoming = activeSlot === 0 ? contentLoaderB : contentLoaderA;
        const outgoing = activeLoader;
        contentTransition.stop();
        incoming.opacity = 0;
        // Enable the destination before constructing its FocusScope. Its
        // onEngagedChanged requests keyboard focus during instantiation.
        activeSlot = incoming === contentLoaderA ? 0 : 1;
        incoming.sourceComponent = next;
        contentViewport.contentY = 0;
        if (outgoing) {
            outgoing.opacity = 0;
            incoming.opacity = 1;
            contentTransition.restart();
        } else {
            incoming.opacity = 1;
        }
        geometryUpdate.restart();
        // FocusScope descendants request focus as they are constructed, but
        // Loader can replace that focus while finishing the load. Restore it
        // once the destination is fully attached to the active loader.
        Qt.callLater(() => {
            if (host.expansionState.hasCurrent && host.currentComponent === next && host.loadedContent)
                host.loadedContent.forceActiveFocus();
        });
    }

    onCurrentComponentChanged: presentComponent(currentComponent)
    Component.onCompleted: presentComponent(currentComponent)

    Timer {
        id: contentTransition
        interval: Math.max(1, host.motion.morph)
        repeat: false
        onTriggered: {
            const outgoing = host.activeSlot === 0 ? contentLoaderB : contentLoaderA;
            outgoing.sourceComponent = null;
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
    // The Wayland layer surface is a stable transparent viewport. Morph only
    // the inner squircle: resizing/repositioning PanelWindow every tab switch
    // causes separate compositor commits and visibly lagging/jumping edges.
    readonly property real viewportWidth: screen ? Math.min(screen.width - theme.spacing4 * 2, 960) : 1
    readonly property real viewportHeight: screen ? Math.max(1, screen.height - (62 + theme.spacing1) - theme.spacing4) : 1

    screen: expansionState.screen
    visible: expansionState.hasCurrent || closing
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
        top: 62 + theme.spacing1
        left: host.screen ? (host.screen.width - host.viewportWidth) / 2 : 0
    }

    WlrLayershell.namespace: "linux-desktop-expansion"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: expansionState.hasCurrent && !themeTerminalActive ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region {
        item: shellSurface
    }

    function navigate(destination: string): void {
        const next = destination === "home" ? "calendar" : destination === "activity" ? "activity" : "system";
        if (next === expansionState.currentName)
            return;

        expansionState.currentView = "";
        expansionState.currentName = next;
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

    HyprlandFocusGrab {
        active: host.expansionState.hasCurrent && !host.themeTerminalActive
        // Bar-originated navigation stays inside the same focus group.
        windows: [host].concat(host.barWindows)
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

        x: (host.width - width) / 2
        y: 0
        width: Math.min(host.width, host.targetWidth)
        height: Math.min(host.height, host.targetHeight)
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
        readonly property color panelTone: Qt.tint(host.theme.background, Qt.rgba(host.theme.surfaceRaised.r, host.theme.surfaceRaised.g, host.theme.surfaceRaised.b, 0.71))
        fillColor: Qt.rgba(panelTone.r, panelTone.g, panelTone.b, host.theme.runtime.panelOpacity)
        luminous: true
        luminousColor: host.theme.accent
        lightIntensity: 1.45
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

        Text {
            id: hubFooter
            width: Math.max(1, parent.width - host.theme.spacing3 * 2)
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                bottomMargin: host.theme.spacing3
            }
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            // Use intrinsic tab content and the stable viewport budget. Testing
            // against contentViewport.height would make this Text's own wrap
            // height a dependency of its content, creating a binding loop.
            readonly property real scrollBudget: Math.max(1, host.viewportHeight - tabs.implicitHeight - host.theme.spacing4 * 2 - host.theme.spacing3 * 4 - host.theme.fontKeyHint * 2)
            text: KeyGlyphs.display("Z  NEXT     SHIFT+Z  PREVIOUS     ESC  BACK / CLOSE     SHIFT+ESC  CLOSE") + (host.loadedContent && host.loadedContent.implicitHeight > scrollBudget ? "     PGUP/PGDN  SCROLL" : "")
            color: host.theme.textMuted
            font.family: host.runtime.fontMono
            font.pixelSize: host.theme.fontKeyHint
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
            // Each view retains its destination layout; overlapping loaders
            // crossfade while the squircle morphs. Scaling compensates only
            // for the brief period when the animated viewport is narrower.
            contentWidth: width
            contentHeight: host.activeLoader ? host.activeLoader.height * host.activeLoader.scale : height
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            Loader {
                id: contentLoaderA
                readonly property Item contentItem: item as Item
                width: Math.max(1, Math.min(host.viewportWidth - host.theme.spacing4 * 2, Math.max(600, contentItem ? contentItem.implicitWidth : 600)))
                height: Math.max(contentViewport.height, contentItem ? contentItem.implicitHeight : 0)
                transformOrigin: Item.TopLeft
                scale: Math.min(1, contentViewport.width / Math.max(1, width))
                x: (contentViewport.width - width * scale) / 2
                opacity: 0
                enabled: host.activeSlot === 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: host.motion.contentFade
                        easing.type: host.motion.enterType
                        easing.bezierCurve: host.activeSlot === 0 ? host.motion.enterCurve : host.motion.exitCurve
                    }
                }
                onLoaded: geometryUpdate.restart()
            }

            Loader {
                id: contentLoaderB
                readonly property Item contentItem: item as Item
                width: Math.max(1, Math.min(host.viewportWidth - host.theme.spacing4 * 2, Math.max(600, contentItem ? contentItem.implicitWidth : 600)))
                height: Math.max(contentViewport.height, contentItem ? contentItem.implicitHeight : 0)
                transformOrigin: Item.TopLeft
                scale: Math.min(1, contentViewport.width / Math.max(1, width))
                x: (contentViewport.width - width * scale) / 2
                opacity: 0
                enabled: host.activeSlot === 1
                Behavior on opacity {
                    NumberAnimation {
                        duration: host.motion.contentFade
                        easing.type: host.motion.enterType
                        easing.bezierCurve: host.activeSlot === 1 ? host.motion.enterCurve : host.motion.exitCurve
                    }
                }
                onLoaded: geometryUpdate.restart()
            }
        }
    }
}

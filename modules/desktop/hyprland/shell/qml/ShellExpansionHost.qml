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

    property Component mediaComponent: null
    property Component systemComponent: null
    property Component calendarComponent: null
    property Component weatherComponent: null
    property Component activityComponent: null
    property bool contentExpanded: false
    property bool closing: false

    readonly property Item loadedContent: contentLoader.item as Item
    readonly property SystemContent systemContent: expansionState.currentName === "system" ? contentLoader.item as SystemContent : null
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
    readonly property real contentWidth: measuredContentWidth > 0 ? measuredContentWidth : expansionState.originWidth
    readonly property real contentHeight: measuredContentHeight > 0 ? measuredContentHeight : expansionState.originHeight

    function updateContentGeometry(): void {
        if (!loadedContent || loadedContent.implicitWidth <= 0 || loadedContent.implicitHeight <= 0)
            return;
        measuredContentWidth = Math.max(loadedContent.implicitWidth, 560) + theme.spacing5 * 2;
        measuredContentHeight = loadedContent.implicitHeight + tabs.implicitHeight + hubFooter.implicitHeight + theme.spacing3 * 2 + theme.spacing5 * 2;
    }

    Timer {
        id: geometryUpdate
        interval: 0
        repeat: false
        onTriggered: host.updateContentGeometry()
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
    readonly property real viewportHeight: screen ? Math.max(1, screen.height - (56 + theme.spacing1) - theme.spacing4) : 1

    screen: expansionState.screen
    visible: expansionState.hasCurrent || closing
    color: "transparent"
    focusable: expansionState.hasCurrent
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: Math.max(1, viewportWidth)
    implicitHeight: Math.max(1, viewportHeight)

    anchors {
        top: true
        left: true
    }

    margins {
        top: 56 + theme.spacing1
        left: host.screen ? (host.screen.width - host.viewportWidth) / 2 : 0
    }

    WlrLayershell.namespace: "linux-desktop-expansion"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: expansionState.hasCurrent ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

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
        active: host.expansionState.hasCurrent
        windows: [host]
        onCleared: host.expansionState.close()
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
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: host.motion.morph
                easing.type: host.motion.morphType
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
        cornerRadius: host.contentExpanded ? host.theme.radiusLarge : Math.min(host.theme.radiusLarge, host.expansionState.originHeight / 2)
        outlined: false

        Behavior on cornerRadius {
            enabled: host.contentExpanded || host.closing

            NumberAnimation {
                duration: host.motion.morph
                easing.type: host.motion.morphType
            }
        }

        HubTabs {
            id: tabs
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: host.theme.spacing5
                rightMargin: host.theme.spacing5
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
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                bottomMargin: host.theme.spacing3
            }
            text: "Z  NEXT     SHIFT+Z  PREVIOUS     ESC  CLOSE"
            color: host.theme.textMuted
            font.family: host.runtime.fontMono
            font.pixelSize: host.theme.fontSize(9)
        }

        Loader {
            id: contentLoader
            onLoaded: geometryUpdate.restart()

            anchors {
                top: tabs.bottom
                left: parent.left
                right: parent.right
                bottom: hubFooter.top
                topMargin: host.theme.spacing3
                leftMargin: host.theme.spacing5
                rightMargin: host.theme.spacing5
                bottomMargin: host.theme.spacing3
            }

            active: host.visible && host.currentComponent !== null
            sourceComponent: host.currentComponent
        }
    }
}

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
    // Falling back to the tiny bar origin for that intermediate frame made the
    // compositor repeatedly collapse and regrow the entire window.
    property real measuredContentWidth: 0
    property real measuredContentHeight: 0
    readonly property real contentWidth: measuredContentWidth > 0 ? measuredContentWidth : expansionState.originWidth
    readonly property real contentHeight: measuredContentHeight > 0 ? measuredContentHeight : expansionState.originHeight

    function updateContentGeometry(): void {
        if (!loadedContent || loadedContent.implicitWidth <= 0 || loadedContent.implicitHeight <= 0)
            return;
        measuredContentWidth = Math.max(loadedContent.implicitWidth, 560) + theme.spacing5 * 2;
        measuredContentHeight = loadedContent.implicitHeight + tabs.implicitHeight + theme.spacing3 + theme.spacing5 * 2;
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
    readonly property real horizontalMargin: {
        if (!screen)
            return 0;

        const width = contentExpanded ? contentWidth : expansionState.originWidth;
        const desired = contentExpanded ? (screen.width - width) / 2 : expansionState.originCenter - width / 2;
        const edge = theme.spacing4;
        return Math.max(edge, Math.min(desired, screen.width - width - edge));
    }
    property real animatedMargin: horizontalMargin

    Behavior on animatedMargin {
        enabled: host.contentExpanded || host.closing

        Anim {
            motion: host.motion
            type: Anim.DefaultSpatial
        }
    }

    screen: expansionState.screen
    visible: expansionState.hasCurrent || closing
    color: "transparent"
    focusable: expansionState.hasCurrent
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: Math.max(1, targetWidth)
    implicitHeight: Math.max(1, targetHeight)

    Behavior on implicitWidth {
        enabled: host.contentExpanded || host.closing

        Anim {
            motion: host.motion
            type: Anim.DefaultSpatial
        }
    }
    Behavior on implicitHeight {
        enabled: host.contentExpanded || host.closing

        Anim {
            motion: host.motion
            type: Anim.DefaultSpatial
        }
    }

    anchors {
        top: true
        left: true
    }

    margins {
        top: 56 + theme.spacing1
        left: host.animatedMargin
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
        sequence: "Ctrl+Tab"
        context: Qt.ApplicationShortcut
        enabled: host.expansionState.hasCurrent
        onActivated: host.cycleTab(1)
    }

    HyprlandFocusGrab {
        active: host.expansionState.hasCurrent
        windows: [host]
        onCleared: host.expansionState.close()
    }

    Timer {
        id: closeTimer
        interval: host.motion.spatialNormal
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

        Keys.priority: Keys.AfterItem
        Keys.onPressed: event => {
            if (host.expansionState.hasCurrent && event.key === Qt.Key_Tab && (event.modifiers & Qt.ControlModifier)) {
                host.cycleTab((event.modifiers & Qt.ShiftModifier) ? -1 : 1);
                event.accepted = true;
            }
        }

        anchors.fill: parent
        scale: host.contentExpanded && host.expansionState.hasCurrent ? 1 : 0.94
        opacity: host.contentExpanded && host.expansionState.hasCurrent ? 1 : 0

        Behavior on scale {
            Anim {
                motion: host.motion
                type: Anim.DefaultSpatial
            }
        }
        Behavior on opacity {
            Anim {
                motion: host.motion
                type: Anim.DefaultEffects
            }
        }

        theme: host.theme
        motion: host.motion
        surfaceLayer: ShellSurface.Pane
        cornerRadius: host.contentExpanded ? host.theme.radiusLarge : Math.min(host.theme.radiusLarge, host.expansionState.originHeight / 2)
        outlined: false

        Behavior on cornerRadius {
            enabled: host.contentExpanded || host.closing

            Anim {
                motion: host.motion
                type: Anim.DefaultSpatial
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

        Loader {
            id: contentLoader
            onLoaded: geometryUpdate.restart()

            anchors {
                top: tabs.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                topMargin: host.theme.spacing3
                leftMargin: host.theme.spacing5
                rightMargin: host.theme.spacing5
                bottomMargin: host.theme.spacing5
            }

            active: host.visible && host.currentComponent !== null
            sourceComponent: host.currentComponent
        }
    }
}

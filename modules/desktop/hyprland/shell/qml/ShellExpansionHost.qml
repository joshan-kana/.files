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
        default:
            return null;
        }
    }
    readonly property real contentWidth: loadedContent ? loadedContent.implicitWidth + theme.spacing5 * 2 : expansionState.originWidth
    readonly property real contentHeight: loadedContent ? loadedContent.implicitHeight + theme.spacing5 * 2 : expansionState.originHeight
    readonly property real targetWidth: contentExpanded ? Math.max(expansionState.originWidth, contentWidth) : expansionState.originWidth
    readonly property real targetHeight: contentExpanded ? Math.max(expansionState.originHeight, contentHeight) : expansionState.originHeight
    readonly property real horizontalMargin: {
        if (!screen)
            return 0;

        const desired = contentExpanded ? (screen.width - implicitWidth) / 2 : expansionState.originCenter - implicitWidth / 2;
        const edge = theme.spacing4;
        return Math.max(edge, Math.min(desired, screen.width - implicitWidth - edge));
    }

    screen: expansionState.screen
    visible: expansionState.hasCurrent || closing
    color: "transparent"
    focusable: expansionState.hasCurrent
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: Math.max(1, targetWidth)
    implicitHeight: Math.max(1, targetHeight)

    anchors {
        top: true
        left: true
    }

    margins {
        top: 56 + theme.spacing1
        left: host.horizontalMargin
    }

    WlrLayershell.namespace: "linux-desktop-expansion"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: expansionState.hasCurrent ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region {
        item: shellSurface
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
        }
    }

    Connections {
        target: host.expansionState

        function onHasCurrentChanged(): void {
            if (host.expansionState.hasCurrent) {
                closeTimer.stop();
                host.closing = false;
                host.contentExpanded = false;
                Qt.callLater(() => host.contentExpanded = true);
            } else if (host.visible) {
                host.closing = true;
                closeTimer.restart();
            }
        }

        function onCurrentNameChanged(): void {
            if (!host.expansionState.hasCurrent)
                return;

            host.contentExpanded = false;
            Qt.callLater(() => host.contentExpanded = true);
        }
    }

    ShellSurface {
        id: shellSurface

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
        cornerRadius: host.theme.radiusLarge
        outlined: false

        Loader {
            id: contentLoader

            anchors {
                fill: parent
                margins: host.theme.spacing5
            }

            active: host.visible && host.currentComponent !== null
            sourceComponent: host.currentComponent
        }
    }
}

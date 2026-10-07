import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: host

    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion
    required property QtObject expansionState

    property Component mediaComponent: null
    property Component systemComponent: null
    property bool contentExpanded: false
    property bool closing: false

    readonly property Component currentComponent: {
        switch (expansionState.currentName) {
        case "media":
            return mediaComponent;
        case "system":
            return systemComponent;
        default:
            return null;
        }
    }
    readonly property real contentWidth: contentLoader.item ? contentLoader.item.implicitWidth + theme.spacing5 * 2 : expansionState.originWidth
    readonly property real contentHeight: contentLoader.item ? contentLoader.item.implicitHeight + theme.spacing5 * 2 : expansionState.originHeight
    readonly property real targetWidth: contentExpanded ? Math.max(expansionState.originWidth, contentWidth) : expansionState.originWidth
    readonly property real targetHeight: contentExpanded ? Math.max(expansionState.originHeight, contentHeight) : expansionState.originHeight
    readonly property real horizontalMargin: {
        if (!screen)
            return 0;

        const desired = expansionState.originCenter - implicitWidth / 2;
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

    Keys.onEscapePressed: expansionState.close()

    HyprlandFocusGrab {
        active: expansionState.hasCurrent
        windows: [host]
        onCleared: expansionState.close()
    }

    Timer {
        id: closeTimer
        interval: motion.spatialNormal
        repeat: false
        onTriggered: {
            host.closing = false;
            expansionState.finishClose();
        }
    }

    Connections {
        target: expansionState

        function onHasCurrentChanged(): void {
            if (expansionState.hasCurrent) {
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

        function onCurrentNameChanged(): void {
            if (!expansionState.hasCurrent)
                return;

            host.contentExpanded = false;
            Qt.callLater(() => host.contentExpanded = true);
        }
    }

    ShellSurface {
        id: shellSurface

        anchors.fill: parent
        theme: host.theme
        motion: host.motion
        surfaceLayer: ShellSurface.Pane
        cornerRadius: theme.radiusLarge
        outlined: true

        Loader {
            id: contentLoader

            anchors {
                fill: parent
                margins: theme.spacing5
            }

            active: host.visible && host.currentComponent !== null
            sourceComponent: host.currentComponent
            opacity: expansionState.hasCurrent && host.contentExpanded ? 1 : 0

            Behavior on opacity {
                Anim {
                    motion: host.motion
                    type: Anim.DefaultEffects
                }
            }
        }
    }

    Behavior on implicitWidth {
        Anim {
            motion: host.motion
            type: Anim.DefaultSpatial
        }
    }

    Behavior on implicitHeight {
        Anim {
            motion: host.motion
            type: Anim.DefaultSpatial
        }
    }

    Behavior on margins.left {
        Anim {
            motion: host.motion
            type: Anim.DefaultSpatial
        }
    }
}

pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: overview

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property bool open: false
    property bool closing: false
    property int selectedIndex: 0

    readonly property var windows: Hyprland.toplevels.values.filter(toplevel => {
        if (!toplevel || !toplevel.workspace || toplevel.workspace.id <= 0)
            return false;
        // Some compositor helper surfaces are exposed as toplevels without an app identity.
        const info = toplevel.lastIpcObject || {};
        return Boolean(info.class || (toplevel.wayland && toplevel.wayland.appId));
    }).sort((left, right) => left.workspace.id - right.workspace.id || left.title.localeCompare(right.title))
    readonly property int focusedWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

    visible: open || closing
    focusable: open
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }
    WlrLayershell.namespace: "linux-desktop-overview"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onWindowsChanged: selectedIndex = Math.max(0, Math.min(selectedIndex, windows.length - 1))

    function show(): void {
        closeTimer.stop();
        closing = false;
        selectedIndex = Math.max(0, windows.findIndex(toplevel => toplevel.activated));
        open = true;
        Qt.callLater(() => keyboard.forceActiveFocus());
    }
    function hide(): void {
        open = false;
        if (motion.fast === 0)
            closing = false;
        else {
            closing = true;
            closeTimer.restart();
        }
    }
    function toggle(): void {
        if (open)
            hide();
        else
            show();
    }
    function focusWorkspace(id: int): void {
        if (id < 1 || id > 10)
            return;
        hide();
        Hyprland.dispatch('hl.dsp.focus({ workspace = "' + id + '" })');
    }
    function activateWindow(index: int): void {
        const toplevel = windows[index];
        if (!toplevel)
            return;
        hide();
        if (toplevel.wayland)
            toplevel.wayland.activate();
    }

    Timer {
        id: closeTimer
        interval: overview.motion.fast
        onTriggered: overview.closing = false
    }

    Rectangle {
        anchors.fill: parent
        color: overview.theme.scrim
        opacity: overview.open ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: overview.motion.fast
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: overview.hide()
        }
    }

    ShellSurface {
        id: card
        anchors.centerIn: parent
        width: Math.min(overview.width - 100, 980)
        height: Math.min(overview.height - 120, Math.max(310, 213 + Math.min(4, Math.ceil(overview.windows.length / 3)) * 204))
        theme: overview.theme
        motion: overview.motion
        surfaceLayer: ShellSurface.Pane
        cornerRadius: theme.radiusPanel
        scale: overview.open ? 1 : theme.panelClosedScale
        opacity: overview.open ? 1 : 0

        Behavior on scale {
            Anim {
                motion: overview.motion
                type: Anim.DefaultSpatial
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: overview.motion.fast
            }
        }

        Column {
            anchors {
                fill: parent
                margins: overview.theme.spacing5
            }
            spacing: overview.theme.spacing4

            Row {
                width: parent.width
                Text {
                    text: "Workspaces & Windows"
                    color: overview.theme.textStrong
                    font.family: overview.runtime.fontMono
                    font.pixelSize: overview.theme.fontPanelTitle
                    font.weight: Font.DemiBold
                }
                Item {
                    width: Math.max(0, parent.width - parent.children[0].width - shortcutHint.width)
                    height: 1
                }
                Text {
                    id: shortcutHint
                    text: "H/J/K/L navigate   ENTER focus   1–0 workspace   ESC close"
                    color: overview.theme.textMuted
                    font.family: overview.runtime.fontMono
                    font.pixelSize: overview.theme.fontSize(10)
                }
            }

            Row {
                id: workspaceRow
                width: parent.width
                spacing: overview.theme.spacing2

                Repeater {
                    model: 10
                    delegate: ShellAction {
                        required property int index
                        width: (workspaceRow.width - workspaceRow.spacing * 9) / 10
                        height: 45
                        runtime: overview.runtime
                        theme: overview.theme
                        motion: overview.motion
                        compact: true
                        title: index === 9 ? "0" : String(index + 1)
                        active: overview.focusedWorkspace === index + 1
                        onActivated: overview.focusWorkspace(index + 1)
                    }
                }
            }

            Text {
                text: overview.windows.length + " WINDOWS   ·   Workspace " + overview.focusedWorkspace
                color: overview.theme.accent
                font.family: overview.runtime.fontMono
                font.pixelSize: overview.theme.fontSubpanelEyebrow
                font.letterSpacing: 1
            }

            GridView {
                id: windowsGrid
                width: parent.width
                height: Math.max(90, parent.height - 162)
                clip: true
                model: overview.windows
                cellWidth: Math.floor(width / 3)
                cellHeight: 204
                currentIndex: overview.selectedIndex
                boundsBehavior: Flickable.StopAtBounds
                displaced: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: overview.motion.spatialFast
                    }
                }
                delegate: OverviewWindow {
                    required property var modelData
                    required property int index
                    width: windowsGrid.cellWidth - overview.theme.spacing2
                    height: windowsGrid.cellHeight - overview.theme.spacing2
                    runtime: overview.runtime
                    theme: overview.theme
                    motion: overview.motion
                    toplevel: modelData
                    active: overview.open
                    selected: overview.selectedIndex === index
                    onActivated: overview.activateWindow(index)
                }
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

                Text {
                    anchors.centerIn: parent
                    visible: overview.windows.length === 0
                    text: "No open application windows"
                    color: overview.theme.textMuted
                    font.family: overview.runtime.fontMono
                    font.pixelSize: overview.theme.fontSize(13)
                }
            }
        }
    }

    FocusScope {
        id: keyboard
        anchors.fill: parent
        focus: overview.open
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                overview.hide();
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                overview.activateWindow(overview.selectedIndex);
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                overview.focusWorkspace(event.key - Qt.Key_0);
            } else if (event.key === Qt.Key_0) {
                overview.focusWorkspace(10);
            } else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
                overview.selectedIndex = Math.max(0, overview.selectedIndex - 1);
            } else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
                overview.selectedIndex = Math.max(0, Math.min(overview.windows.length - 1, overview.selectedIndex + 1));
            } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
                overview.selectedIndex = Math.max(0, Math.min(overview.windows.length - 1, overview.selectedIndex + 3));
            } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
                overview.selectedIndex = Math.max(0, overview.selectedIndex - 3);
            } else {
                return;
            }
            event.accepted = true;
        }
    }
}

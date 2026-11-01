pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: overlay
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    property bool open: false
    property string lastAction: ""
    property bool closing: false

    visible: true
    focusable: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 510
    implicitHeight: 210
    anchors {
        top: true
    }
    margins.top: theme.panelTopOffset
    updatesEnabled: surfaceLifecycle.needsRendering
    mask: surfaceLifecycle.inputRegion
    WlrLayershell.namespace: "linux-desktop-resize-controls"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    PopupSurfaceLifecycle {
        id: surfaceLifecycle
        popup: overlay
        exposed: overlay.open || overlay.closing
    }

    onOpenChanged: {
        if (open) {
            closing = false;
            closeTimer.stop();
            lastAction = "H/J/K/L change size, Shift reverses";
            Qt.callLater(() => resizeKeys.forceActiveFocus());
        } else if (motion.enabled) {
            closing = true;
            closeTimer.restart();
        } else {
            closing = false;
        }
    }

    Timer {
        id: closeTimer
        interval: overlay.motion.fast
        onTriggered: overlay.closing = false
    }

    function resizeWindow(x: int, y: int): void {
        Hyprland.dispatch(`hl.dsp.window.resize({ x = ${x}, y = ${y}, relative = true })`);
        lastAction = `${x > 0 ? "+" : ""}${x} × ${y > 0 ? "+" : ""}${y}`;
    }

    function balance(): void {
        Hyprland.dispatch('hl.dsp.layout("splitratio 1.0 exact")');
        lastAction = "Balanced split";
    }

    FocusScope {
        id: resizeKeys
        anchors.fill: parent
        opacity: overlay.open ? 1 : 0
        scale: overlay.open ? 1 : 0.96
        Behavior on opacity {
            Anim {
                motion: overlay.motion
                type: Anim.FastEffects
            }
        }
        Behavior on scale {
            Anim {
                motion: overlay.motion
                type: Anim.FastSpatial
            }
        }
        focus: overlay.open
        enabled: overlay.open
        Keys.onPressed: event => {
            const opposite = !!(event.modifiers & Qt.ShiftModifier);
            const size = opposite ? -50 : 50;
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_R) {
                overlay.open = false;
            } else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
                overlay.resizeWindow(-size, 0);
            } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
                overlay.resizeWindow(0, size);
            } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
                overlay.resizeWindow(0, -size);
            } else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
                overlay.resizeWindow(size, 0);
            } else if (event.key === Qt.Key_B) {
                overlay.balance();
            } else {
                return;
            }
            event.accepted = true;
        }

        ShellSurface {
            anchors.fill: parent
            theme: overlay.theme
            motion: overlay.motion
            surfaceLayer: ShellSurface.Pane
            cornerRadius: overlay.theme.radiusPanel

            Column {
                anchors {
                    fill: parent
                    margins: overlay.theme.spacing4
                }
                spacing: overlay.theme.spacing3

                Row {
                    width: parent.width
                    spacing: overlay.theme.spacing3
                    Text {
                        text: "󰩨"
                        color: overlay.theme.accent
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: overlay.theme.fontSize(28)
                    }
                    Column {
                        spacing: overlay.theme.spacing1
                        Text {
                            text: "Resize window"
                            color: overlay.theme.textStrong
                            font.family: overlay.runtime.fontMono
                            font.pixelSize: overlay.theme.fontSize(18)
                            font.weight: Font.Bold
                        }
                        Text {
                            text: overlay.lastAction
                            color: overlay.theme.textMuted
                            font.family: overlay.runtime.fontMono
                            font.pixelSize: overlay.theme.fontSize(11)
                        }
                    }
                }

                Flow {
                    width: parent.width
                    spacing: overlay.theme.spacing2
                    Repeater {
                        model: [
                            {
                                key: "H",
                                title: "Narrower",
                                x: -50,
                                y: 0
                            },
                            {
                                key: "J",
                                title: "Taller",
                                x: 0,
                                y: 50
                            },
                            {
                                key: "K",
                                title: "Shorter",
                                x: 0,
                                y: -50
                            },
                            {
                                key: "L",
                                title: "Wider",
                                x: 50,
                                y: 0
                            }
                        ]
                        delegate: ShellAction {
                            required property var modelData
                            width: (resizeKeys.width - overlay.theme.spacing4 * 2 - overlay.theme.spacing2 * 3) / 4
                            height: 70
                            runtime: overlay.runtime
                            theme: overlay.theme
                            motion: overlay.motion
                            shortcut: modelData.key
                            title: modelData.title
                            onActivated: overlay.resizeWindow(modelData.x, modelData.y)
                        }
                    }
                }

                KeyHintStrip {
                    width: parent.width
                    runtime: overlay.runtime
                    theme: overlay.theme
                    hints: [
                        {
                            shortcut: "SHIFT",
                            label: "Reverse"
                        },
                        {
                            shortcut: "B",
                            label: "Balance"
                        },
                        {
                            shortcut: "ESC",
                            label: "Done"
                        }
                    ]
                }
            }
        }
    }
}

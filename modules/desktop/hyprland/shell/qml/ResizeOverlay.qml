pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import "FeedbackSemantics.js" as FeedbackSemantics

PanelWindow {
    id: overlay
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property KeyboardState keyboard
    required property SystemState system
    property bool inspectOpen: false
    property string targetAddress: ""
    property bool readbackPending: false
    property StdioCollector windowOutput: StdioCollector {}
    property Process windowQuery: Process {
        stdout: overlay.windowOutput
        onExited: (exitCode, exitStatus) => {
            overlay.readbackPending = false;
            if (exitCode !== 0) {
                overlay.lastAction = "Unable to read window geometry";
                return;
            }
            try {
                const window = JSON.parse(overlay.windowOutput.text);
                if (!window || !Array.isArray(window.size) || window.size.length < 2) {
                    overlay.lastAction = "Window geometry unavailable";
                    return;
                }
                if (overlay.targetAddress && window.address && overlay.targetAddress !== window.address) {
                    overlay.lastAction = "Focused window changed";
                    return;
                }
                overlay.targetAddress = window.address || overlay.targetAddress;
                overlay.lastAction = `${window.size[0]} × ${window.size[1]}`;
            } catch (error) {
                overlay.lastAction = "Window geometry unavailable";
            }
        }
    }
    property Timer geometryReadback: Timer {
        interval: 100
        onTriggered: {
            if (!overlay.windowQuery.running && overlay.runtime.hyprctl.length > 0) {
                overlay.readbackPending = true;
                overlay.windowQuery.exec([overlay.runtime.hyprctl, "-j", "activewindow"]);
            }
        }
    }
    property bool open: false
    property string lastAction: ""
    property bool closing: false
    property bool frameEnabled: false
    property bool barVisible: true
    readonly property bool screenFullscreen: Hyprland.monitorFor(screen)?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false
    readonly property bool frameConnected: frameEnabled && !screenFullscreen
    property real attachmentProgress: frameConnected ? (open ? 1 : 0) : 1
    Behavior on attachmentProgress {
        NumberAnimation {
            duration: overlay.motion.morph
            easing.type: overlay.motion.morphType
            easing.bezierCurve: overlay.motion.morphCurve
        }
    }
    readonly property var frameBounds: ({
            x: screen ? (screen.width - width) / 2 : 0,
            y: margins.top,
            width: width,
            height: height * attachmentProgress,
            visible: frameConnected && attachmentProgress > 0.001
        })

    visible: true
    focusable: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 510
    implicitHeight: inspectOpen ? 268 : 210
    anchors {
        top: true
    }
    margins.top: frameConnected ? (barVisible ? theme.barInsetTop : theme.frameThickness) : theme.panelTopOffset
    updatesEnabled: surfaceLifecycle.needsRendering
    mask: surfaceLifecycle.inputRegion
    WlrLayershell.namespace: "linux-desktop-resize-controls"
    WlrLayershell.layer: screenFullscreen ? WlrLayer.Overlay : WlrLayer.Top
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
            inspectOpen = false;
            lastAction = "Reading window geometry…";
            targetAddress = "";
            geometryReadback.restart();
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
        interval: overlay.frameConnected ? overlay.motion.morph : overlay.motion.fast
        onTriggered: overlay.closing = false
    }

    function resizeWindow(x: int, y: int): void {
        Hyprland.dispatch(`hl.dsp.window.resize({ x = ${x}, y = ${y}, relative = true })`);
        lastAction = "Reading resulting dimensions…";
        geometryReadback.restart();
    }

    function balance(): void {
        Hyprland.dispatch('hl.dsp.layout("splitratio 1.0 exact")');
        lastAction = "Reading resulting dimensions…";
        geometryReadback.restart();
    }

    FocusScope {
        id: resizeKeys
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: overlay.frameConnected ? overlay.height * overlay.attachmentProgress : overlay.height
        clip: overlay.frameConnected
        opacity: overlay.frameConnected ? 1 : (overlay.open ? 1 : 0)
        scale: overlay.frameConnected ? 1 : (overlay.open ? 1 : 0.96)
        Behavior on opacity {
            enabled: !overlay.frameConnected
            Anim {
                motion: overlay.motion
                type: Anim.FastEffects
            }
        }
        Behavior on scale {
            enabled: !overlay.frameConnected
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
            } else if (event.key === Qt.Key_S) {
                overlay.inspectOpen = !overlay.inspectOpen;
                if (overlay.inspectOpen)
                    overlay.keyboard.refresh("inspect");
            } else {
                return;
            }
            event.accepted = true;
        }

        ShellSurface {
            anchors.fill: parent
            theme: overlay.theme
            frameConnected: overlay.frameConnected
            fillColor: overlay.theme.panelBase
            borderWidth: overlay.frameConnected ? 0 : overlay.theme.borderFocus
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
                        text: FeedbackSemantics.symbol("resize", false, 0, "")
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

                Row {
                    width: parent.width
                    height: overlay.inspectOpen ? overlay.theme.fontSize(26) : 0
                    visible: overlay.inspectOpen
                    spacing: overlay.theme.spacing2
                    Text {
                        text: `Caps ${overlay.keyboard.description(overlay.keyboard.capsState)} · Num ${overlay.keyboard.description(overlay.keyboard.numState)}`
                        color: overlay.theme.textStrong
                        font.family: overlay.runtime.fontMono
                        font.pixelSize: overlay.theme.fontSize(10)
                    }
                    Text {
                        text: overlay.system.microphoneAvailable ? (overlay.system.microphoneMuted ? "Mic muted" : "Mic unmuted") : "Mic unavailable"
                        color: overlay.theme.textMuted
                        font.family: overlay.runtime.fontMono
                        font.pixelSize: overlay.theme.fontSize(10)
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
                            shortcut: "S",
                            label: overlay.inspectOpen ? "Hide status" : "Inspect"
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

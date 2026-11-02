import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland

PanelWindow {
    id: popup

    required property NotificationState notificationState
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    signal centerRequested

    readonly property real dockTop: theme.panelTopOffset
    readonly property int cardHeight: Math.max(92, Math.min(170, Math.floor((screen ? screen.height : 1440) - dockTop - theme.spacing3)))
    readonly property int cardGap: theme.spacing2 + theme.spacing1
    readonly property int toastCount: notificationState.popups.count
    readonly property int visibleToastCount: Math.max(1, Math.min(3, toastCount, Math.floor(((screen ? screen.height : 1440) - margins.top - theme.spacing3 + cardGap) / (cardHeight + cardGap))))

    visible: true
    updatesEnabled: surfaceLifecycle.needsRendering
    PopupSurfaceLifecycle {
        id: surfaceLifecycle
        popup: popup
        exposed: popup.notificationState.popupVisible
    }
    mask: surfaceLifecycle.inputRegion
    color: "transparent"
    implicitWidth: Math.max(1, Math.min(440, (screen ? screen.width : 440) - theme.panelSideOffset * 2))
    implicitHeight: Math.max(1, visibleToastCount * cardHeight + Math.max(0, visibleToastCount - 1) * cardGap)
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
    }

    margins {
        top: popup.dockTop
        right: theme.panelSideOffset
    }

    WlrLayershell.namespace: "linux-desktop-notification-popup"

    function concealForActivity(): void {
        notificationState.hidePopup();
    }

    Repeater {
        id: toastRepeater
        model: popup.notificationState.popups

        ShellSurface {
            id: toast
            required property var notification
            required property string phase
            required property int index
            required property int slot
            required property bool evicted
            readonly property color urgencyColor: notification && notification.urgency === NotificationUrgency.Critical ? popup.theme.critical : notification && notification.urgency === NotificationUrgency.Low ? popup.theme.textMuted : popup.theme.roleColor("notifications")
            x: popup.width - width
            y: slot * (popup.cardHeight + popup.cardGap)
            // Outgoing cards remain beneath the live stack. When another
            // notification takes their slot, it covers the exit naturally
            // instead of rendering two crooked cards side by side.
            z: phase === "closing" ? 0 : 1
            width: popup.width
            height: popup.cardHeight
            visible: slot < popup.visibleToastCount || evicted

            Behavior on y {
                NumberAnimation {
                    duration: popup.motion.enabled ? popup.motion.spatialNormal : 0
                    easing.type: popup.motion.spatialType
                    easing.bezierCurve: popup.motion.spatialCurve
                }
            }
            theme: popup.theme
            motion: popup.motion
            surfaceLayer: ShellSurface.Pane
            cornerRadius: theme.radiusPanel
            fillColor: popup.theme.paneBase
            glassAllowed: true
            borderColor: toast.notification && toast.notification.urgency === NotificationUrgency.Critical ? Qt.rgba(popup.theme.critical.r, popup.theme.critical.g, popup.theme.critical.b, 0.58) : popup.theme.subtleBorder
            borderWidth: popup.theme.borderFocus

            // Only a forced-out toast slides below the three-card window.
            // All ordinary entry, expiry and dismiss animations are unchanged.
            opacity: toast.phase === "visible" && !toast.evicted ? 1 : 0
            scale: toast.phase === "visible" ? 1 : 0.965

            Behavior on opacity {
                NumberAnimation {
                    duration: !popup.motion.enabled ? 0 : toast.evicted ? popup.motion.spatialNormal : popup.motion.fast
                    easing.type: toast.phase === "visible" ? popup.motion.enterType : popup.motion.exitType
                    easing.bezierCurve: toast.phase === "visible" ? popup.motion.enterCurve : popup.motion.exitCurve
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: popup.motion.normal
                    easing.type: popup.motion.enterType
                    easing.bezierCurve: popup.motion.enterCurve
                }
            }

            StateLayer {
                theme: popup.theme
                motion: popup.motion
                cornerRadius: popup.theme.radiusPanel
                disabled: toast.phase !== "visible"
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onActivated: event => {
                    if (event.button === Qt.RightButton) {
                        popup.notificationState.dismiss(toast.notification);
                    } else {
                        popup.notificationState.hidePopup(toast.notification);
                        if (popup.notificationState.captureKind(toast.notification))
                            popup.notificationState.invokeDefault(toast.notification);
                        else
                            popup.centerRequested();
                    }
                }
            }

            Item {
                anchors.fill: parent
                anchors.margins: popup.theme.spacing4

                SquircleSurface {
                    id: accent

                    width: 5
                    cornerRadius: 2.5
                    exponent: popup.theme.squircleExponent
                    fillColor: toast.urgencyColor

                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        left: parent.left
                    }
                }

                Column {
                    anchors {
                        top: parent.top
                        right: parent.right
                        bottom: parent.bottom
                        left: accent.right
                        leftMargin: popup.theme.spacing4
                    }
                    spacing: popup.theme.spacing2

                    Row {
                        width: parent.width
                        spacing: popup.theme.spacing2

                        ShellSurface {
                            id: appMark
                            width: 26
                            height: 26
                            theme: popup.theme
                            motion: popup.motion
                            surfaceLayer: ShellSurface.Control
                            cornerRadius: popup.theme.radiusSmall
                            fillColor: popup.theme.blend(popup.theme.controlBase, toast.urgencyColor, 0.15)

                            Text {
                                anchors.centerIn: parent
                                text: popup.notificationState.captureKind(toast.notification) === "screenshot" ? "󰹑" : popup.notificationState.captureKind(toast.notification) === "recording" ? "󰕧" : toast.notification && toast.notification.urgency === NotificationUrgency.Critical ? "󰀪" : "󰂚"
                                color: toast.urgencyColor
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: popup.theme.fontSize(14)
                            }
                        }

                        Text {
                            id: appName
                            anchors.verticalCenter: parent.verticalCenter
                            text: toast.notification ? (toast.notification.appName || "SYSTEM").toUpperCase() : "SYSTEM"
                            color: toast.urgencyColor
                            font.family: popup.runtime.fontMono
                            font.pixelSize: popup.theme.fontSize(10)
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.4
                        }

                        Item {
                            width: Math.max(0, parent.width - appMark.width - appName.implicitWidth - actionHint.implicitWidth - parent.spacing * 3)
                            height: 1
                        }

                        Text {
                            id: actionHint
                            anchors.verticalCenter: parent.verticalCenter
                            text: !toast.notification ? "" : toast.notification.urgency === NotificationUrgency.Critical ? "CRITICAL" : toast.notification.actions.length > 0 ? toast.notification.actions.length + " ACTION" + (toast.notification.actions.length === 1 ? "" : "S") : popup.notificationState.captureKind(toast.notification) ? "OPEN" : ""
                            color: popup.theme.textMuted
                            font.family: popup.runtime.fontMono
                            font.pixelSize: popup.theme.fontSize(9)
                            font.letterSpacing: 0.8
                        }
                    }

                    MarqueeText {
                        width: parent.width
                        text: toast.notification ? toast.notification.summary : ""
                        textFormat: Text.PlainText
                        color: popup.theme.textStrong
                        font.family: popup.runtime.fontMono
                        font.pixelSize: popup.theme.fontSize(15)
                        font.weight: Font.DemiBold
                    }

                    Text {
                        width: parent.width
                        maximumLineCount: 3
                        text: toast.notification ? toast.notification.body : ""
                        textFormat: Text.PlainText
                        visible: text.length > 0
                        color: popup.theme.text
                        opacity: 0.84
                        font.family: popup.runtime.fontMono
                        font.pixelSize: popup.theme.fontSize(12)
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                    }
                }

                ShellAction {
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                    }
                    visible: popup.notificationState.captureKind(toast.notification).length > 0
                    width: 132
                    height: 31
                    runtime: popup.runtime
                    theme: popup.theme
                    motion: popup.motion
                    compact: true
                    horizontalCompact: true
                    icon: "󰏫"
                    title: popup.notificationState.captureKind(toast.notification) === "screenshot" ? "Markup" : "Trim"
                    onActivated: popup.notificationState.invokeCaptureEdit(toast.notification)
                }

                Text {
                    anchors {
                        left: accent.right
                        bottom: parent.bottom
                        leftMargin: popup.theme.spacing4
                    }
                    text: popup.notificationState.captureKind(toast.notification) ? "CLICK TO OPEN" : "CLICK · HISTORY  /  RMB · DISMISS"
                    color: popup.theme.textMuted
                    opacity: 0.62
                    font.family: popup.runtime.fontMono
                    font.pixelSize: popup.theme.fontSize(8)
                }
            }
        }
    }
}

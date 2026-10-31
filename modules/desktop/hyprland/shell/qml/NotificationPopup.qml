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

    property bool closing: false
    readonly property var notification: notificationState.latest
    readonly property color urgencyColor: {
        if (!notification)
            return theme.roleColor("notifications");
        if (notification.urgency === NotificationUrgency.Critical)
            return theme.critical;
        if (notification.urgency === NotificationUrgency.Low)
            return theme.textMuted;
        return theme.roleColor("notifications");
    }

    visible: true
    updatesEnabled: surfaceLifecycle.needsRendering
    PopupSurfaceLifecycle {
        id: surfaceLifecycle
        popup: popup
        exposed: popup.notificationState.popupVisible || popup.closing
    }
    mask: surfaceLifecycle.inputRegion
    color: "transparent"
    implicitWidth: 440
    implicitHeight: 170
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
    }

    margins {
        top: theme.panelTopOffset
        right: theme.panelSideOffset
    }

    WlrLayershell.namespace: "linux-desktop-notification-popup"

    function concealForActivity(): void {
        // Activity replaces this toast with the complete notification history.
        // Close the layer immediately so its exit animation cannot steal hub focus.
        notificationState.hidePopup();
        closeTimer.stop();
        closing = false;
    }

    Timer {
        id: closeTimer
        interval: popup.motion.fast
        onTriggered: popup.closing = false
    }

    Connections {
        target: popup.notificationState

        function onPopupVisibleChanged(): void {
            if (popup.notificationState.popupVisible) {
                closeTimer.stop();
                popup.closing = false;
            } else if (popup.motion.fast > 0) {
                popup.closing = true;
                closeTimer.restart();
            } else {
                popup.closing = false;
            }
        }
    }

    ShellSurface {
        anchors.fill: parent
        theme: popup.theme
        motion: popup.motion
        surfaceLayer: ShellSurface.Pane
        cornerRadius: theme.radiusLarge
        fillColor: popup.theme.materialContainerHigh
        borderColor: popup.notification && popup.notification.urgency === NotificationUrgency.Critical ? Qt.rgba(popup.theme.critical.r, popup.theme.critical.g, popup.theme.critical.b, 0.58) : popup.theme.subtleBorder
        borderWidth: popup.theme.borderThin

        opacity: popup.notificationState.popupVisible ? 1 : 0
        scale: popup.notificationState.popupVisible ? 1 : 0.965

        Behavior on opacity {
            NumberAnimation {
                duration: popup.motion.fast
                easing.type: popup.notificationState.popupVisible ? popup.motion.enterType : popup.motion.exitType
                easing.bezierCurve: popup.notificationState.popupVisible ? popup.motion.enterCurve : popup.motion.exitCurve
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
            cornerRadius: popup.theme.radiusLarge
            disabled: !popup.notificationState.popupVisible
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onActivated: event => {
                if (event.button === Qt.RightButton) {
                    popup.notificationState.dismiss(popup.notification);
                } else {
                    popup.notificationState.hidePopup();
                    if (popup.notificationState.captureKind(popup.notification))
                        popup.notificationState.invokeDefault(popup.notification);
                    else
                        popup.centerRequested();
                }
            }
        }

        Item {
            anchors.fill: parent
            anchors.margins: popup.theme.spacing4

            Rectangle {
                id: accent

                width: 4
                radius: 2
                color: popup.urgencyColor

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
                        fillColor: popup.theme.blend(popup.theme.controlBase, popup.urgencyColor, 0.15)

                        Text {
                            anchors.centerIn: parent
                            text: popup.notificationState.captureKind(popup.notification) === "screenshot" ? "󰹑" : popup.notificationState.captureKind(popup.notification) === "recording" ? "󰕧" : popup.notification && popup.notification.urgency === NotificationUrgency.Critical ? "󰀪" : "󰂚"
                            color: popup.urgencyColor
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: popup.theme.fontSize(14)
                        }
                    }

                    Text {
                        id: appName
                        anchors.verticalCenter: parent.verticalCenter
                        text: popup.notification ? (popup.notification.appName || "SYSTEM").toUpperCase() : "SYSTEM"
                        color: popup.urgencyColor
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
                        text: !popup.notification ? "" : popup.notification.urgency === NotificationUrgency.Critical ? "CRITICAL" : popup.notification.actions.length > 0 ? popup.notification.actions.length + " ACTION" + (popup.notification.actions.length === 1 ? "" : "S") : popup.notificationState.captureKind(popup.notification) ? "OPEN" : ""
                        color: popup.theme.textMuted
                        font.family: popup.runtime.fontMono
                        font.pixelSize: popup.theme.fontSize(9)
                        font.letterSpacing: 0.8
                    }
                }

                MarqueeText {
                    width: parent.width
                    text: popup.notification ? popup.notification.summary : ""
                    textFormat: Text.PlainText
                    color: popup.theme.textStrong
                    font.family: popup.runtime.fontMono
                    font.pixelSize: popup.theme.fontSize(15)
                    font.weight: Font.DemiBold
                }

                Text {
                    width: parent.width
                    maximumLineCount: 3
                    text: popup.notification ? popup.notification.body : ""
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
                visible: popup.notificationState.captureKind(popup.notification).length > 0
                width: 132
                height: 31
                runtime: popup.runtime
                theme: popup.theme
                motion: popup.motion
                compact: true
                horizontalCompact: true
                icon: "󰏫"
                title: popup.notificationState.captureKind(popup.notification) === "screenshot" ? "Markup" : "Trim"
                onActivated: popup.notificationState.invokeCaptureEdit(popup.notification)
            }

            Text {
                anchors {
                    left: accent.right
                    bottom: parent.bottom
                    leftMargin: popup.theme.spacing4
                }
                text: popup.notificationState.captureKind(popup.notification) ? "CLICK TO OPEN" : "CLICK · HISTORY  /  RMB · DISMISS"
                color: popup.theme.textMuted
                opacity: 0.62
                font.family: popup.runtime.fontMono
                font.pixelSize: popup.theme.fontSize(8)
            }
        }
    }
}

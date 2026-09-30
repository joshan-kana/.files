import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland

PanelWindow {
    id: popup

    required property QtObject notificationState
    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion

    signal centerRequested()

    property bool closing: false
    readonly property var notification: notificationState.latest
    readonly property color urgencyColor: {
        if (!notification)
            return theme.accent;
        if (notification.urgency === NotificationUrgency.Critical)
            return theme.critical;
        if (notification.urgency === NotificationUrgency.Low)
            return theme.textMuted;
        return theme.accent;
    }

    visible: notificationState.popupVisible || closing
    color: "transparent"
    implicitWidth: 440
    implicitHeight: 170
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
    }

    margins {
        top: 82
        right: 24
    }

    WlrLayershell.namespace: "linux-desktop-notification-popup"

    Timer {
        id: closeTimer
        interval: motion.fast
        onTriggered: popup.closing = false
    }

    Connections {
        target: notificationState

        function onPopupVisibleChanged(): void {
            if (notificationState.popupVisible) {
                closeTimer.stop();
                popup.closing = false;
            } else if (motion.fast > 0) {
                popup.closing = true;
                closeTimer.restart();
            } else {
                popup.closing = false;
            }
        }
    }

    SquircleSurface {
        anchors.fill: parent

        exponent: theme.squircleExponent
        cornerRadius: 30
        fillColor: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.985)
        borderColor: Qt.rgba(popup.urgencyColor.r, popup.urgencyColor.g, popup.urgencyColor.b, 0.48)
        borderWidth: theme.borderThin

        opacity: notificationState.popupVisible ? 1 : 0
        scale: notificationState.popupVisible ? 1 : 0.965

        Behavior on opacity {
            NumberAnimation {
                duration: motion.fast
                easing.type: notificationState.popupVisible ? motion.enterType : motion.exitType
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: motion.normal
                easing.type: motion.enterType
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: notificationState.popupVisible
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    notificationState.dismiss(popup.notification);
                } else {
                    notificationState.hidePopup();
                    popup.centerRequested();
                }
            }
        }

        Item {
            anchors.fill: parent
            anchors.margins: theme.spacing4

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
                    leftMargin: theme.spacing4
                }
                spacing: theme.spacing2

                Row {
                    width: parent.width

                    Text {
                        text: popup.notification
                            ? (popup.notification.appName || "SYSTEM").toUpperCase()
                            : "SYSTEM"
                        color: popup.urgencyColor
                        font.family: runtime.fontMono
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.4
                    }

                    Item {
                        width: parent.width - parent.children[0].width - actionHint.width
                        height: 1
                    }

                    Text {
                        id: actionHint
                        text: popup.notification && popup.notification.actions.length > 0
                            ? popup.notification.actions.length + " ACTION" + (popup.notification.actions.length === 1 ? "" : "S")
                            : "NOTIFICATION"
                        color: theme.textMuted
                        font.family: runtime.fontMono
                        font.pixelSize: 9
                        font.letterSpacing: 0.8
                    }
                }

                Text {
                    width: parent.width
                    text: popup.notification ? popup.notification.summary : ""
                    textFormat: Text.PlainText
                    color: theme.textStrong
                    font.family: runtime.fontSans
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    maximumLineCount: 3
                    text: popup.notification ? popup.notification.body : ""
                    textFormat: Text.PlainText
                    visible: text.length > 0
                    color: theme.text
                    opacity: 0.84
                    font.family: runtime.fontSans
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                }

                Item {
                    width: 1
                    height: Math.max(0, parent.height - 94)
                }

                Text {
                    text: "CLICK  HISTORY   //   RMB  DISMISS"
                    color: theme.textMuted
                    opacity: 0.62
                    font.family: runtime.fontMono
                    font.pixelSize: 8
                    font.letterSpacing: 0.8
                }
            }
        }
    }
}

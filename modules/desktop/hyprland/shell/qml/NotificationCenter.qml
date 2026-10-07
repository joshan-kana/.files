import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland

PanelWindow {
    id: center

    required property QtObject notificationState
    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion

    property bool open: false
    property bool closing: false
    property int selectedIndex: 0

    readonly property var items: {
        const values = notificationState.history || [];
        return [...values].reverse();
    }

    visible: open || closing
    color: "transparent"
    focusable: open
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    WlrLayershell.namespace: "linux-desktop-notification-center"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Timer {
        id: closeTimer
        interval: motion.fast
        onTriggered: center.closing = false
    }

    function selectedNotification(): var {
        if (items.length === 0)
            return null;

        const safeIndex = Math.max(0, Math.min(selectedIndex, items.length - 1));
        return items[safeIndex];
    }

    function show(): void {
        closeTimer.stop();
        closing = false;
        selectedIndex = Math.max(0, Math.min(selectedIndex, Math.max(0, items.length - 1)));
        open = true;
        keySink.forceActiveFocus();
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

    function dismissSelected(): void {
        const notification = selectedNotification();
        if (!notification)
            return;

        notificationState.dismiss(notification);
        Qt.callLater(() => {
            selectedIndex = Math.max(0, Math.min(selectedIndex, Math.max(0, items.length - 1)));
        });
    }

    Rectangle {
        anchors.fill: parent
        color: theme.scrim
        opacity: center.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: motion.fast
                easing.type: center.open ? motion.enterType : motion.exitType
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: center.hide()
        }
    }

    SquircleSurface {
        id: card

        width: Math.min(center.width - 120, 720)
        height: {
            const visibleItems = Math.min(center.items.length, 5);
            const desired = visibleItems === 0 ? 300 : 190 + visibleItems * 116;
            return Math.min(center.height - 140, Math.max(300, desired));
        }
        anchors.centerIn: parent

        exponent: theme.squircleExponent
        cornerRadius: theme.radiusPanel
        fillColor: theme.panelFill
        borderColor: theme.panelBorder
        borderWidth: theme.borderThin

        scale: center.open ? 1 : theme.panelClosedScale
        opacity: center.open ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: motion.normal
                easing.type: motion.enterType
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: motion.fast
            }
        }

        Item {
            anchors.fill: parent
            anchors.margins: theme.spacing5

            Column {
                id: header
                width: parent.width
                spacing: theme.spacing1

                Text {
                    text: notificationState.count + " stored"
                    color: theme.accent
                    font.family: runtime.fontSans
                    font.pixelSize: theme.fontSize(12)
                    font.weight: Font.Medium
                }

                Text {
                    text: "Notifications"
                    color: theme.textStrong
                    font.family: runtime.fontSans
                    font.pixelSize: theme.fontPanelTitle
                    font.weight: Font.DemiBold
                }

                Text {
                    text: "↑↓ navigate  ·  Enter action  ·  Delete dismiss  ·  C clear  ·  Esc close"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(9)
                }
            }

            ListView {
                id: list

                anchors {
                    top: header.bottom
                    right: parent.right
                    bottom: footer.top
                    left: parent.left
                    topMargin: theme.spacing4
                    bottomMargin: theme.spacing4
                }

                model: center.items
                spacing: theme.spacing3
                clip: true
                currentIndex: center.selectedIndex
                boundsBehavior: Flickable.StopAtBounds

                delegate: SquircleSurface {
                    id: item

                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    height: Math.max(92, itemBody.implicitHeight + theme.spacing4 * 2)
                    exponent: theme.squircleExponent
                    cornerRadius: theme.radiusMedium
                    fillColor: index === center.selectedIndex ? theme.focusFill : theme.background
                    borderColor: {
                        if (index === center.selectedIndex)
                            return theme.accent;
                        if (modelData.urgency === NotificationUrgency.Critical)
                            return Qt.rgba(theme.critical.r, theme.critical.g, theme.critical.b, 0.42);
                        return theme.outline;
                    }
                    borderWidth: index === center.selectedIndex ? theme.borderFocus : theme.borderThin

                    MouseArea {
                        anchors.fill: parent
                        onClicked: center.selectedIndex = item.index
                        onDoubleClicked: {
                            center.selectedIndex = item.index;
                            notificationState.invokeDefault(modelData);
                        }
                    }

                    Column {
                        id: itemBody

                        anchors {
                            top: parent.top
                            right: parent.right
                            left: parent.left
                            margins: theme.spacing4
                        }
                        spacing: theme.spacing2

                        Row {
                            width: parent.width

                            Text {
                                text: (modelData.appName || "SYSTEM").toUpperCase()
                                color: modelData.urgency === NotificationUrgency.Critical ? theme.critical : theme.accent
                                font.family: runtime.fontMono
                                font.pixelSize: theme.fontSize(9)
                                font.weight: Font.DemiBold
                                font.letterSpacing: 1.2
                            }

                            Item {
                                width: parent.width - parent.children[0].width - actionsLabel.width
                                height: 1
                            }

                            Text {
                                id: actionsLabel
                                text: modelData.actions.length > 0 ? modelData.actions.length + " ACTION" + (modelData.actions.length === 1 ? "" : "S") : ""
                                color: theme.textMuted
                                font.family: runtime.fontMono
                                font.pixelSize: theme.fontSize(8)
                            }
                        }

                        Text {
                            width: parent.width
                            text: modelData.summary
                            textFormat: Text.PlainText
                            color: theme.textStrong
                            font.family: runtime.fontSans
                            font.pixelSize: theme.fontSize(14)
                            font.weight: Font.DemiBold
                            wrapMode: Text.Wrap
                        }

                        Text {
                            width: parent.width
                            visible: text.length > 0
                            maximumLineCount: 4
                            text: modelData.body
                            textFormat: Text.PlainText
                            color: theme.text
                            opacity: 0.78
                            font.family: runtime.fontSans
                            font.pixelSize: theme.fontSize(11)
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                        }
                    }
                }

                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            }

            Text {
                anchors.centerIn: list
                visible: notificationState.count === 0
                text: "You’re all caught up"
                color: theme.textMuted
                font.family: runtime.fontSans
                font.pixelSize: theme.fontSize(12)
            }

            Row {
                id: footer
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                }
                spacing: theme.spacing4

                Text {
                    text: notificationState.count + " STORED"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(9)
                    font.letterSpacing: 1
                }

                Text {
                    text: "C  CLEAR"
                    color: notificationState.count > 0 ? theme.accent : theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(9)
                    font.letterSpacing: 1
                }
            }

            FocusScope {
                id: keySink
                anchors.fill: parent
                focus: center.open

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        center.hide();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        center.selectedIndex = Math.max(0, center.selectedIndex - 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down) {
                        center.selectedIndex = Math.min(center.items.length - 1, center.selectedIndex + 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        notificationState.invokeDefault(center.selectedNotification());
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
                        center.dismissSelected();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_C) {
                        notificationState.clearAll();
                        center.selectedIndex = 0;
                        event.accepted = true;
                    }
                }
            }
        }
    }
}

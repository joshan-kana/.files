pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Notifications

FocusScope {
    id: center

    required property NotificationState notificationState
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property bool engaged: false
    property int selectedIndex: 0
    property var expandedNotification: null
    readonly property var items: [...(notificationState.history || [])].reverse()
    signal closeRequested

    implicitWidth: 620
    implicitHeight: Math.max(252, 142 + Math.min(items.length, 5) * 116)
    focus: engaged

    onEngagedChanged: {
        if (engaged) {
            selectedIndex = Math.max(0, Math.min(selectedIndex, Math.max(0, items.length - 1)));
            Qt.callLater(focusKeyboard);
        }
    }

    onItemsChanged: {
        selectedIndex = Math.max(0, Math.min(selectedIndex, Math.max(0, items.length - 1)));
        if (expandedNotification && items.indexOf(expandedNotification) < 0)
            expandedNotification = null;
        if (engaged)
            Qt.callLater(focusKeyboard);
    }

    function focusKeyboard(): void {
        if (engaged)
            keySink.forceActiveFocus();
    }

    function selectedNotification(): var {
        if (items.length === 0)
            return null;
        return items[Math.max(0, Math.min(selectedIndex, items.length - 1))];
    }

    function toggleExpanded(): void {
        const notification = selectedNotification();
        if (notification)
            expandedNotification = expandedNotification === notification ? null : notification;
    }

    function dismissSelected(): void {
        const notification = selectedNotification();
        if (!notification)
            return;
        notificationState.dismiss(notification);
        Qt.callLater(() => {
            selectedIndex = Math.max(0, Math.min(selectedIndex, Math.max(0, items.length - 1)));
            focusKeyboard();
        });
    }

    Item {
        anchors.fill: parent

        Column {
            id: header
            width: parent.width
            spacing: center.theme.spacing1

            Text {
                text: center.notificationState.count + " stored"
                color: center.theme.accent
                font.family: center.runtime.fontMono
                font.pixelSize: center.theme.fontSize(12)
                font.weight: Font.Medium
            }

            Text {
                text: "Notifications"
                color: center.theme.textStrong
                font.family: center.runtime.fontMono
                font.pixelSize: center.theme.fontPanelTitle
                font.weight: Font.DemiBold
            }

            Text {
                text: "J/K select · E expand · 1–9 actions · Enter default · Del dismiss · C clear · Esc close"
                color: center.theme.textMuted
                font.family: center.runtime.fontMono
                font.pixelSize: center.theme.fontSize(9)
            }
        }

        ListView {
            id: list

            anchors {
                top: header.bottom
                right: parent.right
                bottom: footer.top
                left: parent.left
                topMargin: center.theme.spacing4
                bottomMargin: center.theme.spacing4
            }

            model: center.items
            spacing: center.theme.spacing3
            clip: true
            currentIndex: center.selectedIndex
            boundsBehavior: Flickable.StopAtBounds

            delegate: SquircleSurface {
                id: item

                required property var modelData
                required property int index

                width: ListView.view.width
                readonly property bool expanded: center.expandedNotification === modelData
                height: Math.max(92, itemBody.implicitHeight + center.theme.spacing4 * 2)

                Behavior on height {
                    Anim {
                        motion: center.motion
                        type: Anim.FastSpatial
                    }
                }
                exponent: center.theme.squircleExponent
                cornerRadius: center.theme.radiusMedium
                fillColor: index === center.selectedIndex ? center.theme.focusFill : center.theme.background
                borderColor: {
                    if (index === center.selectedIndex)
                        return center.theme.accent;
                    if (modelData.urgency === NotificationUrgency.Critical)
                        return Qt.rgba(center.theme.critical.r, center.theme.critical.g, center.theme.critical.b, 0.42);
                    return center.theme.outline;
                }
                borderWidth: index === center.selectedIndex ? center.theme.borderFocus : center.theme.borderThin

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        center.selectedIndex = item.index;
                        center.toggleExpanded();
                    }
                    onDoubleClicked: {
                        center.selectedIndex = item.index;
                        center.notificationState.invokeDefault(item.modelData);
                    }
                }

                Column {
                    id: itemBody

                    anchors {
                        top: parent.top
                        right: parent.right
                        left: parent.left
                        margins: center.theme.spacing4
                    }
                    spacing: center.theme.spacing2

                    Row {
                        width: parent.width

                        Text {
                            text: (item.modelData.appName || "SYSTEM").toUpperCase()
                            color: item.modelData.urgency === NotificationUrgency.Critical ? center.theme.critical : center.theme.accent
                            font.family: center.runtime.fontMono
                            font.pixelSize: center.theme.fontSize(9)
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.2
                        }

                        Item {
                            width: parent.width - parent.children[0].width - actionsLabel.width
                            height: 1
                        }

                        Text {
                            id: actionsLabel
                            text: (item.expanded ? "󰅃" : "󰅀") + (item.modelData.actions.length > 0 ? "  " + item.modelData.actions.length + " ACTIONS" : "  EXPAND")
                            color: center.theme.textMuted
                            font.family: center.runtime.fontMono
                            font.pixelSize: center.theme.fontSize(8)
                        }
                    }

                    Text {
                        width: parent.width
                        text: item.modelData.summary
                        textFormat: Text.PlainText
                        color: center.theme.textStrong
                        font.family: center.runtime.fontMono
                        font.pixelSize: center.theme.fontSize(14)
                        font.weight: Font.DemiBold
                        wrapMode: Text.Wrap
                    }

                    Text {
                        width: parent.width
                        visible: text.length > 0
                        maximumLineCount: item.expanded ? 20 : 2
                        text: item.modelData.body
                        textFormat: Text.PlainText
                        color: center.theme.text
                        opacity: 0.78
                        font.family: center.runtime.fontMono
                        font.pixelSize: center.theme.fontSize(11)
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                    }

                    Flow {
                        id: actionButtons
                        width: parent.width
                        spacing: center.theme.spacing2
                        visible: item.expanded && item.modelData.actions.length > 0

                        Repeater {
                            model: item.modelData.actions

                            delegate: ShellAction {
                                required property int index
                                required property var modelData
                                runtime: center.runtime
                                theme: center.theme
                                motion: center.motion
                                compact: true
                                title: (index + 1) + "  " + (modelData.text || "Action")
                                width: Math.min(implicitWidth, actionButtons.width)
                                onActivated: center.notificationState.invokeAction(item.modelData, index)
                            }
                        }
                    }
                }
            }

            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        }

        Text {
            anchors.centerIn: list
            visible: center.notificationState.count === 0
            text: "You’re all caught up"
            color: center.theme.textMuted
            font.family: center.runtime.fontMono
            font.pixelSize: center.theme.fontSize(12)
        }

        Row {
            id: footer
            anchors {
                right: parent.right
                bottom: parent.bottom
            }
            spacing: center.theme.spacing4

            Text {
                text: center.notificationState.count + " STORED"
                color: center.theme.textMuted
                font.family: center.runtime.fontMono
                font.pixelSize: center.theme.fontSize(9)
                font.letterSpacing: 1
            }

            Text {
                text: "C  CLEAR"
                color: center.notificationState.count > 0 ? center.theme.accent : center.theme.textMuted
                font.family: center.runtime.fontMono
                font.pixelSize: center.theme.fontSize(9)
                font.letterSpacing: 1
            }
        }

        FocusScope {
            id: keySink
            anchors.fill: parent
            focus: center.engaged

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    center.closeRequested();
                    event.accepted = true;
                } else if ((event.key === Qt.Key_Up || event.key === Qt.Key_K)) {
                    center.selectedIndex = Math.max(0, center.selectedIndex - 1);
                    event.accepted = true;
                } else if ((event.key === Qt.Key_Down || event.key === Qt.Key_J)) {
                    center.selectedIndex = Math.min(center.items.length - 1, center.selectedIndex + 1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_U || event.key === Qt.Key_D) {
                    const rowHeight = list.currentItem ? list.currentItem.height + list.spacing : 64;
                    const rows = Math.max(1, Math.floor(list.height / Math.max(1, rowHeight) / 2));
                    center.selectedIndex = Math.max(0, Math.min(center.items.length - 1, center.selectedIndex + (event.key === Qt.Key_D ? rows : -rows)));
                    event.accepted = true;
                } else if (event.key === Qt.Key_E) {
                    center.toggleExpanded();
                    event.accepted = true;
                } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                    center.notificationState.invokeAction(center.selectedNotification(), event.key - Qt.Key_1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    center.notificationState.invokeDefault(center.selectedNotification());
                    event.accepted = true;
                } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
                    center.dismissSelected();
                    event.accepted = true;
                } else if (event.key === Qt.Key_C) {
                    center.notificationState.clearAll();
                    center.selectedIndex = 0;
                    event.accepted = true;
                }
            }
        }
    }
}

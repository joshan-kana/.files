pragma ComponentBehavior: Bound
import QtQuick

FocusScope {
    id: center

    required property NotificationState notificationState
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property bool engaged: false
    property int selectedIndex: 0
    property int selectedMemberIndex: 0
    property string expandedGroupKey: ""

    readonly property var items: [...(notificationState.history || [])].reverse()
    // Like end-4's grouped history, but backed by the single Quickshell notification server.
    readonly property var groups: {
        const grouped = [];
        const byApp = new Map();
        for (const notification of items) {
            if (!notification)
                continue;
            const app = notification.appName || "SYSTEM";
            const key = app.toLowerCase();
            if (!byApp.has(key)) {
                const group = {
                    key: key,
                    name: app,
                    notifications: []
                };
                byApp.set(key, group);
                grouped.push(group);
            }
            byApp.get(key).notifications.push(notification);
        }
        return grouped;
    }

    signal closeRequested
    implicitWidth: 620
    implicitHeight: (groups.length === 0 ? 295 : Math.max(360, 235 + Math.min(groups.length, 5) * 116)) + footer.implicitHeight + theme.spacing2
    focus: engaged

    onEngagedChanged: {
        if (engaged)
            Qt.callLater(focusKeyboard);
    }

    onGroupsChanged: {
        if (!groups)
            return;
        selectedIndex = Math.max(0, Math.min(selectedIndex, Math.max(0, groups.length - 1)));
        const group = selectedGroup();
        selectedMemberIndex = group ? Math.max(0, Math.min(selectedMemberIndex, group.notifications.length - 1)) : 0;
        if (!groups.some(group => group.key === expandedGroupKey))
            expandedGroupKey = "";
        if (engaged)
            Qt.callLater(focusKeyboard);
    }

    function focusKeyboard(): void {
        if (engaged)
            keySink.forceActiveFocus();
    }

    function ensureSelectedVisible(): void {
        const groupItem = list.itemAtIndex(selectedIndex);
        if (!groupItem || !groupItem.expanded)
            return;

        const card = groupItem.memberAt(selectedMemberIndex);
        if (!card)
            return;
        const top = card.mapToItem(list.contentItem, 0, 0).y;
        const bottom = top + card.height;
        if (bottom > list.contentY + list.height)
            list.contentY = Math.min(Math.max(0, list.contentHeight - list.height), bottom - list.height);
        else if (top < list.contentY)
            list.contentY = Math.max(0, top);
    }

    onSelectedMemberIndexChanged: Qt.callLater(ensureSelectedVisible)
    onExpandedGroupKeyChanged: Qt.callLater(ensureSelectedVisible)

    function selectedGroup(): var {
        return groups && groups.length > 0 ? groups[Math.max(0, Math.min(selectedIndex, groups.length - 1))] : null;
    }

    function selectedNotification(): var {
        const group = selectedGroup();
        return group ? group.notifications[Math.max(0, Math.min(selectedMemberIndex, group.notifications.length - 1))] : null;
    }

    function selectGroup(delta: int): void {
        selectedIndex = Math.max(0, Math.min(groups.length - 1, selectedIndex + delta));
        selectedMemberIndex = 0;
    }

    function navigate(delta: int): void {
        const group = selectedGroup();
        if (group && expandedGroupKey === group.key) {
            const nextMember = selectedMemberIndex + delta;
            if (nextMember >= 0 && nextMember < group.notifications.length) {
                selectedMemberIndex = nextMember;
                Qt.callLater(ensureSelectedVisible);
                return;
            }
        }
        selectGroup(delta);
    }

    function toggleExpanded(): void {
        const group = selectedGroup();
        if (group)
            expandedGroupKey = expandedGroupKey === group.key ? "" : group.key;
    }

    function dismissNotification(notification): void {
        notificationState.dismiss(notification);
        Qt.callLater(() => {
            selectedIndex = Math.max(0, Math.min(selectedIndex, Math.max(0, groups.length - 1)));
            const group = selectedGroup();
            selectedMemberIndex = group ? Math.min(selectedMemberIndex, group.notifications.length - 1) : 0;
            focusKeyboard();
        });
    }

    function dismissSelected(): void {
        const notification = selectedNotification();
        if (!notification)
            return;
        const groupItem = list.itemAtIndex(selectedIndex);
        const card = groupItem ? groupItem.memberAt(expandedGroupKey === groupItem.modelData.key ? selectedMemberIndex : 0) : null;
        if (card && card.notification === notification)
            card.dismissAnimated();
        else
            dismissNotification(notification);
    }

    Item {
        anchors.fill: parent

        Column {
            id: header
            width: parent.width
            spacing: center.theme.spacing1

            Row {
                id: titleBar
                width: parent.width
                spacing: center.theme.spacing3
                Column {
                    spacing: center.theme.spacing1
                    Text {
                        text: "Notifications"
                        color: center.theme.textStrong
                        font.family: center.runtime.fontMono
                        font.pixelSize: center.theme.fontSize(21)
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: center.notificationState.count + " total · " + center.notificationState.unreadCount + " unread"
                        color: center.theme.textMuted
                        font.family: center.runtime.fontMono
                        font.pixelSize: center.theme.fontSize(10)
                    }
                }
                Item {
                    width: Math.max(0, titleBar.width - titleBar.children[0].implicitWidth - actions.implicitWidth - titleBar.spacing * 2)
                    height: 1
                }
                Row {
                    id: actions
                    spacing: center.theme.spacing2
                    ShellAction {
                        runtime: center.runtime
                        theme: center.theme
                        motion: center.motion
                        compact: true
                        enabled: center.notificationState.unreadCount > 0
                        width: center.theme.minActionTarget
                        height: center.theme.minActionTarget
                        iconOnly: true
                        icon: "󰄭"
                        title: "Mark all read"
                        shortcut: "SHIFT+M"
                        iconHint: true
                        onActivated: center.notificationState.markAllRead()
                    }
                    ShellAction {
                        runtime: center.runtime
                        theme: center.theme
                        motion: center.motion
                        compact: true
                        enabled: center.notificationState.count > center.notificationState.unreadCount
                        width: center.theme.minActionTarget
                        height: center.theme.minActionTarget
                        iconOnly: true
                        icon: "󰄬"
                        title: "Mark all unread"
                        shortcut: "SHIFT+N"
                        iconHint: true
                        onActivated: center.notificationState.markAllUnread()
                    }
                    ShellAction {
                        runtime: center.runtime
                        theme: center.theme
                        motion: center.motion
                        compact: true
                        active: center.notificationState.silent
                        activeColor: center.theme.warning
                        width: center.theme.minActionTarget
                        height: center.theme.minActionTarget
                        iconOnly: true
                        icon: center.notificationState.silent ? "󰂛" : "󰂚"
                        title: center.notificationState.silent ? "Resume alerts" : "Pause alerts"
                        shortcut: "S"
                        iconHint: true
                        onActivated: center.notificationState.toggleSilent()
                    }
                    ShellAction {
                        runtime: center.runtime
                        theme: center.theme
                        motion: center.motion
                        compact: true
                        enabled: center.notificationState.count > 0
                        width: center.theme.minActionTarget
                        height: center.theme.minActionTarget
                        iconOnly: true
                        icon: "󰆴"
                        title: "Clear all"
                        shortcut: "C"
                        iconHint: true
                        onActivated: center.notificationState.clearAll()
                    }
                }
            }
        }

        ShellSurface {
            anchors.centerIn: list
            width: list.width
            height: 148
            visible: center.groups.length === 0
            theme: center.theme
            motion: center.motion
            surfaceLayer: ShellSurface.Group
            cornerRadius: center.theme.radiusLarge

            Column {
                anchors.centerIn: parent
                spacing: center.theme.spacing3
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: center.notificationState.silent ? "󰂛" : "󰂜"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: center.theme.fontSize(36)
                    color: center.theme.roleColor("notifications")
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: center.notificationState.silent ? "Notifications are paused" : "All caught up"
                    font.family: center.runtime.fontMono
                    font.pixelSize: center.theme.fontSize(17)
                    font.weight: Font.DemiBold
                    color: center.theme.textStrong
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "New notifications will appear here"
                    font.family: center.runtime.fontMono
                    font.pixelSize: center.theme.fontSize(10)
                    color: center.theme.textMuted
                }
            }
        }

        KeyHintStrip {
            id: footer
            anchors.bottom: parent.bottom
            width: parent.width
            runtime: center.runtime
            theme: center.theme
            hints: [
                {
                    shortcut: "J/K",
                    label: "Navigate"
                },
                {
                    shortcut: "H/L",
                    label: "Groups"
                },
                {
                    shortcut: "E",
                    label: center.notificationState.captureKind(center.selectedNotification()) === "screenshot" ? "Markup" : center.notificationState.captureKind(center.selectedNotification()) === "recording" ? "Trim" : "Expand"
                },
                {
                    shortcut: "M",
                    label: "Read"
                },
                {
                    shortcut: "DEL",
                    label: "Dismiss"
                }
            ]
        }

        ListView {
            id: list
            anchors {
                top: header.bottom
                right: parent.right
                bottom: footer.top
                left: parent.left
                topMargin: center.theme.spacing4
                bottomMargin: center.theme.spacing2
            }
            model: center.groups
            spacing: center.theme.spacing3
            clip: true
            currentIndex: center.selectedIndex
            boundsBehavior: Flickable.StopAtBounds

            remove: Transition {
                NumberAnimation {
                    property: "opacity"
                    to: 0
                    duration: center.motion.effectsFast
                    easing.type: center.motion.exitType
                    easing.bezierCurve: center.motion.exitCurve
                }
            }
            displaced: Transition {
                NumberAnimation {
                    properties: "x,y"
                    duration: center.motion.spatialFast
                    easing.type: center.motion.spatialType
                    easing.bezierCurve: center.motion.spatialCurve
                }
            }

            delegate: Item {
                id: groupItem
                required property var modelData
                required property int index
                readonly property bool expanded: center.expandedGroupKey === modelData.key
                width: ListView.view.width
                implicitHeight: groupColumn.implicitHeight
                height: implicitHeight
                clip: true

                function memberAt(index: int): var {
                    return members.itemAt(index);
                }
                onHeightChanged: {
                    if (expanded && center.selectedIndex === index && center.selectedMemberIndex > 0)
                        center.ensureSelectedVisible();
                }

                Behavior on height {
                    Anim {
                        motion: center.motion
                        type: Anim.FastSpatial
                    }
                }

                Column {
                    id: groupColumn
                    width: parent.width
                    spacing: center.theme.spacing2

                    move: Transition {
                        NumberAnimation {
                            properties: "x,y"
                            duration: center.motion.spatialFast
                            easing.type: center.motion.spatialType
                            easing.bezierCurve: center.motion.spatialCurve
                        }
                    }

                    Item {
                        width: parent.width
                        height: visible ? 32 : 0
                        visible: groupItem.modelData.notifications.length > 1

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: center.theme.spacing2

                            Text {
                                text: groupItem.modelData.name.toUpperCase()
                                color: center.theme.readableRoleColor("notifications")
                                font.family: center.runtime.fontMono
                                font.pixelSize: center.theme.fontSize(10)
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: groupItem.modelData.notifications.length + " notifications · " + groupItem.modelData.notifications.filter(item => !center.notificationState.isRead(item)).length + " unread " + (groupItem.expanded ? "󰅃" : "󰅀")
                                color: center.theme.textMuted
                                font.family: center.runtime.fontMono
                                font.pixelSize: center.theme.fontSize(9)
                            }
                        }
                        StateLayer {
                            theme: center.theme
                            motion: center.motion
                            cornerRadius: center.theme.radiusSmall
                            onActivated: {
                                center.selectedIndex = groupItem.index;
                                center.selectedMemberIndex = 0;
                                center.toggleExpanded();
                            }
                        }
                    }

                    Repeater {
                        id: members
                        model: !groupItem || !groupItem.modelData ? [] : groupItem.expanded ? groupItem.modelData.notifications : groupItem.modelData.notifications.slice(0, 1)

                        delegate: NotificationCard {
                            id: notificationCard
                            required property var modelData
                            required property int index
                            width: groupColumn.width
                            notification: modelData
                            read: center.notificationState.isRead(modelData)
                            runtime: center.runtime
                            theme: center.theme
                            motion: center.motion
                            groupCount: !groupItem || !groupItem.modelData ? 1 : groupItem.expanded ? 1 : groupItem.modelData.notifications.length
                            selected: !!groupItem && center.selectedIndex === groupItem.index && center.selectedMemberIndex === index
                            expanded: !!groupItem && groupItem.expanded && selected
                            onActivated: {
                                if (center.notificationState.captureKind(modelData)) {
                                    center.notificationState.invokeDefault(modelData);
                                    return;
                                }
                                const sameSelection = center.selectedIndex === groupItem.index && center.selectedMemberIndex === index;
                                center.selectedIndex = groupItem.index;
                                center.selectedMemberIndex = index;
                                if (sameSelection)
                                    center.toggleExpanded();
                                else
                                    center.expandedGroupKey = groupItem.modelData.key;
                            }
                            onDefaultRequested: center.notificationState.invokeDefault(modelData)
                            onActionRequested: action => center.notificationState.invokeAction(modelData, action)
                            onReadToggled: center.notificationState.toggleRead(modelData)
                            onDismissRequested: center.dismissNotification(modelData)
                        }
                    }
                }
            }
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        }

        FocusScope {
            id: keySink
            anchors.fill: parent
            focus: center.engaged

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    center.closeRequested();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                    center.navigate(-1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    center.navigate(1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H || event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                    center.selectGroup((event.key === Qt.Key_Left || event.key === Qt.Key_H) ? -1 : 1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_M && (event.modifiers & Qt.ShiftModifier)) {
                    center.notificationState.markAllRead();
                    event.accepted = true;
                } else if (event.key === Qt.Key_N && (event.modifiers & Qt.ShiftModifier)) {
                    center.notificationState.markAllUnread();
                    event.accepted = true;
                } else if (event.key === Qt.Key_M) {
                    center.notificationState.toggleRead(center.selectedNotification());
                    event.accepted = true;
                } else if (event.key === Qt.Key_U || event.key === Qt.Key_D) {
                    const rowHeight = list.currentItem ? list.currentItem.height + list.spacing : 92;
                    const steps = Math.max(1, Math.floor(list.height / Math.max(1, rowHeight) / 2));
                    center.selectGroup((event.key === Qt.Key_D ? 1 : -1) * steps);
                    event.accepted = true;
                } else if (event.key === Qt.Key_E) {
                    if (center.notificationState.captureKind(center.selectedNotification()))
                        center.notificationState.invokeCaptureEdit(center.selectedNotification());
                    else
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
                } else if (event.key === Qt.Key_S) {
                    center.notificationState.toggleSilent();
                    event.accepted = true;
                } else if (event.key === Qt.Key_C) {
                    center.notificationState.clearAll();
                    center.selectedIndex = 0;
                    center.selectedMemberIndex = 0;
                    event.accepted = true;
                }
            }
        }
    }
}

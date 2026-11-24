pragma ComponentBehavior: Bound
import QtQuick
import "NotificationSemantics.js" as NotificationSemantics

FocusScope {
    id: center

    required property NotificationState notificationState
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property bool engaged: false
    property bool replyEditing: false
    property var replyOwner: null
    property var replyDrafts: new Map()
    property bool restoringSelection: false
    property var selectedNotificationAnchor: null
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
            const key = NotificationSemantics.groupKey(notification);
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

    function focusRequested(): void {
        if (!notificationState.focusRecordId)
            return;
        const selected = items.find(item => notificationState.recordKey(item) === notificationState.focusRecordId);
        const match = NotificationSemantics.findNotification(groups, selected);
        if (!match)
            return;
        restoringSelection = true;
        selectedIndex = match.groupIndex;
        selectedMemberIndex = match.memberIndex;
        selectedNotificationAnchor = selected;
        restoringSelection = false;
        Qt.callLater(ensureSelectedVisible);
        Qt.callLater(focusKeyboard);
    }

    readonly property int focusRequestSerial: notificationState.focusRequestSerial
    onFocusRequestSerialChanged: focusRequested()
    onEngagedChanged: {
        if (engaged) {
            focusRequested();
            Qt.callLater(focusKeyboard);
        } else {
            replyEditing = false;
            replyOwner = null;
        }
    }

    onGroupsChanged: {
        if (!groups)
            return;
        const activeNotifications = new Set(items);
        for (const notification of replyDrafts.keys()) {
            if (!activeNotifications.has(notification))
                replyDrafts.delete(notification);
        }
        const preserved = NotificationSemantics.findNotification(groups, selectedNotificationAnchor);
        restoringSelection = true;
        selectedIndex = preserved ? preserved.groupIndex : Math.max(0, Math.min(selectedIndex, Math.max(0, groups.length - 1)));
        const group = selectedGroup();
        selectedMemberIndex = preserved ? preserved.memberIndex : group ? Math.max(0, Math.min(selectedMemberIndex, group.notifications.length - 1)) : 0;
        if (!groups.some(group => group.key === expandedGroupKey))
            expandedGroupKey = "";
        selectedNotificationAnchor = selectedNotification();
        restoringSelection = false;
        Qt.callLater(ensureSelectedVisible);
        // Recreated group delegates must recover the draft and keyboard focus
        // of the notification already being answered.
        if (engaged && replyOwner && NotificationSemantics.findNotification(groups, replyOwner)) {
            Qt.callLater(() => {
                if (engaged && replyOwner)
                    focusReply();
            });
        } else if (engaged && !replyEditing) {
            Qt.callLater(() => {
                if (!replyEditing)
                    focusKeyboard();
            });
        }
    }

    onSelectedIndexChanged: rememberSelection()

    function replyDraftFor(notification): string {
        return replyDrafts.get(notification) || "";
    }

    function storeReplyDraft(notification, draft: string): void {
        if (draft)
            replyDrafts.set(notification, draft);
        else
            replyDrafts.delete(notification);
    }

    function focusKeyboard(): void {
        if (engaged)
            keySink.forceActiveFocus();
    }

    function navigateBack(): void {
        if (replyEditing) {
            replyOwner = null;
            replyEditing = false;
            focusKeyboard();
        } else if (expandedGroupKey.length > 0) {
            expandedGroupKey = "";
            selectedMemberIndex = 0;
            focusKeyboard();
        } else {
            closeRequested();
        }
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

    onSelectedMemberIndexChanged: {
        rememberSelection();
        Qt.callLater(ensureSelectedVisible);
    }
    onExpandedGroupKeyChanged: Qt.callLater(ensureSelectedVisible)

    function rememberSelection(): void {
        if (!restoringSelection)
            selectedNotificationAnchor = selectedNotification();
    }

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
        rememberSelection();
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
        if (group) {
            expandedGroupKey = expandedGroupKey === group.key ? "" : group.key;
            if (!expandedGroupKey)
                selectedMemberIndex = 0;
        }
    }

    function focusReply(): void {
        const notification = selectedNotification();
        const group = selectedGroup();
        if (!notification || !notification.hasInlineReply || !group)
            return;
        expandedGroupKey = group.key;
        Qt.callLater(() => {
            const groupItem = list.itemAtIndex(selectedIndex);
            const card = groupItem ? groupItem.memberAt(selectedMemberIndex) : null;
            if (card && card.notification === notification)
                card.focusReply();
        });
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
                        font.family: center.runtime.fontSans
                        font.pixelSize: center.theme.fontSize(21)
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: center.notificationState.count + " total · " + center.notificationState.unreadCount + " unread"
                        color: center.theme.textMuted
                        font.family: center.runtime.fontSans
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
                        shortcut: center.runtime.shellHint("NotificationContent.markAllRead")
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
                        shortcut: center.runtime.shellHint("NotificationContent.markAllUnread")
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
                        shortcut: center.runtime.shellHint("NotificationContent.silent")
                        iconHint: true
                        onActivated: center.notificationState.toggleSilent()
                    }
                    ShellAction {
                        runtime: center.runtime
                        theme: center.theme
                        motion: center.motion
                        compact: true
                        active: center.notificationState.presentation
                        activeColor: center.theme.warning
                        width: center.theme.minActionTarget
                        height: center.theme.minActionTarget
                        iconOnly: true
                        icon: center.notificationState.presentation ? "󰍺" : "󰍹"
                        title: center.notificationState.presentation ? "Exit presentation mode" : "Presentation mode"
                        shortcut: center.runtime.shellHint("NotificationContent.presentation")
                        iconHint: true
                        onActivated: center.notificationState.togglePresentation()
                    }
                    ShellAction {
                        runtime: center.runtime
                        theme: center.theme
                        motion: center.motion
                        compact: true
                        active: center.notificationState.historyEnabled
                        width: center.theme.minActionTarget
                        height: center.theme.minActionTarget
                        iconOnly: true
                        icon: center.notificationState.historyEnabled ? "󰋚" : "󰗨"
                        title: center.notificationState.historyEnabled ? "Disable saved history" : "Enable saved history"
                        shortcut: center.runtime.shellHint("NotificationContent.history")
                        iconHint: true
                        onActivated: center.notificationState.toggleHistory()
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
                        shortcut: center.runtime.shellHint("NotificationContent.clearAll")
                        iconHint: true
                        onActivated: center.notificationState.clearAll()
                    }
                }
            }
        }

        Text {
            anchors {
                top: header.bottom
                horizontalCenter: parent.horizontalCenter
            }
            text: "Couldn't save notification history"
            color: center.theme.readableRoleColor("critical")
            visible: center.notificationState.persistenceError.length > 0
            Accessible.role: Accessible.AlertMessage
            Accessible.name: text
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
                    font.family: center.runtime.fontSans
                    font.pixelSize: center.theme.fontSize(17)
                    font.weight: Font.DemiBold
                    color: center.theme.textStrong
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "New notifications will appear here"
                    font.family: center.runtime.fontSans
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
                    shortcut: center.runtime.shellHint("NotificationContent.navigate"),
                    label: "Navigate"
                },
                {
                    shortcut: center.runtime.shellHint("NotificationContent.groups"),
                    label: "Groups"
                },
                {
                    shortcut: center.runtime.shellHint("NotificationContent.expand"),
                    label: "Expand"
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
                                font.family: center.runtime.fontSans
                                font.pixelSize: center.theme.fontSize(10)
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: groupItem.modelData.notifications.length + " notifications · " + groupItem.modelData.notifications.filter(item => !center.notificationState.isRead(item)).length + " unread " + (groupItem.expanded ? "󰅃" : "󰅀")
                                color: center.theme.textMuted
                                font.family: center.runtime.fontSans
                                font.pixelSize: center.theme.fontSize(9)
                            }
                        }
                        StateLayer {
                            theme: center.theme
                            motion: center.motion
                            cornerRadius: center.theme.radiusSmall
                            Accessible.role: Accessible.Button
                            Accessible.name: (groupItem.modelData.name || "Notifications") + ", " + groupItem.modelData.notifications.length + " notifications"
                            Accessible.description: groupItem.expanded ? "Collapse notification group" : "Expand notification group"
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
                            replyDraft: center.replyDraftFor(modelData)
                            read: center.notificationState.isRead(modelData)
                            runtime: center.runtime
                            theme: center.theme
                            motion: center.motion
                            notificationState: center.notificationState
                            groupCount: !groupItem || !groupItem.modelData ? 1 : groupItem.expanded ? 1 : groupItem.modelData.notifications.length
                            selected: !!groupItem && center.selectedIndex === groupItem.index && center.selectedMemberIndex === index
                            expanded: !!groupItem && groupItem.expanded && selected
                            onActivated: {
                                const sameSelection = center.selectedIndex === groupItem.index && center.selectedMemberIndex === index;
                                center.selectedIndex = groupItem.index;
                                center.selectedMemberIndex = index;
                                if (sameSelection)
                                    center.toggleExpanded();
                                else
                                    center.expandedGroupKey = groupItem.modelData.key;
                            }
                            onDefaultRequested: {
                                if (!center.notificationState.invokeDefault(modelData))
                                    center.toggleExpanded();
                            }
                            onActionRequested: action => center.notificationState.invokeAction(modelData, action)
                            onReplyRequested: message => {
                                center.storeReplyDraft(modelData, "");
                                center.replyOwner = null;
                                center.replyEditing = false;
                                center.notificationState.sendReply(modelData, message);
                                center.focusKeyboard();
                            }
                            onReplyTextEdited: message => center.storeReplyDraft(modelData, message)
                            onReplyFocusRequested: {
                                center.selectedIndex = groupItem.index;
                                center.selectedMemberIndex = index;
                                center.rememberSelection();
                                center.focusReply();
                            }
                            onReplyFocusChanged: focused => {
                                if (focused) {
                                    center.replyOwner = modelData;
                                    center.replyEditing = true;
                                }
                            }
                            onReplyFinished: {
                                center.replyOwner = null;
                                center.replyEditing = false;
                                center.focusKeyboard();
                            }
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
                const appActions = {
                    "NotificationCard.popup": "popups",
                    "NotificationCard.history": "history",
                    "NotificationCard.silent": "silent",
                    "NotificationCard.criticalOnly": "criticalOnly",
                    "NotificationCard.privatePreview": "privatePreview",
                    "NotificationCard.defaults": "defaults"
                };
                const appAction = Object.keys(appActions).find(action => center.runtime.shellMatchesHint(action, event.key, event.modifiers));
                if (appAction) {
                    const notification = center.selectedNotification();
                    if (notification && center.expandedGroupKey === center.selectedGroup().key) {
                        if (!event.isAutoRepeat) {
                            const name = appActions[appAction];
                            const prefs = center.notificationState.applicationPreferences(notification);
                            if (name === "defaults")
                                center.notificationState.resetApplicationPreferences(notification);
                            else
                                center.notificationState.setApplicationPreference(notification, name, ["popups", "history"].includes(name) ? prefs[name] === false : prefs[name] !== true);
                        }
                        event.accepted = true;
                    }
                } else if (center.runtime.shellChoiceIndex(event.key, event.modifiers, 9) >= 0) {
                    const group = center.selectedGroup();
                    const index = center.runtime.shellChoiceIndex(event.key, event.modifiers, 9);
                    const actions = center.notificationState.explicitActions(center.selectedNotification());
                    if (!event.isAutoRepeat && group && index < (center.expandedGroupKey === group.key ? actions.length : Math.min(2, actions.length)))
                        center.notificationState.invokeAction(center.selectedNotification(), index);
                    event.accepted = true;
                } else if (event.key === center.runtime.shellKeyCode("activity", "Escape")) {
                    center.navigateBack();
                    event.accepted = true;
                } else if (center.runtime.shellNavigates("activity", "up", event.key)) {
                    center.navigate(-1);
                    event.accepted = true;
                } else if (center.runtime.shellNavigates("activity", "down", event.key)) {
                    center.navigate(1);
                    event.accepted = true;
                } else if (event.key === center.runtime.shellKeyCode("activity", "H") && (center.runtime.shellModifier("activity", "Shift", event.modifiers))) {
                    center.notificationState.toggleHistory();
                    event.accepted = true;
                } else if (center.runtime.shellNavigates("activity", "left", event.key) || center.runtime.shellNavigates("activity", "right", event.key)) {
                    center.selectGroup((center.runtime.shellNavigates("activity", "left", event.key)) ? -1 : 1);
                    event.accepted = true;
                } else if (event.key === center.runtime.shellKeyCode("activity", "P")) {
                    center.notificationState.togglePresentation();
                    event.accepted = true;
                } else if (event.key === center.runtime.shellKeyCode("activity", "M") && (center.runtime.shellModifier("activity", "Shift", event.modifiers))) {
                    center.notificationState.markAllRead();
                    event.accepted = true;
                } else if (event.key === center.runtime.shellKeyCode("activity", "N") && (center.runtime.shellModifier("activity", "Shift", event.modifiers))) {
                    center.notificationState.markAllUnread();
                    event.accepted = true;
                } else if (event.key === center.runtime.shellKeyCode("activity", "M")) {
                    center.notificationState.toggleRead(center.selectedNotification());
                    event.accepted = true;
                } else if (event.key === center.runtime.shellKeyCode("activity", "U") || event.key === center.runtime.shellKeyCode("activity", "PageUp") || event.key === center.runtime.shellKeyCode("activity", "D") || event.key === center.runtime.shellKeyCode("activity", "PageDown")) {
                    const rowHeight = list.currentItem ? list.currentItem.height + list.spacing : 92;
                    const steps = Math.max(1, Math.floor(list.height / Math.max(1, rowHeight) / 2));
                    center.selectGroup(((event.key === center.runtime.shellKeyCode("activity", "D") || event.key === center.runtime.shellKeyCode("activity", "PageDown")) ? 1 : -1) * steps);
                    event.accepted = true;
                } else if (event.key === center.runtime.shellKeyCode("activity", "E")) {
                    center.toggleExpanded();
                    event.accepted = true;
                } else if (event.key === center.runtime.shellKeyCode("activity", "R")) {
                    center.focusReply();
                    event.accepted = true;
                } else if (event.key === center.runtime.shellKeyCode("activity", "Return") || event.key === center.runtime.shellKeyCode("activity", "Enter")) {
                    if (!center.notificationState.invokeDefault(center.selectedNotification()))
                        center.toggleExpanded();
                    event.accepted = true;
                } else if (event.key === center.runtime.shellKeyCode("activity", "Delete") || event.key === center.runtime.shellKeyCode("activity", "Backspace")) {
                    center.dismissSelected();
                    event.accepted = true;
                } else if (event.key === center.runtime.shellKeyCode("activity", "S")) {
                    center.notificationState.toggleSilent();
                    event.accepted = true;
                } else if (event.key === center.runtime.shellKeyCode("activity", "C")) {
                    center.notificationState.clearAll();
                    center.selectedIndex = 0;
                    center.selectedMemberIndex = 0;
                    event.accepted = true;
                }
            }
        }
    }
}

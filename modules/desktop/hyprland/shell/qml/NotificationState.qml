import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import QtCore
import "ToastQueue.js" as ToastQueue
import "NotificationSemantics.js" as NotificationSemantics

QtObject {
    id: root
    required property RuntimeConfig runtime

    // Stable model identities preserve exit and reflow animations. A single
    // event-driven timer handles expiry for the bounded three-toast stack.
    property ListModel popups: ListModel {}
    property int popupRevision: 0
    readonly property int historyLimit: 200
    readonly property int maxToasts: 3
    readonly property bool popupVisible: popups.count > 0
    readonly property bool silent: settings.preferenceSource === "default" ? runtime.notificationSilent : settings.silent

    property Settings preferences: Settings {
        id: settings
        location: "file://" + Quickshell.env("HOME") + "/.config/linux-desktop/notifications.ini"
        category: "Notifications"
        property bool silent: root.runtime.notificationSilent
        property string preferenceSource: ""
    }

    onSilentChanged: {
        if (silent)
            hidePopup();
    }

    function toggleSilent(): void {
        settings.silent = !silent;
        settings.preferenceSource = "user";
        settings.setValue("preferenceSource", "user");
        settings.sync();
    }

    Component.onCompleted: {
        if (settings.preferenceSource !== "")
            return;
        // Preserve explicitly stored values from older settings files.
        settings.preferenceSource = settings.value("silent", null) === null ? "default" : "user";
        settings.setValue("preferenceSource", settings.preferenceSource);
        settings.sync();
    }

    function resetToDeclared(): void {
        settings.preferenceSource = "default";
        settings.setValue("preferenceSource", "default");
        settings.sync();
    }
    readonly property var history: server.trackedNotifications.values
    readonly property int count: history.length
    property var readNotifications: []
    readonly property int unreadCount: history.filter(notification => !readNotifications.includes(notification)).length
    readonly property bool hasCriticalUnread: history.some(notification => notification.urgency === NotificationUrgency.Critical && !readNotifications.includes(notification))

    // Dismissed notifications must not remain alive through stale read references.
    onHistoryChanged: {
        if (readNotifications.length)
            readNotifications = readNotifications.filter(notification => history.includes(notification));
    }

    function isRead(notification): bool {
        return !!notification && readNotifications.includes(notification);
    }

    function setRead(notification, read: bool): void {
        if (!notification || !history.includes(notification))
            return;
        if (read && !isRead(notification))
            readNotifications = [...readNotifications, notification];
        else if (!read && isRead(notification))
            readNotifications = readNotifications.filter(item => item !== notification);
    }

    function toggleRead(notification): void {
        setRead(notification, !isRead(notification));
    }

    function markAllRead(): void {
        readNotifications = [...history];
    }

    function markAllUnread(): void {
        readNotifications = [];
    }

    property NotificationServer server: NotificationServer {
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        inlineReplySupported: true

        onNotification: notification => {
            notification.tracked = !notification.transient;
            if (!notification.lastGeneration && (!root.silent || notification.urgency === NotificationUrgency.Critical))
                root.showPopup(notification);
            Qt.callLater(root.pruneHistory);
        }
    }

    function pruneHistory(): void {
        const records = [...history];
        const excess = records.length - historyLimit;
        for (let i = 0; i < excess; ++i)
            records[i].tracked = false;
    }

    function explicitActions(notification): var {
        return NotificationSemantics.explicitActions(notification ? notification.actions : []);
    }

    function hasDefaultAction(notification): bool {
        return !!NotificationSemantics.defaultAction(notification ? notification.actions : []);
    }

    function timeoutFor(notification): real {
        return NotificationSemantics.timeoutMs(notification.expireTimeout, notification.urgency, NotificationUrgency.Critical, NotificationUrgency.Low);
    }

    function rebalancePopups(now: real): void {
        const entries = [];
        for (let i = 0; i < popups.count; ++i)
            entries.push(popups.get(i));
        const layout = ToastQueue.layout(entries, maxToasts, now, 220);
        for (let i = 0; i < layout.length; ++i) {
            const current = entries[i];
            const next = layout[i];
            // Set the exit direction before changing phase, so the delegate
            // never briefly starts a horizontal shrink during eviction.
            if (current.evicted !== next.evicted)
                popups.setProperty(i, "evicted", next.evicted);
            if (current.phase !== next.phase)
                popups.setProperty(i, "phase", next.phase);
            if (current.slot !== next.slot)
                popups.setProperty(i, "slot", next.slot);
            if (current.removeAt !== next.removeAt)
                popups.setProperty(i, "removeAt", next.removeAt);
        }
        // Keep a bounded exit layer during exceptional notification floods.
        // Normally all three old cards remain until their exit completes.
        for (let i = popups.count - 1; i >= 0 && popups.count > maxToasts * 2; --i) {
            if (popups.get(i).phase === "closing")
                popups.remove(i);
        }
    }

    function showPopup(notification): void {
        const now = Date.now();
        for (let i = popups.count - 1; i >= 0; --i) {
            if (popups.get(i).notification === notification)
                popups.remove(i);
        }
        const timeout = timeoutFor(notification);
        popups.insert(0, {
            notification: notification,
            phase: "visible",
            slot: 0,
            evicted: false,
            expires: timeout === 0 ? 0 : now + timeout,
            paused: false,
            remaining: 0,
            removeAt: 0
        });
        rebalancePopups(now);
        popupRevision++;
        schedulePopups();
    }

    function schedulePopups(): void {
        popupTimer.stop();
        if (!popups.count)
            return;
        let due = Infinity;
        for (let i = 0; i < popups.count; ++i) {
            const item = popups.get(i);
            if (item.phase === "closing")
                due = Math.min(due, item.removeAt);
            else if (!item.paused && item.expires > 0)
                due = Math.min(due, item.expires);
        }
        if (!Number.isFinite(due))
            return;
        popupTimer.interval = Math.max(1, due - Date.now());
        popupTimer.restart();
    }

    property Timer popupTimer: Timer {
        repeat: false
        onTriggered: {
            const now = Date.now();
            for (let i = root.popups.count - 1; i >= 0; --i) {
                const item = root.popups.get(i);
                if (item.phase === "closing" && item.removeAt <= now)
                    root.popups.remove(i);
                else if (item.phase === "visible" && !item.paused && item.expires > 0 && item.expires <= now) {
                    root.popups.setProperty(i, "phase", "closing");
                    root.popups.setProperty(i, "removeAt", now + 220);
                }
            }
            root.rebalancePopups(now);
            root.popupRevision++;
            root.schedulePopups();
        }
    }

    function pausePopup(notification, pause: bool): void {
        for (let i = 0; i < popups.count; ++i) {
            const item = popups.get(i);
            if (item.notification !== notification || item.phase !== "visible" || item.paused === pause)
                continue;
            if (pause) {
                popups.setProperty(i, "remaining", item.expires > 0 ? Math.max(1, item.expires - Date.now()) : 0);
                popups.setProperty(i, "paused", true);
            } else {
                popups.setProperty(i, "expires", item.remaining > 0 ? Date.now() + item.remaining : 0);
                popups.setProperty(i, "paused", false);
            }
        }
        schedulePopups();
    }

    function hidePopup(notification): void {
        if (!notification) {
            popups.clear();
        } else {
            const now = Date.now();
            for (let i = 0; i < popups.count; ++i) {
                if (popups.get(i).notification === notification) {
                    popups.setProperty(i, "phase", "closing");
                    popups.setProperty(i, "removeAt", now + 220);
                    break;
                }
            }
        }
        rebalancePopups(Date.now());
        popupRevision++;
        schedulePopups();
    }

    function dismiss(notification): void {
        if (!notification)
            return;

        hidePopup(notification);

        notification.tracked = false;
    }

    function invokeDefault(notification): bool {
        if (!notification)
            return false;
        const action = NotificationSemantics.defaultAction(notification.actions);
        if (!action)
            return false;
        setRead(notification, true);
        hidePopup(notification);
        action.invoke();
        return true;
    }

    function invokeAction(notification, index: int): void {
        const actions = explicitActions(notification);
        if (!notification || index < 0 || index >= actions.length)
            return;
        setRead(notification, true);
        hidePopup(notification);
        actions[index].invoke();
    }

    function sendReply(notification, message: string): void {
        if (!notification || !notification.hasInlineReply || !message.trim())
            return;
        setRead(notification, true);
        hidePopup(notification);
        notification.sendInlineReply(message);
    }

    function invokeLatest(): bool {
        for (let i = 0; i < popups.count; ++i) {
            const item = popups.get(i);
            if (item.phase === "visible")
                return invokeDefault(item.notification);
        }
        const latest = history.length > 0 ? history[history.length - 1] : null;
        return latest ? invokeDefault(latest) : false;
    }

    function clearAll(): void {
        const items = [...history];
        hidePopup();

        for (const notification of items)
            notification.tracked = false;
    }
}

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import QtCore
import "ToastQueue.js" as ToastQueue

QtObject {
    id: root
    required property RuntimeConfig runtime

    // Stable model identities preserve exit and reflow animations. A single
    // event-driven timer handles expiry for the bounded three-toast stack.
    property ListModel popups: ListModel {}
    property int popupRevision: 0
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
        persistenceSupported: false
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: false
        inlineReplySupported: false

        onNotification: notification => {
            notification.tracked = !notification.transient;
            if (!root.silent)
                root.showPopup(notification);
        }
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
        popups.insert(0, {
            notification: notification,
            phase: "visible",
            slot: 0,
            evicted: false,
            expires: now + (notification.urgency === NotificationUrgency.Critical ? 9000 : 5000),
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
            due = Math.min(due, item.phase === "visible" ? item.expires : item.removeAt);
        }
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
                else if (item.phase === "visible" && item.expires <= now) {
                    root.popups.setProperty(i, "phase", "closing");
                    root.popups.setProperty(i, "removeAt", now + 220);
                }
            }
            root.rebalancePopups(now);
            root.popupRevision++;
            root.schedulePopups();
        }
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

    function captureKind(notification): string {
        if (!notification || notification.appName !== "linux-desktop")
            return "";
        if (notification.summary === "Screenshot saved" || notification.summary === "Screenshot copied")
            return "screenshot";
        if (notification.summary === "Recording saved")
            return "recording";
        return "";
    }

    function invokeCaptureEdit(notification): void {
        const kind = captureKind(notification);
        if (!kind || runtime.notificationOpen.length === 0)
            return;
        Quickshell.execDetached([runtime.notificationOpen, kind === "screenshot" ? "edit-screenshot" : "edit-recording", notification.body]);
        setRead(notification, true);
        hidePopup();
    }

    function invokeDefault(notification): void {
        const kind = captureKind(notification);
        if (kind && runtime.notificationOpen.length > 0) {
            Quickshell.execDetached([runtime.notificationOpen, kind, notification.body]);
            setRead(notification, true);
            return;
        }
        invokeAction(notification, 0);
    }

    function invokeAction(notification, index: int): void {
        if (!notification || !notification.actions || index < 0 || index >= notification.actions.length)
            return;

        notification.actions[index].invoke();
    }

    function clearAll(): void {
        const items = [...history];
        hidePopup();

        for (const notification of items)
            notification.tracked = false;
    }
}

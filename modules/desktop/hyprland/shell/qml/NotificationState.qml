import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import QtCore

QtObject {
    id: root
    required property RuntimeConfig runtime

    property var latest: null
    property bool popupVisible: false
    readonly property bool silent: settings.silent

    property Settings preferences: Settings {
        id: settings
        location: "file://" + Quickshell.env("HOME") + "/.config/linux-desktop/notifications.ini"
        category: "Notifications"
        property bool silent: false
    }

    onSilentChanged: {
        if (silent)
            hidePopup();
    }

    function toggleSilent(): void {
        settings.silent = !settings.silent;
    }
    readonly property var history: server.trackedNotifications.values
    readonly property int count: history.length
    property var readNotifications: []
    readonly property int unreadCount: history.filter(notification => !readNotifications.includes(notification)).length

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
            root.latest = notification;
            if (!root.silent) {
                root.popupVisible = true;
                root.popupTimer.interval = notification.urgency === NotificationUrgency.Critical ? 9000 : 5000;
                root.popupTimer.restart();
            }
        }
    }

    property Timer popupTimer: Timer {
        interval: 5000
        repeat: false
        onTriggered: root.popupVisible = false
    }

    function hidePopup(): void {
        popupTimer.stop();
        popupVisible = false;
    }

    function dismiss(notification): void {
        if (!notification)
            return;

        if (latest === notification)
            hidePopup();

        notification.tracked = false;
    }

    function captureKind(notification): string {
        if (!notification || notification.appName !== "linux-desktop")
            return "";
        if (notification.summary === "Screenshot saved")
            return "screenshot";
        if (notification.summary === "Recording saved")
            return "recording";
        return "";
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

import QtQuick
import Quickshell.Services.Notifications

QtObject {
    id: root

    property var latest: null
    property bool popupVisible: false
    readonly property var history: server.trackedNotifications.values
    readonly property int count: history.length

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
            root.popupVisible = true;

            root.popupTimer.interval = notification.urgency === NotificationUrgency.Critical ? 9000 : 5000;
            root.popupTimer.restart();
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

    function invokeDefault(notification): void {
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

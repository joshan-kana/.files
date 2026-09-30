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

            popupTimer.interval = notification.urgency === NotificationUrgency.Critical
                ? 9000
                : 5000;
            popupTimer.restart();
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
        if (!notification || !notification.actions || notification.actions.length === 0)
            return;

        notification.actions[0].invoke();
    }

    function clearAll(): void {
        const items = [...history];
        hidePopup();

        for (const notification of items)
            notification.tracked = false;
    }
}

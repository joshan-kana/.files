import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import QtCore
import Quickshell.Io
import "NotificationJournal.js" as Journal
import "NotificationPolicy.js" as Policy
import "ToastQueue.js" as ToastQueue
import "NotificationSemantics.js" as NotificationSemantics

QtObject {
    id: root
    required property RuntimeConfig runtime

    // NotificationState is the sole owner of the freedesktop server, durable
    // Activity records, visual presentation policy, and live action handles.
    property ListModel popups: ListModel {}
    property int popupRevision: 0
    readonly property int historyLimit: 200
    readonly property int maxToasts: 3
    readonly property bool popupVisible: popups.count > 0 && !locked
    readonly property bool silent: settings.preferenceSource === "default" ? runtime.notificationSilent : settings.silent
    readonly property bool presentation: settings.presentationSource === "default" ? runtime.notificationPresentation : settings.presentation
    readonly property bool historyEnabled: settings.historySource === "default" ? runtime.notificationHistoryEnabled : settings.historyEnabled
    property bool outputFullscreen: false
    readonly property bool locked: ["requested", "locked"].includes(lockState.text().trim())
    property var journal: []
    property var liveById: ({})
    property var objectKeys: new Map()
    property int nextRecord: 0
    readonly property var history: journal.map(record => liveById[record.recordId] || record)
    readonly property int count: history.length
    readonly property int unreadCount: journal.filter(record => !record.read).length
    readonly property bool hasCriticalUnread: journal.some(record => record.urgency === NotificationUrgency.Critical && !record.read)
    property string persistenceError: ""

    // The native ext-session-lock process publishes only a small, atomic
    // session-state marker. No polling, second notification service, or
    // lock-screen notifications are needed.
    property FileView sessionLock: FileView {
        id: lockState
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/linux-desktop-session-lock.state"
        watchChanges: true
        blockLoading: true
        onFileChanged: reload()
    }

    property Settings preferences: Settings {
        id: settings
        location: "file://" + Quickshell.env("HOME") + "/.config/linux-desktop/notifications.ini"
        category: "Notifications"
        property bool silent: root.runtime.notificationSilent
        property bool presentation: root.runtime.notificationPresentation
        property bool historyEnabled: root.runtime.notificationHistoryEnabled
        property string presentationSource: ""
        property string historySource: ""
        property string appsJson: "{}"
        property string preferenceSource: ""
    }

    property FileView historyFile: FileView {
        id: archiveFile
        path: Quickshell.stateDir + "/notifications.json"
        blockLoading: true
        atomicWrites: true
        onSaveFailed: error => root.persistenceError = String(error)
        onSaved: root.persistenceError = ""
    }
    property Timer saveTimer: Timer {
        interval: 300
        repeat: false
        onTriggered: archiveFile.setText(Journal.serialize(root.journal))
    }

    onSilentChanged: {
        if (silent)
            concealOrdinaryPopups();
    }
    onLockedChanged: {
        if (locked)
            hidePopup();
    }
    onOutputFullscreenChanged: {
        if (outputFullscreen)
            concealOrdinaryPopups();
    }
    onPresentationChanged: {
        if (presentation)
            hidePopup();
    }
    onHistoryEnabledChanged: {
        if (!historyEnabled)
            clearAll();
    }

    function toggleSilent(): void {
        settings.silent = !silent;
        settings.preferenceSource = "user";
        settings.setValue("preferenceSource", "user");
        settings.sync();
    }

    function togglePresentation(): void {
        settings.presentation = !presentation;
        settings.presentationSource = "user";
        settings.sync();
    }

    function toggleHistory(): void {
        settings.historyEnabled = !historyEnabled;
        settings.historySource = "user";
        settings.sync();
    }

    function applicationPreferences(notification): var {
        const key = NotificationSemantics.groupKey(notification);
        try {
            const all = JSON.parse(settings.appsJson || "{}");
            return all[key] || {};
        } catch (_) {
            return {};
        }
    }

    function setApplicationPreference(notification, field: string, value: bool): void {
        if (!["popups", "history", "silent"].includes(field))
            return;
        let all = {};
        try {
            all = JSON.parse(settings.appsJson || "{}");
        } catch (_) {}
        const key = NotificationSemantics.groupKey(notification);
        const updated = Object.assign({}, all[key] || {});
        updated[field] = value;
        all[key] = updated;
        settings.appsJson = JSON.stringify(all);
        settings.sync();
        if (field === "popups" && !value)
            hidePopup();
        if (field === "history" && !value) {
            journal = journal.filter(record => NotificationSemantics.groupKey(record) !== key);
            scheduleSave();
        }
    }

    Component.onCompleted: {
        journal = historyEnabled ? Journal.restore(archiveFile.text()) : [];
        nextRecord = journal.length;
        if (!historyEnabled)
            scheduleSave();
        if (settings.preferenceSource === "") {
            // Preserve explicitly stored values from older settings files.
            settings.preferenceSource = settings.value("silent", null) === null ? "default" : "user";
            settings.setValue("preferenceSource", settings.preferenceSource);
        }
        if (settings.presentationSource === "")
            settings.presentationSource = settings.value("presentation", null) === null ? "default" : "user";
        if (settings.historySource === "")
            settings.historySource = settings.value("historyEnabled", null) === null ? "default" : "user";
        settings.sync();
    }

    function resetToDeclared(): void {
        settings.preferenceSource = "default";
        settings.presentationSource = "default";
        settings.historySource = "default";
        settings.setValue("preferenceSource", "default");
        settings.sync();
    }

    function scheduleSave(): void {
        saveTimer.restart();
    }

    function recordKey(notification): string {
        return notification ? (notification.recordId || objectKeys.get(notification) || "") : "";
    }

    function isRead(notification): bool {
        const key = recordKey(notification);
        return !!key && journal.some(record => record.recordId === key && record.read);
    }

    function setRead(notification, read: bool): void {
        const key = recordKey(notification);
        if (!key || !journal.some(record => record.recordId === key))
            return;
        journal = journal.map(record => record.recordId === key ? Object.assign({}, record, {
                read
            }) : record);
        scheduleSave();
    }

    function toggleRead(notification): void {
        setRead(notification, !isRead(notification));
    }

    function markAllRead(): void {
        journal = journal.map(record => (Object.assign({}, record, {
                    read: true
                })));
        scheduleSave();
    }

    function markAllUnread(): void {
        journal = journal.map(record => (Object.assign({}, record, {
                    read: false
                })));
        scheduleSave();
    }

    function updateRecord(notification): void {
        const key = recordKey(notification);
        if (!key)
            return;
        const previous = journal.find(record => record.recordId === key);
        if (!previous)
            return;
        journal = journal.map(record => record.recordId === key ? Journal.snapshot(notification, key, previous.when, record.read) : record);
        scheduleSave();
    }

    function closeRecord(notification, reason): void {
        const key = recordKey(notification);
        if (!key)
            return;
        const next = Object.assign({}, liveById);
        delete next[key];
        liveById = next;
        objectKeys.delete(notification);
        // Retain only inert record metadata. Close reasons are not callbacks.
        journal = journal.map(record => record.recordId === key ? Object.assign({}, record, {
                closeReason: Number(reason) || 0
            }) : record);
        scheduleSave();
    }

    function applyJournal(records): void {
        const previous = journal;
        const next = Journal.compact(records);
        const keep = new Set(next.map(item => item.recordId));
        // Releasing pruned live handles is essential when a sender produces
        // thousands of persistent notifications with no expiry.
        for (const record of previous) {
            if (keep.has(record.recordId))
                continue;
            const live = liveById[record.recordId];
            if (live && live.tracked)
                live.tracked = false;
        }
        journal = next;
        scheduleSave();
    }

    function acceptNotification(notification): void {
        const policy = applicationPreferences(notification);
        const isTransient = !!notification.transient;
        // Retain transient notifications only for the life of their visible
        // popup; they never become durable Activity records.
        notification.tracked = true;
        const prior = !isTransient && journal.slice().reverse().find(record => record.protocolId === notification.id && record.appName === notification.appName && (notification.lastGeneration || liveById[record.recordId] === notification));
        const key = prior ? prior.recordId : String(Date.now()) + "-" + (++nextRecord);
        objectKeys.set(notification, key);
        if (!isTransient && historyEnabled && policy.history !== false) {
            const record = Journal.snapshot(notification, key, prior ? prior.when : Date.now(), prior ? prior.read : false);
            applyJournal([...journal.filter(item => item.recordId !== key), record]);
            const nextLive = Object.assign({}, liveById);
            nextLive[key] = notification;
            liveById = nextLive;
        }
        const update = () => updateRecord(notification);
        for (const name of ["summaryChanged", "bodyChanged", "appIconChanged", "urgencyChanged"])
            if (notification[name])
                notification[name].connect(update);
        notification.closed.connect(reason => closeRecord(notification, reason));

        const critical = notification.urgency === NotificationUrgency.Critical;
        if (!notification.lastGeneration && policy.popups !== false && policy.silent !== true && Policy.mayShowToast(locked, presentation, outputFullscreen, silent, critical))
            showPopup(notification);
        else if (isTransient || !historyEnabled || policy.history === false)
            notification.expire();
    }

    property NotificationServer server: NotificationServer {
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true
        inlineReplySupported: true
        onNotification: notification => root.acceptNotification(notification)
    }

    function explicitActions(notification): var {
        return notification && !notification.historical ? NotificationSemantics.explicitActions(notification.actions) : [];
    }

    function safeActionIcon(notification, action): string {
        return Policy.safeActionIcon(action ? action.identifier : "", !!(notification && !notification.historical && notification.hasActionIcons));
    }

    function bodyMarkup(notification): string {
        return Policy.safeBody(notification ? notification.body : "");
    }

    function openBodyLink(link: string): void {
        if (locked)
            return;
        const safe = Policy.permittedUrl(link);
        if (safe && runtime.urlOpen)
            Quickshell.execDetached([runtime.urlOpen, safe]);
    }

    function hasDefaultAction(notification): bool {
        return !!(notification && !notification.historical && NotificationSemantics.defaultAction(notification.actions));
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
            removeAt: 0,
            closeWhenDone: false
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
                if (item.phase === "closing" && item.removeAt <= now) {
                    root.popups.remove(i);
                    if (item.notification && (item.closeWhenDone || item.notification.transient || !root.recordKey(item.notification)))
                        item.notification.expire();
                } else if (item.phase === "visible" && !item.paused && item.expires > 0 && item.expires <= now) {
                    root.popups.setProperty(i, "closeWhenDone", true);
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

    function concealOrdinaryPopups(): void {
        for (let i = popups.count - 1; i >= 0; --i) {
            const item = popups.get(i);
            if (item.notification && item.notification.urgency !== NotificationUrgency.Critical) {
                popups.remove(i);
                if (item.notification.transient)
                    item.notification.expire();
            }
        }
        rebalancePopups(Date.now());
        popupRevision++;
        schedulePopups();
    }

    function hidePopup(notification): void {
        if (!notification) {
            for (let i = 0; i < popups.count; ++i) {
                const item = popups.get(i);
                if (item.notification && (item.notification.transient || !recordKey(item.notification)))
                    item.notification.expire();
            }
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
        const key = recordKey(notification);
        journal = journal.filter(record => record.recordId !== key);
        scheduleSave();
        if (!notification.historical)
            notification.dismiss();
    }

    function invokeDefault(notification): bool {
        if (!notification || notification.historical || locked)
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
        if (!notification || notification.historical || locked || index < 0 || index >= actions.length)
            return;
        setRead(notification, true);
        hidePopup(notification);
        actions[index].invoke();
    }

    function sendReply(notification, message: string): void {
        if (!notification || notification.historical || locked || !notification.hasInlineReply || !message.trim())
            return;
        setRead(notification, true);
        hidePopup(notification);
        notification.sendInlineReply(message);
    }

    function invokeLatest(): bool {
        if (locked)
            return false;
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
        journal = [];
        scheduleSave();
        for (const notification of items)
            if (!notification.historical)
                notification.dismiss();
    }
}

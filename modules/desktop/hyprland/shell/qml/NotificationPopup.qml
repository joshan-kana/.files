pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland

PanelWindow {
    id: qmlPopup

    required property NotificationState notificationState
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    signal centerRequested

    property bool frameEnabled: false
    property bool hubVisible: false
    property var hubBounds: null
    readonly property real dockTop: frameConnected ? theme.barHeight + theme.spacing3 : theme.panelTopOffset
    readonly property int cardHeight: Math.max(92, Math.min(170, Math.floor((screen ? screen.height : 1440) - dockTop - (frameConnected ? theme.frameThickness : theme.spacing3))))
    readonly property int cardGap: theme.spacing2 + theme.spacing1
    readonly property int toastCount: {
        const revision = notificationState.popupRevision;
        return notificationState.visibleCountForOutput(screen ? screen.name : "");
    }
    readonly property bool outputFullscreen: Hyprland.monitorFor(screen)?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 0) ?? false
    onOutputFullscreenChanged: {
        if (outputFullscreen && screen)
            notificationState.concealOrdinaryPopupsOnOutput(screen.name);
    }
    onMaxToastSlotsChanged: {
        if (screen)
            notificationState.setOutputCapacity(screen.name, maxToastSlots);
    }
    onFrameDocksChanged: {
        if (screen)
            notificationState.setFrameDocks(screen.name, frameDocks);
    }
    Component.onCompleted: {
        if (screen) {
            notificationState.setOutputCapacity(screen.name, maxToastSlots);
            notificationState.setFrameDocks(screen.name, frameDocks);
        }
    }
    Component.onDestruction: {
        if (screen)
            notificationState.setFrameDocks(screen.name, []);
    }
    property int contourEpoch: 0
    // Reserve the full bounded stack, including when there are no toasts.
    // Resizing the right-anchored Wayland surface as notifications arrive
    // causes the compositor to glide the entire popup instead of just cards.
    readonly property int maxToastSlots: Math.max(1, Math.min(3, Math.floor(((screen ? screen.height : 1440) - dockTop - theme.frameThickness + cardGap) / (cardHeight + cardGap))))
    readonly property int interactiveToastSlots: Math.min(maxToastSlots, toastCount)
    function toastFrameState(toast: var): var {
        return {
            cornerRadius: toast.cornerRadius,
            hovered: toast.hovered,
            pressed: toast.pointerPressed,
            attachmentProgress: toast.attachmentProgress
        };
    }
    readonly property var frameDocks: {
        const epoch = contourEpoch;
        const result = [];
        for (let i = 0; i < notificationState.popups.count; ++i) {
            const toast = toastRepeater.itemAt(i);
            if (toast && toast.visible) {
                // Frame geometry follows only painted cards. Evicted entries
                // remain in the model for cleanup, not on the visible frame.
                const state = toastFrameState(toast);
                const y = Math.max(0, toast.y);
                const bottom = Math.min(qmlPopup.height, toast.y + toast.height);
                if (bottom > y + 0.05)
                    result.push({
                        x: frameBounds.x + toast.x,
                        y: frameBounds.y + y,
                        width: toast.width,
                        height: bottom - y,
                        cornerRadius: state.cornerRadius,
                        hovered: state.hovered,
                        pressed: state.pressed,
                        visible: frameAttached && state.attachmentProgress > 0.001
                    });
            }
        }
        return result;
    }
    readonly property bool frameConnected: frameEnabled && !notificationState.locked && !(Hyprland.monitorFor(screen)?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false)
    // Only overlapping surfaces need an independent fill. The shared frame
    // continues to own the toast's squircle when the hub is merely nearby.
    readonly property real toastLeft: screen ? screen.width - width - (frameConnected ? theme.frameThickness : theme.panelSideOffset) : 0
    readonly property real occupiedHeight: interactiveToastSlots * cardHeight + Math.max(0, interactiveToastSlots - 1) * cardGap
    readonly property bool hubOverlapsToasts: hubVisible && hubBounds && hubBounds.visible !== false && hubBounds.x < toastLeft + width && hubBounds.x + hubBounds.width > toastLeft && hubBounds.y < dockTop + occupiedHeight && hubBounds.y + hubBounds.height > dockTop
    readonly property bool frameAttached: frameConnected && !hubOverlapsToasts
    readonly property var frameBounds: ({
            x: toastLeft,
            y: dockTop,
            width: width,
            height: height,
            visible: frameAttached && toastCount > 0
        })

    visible: true
    updatesEnabled: surfaceLifecycle.needsRendering
    PopupSurfaceLifecycle {
        id: surfaceLifecycle
        popup: qmlPopup
        exposed: qmlPopup.notificationState.popupVisible && qmlPopup.toastCount > 0 && !qmlPopup.notificationState.locked
        // Only actual cards accept input, not the transparent reserved slots.
        interactiveItem: toastInputArea
    }
    Item {
        id: toastInputArea
        width: qmlPopup.width
        height: qmlPopup.interactiveToastSlots > 0 ? qmlPopup.interactiveToastSlots * qmlPopup.cardHeight + (qmlPopup.interactiveToastSlots - 1) * qmlPopup.cardGap : 0
    }
    mask: surfaceLifecycle.inputRegion
    color: "transparent"
    implicitWidth: Math.max(1, Math.min(440, (screen ? screen.width : 440) - (frameConnected ? theme.frameThickness : theme.panelSideOffset) * 2))
    implicitHeight: Math.max(1, maxToastSlots * cardHeight + Math.max(0, maxToastSlots - 1) * cardGap)
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
    }

    margins {
        top: qmlPopup.dockTop
        right: qmlPopup.frameConnected ? qmlPopup.theme.frameThickness : theme.panelSideOffset
    }

    WlrLayershell.namespace: "desktop-shell-notification-popup"
    // The hub is an Overlay layer surface; toast cards must paint above it.
    WlrLayershell.layer: WlrLayer.Overlay

    function concealForActivity(): void {
        notificationState.hidePopup();
    }

    Repeater {
        id: toastRepeater
        model: qmlPopup.notificationState.popups
        onCountChanged: qmlPopup.contourEpoch++

        ShellSurface {
            id: toast
            Accessible.role: Accessible.AlertMessage
            Accessible.name: notification ? (notification.appName || "SYSTEM") + ": " + (notification.summary || "") : "Notification"
            Accessible.description: notification ? (notification.body || "") : ""
            required property var notification
            required property string phase
            required property int index
            required property int slot
            required property string outputName
            required property bool evicted
            property bool attachmentReady: false
            property real attachmentProgress: 0
            function updateAttachment(): void {
                attachmentProgress = qmlPopup.frameAttached && phase !== "visible" && !evicted ? 0 : 1;
            }
            Component.onCompleted: {
                attachmentReady = true;
                updateAttachment();
            }
            onPhaseChanged: {
                if (attachmentReady)
                    updateAttachment();
            }
            onEvictedChanged: {
                if (attachmentReady)
                    updateAttachment();
            }
            Connections {
                target: qmlPopup
                function onFrameConnectedChanged(): void {
                    toast.updateAttachment();
                }
            }
            onAttachmentProgressChanged: qmlPopup.contourEpoch++
            Behavior on attachmentProgress {
                NumberAnimation {
                    duration: qmlPopup.frameAttached && qmlPopup.motion.enabled ? Math.min(190, qmlPopup.motion.morph) : 0
                    easing.type: qmlPopup.motion.morphType
                    easing.bezierCurve: qmlPopup.motion.morphCurve
                }
            }
            readonly property color urgencyColor: notification && notification.urgency === NotificationUrgency.Critical ? qmlPopup.theme.critical : notification && notification.urgency === NotificationUrgency.Low ? qmlPopup.theme.textMuted : qmlPopup.theme.roleColor("notifications")
            readonly property bool pointerPressed: toastPress.visualPressed
            readonly property var explicitActions: qmlPopup.notificationState.explicitActions(notification)
            hovered: toastPress.pointerHovered && phase === "visible"
            onHoveredChanged: {
                qmlPopup.contourEpoch++;
                qmlPopup.notificationState.pausePopup(toast.notification, hovered);
            }
            onPointerPressedChanged: qmlPopup.contourEpoch++
            x: qmlPopup.width - width
            y: slot * (qmlPopup.cardHeight + qmlPopup.cardGap)
            // Expiring cards may finish their ordinary exit under live cards.
            // Evicted cards, however, are not painted: the replacement's
            // animated arrival would otherwise reveal their old text beneath
            // it, even when both use the same bounded slot.
            z: phase === "closing" ? 0 : 1
            onXChanged: qmlPopup.contourEpoch++
            onYChanged: qmlPopup.contourEpoch++
            onWidthChanged: qmlPopup.contourEpoch++
            onHeightChanged: qmlPopup.contourEpoch++
            width: qmlPopup.frameAttached ? qmlPopup.width * attachmentProgress : qmlPopup.width
            height: qmlPopup.cardHeight
            clip: qmlPopup.frameAttached
            visible: !evicted && outputName === (qmlPopup.screen ? qmlPopup.screen.name : "") && slot < qmlPopup.maxToastSlots
            onVisibleChanged: qmlPopup.contourEpoch++

            Behavior on y {
                NumberAnimation {
                    duration: qmlPopup.motion.enabled ? qmlPopup.motion.spatialNormal : 0
                    easing.type: qmlPopup.motion.spatialType
                    easing.bezierCurve: qmlPopup.motion.spatialCurve
                }
            }
            theme: qmlPopup.theme
            motion: qmlPopup.motion
            surfaceLayer: ShellSurface.Pane
            cornerRadius: qmlPopup.theme.radiusMedium
            frameConnected: qmlPopup.frameAttached
            // Preserve readable toast backing above the hub, even when
            // the user's general shell-glass preference is translucent.
            glassAllowed: !qmlPopup.hubOverlapsToasts
            fillColor: qmlPopup.theme.paneBase
            borderColor: toast.notification && toast.notification.urgency === NotificationUrgency.Critical ? Qt.rgba(qmlPopup.theme.critical.r, qmlPopup.theme.critical.g, qmlPopup.theme.critical.b, 0.58) : qmlPopup.theme.subtleBorder
            borderWidth: qmlPopup.frameAttached ? 0 : qmlPopup.theme.borderFocus

            // Ordinary expiry/dismissal still retracts its connected contour,
            // while detached cards use the normal opacity fade. Evicted cards
            // do not participate in the rendered stack.
            opacity: qmlPopup.frameAttached ? 1 : (toast.phase === "visible" && !toast.evicted ? 1 : 0)
            scale: qmlPopup.frameAttached ? 1 : (toast.phase === "visible" ? 1 : 0.965)

            Behavior on opacity {
                enabled: !qmlPopup.frameAttached
                NumberAnimation {
                    duration: !qmlPopup.motion.enabled ? 0 : toast.evicted ? qmlPopup.motion.spatialNormal : qmlPopup.motion.fast
                    easing.type: toast.phase === "visible" ? qmlPopup.motion.enterType : qmlPopup.motion.exitType
                    easing.bezierCurve: toast.phase === "visible" ? qmlPopup.motion.enterCurve : qmlPopup.motion.exitCurve
                }
            }

            Behavior on scale {
                enabled: !qmlPopup.frameAttached
                NumberAnimation {
                    duration: qmlPopup.motion.normal
                    easing.type: qmlPopup.motion.enterType
                    easing.bezierCurve: qmlPopup.motion.enterCurve
                }
            }

            StateLayer {
                id: toastPress
                theme: qmlPopup.theme
                motion: qmlPopup.motion
                cornerRadius: toast.cornerRadius
                stateColor: qmlPopup.theme.roleColor("notifications")
                // The shared frame draws this exact attached contour. A
                // second rectangular/pill overlay would double-highlight it.
                showHover: !qmlPopup.frameAttached
                disabled: toast.phase !== "visible"
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onActivated: event => {
                    if (event.button === Qt.RightButton) {
                        qmlPopup.notificationState.dismiss(toast.notification);
                    } else {
                        qmlPopup.notificationState.hidePopup(toast.notification);
                        if (!qmlPopup.notificationState.invokeDefault(toast.notification))
                            qmlPopup.centerRequested();
                    }
                }
            }

            Item {
                anchors.fill: parent
                anchors.margins: qmlPopup.theme.spacing4

                SquircleSurface {
                    id: accent

                    width: 5
                    cornerRadius: 2.5
                    exponent: qmlPopup.theme.squircleExponent
                    fillColor: toast.urgencyColor

                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        left: parent.left
                    }
                }

                Column {
                    anchors {
                        top: parent.top
                        right: parent.right
                        bottom: parent.bottom
                        left: accent.right
                        leftMargin: qmlPopup.theme.spacing4
                    }
                    spacing: qmlPopup.theme.spacing2

                    Row {
                        width: parent.width
                        spacing: qmlPopup.theme.spacing2

                        ShellSurface {
                            id: appMark
                            width: 26
                            height: 26
                            theme: qmlPopup.theme
                            motion: qmlPopup.motion
                            surfaceLayer: ShellSurface.Control
                            cornerRadius: qmlPopup.theme.radiusSmall
                            fillColor: qmlPopup.theme.blend(qmlPopup.theme.controlBase, toast.urgencyColor, 0.15)

                            NotificationArtwork {
                                anchors.fill: parent
                                anchors.margins: 3
                                notification: toast.notification
                            }
                        }

                        Text {
                            id: appName
                            anchors.verticalCenter: parent.verticalCenter
                            text: toast.notification ? (toast.notification.appName || "SYSTEM").toUpperCase() : "SYSTEM"
                            color: toast.urgencyColor
                            font.family: qmlPopup.runtime.fontMono
                            font.pixelSize: qmlPopup.theme.fontSize(10)
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.4
                            width: Math.min(implicitWidth, Math.max(90, parent.width * 0.42))
                            elide: Text.ElideRight
                        }

                        Item {
                            width: Math.max(0, parent.width - appMark.width - appName.width - actionHint.implicitWidth - parent.spacing * 3)
                            height: 1
                        }

                        Text {
                            id: actionHint
                            anchors.verticalCenter: parent.verticalCenter
                            text: !toast.notification ? "" : toast.notification.urgency === NotificationUrgency.Critical ? "CRITICAL" : toast.explicitActions.length > 0 ? toast.explicitActions.length + " ACTION" + (toast.explicitActions.length === 1 ? "" : "S") : toast.notification.hasInlineReply ? "REPLY" : ""
                            color: qmlPopup.theme.textMuted
                            font.family: qmlPopup.runtime.fontMono
                            font.pixelSize: qmlPopup.theme.fontSize(9)
                            font.letterSpacing: 0.8
                        }
                    }

                    MarqueeText {
                        width: Math.max(1, parent.width - (preview.visible ? preview.width + qmlPopup.theme.spacing2 : 0))
                        text: toast.notification ? toast.notification.summary : ""
                        textFormat: Text.PlainText
                        color: qmlPopup.theme.textStrong
                        font.family: qmlPopup.runtime.fontMono
                        font.pixelSize: qmlPopup.theme.fontSize(15)
                        font.weight: Font.DemiBold
                    }

                    Text {
                        width: Math.max(1, parent.width - (preview.visible ? preview.width + qmlPopup.theme.spacing2 : 0))
                        maximumLineCount: toast.explicitActions.length > 0 ? 2 : 3
                        text: qmlPopup.notificationState.bodyMarkup(toast.notification)
                        textFormat: Text.StyledText
                        onLinkActivated: link => qmlPopup.notificationState.openBodyLink(link)
                        visible: text.length > 0
                        color: qmlPopup.theme.text
                        opacity: 0.84
                        font.family: qmlPopup.runtime.fontMono
                        font.pixelSize: qmlPopup.theme.fontSize(12)
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                    }
                }

                NotificationArtwork {
                    id: preview
                    notification: toast.notification
                    preview: true
                    visible: !!toast.notification && !!toast.notification.image
                    width: 96
                    height: 70
                    anchors {
                        top: parent.top
                        right: parent.right
                        topMargin: 38
                    }
                }

                Row {
                    id: quickActions
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                    }
                    spacing: qmlPopup.theme.spacing1
                    visible: toast.explicitActions.length > 0 || (toast.notification && toast.notification.hasInlineReply)

                    Repeater {
                        model: toast.explicitActions.slice(0, 2)
                        delegate: ShellAction {
                            required property int index
                            required property var modelData
                            runtime: qmlPopup.runtime
                            theme: qmlPopup.theme
                            motion: qmlPopup.motion
                            compact: true
                            horizontalCompact: true
                            width: Math.min(135, Math.max(78, implicitWidth))
                            height: 31
                            title: modelData.text || "Action"
                            iconName: qmlPopup.notificationState.safeActionIcon(toast.notification, modelData)
                            onActivated: qmlPopup.notificationState.invokeAction(toast.notification, index)
                        }
                    }
                    ShellAction {
                        visible: toast.explicitActions.length > 2 || (toast.notification && toast.notification.hasInlineReply)
                        runtime: qmlPopup.runtime
                        theme: qmlPopup.theme
                        motion: qmlPopup.motion
                        compact: true
                        horizontalCompact: true
                        width: 78
                        height: 31
                        title: toast.notification && toast.notification.hasInlineReply ? "Reply…" : "More…"
                        onActivated: {
                            qmlPopup.notificationState.hidePopup(toast.notification);
                            qmlPopup.centerRequested();
                        }
                    }
                }

                Text {
                    anchors {
                        left: accent.right
                        bottom: parent.bottom
                        leftMargin: qmlPopup.theme.spacing4
                    }
                    visible: !quickActions.visible
                    text: qmlPopup.notificationState.hasDefaultAction(toast.notification) ? "CLICK · OPEN  /  RMB · DISMISS" : "CLICK · HISTORY  /  RMB · DISMISS"
                    color: qmlPopup.theme.textMuted
                    opacity: 0.62
                    font.family: qmlPopup.runtime.fontMono
                    font.pixelSize: qmlPopup.theme.fontSize(8)
                }
            }
        }
    }
}

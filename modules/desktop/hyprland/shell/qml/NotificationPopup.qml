pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland

PanelWindow {
    id: popup

    required property NotificationState notificationState
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    signal centerRequested

    property bool frameEnabled: false
    property bool hubVisible: false
    readonly property real dockTop: frameConnected ? theme.barHeight + theme.spacing3 : theme.panelTopOffset
    readonly property int cardHeight: Math.max(92, Math.min(170, Math.floor((screen ? screen.height : 1440) - dockTop - (frameConnected ? theme.frameThickness : theme.spacing3))))
    readonly property int cardGap: theme.spacing2 + theme.spacing1
    readonly property int toastCount: notificationState.popups.count
    property int contourEpoch: 0
    // Reserve the full bounded stack, including when there are no toasts.
    // Resizing the right-anchored Wayland surface as notifications arrive
    // causes the compositor to glide the entire popup instead of just cards.
    readonly property int maxToastSlots: Math.max(1, Math.min(3, Math.floor(((screen ? screen.height : 1440) - dockTop - theme.frameThickness + cardGap) / (cardHeight + cardGap))))
    readonly property int interactiveToastSlots: Math.min(maxToastSlots, toastCount)
    readonly property var frameDocks: {
        const epoch = contourEpoch;
        const result = [];
        for (let i = 0; i < notificationState.popups.count; ++i) {
            const toast = toastRepeater.itemAt(i);
            if (toast && toast.visible) {
                // Clip an evicted toast's frame outline to the same bounded
                // three-slot Wayland viewport as its content.
                const y = Math.max(0, toast.y);
                const bottom = Math.min(popup.height, toast.y + toast.height);
                if (bottom > y + 0.05)
                    result.push({
                        x: frameBounds.x + toast.x,
                        y: frameBounds.y + y,
                        width: toast.width,
                        height: bottom - y,
                        hovered: toast.hovered,
                        pressed: toast.pointerPressed,
                        visible: frameAttached && toast.attachmentProgress > 0.001
                    });
            }
        }
        return result;
    }
    readonly property bool frameConnected: frameEnabled && !(Hyprland.monitorFor(screen)?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false)
    // The shared frame is below the Overlay hub. While they overlap, draw
    // self-contained toast surfaces instead of transparent frame attachments.
    readonly property bool frameAttached: frameConnected && !hubVisible
    readonly property var frameBounds: ({
            x: screen ? screen.width - width - margins.right : 0,
            y: margins.top,
            width: width,
            height: height,
            visible: frameAttached && toastCount > 0
        })

    visible: true
    updatesEnabled: surfaceLifecycle.needsRendering
    PopupSurfaceLifecycle {
        id: surfaceLifecycle
        popup: popup
        exposed: popup.notificationState.popupVisible
        // Only actual cards accept input, not the transparent reserved slots.
        interactiveItem: toastInputArea
    }
    Item {
        id: toastInputArea
        width: popup.width
        height: popup.interactiveToastSlots > 0 ? popup.interactiveToastSlots * popup.cardHeight + (popup.interactiveToastSlots - 1) * popup.cardGap : 0
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
        top: popup.dockTop
        right: popup.frameConnected ? popup.theme.frameThickness : theme.panelSideOffset
    }

    WlrLayershell.namespace: "linux-desktop-notification-popup"
    // The hub is an Overlay layer surface; toast cards must paint above it.
    WlrLayershell.layer: WlrLayer.Overlay

    function concealForActivity(): void {
        notificationState.hidePopup();
    }

    Repeater {
        id: toastRepeater
        model: popup.notificationState.popups
        onCountChanged: popup.contourEpoch++

        ShellSurface {
            id: toast
            required property var notification
            required property string phase
            required property int index
            required property int slot
            required property bool evicted
            property bool attachmentReady: false
            property real attachmentProgress: 0
            function updateAttachment(): void {
                attachmentProgress = popup.frameAttached && phase !== "visible" && !evicted ? 0 : 1;
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
                target: popup
                function onFrameConnectedChanged(): void {
                    toast.updateAttachment();
                }
            }
            onAttachmentProgressChanged: popup.contourEpoch++
            Behavior on attachmentProgress {
                NumberAnimation {
                    duration: popup.frameAttached && popup.motion.enabled ? Math.min(190, popup.motion.morph) : 0
                    easing.type: popup.motion.morphType
                    easing.bezierCurve: popup.motion.morphCurve
                }
            }
            readonly property color urgencyColor: notification && notification.urgency === NotificationUrgency.Critical ? popup.theme.critical : notification && notification.urgency === NotificationUrgency.Low ? popup.theme.textMuted : popup.theme.roleColor("notifications")
            readonly property bool pointerPressed: toastPress.visualPressed
            readonly property var explicitActions: popup.notificationState.explicitActions(notification)
            hovered: toastPress.pointerHovered && phase === "visible"
            onHoveredChanged: {
                popup.contourEpoch++;
                popup.notificationState.pausePopup(toast.notification, hovered);
            }
            onPointerPressedChanged: popup.contourEpoch++
            x: popup.width - width
            y: slot * (popup.cardHeight + popup.cardGap)
            // Outgoing cards remain beneath the live stack. When another
            // notification takes their slot, it covers the exit naturally
            // instead of rendering two crooked cards side by side.
            z: phase === "closing" ? 0 : 1
            onXChanged: popup.contourEpoch++
            onYChanged: popup.contourEpoch++
            onWidthChanged: popup.contourEpoch++
            onHeightChanged: popup.contourEpoch++
            width: popup.frameAttached ? popup.width * attachmentProgress : popup.width
            height: popup.cardHeight
            clip: popup.frameAttached
            visible: slot < popup.maxToastSlots || evicted

            Behavior on y {
                NumberAnimation {
                    duration: popup.motion.enabled ? popup.motion.spatialNormal : 0
                    easing.type: popup.motion.spatialType
                    easing.bezierCurve: popup.motion.spatialCurve
                }
            }
            theme: popup.theme
            motion: popup.motion
            surfaceLayer: ShellSurface.Pane
            cornerRadius: theme.radiusPanel
            frameConnected: popup.frameAttached
            // Preserve readable toast backing above the hub, even when
            // the user's general shell-glass preference is translucent.
            glassAllowed: !popup.hubVisible
            fillColor: popup.theme.paneBase
            borderColor: toast.notification && toast.notification.urgency === NotificationUrgency.Critical ? Qt.rgba(popup.theme.critical.r, popup.theme.critical.g, popup.theme.critical.b, 0.58) : popup.theme.subtleBorder
            borderWidth: popup.frameAttached ? 0 : popup.theme.borderFocus

            // Only a forced-out toast slides below the three-card window.
            // All ordinary entry, expiry and dismiss animations are unchanged.
            // In framed mode the entire card exits through the clipped
            // three-slot viewport, with its contour. Fading its content first
            // leaves an empty dark frame silhouette during overflow.
            opacity: popup.frameAttached ? 1 : (toast.phase === "visible" && !toast.evicted ? 1 : 0)
            scale: popup.frameAttached ? 1 : (toast.phase === "visible" ? 1 : 0.965)

            Behavior on opacity {
                enabled: !popup.frameAttached
                NumberAnimation {
                    duration: !popup.motion.enabled ? 0 : toast.evicted ? popup.motion.spatialNormal : popup.motion.fast
                    easing.type: toast.phase === "visible" ? popup.motion.enterType : popup.motion.exitType
                    easing.bezierCurve: toast.phase === "visible" ? popup.motion.enterCurve : popup.motion.exitCurve
                }
            }

            Behavior on scale {
                enabled: !popup.frameAttached
                NumberAnimation {
                    duration: popup.motion.normal
                    easing.type: popup.motion.enterType
                    easing.bezierCurve: popup.motion.enterCurve
                }
            }

            StateLayer {
                id: toastPress
                theme: popup.theme
                motion: popup.motion
                cornerRadius: popup.theme.radiusPanel
                stateColor: popup.theme.roleColor("notifications")
                // The shared frame draws this exact attached contour. A
                // second rectangular/pill overlay would double-highlight it.
                showHover: !popup.frameAttached
                disabled: toast.phase !== "visible"
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onActivated: event => {
                    if (event.button === Qt.RightButton) {
                        popup.notificationState.dismiss(toast.notification);
                    } else {
                        popup.notificationState.hidePopup(toast.notification);
                        if (!popup.notificationState.invokeDefault(toast.notification))
                            popup.centerRequested();
                    }
                }
            }

            Item {
                anchors.fill: parent
                anchors.margins: popup.theme.spacing4

                SquircleSurface {
                    id: accent

                    width: 5
                    cornerRadius: 2.5
                    exponent: popup.theme.squircleExponent
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
                        leftMargin: popup.theme.spacing4
                    }
                    spacing: popup.theme.spacing2

                    Row {
                        width: parent.width
                        spacing: popup.theme.spacing2

                        ShellSurface {
                            id: appMark
                            width: 26
                            height: 26
                            theme: popup.theme
                            motion: popup.motion
                            surfaceLayer: ShellSurface.Control
                            cornerRadius: popup.theme.radiusSmall
                            fillColor: popup.theme.blend(popup.theme.controlBase, toast.urgencyColor, 0.15)

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
                            font.family: popup.runtime.fontMono
                            font.pixelSize: popup.theme.fontSize(10)
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
                            color: popup.theme.textMuted
                            font.family: popup.runtime.fontMono
                            font.pixelSize: popup.theme.fontSize(9)
                            font.letterSpacing: 0.8
                        }
                    }

                    MarqueeText {
                        width: Math.max(1, parent.width - (preview.visible ? preview.width + popup.theme.spacing2 : 0))
                        text: toast.notification ? toast.notification.summary : ""
                        textFormat: Text.PlainText
                        color: popup.theme.textStrong
                        font.family: popup.runtime.fontMono
                        font.pixelSize: popup.theme.fontSize(15)
                        font.weight: Font.DemiBold
                    }

                    Text {
                        width: Math.max(1, parent.width - (preview.visible ? preview.width + popup.theme.spacing2 : 0))
                        maximumLineCount: toast.explicitActions.length > 0 ? 2 : 3
                        text: toast.notification ? toast.notification.body : ""
                        textFormat: Text.PlainText
                        visible: text.length > 0
                        color: popup.theme.text
                        opacity: 0.84
                        font.family: popup.runtime.fontMono
                        font.pixelSize: popup.theme.fontSize(12)
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
                    spacing: popup.theme.spacing1
                    visible: toast.explicitActions.length > 0 || (toast.notification && toast.notification.hasInlineReply)

                    Repeater {
                        model: toast.explicitActions.slice(0, 2)
                        delegate: ShellAction {
                            required property int index
                            required property var modelData
                            runtime: popup.runtime
                            theme: popup.theme
                            motion: popup.motion
                            compact: true
                            horizontalCompact: true
                            width: Math.min(135, Math.max(78, implicitWidth))
                            height: 31
                            title: modelData.text || "Action"
                            onActivated: popup.notificationState.invokeAction(toast.notification, index)
                        }
                    }
                    ShellAction {
                        visible: toast.explicitActions.length > 2 || (toast.notification && toast.notification.hasInlineReply)
                        runtime: popup.runtime
                        theme: popup.theme
                        motion: popup.motion
                        compact: true
                        horizontalCompact: true
                        width: 78
                        height: 31
                        title: toast.notification && toast.notification.hasInlineReply ? "Reply…" : "More…"
                        onActivated: {
                            popup.notificationState.hidePopup(toast.notification);
                            popup.centerRequested();
                        }
                    }
                }

                Text {
                    anchors {
                        left: accent.right
                        bottom: parent.bottom
                        leftMargin: popup.theme.spacing4
                    }
                    visible: !quickActions.visible
                    text: popup.notificationState.hasDefaultAction(toast.notification) ? "CLICK · OPEN  /  RMB · DISMISS" : "CLICK · HISTORY  /  RMB · DISMISS"
                    color: popup.theme.textMuted
                    opacity: 0.62
                    font.family: popup.runtime.fontMono
                    font.pixelSize: popup.theme.fontSize(8)
                }
            }
        }
    }
}

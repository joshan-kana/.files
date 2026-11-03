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
    readonly property real dockTop: frameConnected ? theme.barHeight + theme.spacing3 : theme.panelTopOffset
    readonly property int cardHeight: Math.max(92, Math.min(170, Math.floor((screen ? screen.height : 1440) - dockTop - (frameConnected ? theme.frameThickness : theme.spacing3))))
    readonly property int cardGap: theme.spacing2 + theme.spacing1
    readonly property int toastCount: notificationState.popups.count
    property int contourEpoch: 0
    readonly property int visibleToastCount: Math.max(1, Math.min(3, toastCount, Math.floor(((screen ? screen.height : 1440) - margins.top - theme.frameThickness + cardGap) / (cardHeight + cardGap))))
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
                        visible: frameConnected && toast.attachmentProgress > 0.001
                    });
            }
        }
        return result;
    }
    readonly property bool frameConnected: frameEnabled && !(Hyprland.monitorFor(screen)?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false)
    readonly property var frameBounds: ({
            x: screen ? screen.width - width - margins.right : 0,
            y: margins.top,
            width: width,
            height: height,
            visible: frameConnected && toastCount > 0
        })

    visible: true
    updatesEnabled: surfaceLifecycle.needsRendering
    PopupSurfaceLifecycle {
        id: surfaceLifecycle
        popup: popup
        exposed: popup.notificationState.popupVisible
    }
    mask: surfaceLifecycle.inputRegion
    color: "transparent"
    implicitWidth: Math.max(1, Math.min(440, (screen ? screen.width : 440) - (frameConnected ? theme.frameThickness : theme.panelSideOffset) * 2))
    implicitHeight: Math.max(1, visibleToastCount * cardHeight + Math.max(0, visibleToastCount - 1) * cardGap)
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
                attachmentProgress = popup.frameConnected && phase !== "visible" && !evicted ? 0 : 1;
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
                    duration: popup.frameConnected && popup.motion.enabled ? Math.min(190, popup.motion.morph) : 0
                    easing.type: popup.motion.morphType
                    easing.bezierCurve: popup.motion.morphCurve
                }
            }
            readonly property color urgencyColor: notification && notification.urgency === NotificationUrgency.Critical ? popup.theme.critical : notification && notification.urgency === NotificationUrgency.Low ? popup.theme.textMuted : popup.theme.roleColor("notifications")
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
            width: popup.frameConnected ? popup.width * attachmentProgress : popup.width
            height: popup.cardHeight
            clip: popup.frameConnected
            visible: slot < popup.visibleToastCount || evicted

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
            frameConnected: popup.frameConnected
            fillColor: popup.theme.paneBase
            borderColor: toast.notification && toast.notification.urgency === NotificationUrgency.Critical ? Qt.rgba(popup.theme.critical.r, popup.theme.critical.g, popup.theme.critical.b, 0.58) : popup.theme.subtleBorder
            borderWidth: popup.frameConnected ? 0 : popup.theme.borderFocus

            // Only a forced-out toast slides below the three-card window.
            // All ordinary entry, expiry and dismiss animations are unchanged.
            // In framed mode the entire card exits through the clipped
            // three-slot viewport, with its contour. Fading its content first
            // leaves an empty dark frame silhouette during overflow.
            opacity: popup.frameConnected ? 1 : (toast.phase === "visible" && !toast.evicted ? 1 : 0)
            scale: popup.frameConnected ? 1 : (toast.phase === "visible" ? 1 : 0.965)

            Behavior on opacity {
                enabled: !popup.frameConnected
                NumberAnimation {
                    duration: !popup.motion.enabled ? 0 : toast.evicted ? popup.motion.spatialNormal : popup.motion.fast
                    easing.type: toast.phase === "visible" ? popup.motion.enterType : popup.motion.exitType
                    easing.bezierCurve: toast.phase === "visible" ? popup.motion.enterCurve : popup.motion.exitCurve
                }
            }

            Behavior on scale {
                enabled: !popup.frameConnected
                NumberAnimation {
                    duration: popup.motion.normal
                    easing.type: popup.motion.enterType
                    easing.bezierCurve: popup.motion.enterCurve
                }
            }

            StateLayer {
                theme: popup.theme
                motion: popup.motion
                cornerRadius: popup.theme.radiusPanel
                disabled: toast.phase !== "visible"
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onActivated: event => {
                    if (event.button === Qt.RightButton) {
                        popup.notificationState.dismiss(toast.notification);
                    } else {
                        popup.notificationState.hidePopup(toast.notification);
                        if (popup.notificationState.captureKind(toast.notification))
                            popup.notificationState.invokeDefault(toast.notification);
                        else
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

                            Text {
                                anchors.centerIn: parent
                                text: popup.notificationState.captureKind(toast.notification) === "screenshot" ? "󰹑" : popup.notificationState.captureKind(toast.notification) === "recording" ? "󰕧" : toast.notification && toast.notification.urgency === NotificationUrgency.Critical ? "󰀪" : "󰂚"
                                color: toast.urgencyColor
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: popup.theme.fontSize(14)
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
                        }

                        Item {
                            width: Math.max(0, parent.width - appMark.width - appName.implicitWidth - actionHint.implicitWidth - parent.spacing * 3)
                            height: 1
                        }

                        Text {
                            id: actionHint
                            anchors.verticalCenter: parent.verticalCenter
                            text: !toast.notification ? "" : toast.notification.urgency === NotificationUrgency.Critical ? "CRITICAL" : toast.notification.actions.length > 0 ? toast.notification.actions.length + " ACTION" + (toast.notification.actions.length === 1 ? "" : "S") : popup.notificationState.captureKind(toast.notification) ? "OPEN" : ""
                            color: popup.theme.textMuted
                            font.family: popup.runtime.fontMono
                            font.pixelSize: popup.theme.fontSize(9)
                            font.letterSpacing: 0.8
                        }
                    }

                    MarqueeText {
                        width: parent.width
                        text: toast.notification ? toast.notification.summary : ""
                        textFormat: Text.PlainText
                        color: popup.theme.textStrong
                        font.family: popup.runtime.fontMono
                        font.pixelSize: popup.theme.fontSize(15)
                        font.weight: Font.DemiBold
                    }

                    Text {
                        width: parent.width
                        maximumLineCount: 3
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

                ShellAction {
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                    }
                    visible: popup.notificationState.captureKind(toast.notification).length > 0
                    width: 132
                    height: 31
                    runtime: popup.runtime
                    theme: popup.theme
                    motion: popup.motion
                    compact: true
                    horizontalCompact: true
                    icon: "󰏫"
                    title: popup.notificationState.captureKind(toast.notification) === "screenshot" ? "Markup" : "Trim"
                    onActivated: popup.notificationState.invokeCaptureEdit(toast.notification)
                }

                Text {
                    anchors {
                        left: accent.right
                        bottom: parent.bottom
                        leftMargin: popup.theme.spacing4
                    }
                    text: popup.notificationState.captureKind(toast.notification) ? "CLICK TO OPEN" : "CLICK · HISTORY  /  RMB · DISMISS"
                    color: popup.theme.textMuted
                    opacity: 0.62
                    font.family: popup.runtime.fontMono
                    font.pixelSize: popup.theme.fontSize(8)
                }
            }
        }
    }
}

pragma ComponentBehavior: Bound
import QtQuick
import "DesktopIcons.js" as DesktopIcons
import Quickshell.Services.Notifications

SquircleSurface {
    id: card

    required property var notification
    required property NotificationState notificationState
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property bool selected: false
    property bool read: false
    property bool expanded: false
    property bool policyOpen: false
    property int groupCount: 1
    property bool dismissing: false
    property string replyDraft: ""
    readonly property var safeActions: notificationState.explicitActions(notification)

    Accessible.role: Accessible.ListItem
    Accessible.name: (notification ? (notification.appName || "SYSTEM") + ": " + (notification.summary || "") : "Notification") + (read ? ", read" : ", unread") + (groupCount > 1 ? ", collapsed stack of " + groupCount : "")
    Accessible.description: (notification ? (notification.body || "") : "") + (safeActions.length > 0 ? ", " + safeActions.length + " actions available" : "") + (notification && notification.hasInlineReply ? ", reply available" : "")

    signal activated
    signal policyRequested
    signal defaultRequested
    signal actionRequested(int index)
    signal replyRequested(string message)
    signal replyTextEdited(string message)
    signal replyFocusChanged(bool focused)
    signal replyFocusRequested
    signal replyFinished

    function focusReply(): void {
        if (notification && notification.hasInlineReply)
            reply.forceActiveFocus();
    }

    function sendReply(): void {
        if (!reply.text.trim())
            return;
        replyRequested(reply.text);
        reply.text = "";
    }

    signal readToggled
    signal dismissRequested

    function dismissAnimated(): void {
        if (dismissing)
            return;
        dismissing = true;
        if (motion.enabled)
            dismissMotion.start();
        else
            dismissRequested();
    }

    Behavior on x {
        enabled: !pointer.drag.active && !card.dismissing
        Anim {
            motion: card.motion
            type: Anim.FastSpatial
        }
    }

    SequentialAnimation {
        id: dismissMotion
        ParallelAnimation {
            NumberAnimation {
                target: card
                property: "x"
                to: card.x < 0 ? -card.width - 24 : card.width + 24
                duration: card.motion.spatialFast
                easing.type: card.motion.spatialType
                easing.bezierCurve: card.motion.spatialCurve
            }
            NumberAnimation {
                target: card
                property: "opacity"
                to: 0
                duration: card.motion.effectsFast
                easing.type: card.motion.effectsType
                easing.bezierCurve: card.motion.effectsCurve
            }
        }
        ScriptAction {
            script: card.dismissRequested()
        }
    }

    implicitHeight: Math.max(92, contents.implicitHeight + theme.spacing4 * 2)
    cornerRadius: theme.radiusMedium
    exponent: theme.squircleExponent
    fillColor: selected ? theme.blend(theme.expressiveSurface, theme.roleColor("notifications"), theme.dark ? 0.065 : 0.04) : theme.expressiveSurface
    borderColor: notification && notification.urgency === NotificationUrgency.Critical ? theme.critical : selected ? theme.roleColor("notifications") : theme.outline
    borderWidth: selected ? theme.borderFocus : theme.borderThin

    StateLayer {
        id: pointer
        theme: card.theme
        motion: card.motion
        cornerRadius: card.cornerRadius
        exponent: card.exponent
        stateColor: card.theme.roleColor("notifications")
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        property bool dragged: false
        drag.target: card
        drag.axis: Drag.XAxis
        drag.threshold: 12
        Connections {
            target: pointer
            function onPressed() {
                pointer.dragged = false;
            }
            function onPositionChanged() {
                if (pointer.drag.active)
                    pointer.dragged = true;
            }
            function onReleased() {
                if (pointer.dragged) {
                    if (Math.abs(card.x) >= 70)
                        card.dismissAnimated();
                    else
                        card.x = 0;
                }
            }
            function onCanceled() {
                card.x = 0;
            }
        }
        onActivated: mouse => {
            if (dragged)
                return;
            if (mouse.button === Qt.MiddleButton)
                card.dismissAnimated();
            else if (mouse.button === Qt.RightButton)
                card.defaultRequested();
            else
                card.activated();
        }
        onDoubleClicked: card.defaultRequested()
    }

    Column {
        id: contents
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: card.theme.spacing4
        }
        spacing: card.theme.spacing2

        Row {
            width: parent.width
            spacing: card.theme.spacing2

            NotificationArtwork {
                notification: card.notification
                width: 24
                height: 24
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: appName
                anchors.verticalCenter: parent.verticalCenter
                text: card.notification && card.notification.appName || "System"
                elide: Text.ElideRight
                width: Math.max(1, Math.min(implicitWidth, card.width - cardActions.implicitWidth - 24 - unreadMarker.width - card.theme.spacing4 * 2 - card.theme.spacing2 * 5))
                color: card.notification && card.notification.urgency === NotificationUrgency.Critical ? card.theme.readableRoleColor("critical") : card.read ? card.theme.textMuted : card.theme.readableRoleColor("notifications")
                font.family: card.runtime.fontSans
                font.pixelSize: card.theme.fontAction
                font.weight: Font.DemiBold
                font.letterSpacing: 0
            }

            Rectangle {
                id: unreadMarker
                visible: !card.read
                anchors.verticalCenter: parent.verticalCenter
                width: visible ? 6 : 0
                height: 6
                radius: 3
                color: card.notification && card.notification.urgency === NotificationUrgency.Critical ? card.theme.critical : card.theme.roleColor("notifications")
                opacity: card.selected ? 1 : 0.85
            }

            Item {
                width: Math.max(0, parent.width - 24 - appName.width - unreadMarker.width - cardActions.implicitWidth - card.theme.spacing2 * 5)
                height: 1
            }

            Row {
                id: cardActions
                spacing: card.theme.spacing2
                anchors.verticalCenter: parent.verticalCenter

                ShellAction {
                    id: details
                    width: implicitWidth
                    height: implicitHeight
                    runtime: card.runtime
                    theme: card.theme
                    motion: card.motion
                    compact: true
                    horizontalCompact: true
                    quietAction: true
                    icon: card.expanded ? "󰅃" : card.groupCount > 1 ? "󰓩" : "󰅀"
                    title: card.groupCount > 1 ? card.groupCount + " notifications" : card.expanded ? "Collapse" : "Details"
                    shortcut: card.selected ? card.runtime.shellHint("NotificationContent.expand") : ""
                    onActivated: card.activated()
                }

                ShellAction {
                    id: readToggle
                    width: implicitWidth
                    height: Math.max(36, implicitHeight)
                    runtime: card.runtime
                    theme: card.theme
                    motion: card.motion
                    iconOnly: true
                    iconHint: true
                    inlineIconHint: true
                    shortcut: card.selected ? card.runtime.shellHint("NotificationCard.mark") : ""
                    active: card.read
                    icon: card.read ? "󰄭" : "󰄬"
                    title: card.read ? "Mark unread" : "Mark read"
                    onActivated: card.readToggled()
                }

                ShellAction {
                    visible: !!card.notification && card.notification.hasInlineReply
                    width: visible ? implicitWidth : 0
                    height: Math.max(36, implicitHeight)
                    runtime: card.runtime
                    theme: card.theme
                    motion: card.motion
                    iconOnly: true
                    iconHint: true
                    inlineIconHint: true
                    shortcut: card.selected ? card.runtime.shellHint("NotificationCard.reply") : ""
                    icon: "󰆁"
                    title: "Reply"
                    onActivated: card.replyFocusRequested()
                }

                ShellAction {
                    width: implicitWidth
                    height: Math.max(36, implicitHeight)
                    runtime: card.runtime
                    theme: card.theme
                    motion: card.motion
                    iconOnly: true
                    iconHint: true
                    inlineIconHint: true
                    shortcut: card.selected ? card.runtime.shellHint("NotificationCard.dismiss") : ""
                    icon: "󰆴"
                    title: "Dismiss"
                    onActivated: card.dismissAnimated()
                }
            }
        }

        Text {
            width: parent.width
            text: card.notification ? card.notification.summary : ""
            textFormat: Text.PlainText
            color: card.theme.textStrong
            font.family: card.runtime.fontSans
            font.pixelSize: card.theme.fontSize(14)
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
        }

        Text {
            width: parent.width
            visible: text.length > 0
            maximumLineCount: card.expanded ? 20 : 2
            text: card.notificationState.bodyMarkup(card.notification)
            textFormat: Text.StyledText
            onLinkActivated: link => card.notificationState.openBodyLink(link)
            color: card.theme.text
            opacity: 0.78
            font.family: card.runtime.fontSans
            font.pixelSize: card.theme.fontSize(11)
            wrapMode: Text.Wrap
            elide: Text.ElideRight
        }

        NotificationArtwork {
            notification: card.notification
            preview: true
            visible: !!card.notification && !!card.notification.image
            width: Math.min(parent.width, 220)
            height: visible ? (card.expanded ? 128 : 80) : 0
        }

        Flow {
            id: actionButtons
            width: parent.width
            spacing: card.theme.spacing2
            visible: card.safeActions.length > 0

            Repeater {
                model: card.expanded ? card.safeActions : card.safeActions.slice(0, 2)

                delegate: ShellAction {
                    required property int index
                    required property var modelData
                    runtime: card.runtime
                    theme: card.theme
                    motion: card.motion
                    compact: true
                    horizontalCompact: true
                    title: modelData.text || "Action"
                    iconName: card.notificationState.safeActionIcon(card.notification, modelData)
                    shortcut: card.selected && index < 9 ? card.runtime.shellChoiceHint(index) : ""
                    width: Math.min(actionButtons.width, implicitWidth)
                    activeColor: card.theme.roleColor("notifications")
                    onActivated: card.actionRequested(index)
                }
            }
        }

        ShellAction {
            visible: card.expanded && !!card.notification
            width: Math.min(parent.width, implicitWidth)
            height: visible ? implicitHeight : 0
            runtime: card.runtime
            theme: card.theme
            motion: card.motion
            compact: true
            horizontalCompact: true
            icon: card.policyOpen ? "󰅃" : "󰒓"
            title: "App notification policy"
            shortcut: card.selected ? card.runtime.shellHint("NotificationCard.policy") : ""
            active: card.policyOpen
            activeColor: card.theme.roleColor("notifications")
            onActivated: card.policyRequested()
        }

        ShellSurface {
            id: applicationOptions
            visible: card.expanded && card.policyOpen && !!card.notification
            width: parent.width
            height: visible ? policyContent.implicitHeight + card.theme.spacing3 * 2 : 0
            theme: card.theme
            motion: card.motion
            surfaceLayer: ShellSurface.Group
            cornerRadius: card.theme.radiusMedium
            readonly property var preferences: card.notificationState.applicationPreferences(card.notification)

            Column {
                id: policyContent
                width: parent.width - card.theme.spacing3 * 2
                anchors.centerIn: parent
                spacing: card.theme.spacing2

                Row {
                    width: parent.width
                    spacing: card.theme.spacing2
                    ShellText {
                        width: Math.max(1, parent.width - resetPolicy.width - parent.spacing)
                        anchors.verticalCenter: parent.verticalCenter
                        runtime: card.runtime
                        theme: card.theme
                        text: "Delivery and privacy"
                        textRole: ShellText.Section
                        wrapMode: Text.WordWrap
                    }
                    ShellAction {
                        id: resetPolicy
                        width: implicitWidth
                        height: implicitHeight
                        runtime: card.runtime
                        theme: card.theme
                        motion: card.motion
                        compact: true
                        iconOnly: true
                        inlineIconHint: true
                        quietAction: true
                        icon: DesktopIcons.actionGlyph("reset")
                        title: "Restore app defaults"
                        shortcut: card.selected ? card.runtime.shellHint("NotificationCard.defaults") : ""
                        onActivated: card.notificationState.resetApplicationPreferences(card.notification)
                    }
                }
                Repeater {
                    model: [
                        {
                            key: "popups",
                            title: "Show popups",
                            action: "NotificationCard.popup",
                            inverted: true
                        },
                        {
                            key: "history",
                            title: "Save history",
                            action: "NotificationCard.history",
                            inverted: true
                        },
                        {
                            key: "silent",
                            title: "Quiet app",
                            action: "NotificationCard.silent",
                            inverted: false
                        },
                        {
                            key: "criticalOnly",
                            title: "Critical only",
                            action: "NotificationCard.criticalOnly",
                            inverted: false
                        },
                        {
                            key: "privatePreview",
                            title: "Hide preview",
                            action: "NotificationCard.privatePreview",
                            inverted: false
                        }
                    ]
                    delegate: Row {
                        id: policyRow
                        required property var modelData
                        width: policyContent.width
                        spacing: card.theme.spacing2
                        ShellText {
                            width: Math.max(1, parent.width - policySwitch.width - parent.spacing)
                            anchors.verticalCenter: parent.verticalCenter
                            runtime: card.runtime
                            theme: card.theme
                            text: policyRow.modelData.title
                            textRole: ShellText.Action
                            wrapMode: Text.WordWrap
                        }
                        ShellAction {
                            id: policySwitch
                            width: implicitWidth
                            height: implicitHeight
                            runtime: card.runtime
                            theme: card.theme
                            motion: card.motion
                            compact: true
                            iconOnly: true
                            switchControl: true
                            active: policyRow.modelData.inverted ? applicationOptions.preferences[policyRow.modelData.key] !== false : applicationOptions.preferences[policyRow.modelData.key] === true
                            activeColor: card.theme.roleColor("notifications")
                            title: policyRow.modelData.title
                            shortcut: card.selected ? card.runtime.shellHint(policyRow.modelData.action) : ""
                            onActivated: card.notificationState.setApplicationPreference(card.notification, policyRow.modelData.key, !active)
                        }
                    }
                }
            }
        }

        Row {
            id: replyRow
            width: parent.width
            spacing: card.theme.spacing2
            visible: card.expanded && !!card.notification && card.notification.hasInlineReply

            SearchFieldSurface {
                theme: card.theme
                motion: card.motion
                width: Math.max(1, replyRow.width - sendReply.width - replyRow.spacing)
                height: 42
                fieldFocused: reply.activeFocus

                TextInput {
                    id: reply
                    Accessible.role: Accessible.EditableText
                    Accessible.name: "Reply to " + (card.notification ? (card.notification.appName || "notification") : "notification")
                    Accessible.description: card.notification ? card.notification.summary || "" : ""
                    anchors.fill: parent
                    anchors.leftMargin: card.theme.spacing3
                    anchors.rightMargin: card.theme.spacing3
                    verticalAlignment: TextInput.AlignVCenter
                    color: card.theme.textStrong
                    selectionColor: card.theme.accent
                    selectedTextColor: card.theme.background
                    font.family: card.runtime.fontSans
                    font.pixelSize: card.theme.fontSize(11)
                    clip: true
                    text: card.replyDraft
                    onTextEdited: card.replyTextEdited(text)
                    onActiveFocusChanged: card.replyFocusChanged(activeFocus)
                    Keys.onPressed: event => {
                        if (event.key === card.runtime.shellKeyCode("activity", "Return") || event.key === card.runtime.shellKeyCode("activity", "Enter")) {
                            card.sendReply();
                            event.accepted = true;
                        } else if (event.key === card.runtime.shellKeyCode("activity", "Escape")) {
                            card.replyFinished();
                            event.accepted = true;
                        }
                    }
                    Text {
                        anchors.fill: parent
                        visible: reply.text.length === 0
                        text: card.notification && card.notification.inlineReplyPlaceholder || "Write a reply…"
                        verticalAlignment: Text.AlignVCenter
                        color: card.theme.textMuted
                        font: reply.font
                        elide: Text.ElideRight
                    }
                }
            }

            ShellAction {
                id: sendReply
                runtime: card.runtime
                theme: card.theme
                motion: card.motion
                compact: true
                horizontalCompact: true
                title: "Send"
                shortcut: reply.activeFocus ? card.runtime.shellHint("NotificationCard.submit") : ""
                width: 126
                height: 42
                enabled: reply.text.trim().length > 0
                onActivated: card.sendReply()
            }
        }
    }
}

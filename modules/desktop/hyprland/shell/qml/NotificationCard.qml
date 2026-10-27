pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Notifications

SquircleSurface {
    id: card

    required property var notification
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property bool selected: false
    property bool read: false
    property bool expanded: false
    property int groupCount: 1
    property bool dismissing: false
    readonly property var safeActions: notification && notification.actions ? notification.actions : []

    signal activated
    signal defaultRequested
    signal actionRequested(int index)
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

    MouseArea {
        id: pointer
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        property bool dragged: false
        drag.target: card
        drag.axis: Drag.XAxis
        drag.threshold: 12
        onPressed: dragged = false
        onPositionChanged: {
            if (drag.active)
                dragged = true;
        }
        onReleased: {
            if (dragged) {
                if (Math.abs(card.x) >= 70)
                    card.dismissAnimated();
                else
                    card.x = 0;
            }
        }
        onCanceled: card.x = 0
        onClicked: mouse => {
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

            Text {
                id: appName
                anchors.verticalCenter: parent.verticalCenter
                text: (card.notification && card.notification.appName || "SYSTEM").toUpperCase()
                color: card.notification && card.notification.urgency === NotificationUrgency.Critical ? card.theme.readableRoleColor("critical") : card.read ? card.theme.textMuted : card.theme.readableRoleColor("notifications")
                font.family: card.runtime.fontMono
                font.pixelSize: card.theme.fontSize(9)
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2
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
                width: Math.max(0, parent.width - appName.implicitWidth - unreadMarker.width - cardActions.implicitWidth - card.theme.spacing2 * 2)
                height: 1
            }

            Row {
                id: cardActions
                spacing: card.theme.spacing2
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    id: details
                    anchors.verticalCenter: parent.verticalCenter
                    text: (card.groupCount > 1 ? card.groupCount + " ITEMS · " : "") + (card.expanded ? "󰅃" : "󰅀") + (card.safeActions.length > 0 ? "  " + card.safeActions.length + " ACTIONS" : card.notification && card.notification.appName === "linux-desktop" && (card.notification.summary === "Screenshot saved" || card.notification.summary === "Recording saved") ? "  OPEN" : "  EXPAND")
                    color: card.theme.textMuted
                    font.family: card.runtime.fontMono
                    font.pixelSize: card.theme.fontSize(8)
                }

                ShellAction {
                    id: readToggle
                    width: 36
                    height: 36
                    runtime: card.runtime
                    theme: card.theme
                    motion: card.motion
                    iconOnly: true
                    active: card.read
                    icon: card.read ? "󰄭" : "󰄬"
                    title: card.read ? "Mark unread" : "Mark read"
                    onActivated: card.readToggled()
                }
            }
        }

        Text {
            width: parent.width
            text: card.notification ? card.notification.summary : ""
            textFormat: Text.PlainText
            color: card.theme.textStrong
            font.family: card.runtime.fontMono
            font.pixelSize: card.theme.fontSize(14)
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
        }

        Text {
            width: parent.width
            visible: text.length > 0
            maximumLineCount: card.expanded ? 20 : 2
            text: card.notification ? card.notification.body : ""
            textFormat: Text.PlainText
            color: card.theme.text
            opacity: 0.78
            font.family: card.runtime.fontMono
            font.pixelSize: card.theme.fontSize(11)
            wrapMode: Text.Wrap
            elide: Text.ElideRight
        }

        Flow {
            id: actionButtons
            width: parent.width
            spacing: card.theme.spacing2
            visible: card.expanded && card.safeActions.length > 0

            Repeater {
                model: card.safeActions

                delegate: ShellAction {
                    required property int index
                    required property var modelData
                    runtime: card.runtime
                    theme: card.theme
                    motion: card.motion
                    compact: true
                    title: (index + 1) + "  " + (modelData.text || "Action")
                    width: Math.min(implicitWidth, actionButtons.width)
                    onActivated: card.actionRequested(index)
                }
            }
        }
    }
}

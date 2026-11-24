import QtQuick
import Quickshell

Item {
    id: root

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property string iconName: ""
    property string shortcut: ""
    property bool active: false
    property color activeColor: theme.accent
    property color iconColor: active ? activeColor : theme.textStrong
    property bool compact: false
    property bool horizontalCompact: false
    property bool headerEntry: false
    property bool iconOnly: false
    property bool iconHint: false
    property bool inlineIconHint: false
    property int horizontalPadding: headerEntry ? theme.spacing4 + theme.spacing2 : compact ? theme.spacing3 : theme.spacing4

    property bool foregroundBusy: false
    property color foregroundColor: theme.accent

    signal activated

    implicitWidth: iconOnly ? 44 : Math.max(96, content.implicitWidth + horizontalPadding * 2)
    implicitHeight: iconOnly ? 40 : compact ? 40 : 58
    Accessible.role: Accessible.Button
    Accessible.name: title
    // Assistive-technology press must use the same activation signal as
    // pointer and keyboard controls. A role/name without a press handler is
    // discoverable but cannot actually invoke sender-owned actions.
    Accessible.onPressAction: {
        if (root.enabled)
            root.trigger();
    }
    opacity: enabled ? 1 : 0.42
    // Keep the pointer/keyboard target fixed; deform the painted body only.
    property bool connectedGroup: false
    property bool neighborPressed: false
    readonly property bool visualPressed: interaction.visualPressed
    property real bodyScaleX: !motion.enabled ? 1 : visualPressed ? (connectedGroup ? motion.pressGroupExpand : motion.pressScaleNormal) : neighborPressed ? motion.pressGroupCompress : 1
    property real bodyScaleY: motion.enabled && visualPressed ? motion.pressScaleNormal : 1
    function trigger(): void {
        if (!enabled)
            return;
        interaction.playPressFeedback(width / 2, height / 2);
        activated();
    }
    Behavior on bodyScaleX {
        enabled: root.motion.enabled
        SpringAnimation {
            spring: root.motion.pressSpring
            damping: root.motion.pressDamping
            epsilon: root.motion.pressEpsilon
        }
    }
    Behavior on bodyScaleY {
        enabled: root.motion.enabled
        SpringAnimation {
            spring: root.motion.pressSpring
            damping: root.motion.pressDamping
            epsilon: root.motion.pressEpsilon
        }
    }

    Item {
        id: visualBody
        anchors.fill: parent
        transform: Scale {
            origin.x: root.width / 2
            origin.y: root.height / 2
            xScale: root.bodyScaleX
            yScale: root.bodyScaleY
        }
        ShellSurface {
            id: buttonSurface
            foregroundBusy: root.foregroundBusy
            foregroundColor: root.foregroundColor
            anchors.fill: parent
            theme: root.theme
            motion: root.motion
            surfaceLayer: ShellSurface.Control
            selected: root.active
            fillColor: root.active ? root.theme.blend(root.theme.controlBase, root.activeColor, root.theme.dark ? 0.20 : 0.12) : root.theme.expressiveSurfaceStrong
            cornerRadius: root.motion.enabled && interaction.visualPressed ? Math.min(root.height / 2, root.theme.radiusSmall) : root.active ? root.theme.radiusLarge : root.compact ? theme.radiusSmall : theme.radiusMedium
            Behavior on cornerRadius {
                Anim {
                    motion: root.motion
                    type: Anim.FastSpatial
                }
            }
        }

        Column {
            id: content
            visible: !root.horizontalCompact
            width: Math.max(1, root.width - (root.iconOnly ? 0 : root.horizontalPadding * 2))
            anchors.centerIn: parent
            spacing: root.theme.spacing1

            Text {
                visible: !root.iconOnly && root.icon.length > 0
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.icon
                color: root.iconColor
                font.family: "Symbols Nerd Font"
                font.pixelSize: root.theme.fontSize(root.compact ? 15 : 19)
            }

            ShellText {
                visible: !root.iconOnly
                width: Math.max(1, root.width - root.horizontalPadding * 2)
                horizontalAlignment: root.icon.length > 0 ? Text.AlignHCenter : Text.AlignLeft
                elide: Text.ElideRight
                runtime: root.runtime
                theme: root.theme
                text: root.title
                color: root.active ? root.activeColor : theme.textStrong
                font.pixelSize: theme.fontSize(root.compact ? 10 : 11)
                font.weight: Font.DemiBold
            }

            ShellText {
                visible: !root.iconOnly && root.subtitle.length > 0
                width: Math.max(1, root.width - root.horizontalPadding * 2)
                horizontalAlignment: root.icon.length > 0 ? Text.AlignHCenter : Text.AlignLeft
                runtime: root.runtime
                theme: root.theme
                text: root.subtitle
                color: theme.textMuted
                font.pixelSize: theme.fontSize(root.compact ? 9 : 11)
                elide: Text.ElideRight
            }
        }

        // The 40-pixel header tiles use one line, leaving actual room for their
        // labels, symbols and keyboard hints instead of stacking three rows.
        Row {
            id: inlineContent
            visible: root.horizontalCompact && !root.iconOnly
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
                right: parent.right
                leftMargin: root.horizontalPadding
                rightMargin: root.horizontalPadding
            }
            spacing: root.theme.spacing2

            Image {
                id: inlineThemeIcon
                visible: root.iconName.length > 0
                anchors.verticalCenter: parent.verticalCenter
                width: visible ? root.theme.fontSize(17) : 0
                height: width
                source: visible ? Quickshell.iconPath(root.iconName) : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            Text {
                id: inlineIcon
                visible: root.iconName.length === 0
                anchors.verticalCenter: parent.verticalCenter
                text: root.icon
                color: root.iconColor
                font.family: "Symbols Nerd Font"
                font.pixelSize: root.theme.fontSize(15)
            }

            ShellText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(1, inlineContent.width - (inlineThemeIcon.visible ? inlineThemeIcon.width : inlineIcon.implicitWidth) - inlineHint.implicitWidth - inlineContent.spacing * 2)
                text: root.title
                elide: Text.ElideRight
                runtime: root.runtime
                theme: root.theme
                color: root.active ? root.activeColor : root.theme.textStrong
                font.pixelSize: root.theme.fontSize(10)
                font.weight: Font.DemiBold
            }

            KeyHint {
                id: inlineHint
                visible: root.shortcut.length > 0
                anchors.verticalCenter: parent.verticalCenter
                shortcut: root.shortcut
                compact: true
                runtime: root.runtime
                theme: root.theme
                emphasized: root.active
                emphasisColor: root.activeColor
            }
        }

        // Icon-only actions share one fixed glyph box, independent of font bearings.
        Text {
            visible: root.iconOnly && !root.inlineIconHint
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.iconHint ? -6 : 0
            width: root.width
            height: root.iconHint ? Math.max(20, root.height - 14) : root.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.icon
            color: root.iconColor
            font.family: "Symbols Nerd Font"
            font.pixelSize: root.theme.fontSize(17)
        }

        Row {
            visible: root.iconOnly && root.iconHint && root.inlineIconHint
            anchors.centerIn: parent
            spacing: root.theme.spacing1

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.icon
                color: root.iconColor
                font.family: "Symbols Nerd Font"
                font.pixelSize: root.theme.fontSize(16)
            }

            KeyHint {
                anchors.verticalCenter: parent.verticalCenter
                shortcut: root.shortcut
                compact: true
                runtime: root.runtime
                theme: root.theme
                emphasized: root.active
                emphasisColor: root.activeColor
            }
        }

        KeyHint {
            visible: !root.iconOnly && !root.horizontalCompact && root.shortcut.length > 0
            anchors {
                top: parent.top
                right: parent.right
                margins: root.theme.spacing2
            }
            shortcut: root.shortcut
            compact: true
            runtime: root.runtime
            theme: root.theme
            emphasized: root.active
            emphasisColor: root.activeColor
        }

        KeyHint {
            visible: root.iconOnly && root.iconHint && !root.inlineIconHint && root.shortcut.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            shortcut: root.shortcut
            compact: true
            runtime: root.runtime
            theme: root.theme
            emphasized: root.active
            emphasisColor: root.activeColor
        }
    }

    StateLayer {
        id: interaction
        theme: root.theme
        motion: root.motion
        disabled: !root.enabled
        selected: root.active
        keyboardFocusable: !root.iconOnly || root.iconHint
        Accessible.role: Accessible.Button
        Accessible.name: root.title.length > 0 ? root.title : "Activate control"
        Accessible.onPressAction: root.trigger()
        stateColor: root.active ? root.activeColor : root.theme.textStrong
        effectScaleX: root.bodyScaleX
        effectScaleY: root.bodyScaleY
        cornerRadius: buttonSurface.cornerRadius
        onActivated: root.activated()
    }
}

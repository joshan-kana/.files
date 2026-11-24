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
    property bool prominentAction: false
    property color iconColor: prominentAction ? theme.onColor(activeColor) : active ? activeColor : theme.textStrong
    property bool compact: false
    property bool horizontalCompact: false
    property bool headerEntry: false
    property bool iconOnly: false
    property bool iconHint: shortcut.length > 0
    property bool switchControl: false
    property bool quietAction: false
    readonly property bool inlineSymbol: inlineIconHint || switchControl
    property bool inlineIconHint: false
    property int horizontalPadding: headerEntry ? theme.spacing4 + theme.spacing2 : compact ? theme.spacing3 : theme.spacing4

    property bool foregroundBusy: false
    property color foregroundColor: theme.accent

    signal activated

    readonly property real inlineGlyphWidth: iconName.length > 0 ? theme.fontSize(17) : icon.length > 0 ? inlineIcon.implicitWidth : 0
    readonly property real inlineHintWidth: shortcut.length > 0 ? inlineHint.implicitWidth : 0
    readonly property real symbolWidth: switchControl ? Math.max(46, theme.fontSize(42)) : theme.iconRegular
    readonly property real symbolHeight: switchControl ? Math.max(26, theme.fontSize(24)) : inlineSymbol ? theme.iconRegular : theme.fontSize(17)
    implicitWidth: iconOnly ? Math.max(theme.minActionTarget, inlineSymbol ? symbolWidth + inlineHintWidth + (iconHint ? theme.spacing1 : 0) + theme.spacing2 * 2 : Math.max(symbolWidth, iconHint ? inlineHintWidth : 0) + theme.spacing2) : Math.max(96, horizontalPadding * 2 + (horizontalCompact ? Math.ceil(Math.max(actionLabelMetrics.advanceWidth, actionLabelMetrics.boundingRect.width)) + 2 + inlineGlyphWidth + inlineHintWidth + (inlineGlyphWidth > 0 ? theme.spacing2 : 0) + (inlineHintWidth > 0 ? theme.spacing2 : 0) : Math.max(stackedLabel.implicitWidth, stackedSubtitle.implicitWidth)))
    implicitHeight: iconOnly ? Math.max(40, inlineSymbol ? Math.max(symbolHeight, inlineHint.implicitHeight) + theme.spacing2 : symbolHeight + (iconHint ? inlineHint.implicitHeight + theme.spacing1 : 0) + theme.spacing1) : horizontalCompact ? Math.max(40, inlineLabel.implicitHeight + theme.spacing2 * 2, inlineHint.implicitHeight + theme.spacing2 * 2) : Math.max(compact ? 40 : 58, content.implicitHeight + theme.spacing2 * 2)

    TextMetrics {
        id: actionLabelMetrics
        text: root.title
        font: inlineLabel.font
    }
    Accessible.role: switchControl ? Accessible.CheckBox : Accessible.Button
    Accessible.checkable: switchControl
    Accessible.checked: switchControl && active
    Accessible.name: title
    Accessible.description: subtitle
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
    property real animatedScaleX: !motion.enabled ? 1 : visualPressed ? (connectedGroup ? 1 : motion.pressScaleNormal) : neighborPressed ? motion.pressGroupCompress : connectedGroup ? motion.hoverRestScale : 1
    readonly property real bodyScaleX: Math.max(0, Math.min(1, animatedScaleX))
    property real animatedScaleY: motion.enabled && visualPressed ? motion.pressScaleNormal : 1
    readonly property real bodyScaleY: Math.max(0, Math.min(1, animatedScaleY))
    function trigger(): void {
        if (!enabled)
            return;
        interaction.playPressFeedback(width / 2, height / 2);
        activated();
    }
    Behavior on animatedScaleX {
        enabled: root.motion.enabled
        SpringAnimation {
            spring: root.motion.pressSpring
            damping: root.motion.pressDamping
            epsilon: root.motion.pressEpsilon
        }
    }
    Behavior on animatedScaleY {
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
            fillColor: root.prominentAction ? root.activeColor : root.quietAction || root.switchControl ? "transparent" : root.active ? root.theme.blend(root.theme.controlBase, root.activeColor, root.theme.dark ? 0.20 : 0.12) : root.theme.expressiveSurfaceStrong
            cornerRadius: root.motion.enabled && interaction.visualPressed ? Math.min(root.height / 2, root.theme.radiusSmall) : root.active || root.prominentAction ? root.theme.radiusLarge : root.compact ? theme.radiusSmall : theme.radiusMedium
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
                id: stackedLabel
                visible: !root.iconOnly
                width: Math.max(1, root.width - root.horizontalPadding * 2)
                horizontalAlignment: root.icon.length > 0 ? Text.AlignHCenter : Text.AlignLeft
                wrapMode: Text.WordWrap
                runtime: root.runtime
                theme: root.theme
                text: root.title
                color: root.prominentAction ? root.theme.onColor(root.activeColor) : root.active ? root.activeColor : theme.textStrong
                font.pixelSize: root.compact ? theme.fontCompactAction : theme.fontAction
                font.weight: Font.DemiBold
            }

            ShellText {
                id: stackedSubtitle
                visible: !root.iconOnly && root.subtitle.length > 0
                width: Math.max(1, root.width - root.horizontalPadding * 2)
                horizontalAlignment: root.icon.length > 0 ? Text.AlignHCenter : Text.AlignLeft
                runtime: root.runtime
                theme: root.theme
                text: root.subtitle
                color: theme.textMuted
                font.pixelSize: theme.fontSupporting
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
                visible: root.iconName.length === 0 && root.icon.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: root.icon
                color: root.iconColor
                font.family: "Symbols Nerd Font"
                font.pixelSize: root.theme.fontSize(15)
            }

            ShellText {
                id: inlineLabel
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(1, inlineContent.width - root.inlineGlyphWidth - root.inlineHintWidth - (root.inlineGlyphWidth > 0 ? inlineContent.spacing : 0) - (root.inlineHintWidth > 0 ? inlineContent.spacing : 0))
                text: root.title
                wrapMode: Text.WordWrap
                runtime: root.runtime
                theme: root.theme
                color: root.prominentAction ? root.theme.onColor(root.activeColor) : root.active ? root.activeColor : root.theme.textStrong
                font.pixelSize: root.compact ? root.theme.fontCompactAction : root.theme.fontAction
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
            visible: root.iconOnly && !root.inlineSymbol
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.iconHint ? -(inlineHint.implicitHeight + root.theme.spacing1) / 2 : 0
            width: root.width
            height: root.symbolHeight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.icon
            color: root.iconColor
            font.family: "Symbols Nerd Font"
            font.pixelSize: root.theme.fontSize(17)
        }

        Row {
            visible: root.iconOnly && root.inlineSymbol
            anchors.centerIn: parent
            spacing: root.theme.spacing1

            Item {
                width: root.symbolWidth
                height: root.symbolHeight
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent
                    visible: root.switchControl
                    radius: height / 2
                    color: root.active ? root.theme.blend(root.theme.controlBase, root.activeColor, 0.60) : root.theme.layer3
                    border.color: root.active ? root.activeColor : root.theme.subtleBorder
                    border.width: root.theme.borderThin
                    Rectangle {
                        id: switchThumb
                        width: parent.height - root.theme.spacing1 * 2
                        height: width
                        radius: width / 2
                        x: root.active ? parent.width - width - root.theme.spacing1 : root.theme.spacing1
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.active ? root.activeColor : root.theme.textMuted
                        Behavior on x {
                            Anim {
                                motion: root.motion
                                type: Anim.FastSpatial
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: root.active ? "✓" : "−"
                            color: root.theme.background
                            font.family: root.runtime.fontSans
                            font.pixelSize: root.theme.fontUtility
                            font.weight: Font.DemiBold
                        }
                    }
                }
                Text {
                    visible: !root.switchControl
                    anchors.centerIn: parent
                    text: root.icon
                    color: root.iconColor
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: root.theme.iconSmall
                }
            }

            KeyHint {
                visible: root.iconHint && root.shortcut.length > 0
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
            visible: root.iconOnly && root.iconHint && !root.inlineSymbol && root.shortcut.length > 0
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
        keyboardFocusable: !root.iconOnly || root.iconHint || root.title.length > 0
        Accessible.role: root.switchControl ? Accessible.CheckBox : Accessible.Button
        Accessible.checkable: root.switchControl
        Accessible.checked: root.switchControl && root.active
        Accessible.name: root.title.length > 0 ? root.title : "Activate control"
        Accessible.onPressAction: root.trigger()
        stateColor: root.active ? root.activeColor : root.theme.textStrong
        effectScaleX: root.bodyScaleX
        effectScaleY: root.bodyScaleY
        cornerRadius: buttonSurface.cornerRadius
        onActivated: root.activated()
    }
}

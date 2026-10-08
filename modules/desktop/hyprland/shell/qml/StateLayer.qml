import QtQuick

MouseArea {
    id: root

    required property Theme theme
    required property Motion motion

    property bool disabled: false
    property bool selected: false
    property bool manualHover: false
    property bool manualPress: false
    property bool showHover: true
    property color stateColor: selected ? theme.accent : theme.textStrong
    property real hoverOpacity: 0.08
    property real pressOpacity: 0.12
    property real cornerRadius: theme.radiusMedium

    signal activated(var event)

    anchors.fill: parent
    enabled: !disabled
    hoverEnabled: true
    cursorShape: disabled ? Qt.ArrowCursor : Qt.PointingHandCursor

    onClicked: event => activated(event)

    SquircleSurface {
        anchors.fill: parent
        cornerRadius: root.cornerRadius
        exponent: root.theme.squircleExponent
        fillColor: root.stateColor
        opacity: {
            if (root.pressed || root.manualPress)
                return root.pressOpacity;
            if (root.showHover && (root.containsMouse || root.manualHover))
                return root.hoverOpacity;
            return 0;
        }

        Behavior on opacity {
            Anim {
                motion: root.motion
                type: Anim.FastEffects
            }
        }
    }
}

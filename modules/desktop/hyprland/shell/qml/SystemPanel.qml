import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: panel

    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion
    required property QtObject system
    required property QtObject brightness

    property bool open: false
    property bool closing: false
    readonly property bool trayMenuOpen: systemContent.trayMenuOpen
    readonly property int trayMenuItemCount: systemContent.trayMenuItemCount
    readonly property bool networkOpen: systemContent.networkOpen
    readonly property bool bluetoothOpen: systemContent.bluetoothOpen
    readonly property bool themeOpen: systemContent.themeOpen
    readonly property bool sessionOpen: systemContent.sessionOpen

    visible: open || closing
    color: "transparent"
    focusable: open
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    WlrLayershell.namespace: "linux-desktop-system"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Timer {
        id: closeTimer
        interval: motion.fast
        onTriggered: panel.closing = false
    }

    function show(): void {
        closeTimer.stop();
        closing = false;
        open = true;
    }

    function hide(): void {
        open = false;
        if (motion.fast === 0)
            closing = false;
        else {
            closing = true;
            closeTimer.restart();
        }
    }

    function toggle(): void {
        if (open)
            hide();
        else
            show();
    }

    function showTheme(): void {
        show();
        systemContent.showTheme();
    }

    function showSession(): void {
        show();
        systemContent.showSession();
    }

    function activateTrayItem(): void {
        systemContent.activateTrayItem();
    }

    Rectangle {
        anchors.fill: parent
        color: theme.contextualScrim
        opacity: panel.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: motion.fast
                easing.type: panel.open ? motion.enterType : motion.exitType
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: panel.hide()
        }
    }

    SquircleSurface {
        id: card
        width: Math.min(panel.width - 120, 560)
        height: Math.min(panel.height - 140, systemContent.implicitHeight + theme.spacing5 * 2)
        anchors.centerIn: parent
        exponent: theme.squircleExponent
        cornerRadius: theme.radiusPanel
        fillColor: theme.panelFill
        borderColor: theme.subtleBorder
        borderWidth: theme.borderThin
        scale: panel.open ? 1 : theme.panelClosedScale
        opacity: panel.open ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: motion.normal
                easing.type: motion.enterType
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: motion.fast
            }
        }

        SystemContent {
            id: systemContent
            anchors.fill: parent
            anchors.margins: theme.spacing5
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            system: panel.system
            brightness: panel.brightness
            engaged: panel.open
            onCloseRequested: panel.hide()
        }
    }
}

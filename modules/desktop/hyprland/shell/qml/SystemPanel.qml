import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
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
    property int trayIndex: 0
    readonly property bool trayMenuOpen: trayMenu.open
    readonly property int trayMenuItemCount: trayMenu.itemCount
    readonly property bool networkOpen: networkPanel.open
    readonly property bool themeOpen: themePanel.open

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
        trayIndex = Math.max(0, Math.min(trayIndex, Math.max(0, system.trayCount - 1)));
        open = true;
        keyboardFocus.forceActiveFocus();
    }

    function hide(): void {
        trayMenu.closeMenu();
        networkPanel.closeView();
        themePanel.closeView();
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

    function openNetwork(): void {
        trayMenu.closeMenu();
        themePanel.closeView();
        networkPanel.openView();
    }

    function openTheme(): void {
        trayMenu.closeMenu();
        networkPanel.closeView();
        themePanel.openView();
    }

    function showTheme(): void {
        show();
        openTheme();
    }

    function activateTrayItem(): void {
        if (system.trayCount === 0)
            return;

        const index = Math.max(0, Math.min(trayIndex, system.trayCount - 1));
        const item = system.trayItems[index];

        if (item.hasMenu || item.onlyMenu)
            trayMenu.openFor(item);
        else
            item.activate();
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.48)
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
        width: Math.min(panel.width - 70, 500)
        height: Math.min(panel.height - 110, 430 + (brightness.supported ? 100 : 0) + (system.trayCount > 0 ? 116 : 0))

        anchors {
            top: parent.top
            right: parent.right
            topMargin: 82
            rightMargin: 24
        }

        exponent: theme.squircleExponent
        cornerRadius: 36
        fillColor: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.985)
        borderColor: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.38)
        borderWidth: 1

        scale: panel.open ? 1 : 0.96
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

        Item {
            anchors.fill: parent
            anchors.margins: theme.spacing5

            Column {
                id: content
                width: parent.width
                visible: !trayMenu.open && !networkPanel.open && !themePanel.open
                spacing: theme.spacing4

                Text {
                    text: "SYSTEM // LIVE"
                    color: theme.accent
                    font.family: runtime.fontMono
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.8
                }

                Text {
                    text: "Control centre"
                    color: theme.textStrong
                    font.family: runtime.fontSans
                    font.pixelSize: 27
                    font.weight: Font.DemiBold
                }

                SquircleSurface {
                    width: parent.width
                    height: 112
                    exponent: theme.squircleExponent
                    cornerRadius: theme.radiusLarge
                    fillColor: theme.background
                    borderColor: theme.outline
                    borderWidth: 1

                    Item {
                        anchors.fill: parent
                        anchors.margins: theme.spacing4

                        Row {
                            anchors {
                                top: parent.top
                                left: parent.left
                                right: parent.right
                            }

                            Text {
                                text: system.muted ? "AUDIO // MUTED" : "AUDIO // " + system.volumePercent + "%"
                                color: system.muted ? theme.warning : theme.textStrong
                                font.family: runtime.fontMono
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }

                            Item {
                                width: parent.width - parent.children[0].width - sinkName.width
                                height: 1
                            }

                            Text {
                                id: sinkName
                                width: Math.min(220, implicitWidth)
                                text: system.audioAvailable && system.audioSink ? (system.audioSink.description || system.audioSink.name) : "NO SINK"
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                                color: theme.textMuted
                                font.family: runtime.fontMono
                                font.pixelSize: 9
                            }
                        }

                        Rectangle {
                            anchors {
                                right: parent.right
                                bottom: parent.bottom
                                left: parent.left
                            }
                            height: 7
                            radius: height / 2
                            color: theme.surfaceRaised

                            Rectangle {
                                height: parent.height
                                radius: parent.radius
                                width: parent.width * Math.max(0, Math.min(1, system.volume))
                                color: system.muted ? theme.warning : theme.accent

                                Behavior on width {
                                    NumberAnimation {
                                        duration: motion.fast
                                        easing.type: motion.enterType
                                    }
                                }
                            }
                        }
                    }
                }

                SquircleSurface {
                    width: parent.width
                    height: 82
                    visible: brightness.supported
                    exponent: theme.squircleExponent
                    cornerRadius: theme.radiusLarge
                    fillColor: theme.background
                    borderColor: theme.outline
                    borderWidth: 1

                    Item {
                        anchors.fill: parent
                        anchors.margins: theme.spacing4

                        Row {
                            anchors {
                                top: parent.top
                                left: parent.left
                                right: parent.right
                            }

                            Text {
                                text: "DISPLAY // " + brightness.percent + "%"
                                color: theme.textStrong
                                font.family: runtime.fontMono
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }

                            Item {
                                width: parent.width - parent.children[0].width - brightnessDevice.width
                                height: 1
                            }

                            Text {
                                id: brightnessDevice
                                width: Math.min(220, implicitWidth)
                                text: brightness.device
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                                color: theme.textMuted
                                font.family: runtime.fontMono
                                font.pixelSize: 9
                            }
                        }

                        Rectangle {
                            anchors {
                                right: parent.right
                                bottom: parent.bottom
                                left: parent.left
                            }
                            height: 7
                            radius: height / 2
                            color: theme.surfaceRaised

                            Rectangle {
                                height: parent.height
                                radius: parent.radius
                                width: parent.width * brightness.percent / 100
                                color: theme.positive

                                Behavior on width {
                                    NumberAnimation {
                                        duration: motion.fast
                                        easing.type: motion.enterType
                                    }
                                }
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: theme.spacing3

                    Repeater {
                        id: controlTiles

                        model: [
                            {
                                id: "network",
                                label: "NETWORK",
                                value: system.networkConnected ? system.networkName : "OFFLINE",
                                active: system.networkConnected
                            },
                            {
                                id: "bluetooth",
                                label: "BLUETOOTH",
                                value: system.bluetoothEnabled ? system.bluetoothConnectedCount + " CONNECTED" : "OFF",
                                active: system.bluetoothEnabled
                            },
                            {
                                id: "theme",
                                label: "THEME",
                                value: "PALETTE",
                                active: true
                            }
                        ]

                        delegate: SquircleSurface {
                            required property var modelData

                            width: (content.width - theme.spacing3 * (controlTiles.count - 1)) / controlTiles.count
                            height: 92
                            exponent: theme.squircleExponent
                            cornerRadius: theme.radiusLarge
                            fillColor: theme.background
                            borderColor: modelData.active ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.30) : theme.outline
                            borderWidth: 1

                            MouseArea {
                                anchors.fill: parent
                                enabled: modelData.id === "network" || modelData.id === "theme"
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                                onClicked: {
                                    if (modelData.id === "network")
                                        panel.openNetwork();
                                    else if (modelData.id === "theme")
                                        panel.openTheme();
                                }
                            }

                            Column {
                                anchors {
                                    fill: parent
                                    margins: theme.spacing4
                                }
                                spacing: theme.spacing2

                                Text {
                                    text: modelData.label
                                    color: modelData.active ? theme.accent : theme.textMuted
                                    font.family: runtime.fontMono
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 1.2
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.value
                                    elide: Text.ElideRight
                                    color: theme.text
                                    font.family: runtime.fontSans
                                    font.pixelSize: 13
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    visible: system.trayCount > 0
                    spacing: theme.spacing2

                    Row {
                        width: parent.width

                        Text {
                            text: "SYSTEM TRAY // " + system.trayCount
                            color: theme.textMuted
                            font.family: runtime.fontMono
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.2
                        }

                        Item {
                            width: parent.width - parent.children[0].width - trayHint.width
                            height: 1
                        }

                        Text {
                            id: trayHint
                            text: "[ / ] SELECT   T OPEN"
                            color: theme.textMuted
                            opacity: 0.62
                            font.family: runtime.fontMono
                            font.pixelSize: 8
                        }
                    }

                    Row {
                        spacing: theme.spacing2

                        Repeater {
                            model: system.trayItems

                            delegate: SquircleSurface {
                                id: trayItem

                                required property var modelData
                                required property int index

                                width: 72
                                height: 66
                                exponent: theme.squircleExponent
                                cornerRadius: theme.radiusMedium
                                fillColor: index === panel.trayIndex ? theme.surfaceRaised : theme.background
                                borderColor: index === panel.trayIndex ? theme.accent : theme.outline
                                borderWidth: 1

                                Behavior on fillColor {
                                    ColorAnimation {
                                        duration: motion.fast
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                                    onClicked: mouse => {
                                        panel.trayIndex = trayItem.index;

                                        if (mouse.button === Qt.RightButton) {
                                            modelData.secondaryActivate();
                                        } else if (modelData.hasMenu || modelData.onlyMenu) {
                                            trayMenu.openFor(modelData);
                                        } else {
                                            modelData.activate();
                                        }
                                    }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    width: parent.width - 10
                                    spacing: 4

                                    Image {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 24
                                        height: 24
                                        source: modelData.icon.length > 0
                                            ? modelData.icon
                                            : Quickshell.iconPath("application-x-executable")
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                    }

                                    Text {
                                        width: parent.width
                                        text: modelData.title || modelData.id
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        color: theme.text
                                        font.family: runtime.fontSans
                                        font.pixelSize: 8
                                    }
                                }
                            }
                        }
                    }
                }

                SquircleSurface {
                    width: parent.width
                    height: 64
                    visible: system.batteryAvailable
                    exponent: theme.squircleExponent
                    cornerRadius: theme.radiusMedium
                    fillColor: theme.background
                    borderColor: theme.outline
                    borderWidth: 1

                    Row {
                        anchors {
                            fill: parent
                            leftMargin: theme.spacing4
                            rightMargin: theme.spacing4
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "BATTERY"
                            color: theme.textMuted
                            font.family: runtime.fontMono
                            font.pixelSize: 10
                            font.letterSpacing: 1.2
                        }

                        Item {
                            width: parent.width - parent.children[0].width - batteryValue.width
                            height: 1
                        }

                        Text {
                            id: batteryValue
                            anchors.verticalCenter: parent.verticalCenter
                            text: system.batteryPercent + "%"
                            color: system.batteryPercent <= 20 ? theme.warning : theme.textStrong
                            font.family: runtime.fontMono
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            NetworkPanel {
                id: networkPanel

                anchors.fill: parent

                system: panel.system
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion

                onKeyboardRequested: keyboardFocus.forceActiveFocus()
            }

            ThemePanel {
                id: themePanel

                anchors.fill: parent

                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion

                onKeyboardRequested: keyboardFocus.forceActiveFocus()
            }

            TrayMenuView {
                id: trayMenu

                anchors.fill: parent

                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
            }

            Row {
                id: footer

                visible: !trayMenu.open && !networkPanel.open && !themePanel.open

                anchors {
                    right: parent.right
                    bottom: parent.bottom
                }
                spacing: theme.spacing4

                Text {
                    text: "←/→  VOLUME"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }

                Text {
                    text: "M  MUTE"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }

                Text {
                    visible: brightness.supported
                    text: "↑/↓  BRIGHTNESS"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }

                Text {
                    visible: system.trayCount > 0
                    text: "[/]  TRAY   T  OPEN"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }

                Text {
                    text: "N  NETWORK"
                    color: theme.accent
                    font.family: runtime.fontMono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }

                Text {
                    text: "Y  THEME"
                    color: theme.accent
                    font.family: runtime.fontMono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }

                Text {
                    text: "ESC  CLOSE"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }
            }

            FocusScope {
                id: keyboardFocus
                anchors.fill: parent
                focus: panel.open

                Keys.onPressed: event => {
                    if (themePanel.open) {
                        if (event.key === Qt.Key_Escape
                            || event.key === Qt.Key_Backspace) {
                            themePanel.closeView();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            themePanel.moveSelection(-1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            themePanel.moveSelection(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return
                            || event.key === Qt.Key_Enter) {
                            themePanel.activateSelected();
                            event.accepted = true;
                        }

                        return;
                    }

                    if (networkPanel.open) {
                        if (networkPanel.passwordPrompt)
                            return;

                        if (event.key === Qt.Key_Escape
                            || event.key === Qt.Key_Backspace) {
                            networkPanel.closeView();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            networkPanel.moveSelection(-1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            networkPanel.moveSelection(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return
                            || event.key === Qt.Key_Enter) {
                            networkPanel.activateSelected();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_W) {
                            networkPanel.toggleWifi();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_A) {
                            Quickshell.execDetached(["nm-connection-editor"]);
                            event.accepted = true;
                        }

                        return;
                    }

                    if (trayMenu.open) {
                        if (event.key === Qt.Key_Escape
                            || event.key === Qt.Key_Backspace
                            || event.key === Qt.Key_Left) {
                            trayMenu.goBack();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            trayMenu.moveSelection(-1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            trayMenu.moveSelection(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return
                            || event.key === Qt.Key_Enter
                            || event.key === Qt.Key_Right) {
                            trayMenu.activateSelected();
                            event.accepted = true;
                        }

                        return;
                    }

                    if (event.key === Qt.Key_Escape) {
                        panel.hide();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Left) {
                        system.adjustVolume(-0.05);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right) {
                        system.adjustVolume(0.05);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_M) {
                        system.toggleMute();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_N) {
                        panel.openNetwork();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Y) {
                        panel.openTheme();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up && brightness.supported) {
                        brightness.adjust(5);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down && brightness.supported) {
                        brightness.adjust(-5);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_BracketLeft && system.trayCount > 0) {
                        panel.trayIndex = (panel.trayIndex - 1 + system.trayCount) % system.trayCount;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_BracketRight && system.trayCount > 0) {
                        panel.trayIndex = (panel.trayIndex + 1) % system.trayCount;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_T && system.trayCount > 0) {
                        panel.activateTrayItem();
                        event.accepted = true;
                    }
                }
            }
        }
    }
}

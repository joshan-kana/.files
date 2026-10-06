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
    property bool helpOpen: false
    property int trayIndex: 0
    readonly property bool trayMenuOpen: trayMenu.open
    readonly property int trayMenuItemCount: trayMenu.itemCount
    readonly property bool networkOpen: networkPanel.open
    readonly property bool bluetoothOpen: bluetoothPanel.open
    readonly property bool themeOpen: themePanel.open
    readonly property bool sessionOpen: sessionPanel.open
    readonly property string helpTitle: bluetoothPanel.open ? "Bluetooth controls" : (networkPanel.open ? "Network controls" : (themePanel.open ? "Theme controls" : (sessionPanel.open ? "Session controls" : (trayMenu.open ? "Tray menu controls" : "System controls"))))
    readonly property var helpBindings: bluetoothPanel.open ? [
        {
            key: "↑ / ↓",
            action: "Select device"
        },
        {
            key: "ENTER",
            action: "Connect / disconnect"
        },
        {
            key: "B / D",
            action: "Bluetooth radio / discovery"
        },
        {
            key: "P / T / F",
            action: "Pair / trust / forget"
        },
        {
            key: "ESC",
            action: "Back"
        }
    ] : (networkPanel.open ? [
            {
                key: "↑ / ↓",
                action: "Select network"
            },
            {
                key: "ENTER",
                action: "Join / disconnect"
            },
            {
                key: "W",
                action: "Toggle Wi-Fi"
            },
            {
                key: "A",
                action: "Advanced network editor"
            },
            {
                key: "ESC",
                action: "Back"
            }
        ] : (themePanel.open ? [
                {
                    key: "↑ / ↓",
                    action: "Select theme"
                },
                {
                    key: "ENTER",
                    action: "Apply theme"
                },
                {
                    key: "ESC",
                    action: "Back"
                }
            ] : (sessionPanel.open ? [
                    {
                        key: "↑ / ↓",
                        action: "Select action"
                    },
                    {
                        key: "ENTER",
                        action: "Activate / confirm"
                    },
                    {
                        key: "ESC",
                        action: "Back"
                    }
                ] : (trayMenu.open ? [
                        {
                            key: "↑ / ↓",
                            action: "Select item"
                        },
                        {
                            key: "ENTER / →",
                            action: "Activate / open submenu"
                        },
                        {
                            key: "← / ESC",
                            action: "Back"
                        }
                    ] : [
                        {
                            key: "← / →",
                            action: "Volume down / up"
                        },
                        {
                            key: "↑ / ↓",
                            action: "Brightness up / down"
                        },
                        {
                            key: "M",
                            action: "Mute / unmute"
                        },
                        {
                            key: "N / B",
                            action: "Network / Bluetooth"
                        },
                        {
                            key: "Y / P",
                            action: "Theme / session"
                        },
                        {
                            key: "[ / ] / T",
                            action: "Select / open tray item"
                        },
                        {
                            key: "ESC",
                            action: "Close"
                        }
                    ]))))

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
        helpOpen = false;
        open = true;
        keyboardFocus.forceActiveFocus();
    }

    function hide(): void {
        helpOpen = false;
        trayMenu.closeMenu();
        networkPanel.closeView();
        bluetoothPanel.closeView();
        themePanel.closeView();
        sessionPanel.closeView();
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
        helpOpen = false;
        trayMenu.closeMenu();
        bluetoothPanel.closeView();
        themePanel.closeView();
        sessionPanel.closeView();
        networkPanel.openView();
    }

    function openBluetooth(): void {
        helpOpen = false;
        trayMenu.closeMenu();
        networkPanel.closeView();
        themePanel.closeView();
        sessionPanel.closeView();
        bluetoothPanel.openView();
    }

    function openTheme(): void {
        helpOpen = false;
        trayMenu.closeMenu();
        networkPanel.closeView();
        bluetoothPanel.closeView();
        sessionPanel.closeView();
        themePanel.openView();
    }

    function showTheme(): void {
        show();
        openTheme();
    }

    function openSession(): void {
        helpOpen = false;
        trayMenu.closeMenu();
        networkPanel.closeView();
        bluetoothPanel.closeView();
        themePanel.closeView();
        sessionPanel.openView();
    }

    function showSession(): void {
        show();
        openSession();
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

        width: Math.min(panel.width - 70, 500)
        height: Math.min(panel.height - 110, theme.spacing5 * 2 + content.implicitHeight + theme.spacing3 + footer.implicitHeight)

        anchors {
            top: parent.top
            right: parent.right
            topMargin: theme.panelTopOffset
            rightMargin: theme.panelSideOffset
        }

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

        Item {
            anchors.fill: parent
            anchors.margins: theme.spacing5

            Column {
                id: content
                width: parent.width
                visible: !trayMenu.open && !networkPanel.open && !bluetoothPanel.open && !themePanel.open && !sessionPanel.open
                spacing: theme.spacing4

                Text {
                    text: "System"
                    color: theme.accent
                    font.family: runtime.fontSans
                    font.pixelSize: theme.fontSize(12)
                    font.weight: Font.Medium
                }

                Text {
                    text: "Control centre"
                    color: theme.textStrong
                    font.family: runtime.fontSans
                    font.pixelSize: theme.fontPanelTitle
                    font.weight: Font.DemiBold
                }

                SquircleSurface {
                    width: parent.width
                    height: 112
                    exponent: theme.squircleExponent
                    cornerRadius: theme.radiusLarge
                    fillColor: theme.background
                    borderColor: theme.outline
                    borderWidth: theme.borderThin

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
                                text: system.muted ? "Sound · muted" : "Sound  " + system.volumePercent + "%"
                                color: system.muted ? theme.warning : theme.textStrong
                                font.family: runtime.fontSans
                                font.pixelSize: theme.fontSize(13)
                                font.weight: Font.DemiBold
                            }

                            Item {
                                width: parent.width - parent.children[0].width - sinkName.width
                                height: 1
                            }

                            Text {
                                id: sinkName
                                width: Math.min(220, implicitWidth)
                                text: system.audioAvailable && system.audioSink ? (system.audioSink.description || system.audioSink.name) : "No output"
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                                color: theme.textMuted
                                font.family: runtime.fontMono
                                font.pixelSize: theme.fontSize(9)
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
                    borderWidth: theme.borderThin

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
                                text: "Display  " + brightness.percent + "%"
                                color: theme.textStrong
                                font.family: runtime.fontMono
                                font.pixelSize: theme.fontSize(11)
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
                                font.pixelSize: theme.fontSize(9)
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
                                label: "Network",
                                value: system.networkConnected ? system.networkName : "Offline",
                                active: system.networkConnected
                            },
                            {
                                id: "bluetooth",
                                label: "Bluetooth",
                                value: system.bluetoothEnabled ? system.bluetoothConnectedCount + " connected" : "Off",
                                active: system.bluetoothEnabled
                            },
                            {
                                id: "theme",
                                label: "Theme",
                                value: "Palette",
                                active: true
                            },
                            {
                                id: "session",
                                label: "Session",
                                value: "Power",
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
                            borderWidth: theme.borderThin

                            MouseArea {
                                anchors.fill: parent
                                enabled: modelData.id === "network" || modelData.id === "bluetooth" || modelData.id === "theme" || modelData.id === "session"
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                                onClicked: {
                                    if (modelData.id === "network")
                                        panel.openNetwork();
                                    else if (modelData.id === "bluetooth")
                                        panel.openBluetooth();
                                    else if (modelData.id === "theme")
                                        panel.openTheme();
                                    else if (modelData.id === "session")
                                        panel.openSession();
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
                                    font.family: runtime.fontSans
                                    font.pixelSize: theme.fontSize(11)
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.value
                                    elide: Text.ElideRight
                                    color: theme.text
                                    font.family: runtime.fontSans
                                    font.pixelSize: theme.fontSize(13)
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
                            text: "Tray  " + system.trayCount
                            color: theme.textMuted
                            font.family: runtime.fontMono
                            font.pixelSize: theme.fontSize(10)
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
                            font.pixelSize: theme.fontSize(8)
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
                                fillColor: index === panel.trayIndex ? theme.focusFill : theme.background
                                borderColor: index === panel.trayIndex ? theme.accent : theme.outline
                                borderWidth: index === panel.trayIndex ? theme.borderFocus : theme.borderThin

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
                                    spacing: theme.spacing1

                                    Image {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 24
                                        height: 24
                                        source: modelData.icon.length > 0 ? modelData.icon : Quickshell.iconPath("application-x-executable")
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
                                        font.pixelSize: theme.fontSize(8)
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
                    borderWidth: theme.borderThin

                    Row {
                        anchors {
                            fill: parent
                            leftMargin: theme.spacing4
                            rightMargin: theme.spacing4
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Battery"
                            color: theme.textMuted
                            font.family: runtime.fontMono
                            font.pixelSize: theme.fontSize(10)
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
                            font.pixelSize: theme.fontSize(13)
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

            BluetoothPanel {
                id: bluetoothPanel

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

            SessionPanel {
                id: sessionPanel

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

            Column {
                id: footer

                width: parent.width
                visible: !trayMenu.open && !networkPanel.open && !bluetoothPanel.open && !themePanel.open && !sessionPanel.open

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                spacing: theme.spacing1

                Row {
                    anchors.right: parent.right
                    spacing: theme.spacing4

                    Text {
                        text: "←/→  VOLUME"
                        color: theme.textMuted
                        font.family: runtime.fontMono
                        font.pixelSize: theme.fontSize(9)
                        font.letterSpacing: 1
                    }

                    Text {
                        text: "M  MUTE"
                        color: theme.textMuted
                        font.family: runtime.fontMono
                        font.pixelSize: theme.fontSize(9)
                        font.letterSpacing: 1
                    }

                    Text {
                        visible: brightness.supported
                        text: "↑/↓  BRIGHTNESS"
                        color: theme.textMuted
                        font.family: runtime.fontMono
                        font.pixelSize: theme.fontSize(9)
                        font.letterSpacing: 1
                    }

                    Text {
                        visible: system.trayCount > 0
                        text: "[/]  TRAY   T  OPEN"
                        color: theme.textMuted
                        font.family: runtime.fontMono
                        font.pixelSize: theme.fontSize(9)
                        font.letterSpacing: 1
                    }
                }

                Row {
                    anchors.right: parent.right
                    spacing: theme.spacing4

                    Text {
                        text: "N  NETWORK"
                        color: theme.accent
                        font.family: runtime.fontMono
                        font.pixelSize: theme.fontSize(9)
                        font.letterSpacing: 1
                    }

                    Text {
                        text: "B  BLUETOOTH"
                        color: theme.accent
                        font.family: runtime.fontMono
                        font.pixelSize: theme.fontSize(9)
                        font.letterSpacing: 1
                    }

                    Text {
                        text: "Y  THEME"
                        color: theme.accent
                        font.family: runtime.fontMono
                        font.pixelSize: theme.fontSize(9)
                        font.letterSpacing: 1
                    }

                    Text {
                        text: "P  SESSION"
                        color: theme.accent
                        font.family: runtime.fontMono
                        font.pixelSize: theme.fontSize(9)
                        font.letterSpacing: 1
                    }

                    Text {
                        text: "?  HELP"
                        color: theme.textMuted
                        font.family: runtime.fontMono
                        font.pixelSize: theme.fontSize(9)
                        font.letterSpacing: 1

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panel.helpOpen = true
                        }
                    }

                    Text {
                        text: "ESC  CLOSE"
                        color: theme.textMuted
                        font.family: runtime.fontMono
                        font.pixelSize: theme.fontSize(9)
                        font.letterSpacing: 1
                    }
                }
            }

            FocusScope {
                id: keyboardFocus
                anchors.fill: parent
                focus: panel.open

                Keys.onPressed: event => {
                    const helpKey = event.key === Qt.Key_Question || (event.key === Qt.Key_Slash && (event.modifiers & Qt.ShiftModifier));

                    if (panel.helpOpen) {
                        if (helpKey || event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
                            panel.helpOpen = false;
                            event.accepted = true;
                        }
                        return;
                    }

                    if (helpKey) {
                        panel.helpOpen = true;
                        event.accepted = true;
                        return;
                    }

                    if (bluetoothPanel.open) {
                        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
                            bluetoothPanel.closeView();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            bluetoothPanel.moveSelection(-1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            bluetoothPanel.moveSelection(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            bluetoothPanel.activateSelected();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_B) {
                            bluetoothPanel.toggleBluetooth();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_D) {
                            bluetoothPanel.toggleDiscovery();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_P) {
                            bluetoothPanel.pairSelected();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_T) {
                            bluetoothPanel.toggleTrust();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_F) {
                            bluetoothPanel.forgetSelected();
                            event.accepted = true;
                        }

                        return;
                    }

                    if (sessionPanel.open) {
                        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
                            sessionPanel.closeView();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            sessionPanel.moveSelection(-1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            sessionPanel.moveSelection(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            sessionPanel.activateSelected();
                            event.accepted = true;
                        }

                        return;
                    }

                    if (themePanel.open) {
                        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
                            themePanel.closeView();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            themePanel.moveSelection(-1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            themePanel.moveSelection(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            themePanel.activateSelected();
                            event.accepted = true;
                        }

                        return;
                    }

                    if (networkPanel.open) {
                        if (networkPanel.passwordPrompt)
                            return;

                        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
                            networkPanel.closeView();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            networkPanel.moveSelection(-1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            networkPanel.moveSelection(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            networkPanel.activateSelected();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_W) {
                            networkPanel.toggleWifi();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_A) {
                            Quickshell.execDetached([runtime.networkConnectionEditor]);
                            event.accepted = true;
                        }

                        return;
                    }

                    if (trayMenu.open) {
                        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace || event.key === Qt.Key_Left) {
                            trayMenu.goBack();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            trayMenu.moveSelection(-1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            trayMenu.moveSelection(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Right) {
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
                    } else if (event.key === Qt.Key_B) {
                        panel.openBluetooth();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Y) {
                        panel.openTheme();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_P) {
                        panel.openSession();
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

        WidgetHelp {
            anchors.fill: parent
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            open: panel.helpOpen
            title: panel.helpTitle
            bindings: panel.helpBindings
            onDismissed: panel.helpOpen = false
        }
    }
}

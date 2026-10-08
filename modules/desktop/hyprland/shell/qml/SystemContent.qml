pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

FocusScope {
    id: root

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property SystemState system
    required property MediaState media
    required property NotificationState notificationState
    required property BrightnessState brightness
    required property ResourceState resourceState
    required property PowerProfileState powerProfile

    property bool engaged: false
    property bool mixerOpen: false
    property string requestedView: ""
    property bool helpOpen: false
    property int trayIndex: 0
    readonly property bool trayMenuOpen: trayMenu.open
    readonly property int trayMenuItemCount: trayMenu.itemCount
    readonly property bool networkOpen: networkPanel.open
    readonly property bool bluetoothOpen: bluetoothPanel.open
    readonly property bool themeOpen: themePanel.open
    readonly property bool sessionOpen: sessionPanel.open
    readonly property bool resourcesOpen: resourcesPanel.open
    readonly property string helpTitle: mixerOpen ? "Application mixer" : resourcesPanel.open ? "Resource monitor" : (bluetoothPanel.open ? "Bluetooth controls" : (networkPanel.open ? "Network controls" : (themePanel.open ? "Theme controls" : (sessionPanel.open ? "Session controls" : (trayMenu.open ? "Tray menu controls" : "System controls")))))
    readonly property var helpBindings: mixerOpen ? [
        {
            key: "J/K · U/D",
            action: "Select stream / half page"
        },
        {
            key: "H/L · ←/→",
            action: "Adjust volume"
        },
        {
            key: "M",
            action: "Mute selected stream"
        },
        {
            key: "ESC",
            action: "Back to Controls"
        }
    ] : resourcesPanel.open ? [
        {
            key: "R",
            action: "Refresh now"
        },
        {
            key: "ESC",
            action: "Back to controls"
        }
    ] : bluetoothPanel.open ? [
        {
            key: "J/K · U/D",
            action: "Select device"
        },
        {
            key: "ENTER",
            action: "Connect / disconnect"
        },
        {
            key: "B / SHIFT+D",
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
                key: "J/K · U/D",
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
                    key: "J/K · U/D",
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
                        key: "J/K · U/D",
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
                            key: "J/K · U/D",
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
                            key: "H/L · ←/→",
                            action: "Volume down / up"
                        },
                        {
                            key: "K/J · ↑/↓",
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
                            key: "G / V / A",
                            action: "Resources / media details / app mixer"
                        },
                        {
                            key: "SPACE / , / .",
                            action: "Play-pause / previous / next media"
                        },
                        {
                            key: "Q / I",
                            action: "Do Not Disturb / Stay awake"
                        },
                        {
                            key: "O",
                            action: "Cycle available power profiles"
                        },
                        {
                            key: "CTRL+TAB",
                            action: "Cycle Home / Controls / Activity"
                        },
                        {
                            key: "[ / ]",
                            action: "Select tray item"
                        },
                        {
                            key: "ENTER",
                            action: "Open tray item"
                        },
                        {
                            key: "ESC",
                            action: "Close"
                        }
                    ]))))

    signal closeRequested
    signal mediaRequested

    implicitWidth: 512
    implicitHeight: mixerOpen ? mixerView.implicitHeight : sessionPanel.open ? sessionPanel.implicitHeight : (resourcesPanel.open ? resourcesPanel.implicitHeight : content.implicitHeight + theme.spacing3 + footer.implicitHeight)
    focus: engaged

    function applyRequestedView(): void {
        if (!engaged)
            return;

        if (requestedView === "theme")
            openTheme();
        else if (requestedView === "session")
            openSession();
        else if (requestedView === "network")
            openNetwork();
        else if (requestedView === "bluetooth")
            openBluetooth();
        else if (requestedView === "resources")
            openResources();
        else if (requestedView === "mixer")
            openMixer();
        else if (requestedView.startsWith("tray:")) {
            const index = Number(requestedView.slice(5));
            if (Number.isInteger(index) && index >= 0 && index < system.trayCount) {
                trayIndex = index;
                const item = system.trayItems[index];
                if (item.hasMenu)
                    trayMenu.openFor(item);
            }
        } else if (requestedView.length === 0) {
            trayMenu.closeMenu();
            networkPanel.closeView();
            bluetoothPanel.closeView();
            themePanel.closeView();
            sessionPanel.closeView();
            resourcesPanel.closeView();
            mixerOpen = false;
        }
    }

    onEngagedChanged: {
        if (engaged) {
            trayIndex = Math.max(0, Math.min(trayIndex, Math.max(0, system.trayCount - 1)));
            helpOpen = false;
            keyboardFocus.forceActiveFocus();
            Qt.callLater(applyRequestedView);
        } else {
            helpOpen = false;
            trayMenu.closeMenu();
            networkPanel.closeView();
            bluetoothPanel.closeView();
            themePanel.closeView();
            sessionPanel.closeView();
            resourcesPanel.closeView();
            mixerOpen = false;
        }
    }

    onRequestedViewChanged: Qt.callLater(applyRequestedView)

    function openNetwork(): void {
        helpOpen = false;
        mixerOpen = false;
        resourcesPanel.closeView();
        trayMenu.closeMenu();
        bluetoothPanel.closeView();
        themePanel.closeView();
        sessionPanel.closeView();
        networkPanel.openView();
    }

    function openBluetooth(): void {
        helpOpen = false;
        mixerOpen = false;
        resourcesPanel.closeView();
        trayMenu.closeMenu();
        networkPanel.closeView();
        themePanel.closeView();
        sessionPanel.closeView();
        bluetoothPanel.openView();
    }

    function openTheme(): void {
        helpOpen = false;
        mixerOpen = false;
        resourcesPanel.closeView();
        trayMenu.closeMenu();
        networkPanel.closeView();
        bluetoothPanel.closeView();
        sessionPanel.closeView();
        themePanel.openView();
    }

    function showTheme(): void {
        openTheme();
    }

    function openSession(): void {
        helpOpen = false;
        mixerOpen = false;
        resourcesPanel.closeView();
        trayMenu.closeMenu();
        networkPanel.closeView();
        bluetoothPanel.closeView();
        themePanel.closeView();
        sessionPanel.openView();
    }

    function showSession(): void {
        openSession();
    }

    function openResources(): void {
        helpOpen = false;
        mixerOpen = false;
        trayMenu.closeMenu();
        networkPanel.closeView();
        bluetoothPanel.closeView();
        themePanel.closeView();
        sessionPanel.closeView();
        resourcesPanel.openView();
    }

    function openMixer(): void {
        helpOpen = false;
        trayMenu.closeMenu();
        resourcesPanel.closeView();
        networkPanel.closeView();
        bluetoothPanel.closeView();
        themePanel.closeView();
        sessionPanel.closeView();
        mixerOpen = true;
    }

    function closeMixer(): void {
        mixerOpen = false;
        keyboardFocus.forceActiveFocus();
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

    Item {
        anchors.fill: parent

        Column {
            id: content
            width: parent.width
            visible: !trayMenu.open && !networkPanel.open && !bluetoothPanel.open && !themePanel.open && !sessionPanel.open && !resourcesPanel.open && !root.mixerOpen
            spacing: root.theme.spacing4

            Text {
                text: "System"
                color: root.theme.accent
                font.family: root.runtime.fontMono
                font.pixelSize: root.theme.fontSize(12)
                font.weight: Font.Medium
            }

            Text {
                text: "Control centre"
                color: root.theme.textStrong
                font.family: root.runtime.fontMono
                font.pixelSize: root.theme.fontPanelTitle
                font.weight: Font.DemiBold
            }

            ShellSurface {
                width: parent.width
                height: 98
                theme: root.theme
                motion: root.motion
                surfaceLayer: ShellSurface.Group
                cornerRadius: theme.radiusLarge

                ShellSection {
                    anchors {
                        fill: parent
                        margins: theme.spacing4
                    }
                    runtime: root.runtime
                    theme: root.theme
                    title: root.system.muted ? "Sound · muted" : "Sound  " + root.system.volumePercent + "%"
                    detail: root.system.audioAvailable && root.system.audioSink ? (root.system.audioSink.description || root.system.audioSink.name) : "No output"

                    ShellSlider {
                        width: parent.width
                        theme: root.theme
                        motion: root.motion
                        value: root.system.volume
                        enabled: root.system.audioAvailable
                        accentColor: root.system.muted ? theme.warning : theme.accent
                        trackHeight: 8
                        handleSize: 18
                        onValueRequested: value => root.system.setVolume(value)
                    }
                }
            }

            ShellSurface {
                width: parent.width
                height: 84
                visible: root.brightness.supported
                theme: root.theme
                motion: root.motion
                surfaceLayer: ShellSurface.Group
                cornerRadius: theme.radiusLarge

                ShellSection {
                    anchors {
                        fill: parent
                        margins: theme.spacing4
                    }
                    runtime: root.runtime
                    theme: root.theme
                    title: "Display  " + root.brightness.percent + "%"
                    detail: root.brightness.device

                    ShellSlider {
                        width: parent.width
                        theme: root.theme
                        motion: root.motion
                        value: root.brightness.percent / 100
                        interactive: false
                        accentColor: theme.positive
                        trackHeight: 8
                        handleSize: 0
                    }
                }
            }

            Row {
                width: parent.width
                spacing: root.theme.spacing3

                Repeater {
                    id: controlTiles

                    model: [
                        {
                            id: "network",
                            label: "Network",
                            value: root.system.networkConnected ? root.system.networkName : "Offline",
                            active: root.system.networkConnected
                        },
                        {
                            id: "bluetooth",
                            label: "Bluetooth",
                            value: root.system.bluetoothEnabled ? root.system.bluetoothConnectedCount + " connected" : "Off",
                            active: root.system.bluetoothEnabled
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

                    delegate: ShellAction {
                        required property var modelData

                        width: (content.width - theme.spacing3 * (controlTiles.count - 1)) / controlTiles.count
                        height: 78
                        runtime: root.runtime
                        theme: root.theme
                        motion: root.motion
                        title: modelData.label
                        subtitle: modelData.value
                        active: modelData.active

                        onActivated: {
                            if (modelData.id === "network")
                                root.openNetwork();
                            else if (modelData.id === "bluetooth")
                                root.openBluetooth();
                            else if (modelData.id === "theme")
                                root.openTheme();
                            else if (modelData.id === "session")
                                root.openSession();
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: root.theme.spacing3

                ShellAction {
                    width: (parent.width - parent.spacing) / 2
                    height: 54
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    title: "󰂛  Do not disturb"
                    subtitle: root.notificationState.silent ? "Alerts paused · Q" : "Alerts enabled · Q"
                    active: root.notificationState.silent
                    onActivated: root.notificationState.toggleSilent()
                }

                ShellAction {
                    width: (parent.width - parent.spacing) / 2
                    height: 54
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    title: "󰅶  Stay awake"
                    subtitle: root.system.idleInhibited ? "Idle blocked · I" : "Normal idle · I"
                    active: root.system.idleInhibited
                    onActivated: root.system.toggleIdleInhibited()
                }
            }

            Column {
                width: parent.width
                spacing: root.theme.spacing2
                visible: root.powerProfile.available

                Text {
                    text: "Power profile  ·  O to cycle"
                    color: root.theme.textMuted
                    font.family: root.runtime.fontMono
                    font.pixelSize: root.theme.fontSize(10)
                    font.weight: Font.DemiBold
                }

                Row {
                    id: profileRow
                    width: parent.width
                    spacing: root.theme.spacing3

                    Repeater {
                        model: root.powerProfile.profiles

                        delegate: ShellAction {
                            required property string modelData
                            width: (profileRow.width - (root.powerProfile.profiles.length - 1) * profileRow.spacing) / root.powerProfile.profiles.length
                            height: 52
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            title: root.powerProfile.label(modelData)
                            subtitle: root.powerProfile.current === modelData ? "Selected" : "Select"
                            active: root.powerProfile.current === modelData
                            enabled: !root.powerProfile.applying
                            onActivated: root.powerProfile.setProfile(modelData)
                        }
                    }
                }
            }

            ShellSurface {
                width: parent.width
                height: 170
                visible: root.media.available
                theme: root.theme
                motion: root.motion
                surfaceLayer: ShellSurface.Group
                cornerRadius: theme.radiusLarge

                Column {
                    anchors {
                        fill: parent
                        margins: root.theme.spacing4
                    }
                    spacing: root.theme.spacing3

                    Row {
                        width: parent.width
                        height: 64
                        spacing: root.theme.spacing3

                        ShellSurface {
                            width: 64
                            height: 64
                            theme: root.theme
                            motion: root.motion
                            surfaceLayer: ShellSurface.Control
                            cornerRadius: theme.radiusMedium
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: root.media.artUrl
                                asynchronous: true
                                cache: true
                                fillMode: Image.PreserveAspectCrop
                                visible: root.media.artUrl.length > 0
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: root.media.artUrl.length === 0
                                text: "♫"
                                color: root.theme.accent
                                font.family: root.runtime.fontMono
                                font.pixelSize: root.theme.fontSize(28)
                            }
                        }

                        Column {
                            width: Math.max(1, parent.width - 64 - detailsButton.width - parent.spacing * 2)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: root.theme.spacing1

                            Text {
                                text: root.media.identity || "Now playing"
                                width: parent.width
                                color: root.theme.accent
                                font.family: root.runtime.fontMono
                                font.pixelSize: root.theme.fontSize(10)
                                elide: Text.ElideRight
                            }

                            Text {
                                text: root.media.title
                                width: parent.width
                                color: root.theme.textStrong
                                font.family: root.runtime.fontMono
                                font.pixelSize: root.theme.fontSize(13)
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                text: root.media.artist
                                width: parent.width
                                color: root.theme.textMuted
                                font.family: root.runtime.fontMono
                                font.pixelSize: root.theme.fontSize(10)
                                elide: Text.ElideRight
                            }
                        }

                        ShellAction {
                            id: detailsButton
                            width: 94
                            height: 40
                            anchors.verticalCenter: parent.verticalCenter
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            compact: true
                            title: "V  Detail ↗"
                            onActivated: root.mediaRequested()
                        }
                    }

                    Item {
                        width: parent.width
                        height: 40

                        MediaTransport {
                            anchors.centerIn: parent
                            media: root.media
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            compact: true
                        }
                    }
                }
            }

            ShellAction {
                width: parent.width
                height: 54
                visible: !root.media.available
                runtime: root.runtime
                theme: root.theme
                motion: root.motion
                title: "󰝚  Media & visualiser"
                subtitle: "No player connected · V for detailed view"
                onActivated: root.mediaRequested()
            }

            ShellAction {
                width: parent.width
                height: 54
                runtime: root.runtime
                theme: root.theme
                motion: root.motion
                title: "󰕾  Application audio mixer"
                subtitle: "Individual streams · volume · mute    A ↗"
                onActivated: root.openMixer()
            }

            ShellAction {
                width: parent.width
                height: 54
                runtime: root.runtime
                theme: root.theme
                motion: root.motion
                title: "󰍛  Resource monitor"
                subtitle: "CPU · memory · activity history    G ↗"
                onActivated: root.openResources()
            }

            Column {
                width: parent.width
                visible: root.system.trayCount > 0
                spacing: root.theme.spacing2

                Row {
                    width: parent.width

                    Text {
                        text: "Tray  " + root.system.trayCount
                        color: root.theme.textMuted
                        font.family: root.runtime.fontMono
                        font.pixelSize: root.theme.fontSize(10)
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.2
                    }

                    Item {
                        width: parent.width - parent.children[0].width - trayHint.width
                        height: 1
                    }

                    Text {
                        id: trayHint
                        text: "[ / ] SELECT   ENTER OPEN"
                        color: root.theme.textMuted
                        opacity: 0.62
                        font.family: root.runtime.fontMono
                        font.pixelSize: root.theme.fontSize(8)
                    }
                }

                Row {
                    spacing: root.theme.spacing2

                    Repeater {
                        model: root.system.trayItems

                        delegate: ShellSurface {
                            id: trayItem

                            required property var modelData
                            required property int index

                            width: 72
                            height: 66
                            theme: root.theme
                            motion: root.motion
                            surfaceLayer: ShellSurface.Control
                            selected: index === root.trayIndex
                            cornerRadius: theme.radiusMedium

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton

                                onClicked: mouse => {
                                    root.trayIndex = trayItem.index;

                                    if (mouse.button === Qt.RightButton) {
                                        trayItem.modelData.secondaryActivate();
                                    } else if (trayItem.modelData.hasMenu || trayItem.modelData.onlyMenu) {
                                        trayMenu.openFor(trayItem.modelData);
                                    } else {
                                        trayItem.modelData.activate();
                                    }
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - 10
                                spacing: root.theme.spacing1

                                Image {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 24
                                    height: 24
                                    source: trayItem.modelData.icon.length > 0 ? trayItem.modelData.icon : Quickshell.iconPath("application-x-executable")
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }

                                Text {
                                    width: parent.width
                                    text: trayItem.modelData.title || trayItem.modelData.id
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    color: root.theme.text
                                    font.family: root.runtime.fontMono
                                    font.pixelSize: root.theme.fontSize(8)
                                }
                            }
                        }
                    }
                }
            }

            ShellSurface {
                width: parent.width
                height: 64
                visible: root.system.batteryAvailable
                theme: root.theme
                motion: root.motion
                surfaceLayer: ShellSurface.Group
                cornerRadius: theme.radiusMedium

                Row {
                    anchors {
                        fill: parent
                        leftMargin: root.theme.spacing4
                        rightMargin: root.theme.spacing4
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Battery"
                        color: root.theme.textMuted
                        font.family: root.runtime.fontMono
                        font.pixelSize: root.theme.fontSize(10)
                        font.letterSpacing: 1.2
                    }

                    Item {
                        width: parent.width - parent.children[0].width - batteryValue.width
                        height: 1
                    }

                    Text {
                        id: batteryValue
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.system.batteryPercent + "%"
                        color: root.system.batteryPercent <= 20 ? root.theme.warning : root.theme.textStrong
                        font.family: root.runtime.fontMono
                        font.pixelSize: root.theme.fontSize(13)
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        AudioMixerContent {
            id: mixerView
            anchors.fill: parent
            visible: root.mixerOpen
            active: root.engaged && root.mixerOpen
            system: root.system
            runtime: root.runtime
            theme: root.theme
            motion: root.motion
            onCloseRequested: root.closeMixer()
        }

        ResourceDashboard {
            id: resourcesPanel
            anchors.fill: parent
            runtime: root.runtime
            theme: root.theme
            motion: root.motion
            resourceState: root.resourceState
            onKeyboardRequested: keyboardFocus.forceActiveFocus()
        }

        NetworkPanel {
            id: networkPanel

            anchors.fill: parent

            system: root.system
            runtime: root.runtime
            theme: root.theme
            motion: root.motion

            onKeyboardRequested: keyboardFocus.forceActiveFocus()
        }

        BluetoothPanel {
            id: bluetoothPanel

            anchors.fill: parent

            system: root.system
            runtime: root.runtime
            theme: root.theme
            motion: root.motion

            onKeyboardRequested: keyboardFocus.forceActiveFocus()
        }

        ThemePanel {
            id: themePanel

            anchors.fill: parent

            runtime: root.runtime
            theme: root.theme
            motion: root.motion

            onKeyboardRequested: keyboardFocus.forceActiveFocus()
        }

        SessionPanel {
            id: sessionPanel

            anchors.fill: parent

            runtime: root.runtime
            theme: root.theme
            motion: root.motion

            onKeyboardRequested: keyboardFocus.forceActiveFocus()
        }

        TrayMenuView {
            id: trayMenu

            anchors.fill: parent

            runtime: root.runtime
            theme: root.theme
            motion: root.motion
        }

        Column {
            id: footer

            width: parent.width
            visible: !trayMenu.open && !networkPanel.open && !bluetoothPanel.open && !themePanel.open && !sessionPanel.open && !resourcesPanel.open && !root.mixerOpen

            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            spacing: root.theme.spacing1

            Row {
                anchors.right: parent.right
                spacing: root.theme.spacing4

                Text {
                    text: "←/→  VOLUME"
                    color: root.theme.textMuted
                    font.family: root.runtime.fontMono
                    font.pixelSize: root.theme.fontSize(9)
                    font.letterSpacing: 1
                }

                Text {
                    text: "M  MUTE"
                    color: root.theme.textMuted
                    font.family: root.runtime.fontMono
                    font.pixelSize: root.theme.fontSize(9)
                    font.letterSpacing: 1
                }

                Text {
                    visible: root.brightness.supported
                    text: "↑/↓  BRIGHTNESS"
                    color: root.theme.textMuted
                    font.family: root.runtime.fontMono
                    font.pixelSize: root.theme.fontSize(9)
                    font.letterSpacing: 1
                }

                Text {
                    visible: root.system.trayCount > 0
                    text: "[/]  TRAY   ENTER  OPEN"
                    color: root.theme.textMuted
                    font.family: root.runtime.fontMono
                    font.pixelSize: root.theme.fontSize(9)
                    font.letterSpacing: 1
                }
            }

            Row {
                anchors.right: parent.right
                spacing: root.theme.spacing4

                Text {
                    text: "O  POWER"
                    visible: root.powerProfile.available
                    color: root.theme.accent
                    font.family: root.runtime.fontMono
                    font.pixelSize: root.theme.fontSize(9)
                    font.letterSpacing: 1
                }

                Text {
                    text: "I  AWAKE"
                    color: root.theme.accent
                    font.family: root.runtime.fontMono
                    font.pixelSize: root.theme.fontSize(9)
                    font.letterSpacing: 1
                }

                Text {
                    text: "Q  QUIET"
                    color: root.theme.accent
                    font.family: root.runtime.fontMono
                    font.pixelSize: root.theme.fontSize(9)
                    font.letterSpacing: 1
                }

                Text {
                    text: "N  NETWORK"
                    color: root.theme.accent
                    font.family: root.runtime.fontMono
                    font.pixelSize: root.theme.fontSize(9)
                    font.letterSpacing: 1
                }

                Text {
                    text: "B  BLUETOOTH"
                    color: root.theme.accent
                    font.family: root.runtime.fontMono
                    font.pixelSize: root.theme.fontSize(9)
                    font.letterSpacing: 1
                }
            }

            Row {
                anchors.right: parent.right
                spacing: root.theme.spacing4

                Text {
                    text: "Y  THEME"
                    color: root.theme.accent
                    font.family: root.runtime.fontMono
                    font.pixelSize: root.theme.fontSize(9)
                    font.letterSpacing: 1
                }

                Text {
                    text: "P  SESSION"
                    color: root.theme.accent
                    font.family: root.runtime.fontMono
                    font.pixelSize: root.theme.fontSize(9)
                    font.letterSpacing: 1
                }

                Text {
                    text: "?  HELP"
                    color: root.theme.textMuted
                    font.family: root.runtime.fontMono
                    font.pixelSize: root.theme.fontSize(9)
                    font.letterSpacing: 1

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.helpOpen = true
                    }
                }

                Text {
                    text: "ESC  CLOSE"
                    color: root.theme.textMuted
                    font.family: root.runtime.fontMono
                    font.pixelSize: root.theme.fontSize(9)
                    font.letterSpacing: 1
                }
            }
        }

        FocusScope {
            id: keyboardFocus
            anchors.fill: parent
            focus: root.engaged

            Keys.onPressed: event => {
                const helpKey = event.key === Qt.Key_Question || (event.key === Qt.Key_Slash && (event.modifiers & Qt.ShiftModifier));

                if (root.helpOpen) {
                    if (helpKey || event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
                        root.helpOpen = false;
                        event.accepted = true;
                    }
                    return;
                }

                if (helpKey) {
                    root.helpOpen = true;
                    event.accepted = true;
                    return;
                }

                if (root.mixerOpen)
                    return;

                if (resourcesPanel.open) {
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
                        resourcesPanel.closeView();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_R) {
                        root.resourceState.refresh();
                        event.accepted = true;
                    }
                    return;
                }

                if (bluetoothPanel.open) {
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
                        bluetoothPanel.closeView();
                        event.accepted = true;
                    } else if ((event.key === Qt.Key_Up || event.key === Qt.Key_K)) {
                        bluetoothPanel.moveSelection(-1);
                        event.accepted = true;
                    } else if ((event.key === Qt.Key_Down || event.key === Qt.Key_J)) {
                        bluetoothPanel.moveSelection(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_U || (event.key === Qt.Key_D && !(event.modifiers & Qt.ShiftModifier))) {
                        bluetoothPanel.moveHalfPage(event.key === Qt.Key_U ? -1 : 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        bluetoothPanel.activateSelected();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_B) {
                        bluetoothPanel.toggleBluetooth();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_D && (event.modifiers & Qt.ShiftModifier)) {
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
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                        sessionPanel.moveGrid(0, -1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                        sessionPanel.moveGrid(0, 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                        sessionPanel.moveGrid(-1, 0);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                        sessionPanel.moveGrid(1, 0);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_U || event.key === Qt.Key_D) {
                        sessionPanel.moveHalfPage(event.key === Qt.Key_U ? -1 : 1);
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
                    } else if ((event.key === Qt.Key_Up || event.key === Qt.Key_K)) {
                        themePanel.moveSelection(-1);
                        event.accepted = true;
                    } else if ((event.key === Qt.Key_Down || event.key === Qt.Key_J)) {
                        themePanel.moveSelection(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_U || (event.key === Qt.Key_D && !(event.modifiers & Qt.ShiftModifier))) {
                        themePanel.moveHalfPage(event.key === Qt.Key_U ? -1 : 1);
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
                    } else if ((event.key === Qt.Key_Up || event.key === Qt.Key_K)) {
                        networkPanel.moveSelection(-1);
                        event.accepted = true;
                    } else if ((event.key === Qt.Key_Down || event.key === Qt.Key_J)) {
                        networkPanel.moveSelection(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_U || (event.key === Qt.Key_D && !(event.modifiers & Qt.ShiftModifier))) {
                        networkPanel.moveHalfPage(event.key === Qt.Key_U ? -1 : 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        networkPanel.activateSelected();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_W) {
                        networkPanel.toggleWifi();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_A) {
                        Quickshell.execDetached([root.runtime.networkConnectionEditor]);
                        event.accepted = true;
                    }

                    return;
                }

                if (trayMenu.open) {
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace || (event.key === Qt.Key_Left || event.key === Qt.Key_H)) {
                        trayMenu.goBack();
                        event.accepted = true;
                    } else if ((event.key === Qt.Key_Up || event.key === Qt.Key_K)) {
                        trayMenu.moveSelection(-1);
                        event.accepted = true;
                    } else if ((event.key === Qt.Key_Down || event.key === Qt.Key_J)) {
                        trayMenu.moveSelection(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_U || (event.key === Qt.Key_D && !(event.modifiers & Qt.ShiftModifier))) {
                        trayMenu.moveHalfPage(event.key === Qt.Key_U ? -1 : 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || (event.key === Qt.Key_Right || event.key === Qt.Key_L)) {
                        trayMenu.activateSelected();
                        event.accepted = true;
                    }

                    return;
                }

                if (event.key === Qt.Key_Escape) {
                    root.closeRequested();
                    event.accepted = true;
                } else if ((event.key === Qt.Key_Left || event.key === Qt.Key_H)) {
                    root.system.adjustVolume(-0.05);
                    event.accepted = true;
                } else if ((event.key === Qt.Key_Right || event.key === Qt.Key_L)) {
                    root.system.adjustVolume(0.05);
                    event.accepted = true;
                } else if (event.key === Qt.Key_M) {
                    root.system.toggleMute();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Q) {
                    root.notificationState.toggleSilent();
                    event.accepted = true;
                } else if (event.key === Qt.Key_I) {
                    root.system.toggleIdleInhibited();
                    event.accepted = true;
                } else if (event.key === Qt.Key_O && root.powerProfile.available) {
                    root.powerProfile.cycle();
                    event.accepted = true;
                } else if (event.key === Qt.Key_N) {
                    root.openNetwork();
                    event.accepted = true;
                } else if (event.key === Qt.Key_B) {
                    root.openBluetooth();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Y) {
                    root.openTheme();
                    event.accepted = true;
                } else if (event.key === Qt.Key_P) {
                    root.openSession();
                    event.accepted = true;
                } else if (event.key === Qt.Key_G) {
                    root.openResources();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Space) {
                    root.media.togglePlaying();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Comma) {
                    root.media.previous();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Period) {
                    root.media.next();
                    event.accepted = true;
                } else if (event.key === Qt.Key_V) {
                    root.mediaRequested();
                    event.accepted = true;
                } else if (event.key === Qt.Key_A) {
                    root.openMixer();
                    event.accepted = true;
                } else if ((event.key === Qt.Key_Up || event.key === Qt.Key_K) && root.brightness.supported) {
                    root.brightness.adjust(5);
                    event.accepted = true;
                } else if ((event.key === Qt.Key_Down || event.key === Qt.Key_J) && root.brightness.supported) {
                    root.brightness.adjust(-5);
                    event.accepted = true;
                } else if (event.key === Qt.Key_BracketLeft && root.system.trayCount > 0) {
                    root.trayIndex = (root.trayIndex - 1 + root.system.trayCount) % root.system.trayCount;
                    event.accepted = true;
                } else if (event.key === Qt.Key_BracketRight && root.system.trayCount > 0) {
                    root.trayIndex = (root.trayIndex + 1) % root.system.trayCount;
                    event.accepted = true;
                } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.system.trayCount > 0) {
                    root.activateTrayItem();
                    event.accepted = true;
                }
            }
        }
    }

    WidgetHelp {
        anchors.fill: parent
        runtime: root.runtime
        theme: root.theme
        motion: root.motion
        open: root.helpOpen
        title: root.helpTitle
        bindings: root.helpBindings
        onDismissed: root.helpOpen = false
    }
}

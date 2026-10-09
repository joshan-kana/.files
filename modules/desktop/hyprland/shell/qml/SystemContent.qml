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
    readonly property bool wallpaperOpen: wallpaperPanel.open
    readonly property bool sessionOpen: sessionPanel.open
    readonly property bool resourcesOpen: resourcesPanel.open
    readonly property string helpTitle: wallpaperPanel.open ? "Wallpaper library" : mixerOpen ? "Application mixer" : resourcesPanel.open ? "Resource monitor" : (bluetoothPanel.open ? "Bluetooth controls" : (networkPanel.open ? "Network controls" : (themePanel.open ? "Theme controls" : (sessionPanel.open ? "Session controls" : (trayMenu.open ? "Tray menu controls" : "System controls")))))
    readonly property var helpBindings: wallpaperPanel.open ? [
        {
            key: "H/J/K/L",
            action: "Choose thumbnail"
        },
        {
            key: "U/D",
            action: "Page selection"
        },
        {
            key: "/",
            action: "Search wallpapers"
        },
        {
            key: "ENTER",
            action: "Apply to focused monitor"
        },
        {
            key: "F / R",
            action: "Fit/fill / reset"
        },
        {
            key: "ESC",
            action: "Back to Controls"
        }
    ] : mixerOpen ? [
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
                            key: "M / X",
                            action: "Output mute / microphone mute"
                        },
                        {
                            key: "N / B",
                            action: "Network / Bluetooth"
                        },
                        {
                            key: "Y / P",
                            action: "Theme / session (W wallpapers)"
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
                            key: "Z / SHIFT+Z",
                            action: "Next / previous hub tab"
                        },
                        {
                            key: "/ / [",
                            action: "Next / previous tray app"
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
    implicitHeight: wallpaperPanel.open ? wallpaperPanel.implicitHeight : mixerOpen ? mixerView.implicitHeight : sessionPanel.open ? sessionPanel.implicitHeight : (resourcesPanel.open ? resourcesPanel.implicitHeight : content.implicitHeight + theme.spacing3 + footer.implicitHeight)
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
        else if (requestedView === "wallpaper")
            openWallpaper();
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
            wallpaperPanel.closeView();
            networkPanel.closeView();
            bluetoothPanel.closeView();
            themePanel.closeView();
            sessionPanel.closeView();
            resourcesPanel.closeView();
            mixerOpen = false;
        }
    }

    // Keep the deferred view update tied to this lazy-loaded item's lifetime.
    // Qt.callLater can outlive SystemContent when the hub rapidly changes tabs.
    Timer {
        id: requestedViewTimer
        interval: 0
        repeat: false
        onTriggered: root.applyRequestedView()
    }

    onEngagedChanged: {
        if (engaged) {
            trayIndex = Math.max(0, Math.min(trayIndex, Math.max(0, system.trayCount - 1)));
            helpOpen = false;
            keyboardFocus.forceActiveFocus();
            requestedViewTimer.restart();
        } else {
            helpOpen = false;
            trayMenu.closeMenu();
            wallpaperPanel.closeView();
            networkPanel.closeView();
            bluetoothPanel.closeView();
            themePanel.closeView();
            sessionPanel.closeView();
            resourcesPanel.closeView();
            mixerOpen = false;
        }
    }

    onRequestedViewChanged: requestedViewTimer.restart()

    function openNetwork(): void {
        helpOpen = false;
        mixerOpen = false;
        resourcesPanel.closeView();
        trayMenu.closeMenu();
        wallpaperPanel.closeView();
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
        wallpaperPanel.closeView();
        networkPanel.closeView();
        themePanel.closeView();
        sessionPanel.closeView();
        bluetoothPanel.openView();
    }

    function openWallpaper(): void {
        helpOpen = false;
        mixerOpen = false;
        resourcesPanel.closeView();
        trayMenu.closeMenu();
        networkPanel.closeView();
        bluetoothPanel.closeView();
        themePanel.closeView();
        sessionPanel.closeView();
        wallpaperPanel.openView();
    }

    function openTheme(): void {
        helpOpen = false;
        mixerOpen = false;
        resourcesPanel.closeView();
        trayMenu.closeMenu();
        wallpaperPanel.closeView();
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
        wallpaperPanel.closeView();
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
        wallpaperPanel.closeView();
        networkPanel.closeView();
        bluetoothPanel.closeView();
        themePanel.closeView();
        sessionPanel.closeView();
        resourcesPanel.openView();
    }

    function openMixer(): void {
        helpOpen = false;
        trayMenu.closeMenu();
        wallpaperPanel.closeView();
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
            visible: !trayMenu.open && !networkPanel.open && !bluetoothPanel.open && !themePanel.open && !wallpaperPanel.open && !sessionPanel.open && !resourcesPanel.open && !root.mixerOpen
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
                height: audioStack.implicitHeight + root.theme.spacing4 * 2
                theme: root.theme
                motion: root.motion
                surfaceLayer: ShellSurface.Group
                cornerRadius: theme.radiusLarge

                Column {
                    id: audioStack
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: root.theme.spacing4
                    }
                    spacing: root.theme.spacing3

                    AudioQuickSection {
                        width: audioStack.width
                        system: root.system
                        runtime: root.runtime
                        theme: root.theme
                        motion: root.motion
                    }
                    AudioQuickSection {
                        width: audioStack.width
                        visible: root.system.microphoneAvailable
                        microphone: true
                        system: root.system
                        runtime: root.runtime
                        theme: root.theme
                        motion: root.motion
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
                            shortcut: "N",
                            label: "Network",
                            icon: root.system.wifiConnected ? "󰤨" : "󰈀",
                            value: root.system.networkConnected ? root.system.networkName : "Offline",
                            active: root.system.networkConnected
                        },
                        {
                            id: "bluetooth",
                            shortcut: "B",
                            label: "Bluetooth",
                            icon: root.system.bluetoothEnabled ? "󰂯" : "󰂲",
                            value: root.system.bluetoothEnabled ? root.system.bluetoothConnectedCount + " connected" : "Off",
                            active: root.system.bluetoothEnabled
                        },
                        {
                            id: "theme",
                            shortcut: "Y",
                            label: "Theme",
                            icon: "󰏘",
                            value: "Palette",
                            active: true
                        },
                        {
                            id: "wallpaper",
                            shortcut: "W",
                            label: "Wallpaper",
                            icon: "󰸉",
                            value: "Library",
                            active: true
                        },
                        {
                            id: "session",
                            shortcut: "P",
                            label: "Session",
                            icon: "󰐥",
                            value: "Power",
                            active: true
                        }
                    ]

                    delegate: ShellAction {
                        required property var modelData

                        width: (content.width - theme.spacing3 * (controlTiles.count - 1)) / controlTiles.count
                        height: 84
                        icon: modelData.icon
                        shortcut: modelData.shortcut
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
                            else if (modelData.id === "wallpaper")
                                root.openWallpaper();
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
                    width: (parent.width - parent.spacing * 2) / 3
                    height: 82
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    icon: root.notificationState.silent ? "󰂛" : "󰂚"
                    shortcut: "Q"
                    title: "Do not disturb"
                    subtitle: root.notificationState.silent ? "Alerts paused" : "Alerts enabled"
                    active: root.notificationState.silent
                    onActivated: root.notificationState.toggleSilent()
                }

                ShellAction {
                    width: (parent.width - parent.spacing * 2) / 3
                    height: 82
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    icon: "󰅶"
                    shortcut: "I"
                    title: "Stay awake"
                    subtitle: root.system.idleInhibited ? "Idle blocked" : "Normal idle"
                    active: root.system.idleInhibited
                    onActivated: root.system.toggleIdleInhibited()
                }

                ShellAction {
                    width: (parent.width - parent.spacing * 2) / 3
                    height: 82
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    icon: "󰍛"
                    shortcut: "G"
                    title: "Resources"
                    subtitle: "CPU · Memory"
                    onActivated: root.openResources()
                }
            }

            ShellSurface {
                width: parent.width
                height: 74
                visible: root.system.batteryAvailable || root.powerProfile.available
                theme: root.theme
                motion: root.motion
                surfaceLayer: ShellSurface.Control
                cornerRadius: theme.radiusMedium

                Row {
                    anchors {
                        fill: parent
                        margins: root.theme.spacing3
                    }
                    spacing: root.theme.spacing3

                    ResourceGauge {
                        width: 42
                        height: 42
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.system.batteryAvailable
                        theme: root.theme
                        motion: root.motion
                        compact: true
                        value: root.system.batteryPercent / 100
                        accentColor: root.system.batteryPercent <= 20 ? root.theme.warning : root.theme.accent
                        compactIcon: root.system.batteryPercent <= 20 ? "󰁺" : root.system.batteryPercent < 65 ? "󰁾" : "󰁹"
                    }

                    Column {
                        width: Math.max(1, parent.width - (root.system.batteryAvailable ? 42 + parent.spacing : 0))
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: root.theme.spacing1

                        Text {
                            text: root.system.batteryAvailable ? ("Battery " + root.system.batteryPercent + "%") : "Power profile"
                            color: root.theme.textStrong
                            font.family: root.runtime.fontMono
                            font.pixelSize: root.theme.fontSize(12)
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: root.powerProfile.available ? root.powerProfile.label(root.powerProfile.current) + " · O to cycle" : "Power profile unavailable"
                            color: root.theme.textMuted
                            font.family: root.runtime.fontMono
                            font.pixelSize: root.theme.fontSize(10)
                        }
                    }
                }

                StateLayer {
                    theme: root.theme
                    motion: root.motion
                    cornerRadius: root.theme.radiusMedium
                    disabled: !root.powerProfile.available || root.powerProfile.applying
                    onActivated: root.powerProfile.cycle()
                }
            }

            Column {
                width: parent.width
                spacing: root.theme.spacing2

                Text {
                    visible: root.media.available
                    text: "MEDIA"
                    color: root.theme.textMuted
                    font.family: root.runtime.fontMono
                    font.pixelSize: root.theme.fontSize(10)
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                }

                ShellSurface {
                    width: parent.width
                    height: 120
                    visible: root.media.available
                    theme: root.theme
                    motion: root.motion
                    surfaceLayer: ShellSurface.Group
                    cornerRadius: theme.radiusLarge

                    Column {
                        anchors {
                            fill: parent
                            margins: root.theme.spacing3
                        }
                        spacing: root.theme.spacing2

                        Row {
                            width: parent.width
                            height: 48
                            spacing: root.theme.spacing3

                            ShellSurface {
                                width: 48
                                height: 48
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
                                width: Math.max(1, parent.width - 48 - detailsButton.width - parent.spacing * 2)
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
                        text: "/  NEXT     [  PREVIOUS     ENTER  OPEN"
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

        WallpaperPanel {
            id: wallpaperPanel
            anchors.fill: parent
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

        Row {
            id: footer
            visible: !trayMenu.open && !networkPanel.open && !bluetoothPanel.open && !themePanel.open && !wallpaperPanel.open && !sessionPanel.open && !resourcesPanel.open && !root.mixerOpen
            anchors {
                right: parent.right
                bottom: parent.bottom
            }
            spacing: root.theme.spacing3

            Text {
                text: "H/L  VOLUME     M  SPEAKER     X  MIC"
                color: root.theme.textMuted
                font.family: root.runtime.fontMono
                font.pixelSize: root.theme.fontSize(9)
            }
            Text {
                text: "?  HELP"
                color: root.theme.textMuted
                font.family: root.runtime.fontMono
                font.pixelSize: root.theme.fontSize(9)
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.helpOpen = true
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

                if (wallpaperPanel.open) {
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
                        wallpaperPanel.closeView();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Slash) {
                        wallpaperPanel.enterSearch();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                        wallpaperPanel.moveSelection(-1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                        wallpaperPanel.moveSelection(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                        wallpaperPanel.moveSelection(-3);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                        wallpaperPanel.moveSelection(3);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_U || event.key === Qt.Key_D) {
                        wallpaperPanel.moveSelection(event.key === Qt.Key_U ? -6 : 6);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_F) {
                        wallpaperPanel.toggleFit();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_R) {
                        wallpaperPanel.resetWallpaper();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        wallpaperPanel.applySelected();
                        event.accepted = true;
                    }
                    return;
                }

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
                } else if (event.key === Qt.Key_X) {
                    root.system.toggleMicrophoneMute();
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
                } else if (event.key === Qt.Key_W) {
                    root.openWallpaper();
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
                } else if ((event.key === Qt.Key_Slash || event.key === Qt.Key_BracketRight) && root.system.trayCount > 0) {
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

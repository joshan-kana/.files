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
    required property SpectrumState spectrum
    required property NotificationState notificationState
    required property BrightnessState brightness
    required property NightLightState nightLight
    required property ResourceState resourceState
    required property PowerProfileState powerProfile

    property bool engaged: false
    property bool mixerOpen: false
    property string requestedView: ""
    property bool helpOpen: false
    property int trayIndex: 0
    property int selectedAudioIndex: 0
    readonly property var quickAudioTargets: [
        {
            kind: "output"
        }
    ].concat(system.audioApplicationStreams.slice(0, 2).map(node => ({
                kind: "stream",
                node: node
            }))).concat(system.microphoneAvailable ? [
        {
            kind: "input"
        }
    ] : []).concat(system.audioCaptureStreams.slice(0, 2).map(node => ({
                kind: "stream",
                node: node
            })))
    readonly property int microphoneAudioIndex: 1 + Math.min(2, system.audioApplicationStreams.length)

    readonly property bool trayMenuOpen: trayMenu.open
    readonly property int trayMenuItemCount: trayMenu.itemCount
    readonly property bool networkOpen: networkPanel.open
    readonly property bool bluetoothOpen: bluetoothPanel.open
    readonly property bool themeOpen: themePanel.open
    readonly property bool wallpaperOpen: wallpaperPanel.open
    readonly property bool sessionOpen: sessionPanel.open
    readonly property bool resourcesOpen: resourcesPanel.open
    readonly property bool recordingsOpen: recordingsPanel.open
    readonly property string helpTitle: recordingsPanel.open ? "Recording library" : wallpaperPanel.open ? "Wallpaper library" : mixerOpen ? "Application mixer" : resourcesPanel.open ? "Resource monitor" : (bluetoothPanel.open ? "Bluetooth controls" : (networkPanel.open ? "Network controls" : (themePanel.open ? "Theme controls" : (sessionPanel.open ? "Session controls" : (trayMenu.open ? "Tray menu controls" : "System controls")))))
    readonly property var helpBindings: recordingsPanel.open ? [
        {
            key: "J/K · U/D",
            action: "Select clip / half-page"
        },
        {
            key: "ENTER / O",
            action: "Open selected recording"
        },
        {
            key: "D · ENTER",
            action: "Confirm move to Trash"
        },
        {
            key: "R",
            action: "Refresh saved clips"
        },
        {
            key: "ESC",
            action: "Cancel deletion / back to Controls"
        }
    ] : wallpaperPanel.open ? [
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
                        key: "H/J/K/L · ARROWS",
                        action: "Navigate actions"
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
                            key: "J/K · ↑/↓",
                            action: "Select output, microphone or application"
                        },
                        {
                            key: "H/L · ←/→",
                            action: "Adjust selected audio level"
                        },
                        {
                            key: "M / X",
                            action: "Selected audio mute / microphone mute"
                        },
                        {
                            key: "N/B/Y/W/P/G",
                            action: "Open the labelled tile"
                        },
                        {
                            key: "V / A",
                            action: "Media details / application mixer"
                        },
                        {
                            key: "SPACE / , / .",
                            action: "Play-pause / previous / next media"
                        },
                        {
                            key: "S / SHIFT+R / SHIFT+P",
                            action: "MPRIS shuffle / repeat / choose player"
                        },
                        {
                            key: "Q / I / R",
                            action: "Toggle Notifications / Stay awake / Motion"
                        },
                        {
                            key: "T / SHIFT+T",
                            action: "Night Light / automatic schedule"
                        },
                        {
                            key: "O",
                            action: "Cycle available power profiles"
                        },
                        {
                            key: "[ / ]",
                            action: "Previous / next tray app"
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
    signal themeTerminalActiveChanged(bool active)
    signal mediaRequested
    signal revealContent(real top, real bottom)

    implicitWidth: 710
    implicitHeight: recordingsPanel.open ? recordingsPanel.implicitHeight : wallpaperPanel.open ? wallpaperPanel.implicitHeight : mixerOpen ? mixerView.implicitHeight : sessionPanel.open ? sessionPanel.implicitHeight : resourcesPanel.open ? resourcesPanel.implicitHeight : networkPanel.open ? networkPanel.implicitHeight : bluetoothPanel.open ? bluetoothPanel.implicitHeight : themePanel.open ? themePanel.implicitHeight : content.implicitHeight
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
        else if (requestedView === "recordings")
            openRecordings();
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
            recordingsPanel.closeView();
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
            nightLight.refresh();
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
            recordingsPanel.closeView();
            mixerOpen = false;
        }
    }

    onRequestedViewChanged: requestedViewTimer.restart()

    function openNetwork(): void {
        helpOpen = false;
        recordingsPanel.closeView();
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
        recordingsPanel.closeView();
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
        recordingsPanel.closeView();
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
        recordingsPanel.closeView();
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
        recordingsPanel.closeView();
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
        recordingsPanel.closeView();
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
        recordingsPanel.closeView();
        trayMenu.closeMenu();
        wallpaperPanel.closeView();
        resourcesPanel.closeView();
        networkPanel.closeView();
        bluetoothPanel.closeView();
        themePanel.closeView();
        sessionPanel.closeView();
        mixerOpen = true;
    }

    function openRecordings(): void {
        helpOpen = false;
        mixerOpen = false;
        trayMenu.closeMenu();
        wallpaperPanel.closeView();
        resourcesPanel.closeView();
        networkPanel.closeView();
        bluetoothPanel.closeView();
        themePanel.closeView();
        sessionPanel.closeView();
        recordingsPanel.openView();
    }

    function closeMixer(): void {
        mixerOpen = false;
        keyboardFocus.forceActiveFocus();
    }

    function moveAudioSelection(direction: int): void {
        selectedAudioIndex = (selectedAudioIndex + direction + quickAudioTargets.length) % quickAudioTargets.length;
    }

    function adjustSelectedAudio(delta: real): void {
        const target = quickAudioTargets[Math.min(selectedAudioIndex, quickAudioTargets.length - 1)];
        if (target.kind === "output")
            system.adjustVolume(delta);
        else if (target.kind === "input")
            system.setMicrophoneVolume(system.microphoneVolume + delta);
        else
            system.adjustStreamVolume(target.node, delta);
    }

    function toggleSelectedAudioDeviceChooser(): void {
        const target = quickAudioTargets[Math.min(selectedAudioIndex, quickAudioTargets.length - 1)];
        if (target.kind === "output")
            outputQuick.toggleDeviceChooser();
        else if (target.kind === "input")
            inputQuick.toggleDeviceChooser();
    }

    function muteSelectedAudio(): void {
        const target = quickAudioTargets[Math.min(selectedAudioIndex, quickAudioTargets.length - 1)];
        if (target.kind === "output")
            system.toggleMute();
        else if (target.kind === "input")
            system.toggleMicrophoneMute();
        else
            system.toggleStreamMute(target.node);
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
            visible: !trayMenu.open && !networkPanel.open && !bluetoothPanel.open && !themePanel.open && !wallpaperPanel.open && !sessionPanel.open && !resourcesPanel.open && !root.mixerOpen && !recordingsPanel.open
            spacing: root.theme.spacing2

            Row {
                id: controlsHeading
                width: parent.width
                height: 40
                spacing: root.theme.spacing2

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Control centre"
                    color: root.theme.textStrong
                    font.family: root.runtime.fontMono
                    font.pixelSize: root.theme.fontSize(23)
                    font.weight: Font.DemiBold
                }

                Item {
                    width: Math.max(1, controlsHeading.width - controlsHeading.children[0].implicitWidth - appearanceButton.width - wallpaperButton.width - sessionButton.width - helpButton.width - controlsHeading.spacing * 5)
                    height: 1
                }

                ShellAction {
                    id: appearanceButton
                    anchors.verticalCenter: parent.verticalCenter
                    width: 102
                    height: 36
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    compact: true
                    horizontalCompact: true
                    icon: "󰏘"
                    title: "Themes"
                    shortcut: "Y"
                    onActivated: root.openTheme()
                }
                ShellAction {
                    id: wallpaperButton
                    anchors.verticalCenter: parent.verticalCenter
                    width: 123
                    height: 36
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    compact: true
                    horizontalCompact: true
                    icon: "󰸉"
                    title: "Wallpaper"
                    shortcut: "W"
                    onActivated: root.openWallpaper()
                }
                ShellAction {
                    id: sessionButton
                    anchors.verticalCenter: parent.verticalCenter
                    width: 105
                    height: 36
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    compact: true
                    horizontalCompact: true
                    icon: "󰐥"
                    title: "Session"
                    shortcut: "P"
                    onActivated: root.openSession()
                }

                ShellAction {
                    id: helpButton
                    width: 33
                    height: 36
                    anchors.verticalCenter: parent.verticalCenter
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    iconOnly: true
                    icon: "󰋗"
                    title: "Help (?)"
                    onActivated: root.helpOpen = true
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

            Text {
                text: "SYSTEM · QUICK SETTINGS"
                color: root.theme.accent
                font.family: root.runtime.fontMono
                font.pixelSize: root.theme.fontPanelEyebrow
                font.weight: Font.DemiBold
                font.letterSpacing: 1.4
            }

            ShellSurface {
                width: parent.width
                height: 80
                theme: root.theme
                motion: root.motion
                surfaceLayer: ShellSurface.Group
                cornerRadius: root.theme.radiusLarge

                Row {
                    anchors.fill: parent
                    anchors.margins: root.theme.spacing3
                    spacing: root.theme.spacing2

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(130, parent.width - nightToggle.width - nightAuto.width - nightWarmer.width - nightCooler.width - parent.spacing * 4)
                        spacing: 4
                        Text {
                            text: "Night light"
                            color: root.theme.textStrong
                            font.family: root.runtime.fontMono
                            font.pixelSize: root.theme.fontSize(15)
                            font.weight: Font.DemiBold
                        }
                        Text {
                            width: parent.width
                            text: root.nightLight.error.length > 0 ? root.nightLight.error : root.nightLight.detail
                            color: root.nightLight.error.length > 0 ? root.theme.warning : root.theme.textMuted
                            font.family: root.runtime.fontMono
                            font.pixelSize: root.theme.fontSize(10)
                            elide: Text.ElideRight
                        }
                    }
                    QuickSettingChip {
                        id: nightToggle
                        anchors.verticalCenter: parent.verticalCenter
                        width: 100
                        height: 54
                        runtime: root.runtime
                        theme: root.theme
                        motion: root.motion
                        title: root.nightLight.active ? "Warm" : "Off"
                        icon: root.nightLight.active ? "󰖔" : "󰖙"
                        shortcut: "T"
                        active: root.nightLight.active
                        activeColor: root.theme.warning
                        enabled: root.nightLight.supported && !root.nightLight.busy
                        onActivated: root.nightLight.toggle()
                    }
                    QuickSettingChip {
                        id: nightAuto
                        anchors.verticalCenter: parent.verticalCenter
                        width: 97
                        height: 54
                        runtime: root.runtime
                        theme: root.theme
                        motion: root.motion
                        title: "Auto"
                        icon: root.nightLight.automatic ? "󰃰" : "󰃯"
                        shortcut: "⇧T"
                        active: root.nightLight.automatic
                        enabled: root.nightLight.supported && !root.nightLight.busy
                        onActivated: root.nightLight.toggleAuto()
                    }
                    ShellAction {
                        id: nightWarmer
                        anchors.verticalCenter: parent.verticalCenter
                        width: 48
                        height: 48
                        runtime: root.runtime
                        theme: root.theme
                        motion: root.motion
                        compact: true
                        title: "−500"
                        icon: "󰖔"
                        enabled: root.nightLight.supported && !root.nightLight.busy && root.nightLight.temperature > 2500
                        onActivated: root.nightLight.warmer()
                    }
                    ShellAction {
                        id: nightCooler
                        anchors.verticalCenter: parent.verticalCenter
                        width: 48
                        height: 48
                        runtime: root.runtime
                        theme: root.theme
                        motion: root.motion
                        compact: true
                        title: "+500"
                        icon: "󰖙"
                        enabled: root.nightLight.supported && !root.nightLight.busy && root.nightLight.temperature < 6500
                        onActivated: root.nightLight.cooler()
                    }
                }
            }

            Grid {
                id: connectionTiles
                width: parent.width
                columns: width < 560 || root.theme.textScale >= 1.5 ? 1 : 2
                columnSpacing: root.theme.spacing3
                rowSpacing: root.theme.spacing3
                readonly property real cellWidth: (width - columnSpacing * (columns - 1)) / columns

                ConnectivityTile {
                    width: connectionTiles.cellWidth
                    height: 84
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    title: "Network"
                    detail: root.system.networkConnected ? root.system.networkName : "No connection"
                    status: root.system.networkConnected ? (root.system.wifiConnected ? "WI-FI · CONNECTED" : "ETHERNET · CONNECTED") : "OFFLINE"
                    glyph: root.system.wifiConnected ? "󰤨" : "󰈀"
                    shortcut: "N"
                    connected: root.system.networkConnected
                    onActivated: root.openNetwork()
                }

                ConnectivityTile {
                    width: connectionTiles.cellWidth
                    height: 84
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    title: "Bluetooth"
                    detail: root.system.bluetoothEnabled ? root.system.bluetoothConnectedCount + " connected devices" : "Radio disabled"
                    status: root.system.bluetoothEnabled ? "ADAPTER ON" : "RADIO OFF"
                    glyph: root.system.bluetoothEnabled ? "󰂯" : "󰂲"
                    shortcut: "B"
                    connected: root.system.bluetoothEnabled
                    onActivated: root.openBluetooth()
                }
            }

            Row {
                width: parent.width
                spacing: root.theme.spacing2

                Text {
                    text: "QUICK ACTIONS"
                    color: root.theme.textMuted
                    font.family: root.runtime.fontMono
                    font.pixelSize: root.theme.fontPanelEyebrow
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.1
                }
            }

            Grid {
                id: actionStrip
                width: parent.width
                columns: width < 600 || root.theme.textScale >= 1.5 ? 3 : 5
                columnSpacing: root.theme.spacing2
                rowSpacing: root.theme.spacing2
                readonly property real cellWidth: (width - columnSpacing * (columns - 1)) / columns

                QuickSettingChip {
                    width: actionStrip.cellWidth
                    height: 64
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    icon: root.notificationState.silent ? "󰂛" : "󰂚"
                    title: root.notificationState.silent ? "Alerts paused" : "Alerts"
                    shortcut: "Q"
                    active: root.notificationState.silent
                    activeColor: root.theme.warning
                    onActivated: root.notificationState.toggleSilent()
                }

                QuickSettingChip {
                    width: actionStrip.cellWidth
                    height: 64
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    icon: "󰅶"
                    title: root.system.idleInhibited ? "Stay awake" : "Idle allowed"
                    shortcut: "I"
                    active: root.system.idleInhibited
                    onActivated: root.system.toggleIdleInhibited()
                }

                QuickSettingChip {
                    width: actionStrip.cellWidth
                    height: 64
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    icon: root.motion.enabled ? "󰔎" : "󰾅"
                    title: root.motion.enabled ? "Animations" : "Motion off"
                    shortcut: "R"
                    active: !root.motion.enabled
                    onActivated: root.motion.toggle()
                }

                QuickSettingChip {
                    width: actionStrip.cellWidth
                    height: 64
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    icon: "󰍛"
                    title: "Resources"
                    shortcut: "G"
                    onActivated: root.openResources()
                }

                QuickSettingChip {
                    width: actionStrip.cellWidth
                    height: 64
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    icon: root.system.batteryAvailable ? (root.system.batteryPercent <= 20 ? "󰁺" : "󰁹") : "󰐥"
                    title: root.system.batteryAvailable ? "Battery " + root.system.batteryPercent + "%" : root.powerProfile.available ? root.powerProfile.label(root.powerProfile.current) : "Power"
                    shortcut: "O"
                    enabled: root.powerProfile.available && !root.powerProfile.applying
                    active: root.powerProfile.current === "power-saver"
                    activeColor: root.theme.warning
                    onActivated: root.powerProfile.cycle()
                }
            }

            ShellSurface {
                width: parent.width
                height: audioStack.implicitHeight + root.theme.spacing3 * 2
                theme: root.theme
                motion: root.motion
                surfaceLayer: ShellSurface.Group
                cornerRadius: theme.radiusLarge
                luminous: true
                luminousColor: root.theme.accent
                fillColor: root.theme.blend(root.theme.groupBase, root.theme.accent, root.theme.dark ? 0.07 : 0.035)

                Column {
                    id: audioStack
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: root.theme.spacing3
                    }
                    spacing: root.theme.spacing1

                    AudioQuickSection {
                        id: outputQuick
                        width: audioStack.width
                        showMixer: true
                        inline: true
                        meterEnabled: root.visible && !root.mixerOpen
                        onChooserOpenChanged: {
                            if (chooserOpen)
                                inputQuick.chooserOpen = false;
                        }
                        baseIndex: 0
                        selectedAudioIndex: root.selectedAudioIndex
                        onSelectionRequested: index => root.selectedAudioIndex = index
                        onMixerRequested: root.openMixer()
                        system: root.system
                        runtime: root.runtime
                        theme: root.theme
                        motion: root.motion
                    }
                    AudioQuickSection {
                        id: inputQuick
                        width: audioStack.width
                        onChooserOpenChanged: {
                            if (chooserOpen)
                                outputQuick.chooserOpen = false;
                        }
                        visible: root.system.microphoneAvailable
                        microphone: true
                        inline: true
                        meterEnabled: root.visible && !root.mixerOpen
                        baseIndex: root.microphoneAudioIndex
                        selectedAudioIndex: root.selectedAudioIndex
                        onSelectionRequested: index => root.selectedAudioIndex = index
                        system: root.system
                        runtime: root.runtime
                        theme: root.theme
                        motion: root.motion
                    }
                }
            }

            Text {
                visible: false
                width: parent.width
                text: "J/K  SELECT AUDIO     H/L  LEVEL     M  MUTE     X  MIC"
                horizontalAlignment: Text.AlignRight
                color: root.theme.textMuted
                font.family: root.runtime.fontMono
                font.pixelSize: root.theme.fontSize(11)
            }

            Column {
                width: parent.width
                spacing: root.theme.spacing2

                Row {
                    width: parent.width
                    height: 30
                    spacing: root.theme.spacing3
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(1, parent.width - recordingsButton.width - parent.spacing)
                        text: root.media.available ? "MEDIA  ·  ⬆H/L SEEK" : "NOW PLAYING  ·  NO ACTIVE PLAYER"
                        color: root.theme.textMuted
                        font.family: root.runtime.fontMono
                        font.pixelSize: root.theme.fontSize(10)
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                        elide: Text.ElideRight
                    }
                    ShellAction {
                        id: recordingsButton
                        anchors.verticalCenter: parent.verticalCenter
                        width: 152
                        height: 30
                        runtime: root.runtime
                        theme: root.theme
                        motion: root.motion
                        compact: true
                        horizontalCompact: true
                        icon: "󰕧"
                        title: "RECORDINGS"
                        shortcut: "C"
                        onActivated: root.openRecordings()
                    }
                }

                ShellSurface {
                    width: parent.width
                    height: root.media.available ? 204 : 156
                    visible: true
                    theme: root.theme
                    motion: root.motion
                    surfaceLayer: ShellSurface.Group
                    cornerRadius: theme.radiusLarge
                    luminous: true
                    lightIntensity: 1.25
                    luminousColor: root.theme.accent
                    fillColor: root.theme.blend(root.theme.groupBase, root.theme.accent, root.theme.dark ? 0.095 : 0.05)

                    StateLayer {
                        theme: root.theme
                        motion: root.motion
                        cornerRadius: root.theme.radiusLarge
                        Accessible.role: Accessible.Button
                        Accessible.name: "Open full media player"
                        onActivated: root.mediaRequested()
                    }

                    Text {
                        anchors {
                            top: parent.top
                            right: parent.right
                            margins: root.theme.spacing3
                        }
                        z: 1
                        text: "V"
                        visible: root.media.available
                        color: root.theme.textMuted
                        font.family: root.runtime.fontMono
                        font.pixelSize: root.theme.fontSize(11)
                    }

                    Column {
                        anchors {
                            fill: parent
                            margins: root.theme.spacing3
                        }
                        spacing: root.theme.spacing2

                        Row {
                            width: parent.width
                            height: 60
                            spacing: root.theme.spacing3

                            ShellSurface {
                                width: 60
                                height: 60
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
                                width: Math.max(1, parent.width - 60 - (root.media.available ? mediaInlineTransport.width + mediaQuickExtras.width : 0) - parent.spacing * (root.media.available ? 3 : 1) - root.theme.spacing2)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: root.theme.spacing1

                                Text {
                                    text: root.media.available ? (root.media.identity || "Now playing") : "Open Now Playing  ↗"
                                    width: parent.width
                                    color: root.theme.accent
                                    font.family: root.runtime.fontMono
                                    font.pixelSize: root.theme.fontSize(10)
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: root.media.available ? root.media.title : "No active media player"
                                    width: parent.width
                                    color: root.theme.textStrong
                                    font.family: root.runtime.fontMono
                                    font.pixelSize: root.theme.fontSize(16)
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: root.media.artist
                                    visible: root.media.available
                                    width: parent.width
                                    color: root.theme.textMuted
                                    font.family: root.runtime.fontMono
                                    font.pixelSize: root.theme.fontSize(10)
                                    elide: Text.ElideRight
                                }
                            }

                            MediaTransport {
                                id: mediaInlineTransport
                                anchors.verticalCenter: parent.verticalCenter
                                visible: root.media.available
                                width: root.media.available ? implicitWidth : 0
                                media: root.media
                                runtime: root.runtime
                                theme: root.theme
                                motion: root.motion
                                compact: true
                                minimal: true
                            }

                            Row {
                                id: mediaQuickExtras
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: root.theme.spacing1
                                visible: root.media.available
                                width: root.media.available ? implicitWidth : 0

                                ShellAction {
                                    width: 70
                                    height: 36
                                    runtime: root.runtime
                                    theme: root.theme
                                    motion: root.motion
                                    compact: true
                                    horizontalCompact: true
                                    icon: "󰒝"
                                    title: root.media.shuffled ? "ON" : "OFF"
                                    shortcut: "S"
                                    active: root.media.shuffled
                                    enabled: root.media.shuffleAvailable
                                    onActivated: root.media.toggleShuffle()
                                }
                                ShellAction {
                                    width: 84
                                    height: 36
                                    runtime: root.runtime
                                    theme: root.theme
                                    motion: root.motion
                                    compact: true
                                    horizontalCompact: true
                                    icon: root.media.repeatState === 1 ? "󰑘" : "󰑖"
                                    title: root.media.repeatLabel
                                    shortcut: "⇧R"
                                    active: root.media.repeatState !== 0
                                    enabled: root.media.repeatAvailable
                                    onActivated: root.media.toggleRepeat()
                                }
                                ShellAction {
                                    width: 70
                                    height: 36
                                    runtime: root.runtime
                                    theme: root.theme
                                    motion: root.motion
                                    compact: true
                                    horizontalCompact: true
                                    icon: "󰎄"
                                    title: String(Math.max(1, root.media.selectedPlayerIndex + 1))
                                    shortcut: "⇧P"
                                    active: root.media.playerCount > 1
                                    enabled: root.media.playerCount > 1
                                    onActivated: root.media.cyclePlayer()
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: root.media.available ? 94 : 60
                            visible: true

                            SpectrumScale {
                                id: compactFrequency
                                lowHz: root.spectrum.lowHz
                                highHz: root.spectrum.highHz
                            }

                            Row {
                                visible: !root.media.available && !root.spectrum.hasEnergy
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    bottom: parent.bottom
                                }
                                height: 3
                                spacing: 4

                                Repeater {
                                    model: 36
                                    delegate: Rectangle {
                                        required property int index
                                        width: Math.max(2, (parent.width - 35 * 4) / 36)
                                        height: 3
                                        radius: 2
                                        color: root.theme.accent
                                        opacity: 0.34
                                    }
                                }
                            }

                            SpectrumBars {
                                anchors.fill: parent
                                spectrum: root.spectrum
                                theme: root.theme
                                frequencyScale: compactFrequency
                                barCount: 36
                            }
                        }
                    }
                }
            }

            Row {
                width: parent.width
                height: 37
                visible: root.system.trayCount > 0
                spacing: root.theme.spacing2

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "TRAY  " + root.system.trayCount
                    color: root.theme.textMuted
                    font.family: root.runtime.fontMono
                    font.pixelSize: root.theme.fontPanelEyebrow
                    font.weight: Font.DemiBold
                }

                Repeater {
                    model: root.system.trayItems

                    delegate: ShellSurface {
                        id: trayItem
                        required property var modelData
                        required property int index

                        width: 98
                        height: 36
                        theme: root.theme
                        motion: root.motion
                        surfaceLayer: ShellSurface.Control
                        selected: index === root.trayIndex
                        cornerRadius: theme.radiusSmall

                        Row {
                            anchors {
                                fill: parent
                                margins: root.theme.spacing2
                            }
                            spacing: root.theme.spacing1

                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 19
                                height: 19
                                source: trayItem.modelData.icon.length > 0 ? trayItem.modelData.icon : Quickshell.iconPath("application-x-executable")
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(1, parent.width - 19 - parent.spacing)
                                text: trayItem.modelData.title || trayItem.modelData.id
                                elide: Text.ElideRight
                                color: root.theme.text
                                font.family: root.runtime.fontMono
                                font.pixelSize: root.theme.fontSize(10)
                            }
                        }
                        StateLayer {
                            theme: root.theme
                            motion: root.motion
                            selected: trayItem.index === root.trayIndex
                            cornerRadius: root.theme.radiusSmall
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onActivated: event => {
                                root.trayIndex = trayItem.index;
                                if (event.button === Qt.RightButton)
                                    trayItem.modelData.secondaryActivate();
                                else if (trayItem.modelData.hasMenu || trayItem.modelData.onlyMenu)
                                    trayMenu.openFor(trayItem.modelData);
                                else
                                    trayItem.modelData.activate();
                            }
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "[]  PREV / NEXT · ENTER OPEN"
                    color: root.theme.textMuted
                    font.family: root.runtime.fontMono
                    font.pixelSize: root.theme.fontSize(9)
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

        RecordingLibrary {
            id: recordingsPanel
            anchors.fill: parent
            runtime: root.runtime
            theme: root.theme
            motion: root.motion
            onKeyboardRequested: keyboardFocus.forceActiveFocus()
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
            onSwitchLaunched: root.themeTerminalActiveChanged(true)
            onSwitchFinished: root.themeTerminalActiveChanged(false)
        }

        SessionPanel {
            id: sessionPanel

            anchors.fill: parent

            runtime: root.runtime
            theme: root.theme
            motion: root.motion

            onKeyboardRequested: keyboardFocus.forceActiveFocus()
            onRevealSelection: (top, bottom) => root.revealContent(top, bottom)
        }

        TrayMenuView {
            id: trayMenu

            anchors.fill: parent

            runtime: root.runtime
            theme: root.theme
            motion: root.motion
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

                if (outputQuick.chooserOpen || inputQuick.chooserOpen) {
                    const picker = outputQuick.chooserOpen ? outputQuick : inputQuick;
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace || event.key === Qt.Key_D)
                        picker.chooserOpen = false;
                    else if (event.key === Qt.Key_J || event.key === Qt.Key_Down)
                        picker.moveDeviceSelection(1);
                    else if (event.key === Qt.Key_K || event.key === Qt.Key_Up)
                        picker.moveDeviceSelection(-1);
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                        picker.selectDevice(picker.chooserIndex);
                    else
                        return;
                    event.accepted = true;
                    return;
                }

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

                if (recordingsPanel.open) {
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
                        if (recordingsPanel.deletePending.length > 0)
                            recordingsPanel.cancelDelete();
                        else
                            recordingsPanel.closeView();
                    } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
                        recordingsPanel.moveSelection(1);
                    } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
                        recordingsPanel.moveSelection(-1);
                    } else if (event.key === Qt.Key_U) {
                        recordingsPanel.moveSelection(-4);
                    } else if (event.key === Qt.Key_D && (event.modifiers & Qt.ShiftModifier)) {
                        recordingsPanel.moveSelection(4);
                    } else if (event.key === Qt.Key_D) {
                        recordingsPanel.requestDelete();
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_O) {
                        recordingsPanel.openSelected();
                    } else if (event.key === Qt.Key_R) {
                        recordingsPanel.refresh();
                    } else {
                        return;
                    }
                    event.accepted = true;
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
                        themePanel.moveGrid(0, -1);
                        event.accepted = true;
                    } else if ((event.key === Qt.Key_Down || event.key === Qt.Key_J)) {
                        themePanel.moveGrid(0, 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
                        themePanel.moveGrid(-1, 0);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
                        themePanel.moveGrid(1, 0);
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
                        if (networkPanel.detailView)
                            networkPanel.toggleDetailView();
                        else
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
                    } else if (event.key === Qt.Key_I) {
                        networkPanel.toggleDetailView();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_R && networkPanel.detailView) {
                        networkPanel.refreshDetails();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_P && !networkPanel.detailView) {
                        networkPanel.toggleSavedView();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_R && networkPanel.savedView && !networkPanel.detailView) {
                        networkPanel.refreshSaved();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_W && !networkPanel.savedView) {
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
                } else if (event.key === Qt.Key_H && (event.modifiers & Qt.ShiftModifier)) {
                    root.media.seek(-5);
                    event.accepted = true;
                } else if (event.key === Qt.Key_L && (event.modifiers & Qt.ShiftModifier)) {
                    root.media.seek(5);
                    event.accepted = true;
                } else if ((event.key === Qt.Key_Left || event.key === Qt.Key_H)) {
                    root.adjustSelectedAudio(-0.05);
                    event.accepted = true;
                } else if ((event.key === Qt.Key_Right || event.key === Qt.Key_L)) {
                    root.adjustSelectedAudio(0.05);
                    event.accepted = true;
                } else if (event.key === Qt.Key_M) {
                    root.muteSelectedAudio();
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
                } else if (event.key === Qt.Key_R && (event.modifiers & Qt.ShiftModifier)) {
                    root.media.toggleRepeat();
                    event.accepted = true;
                } else if (event.key === Qt.Key_R) {
                    root.motion.toggle();
                    event.accepted = true;
                } else if (event.key === Qt.Key_T) {
                    if ((event.modifiers & Qt.ShiftModifier) !== 0)
                        root.nightLight.toggleAuto();
                    else
                        root.nightLight.toggle();
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
                } else if (event.key === Qt.Key_P && (event.modifiers & Qt.ShiftModifier)) {
                    root.media.cyclePlayer();
                    event.accepted = true;
                } else if (event.key === Qt.Key_P) {
                    root.openSession();
                    event.accepted = true;
                } else if (event.key === Qt.Key_C) {
                    root.openRecordings();
                    event.accepted = true;
                } else if (event.key === Qt.Key_G) {
                    root.openResources();
                    event.accepted = true;
                } else if (event.key === Qt.Key_S) {
                    root.media.toggleShuffle();
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
                } else if (event.key === Qt.Key_D) {
                    root.toggleSelectedAudioDeviceChooser();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                    root.moveAudioSelection(-1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    root.moveAudioSelection(1);
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
}

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
    required property bool wallpaperSpectrumEnabled
    required property bool musicReactiveEnabled
    required property bool barVisible
    required property bool windowTransparencyEnabled
    required property bool shellGlassEnabled

    signal wallpaperSpectrumToggleRequested
    signal musicReactiveToggleRequested
    signal barToggleRequested
    signal windowTransparencyToggleRequested
    signal shellGlassToggleRequested

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
    readonly property bool themeOperationRunning: themePanel.open && themePanel.operationRunning
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
            action: "Apply to selected output"
        },
        {
            key: "M",
            action: "Choose monitor / all outputs"
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
            key: "C",
            action: "Switch between sampled resource history and per-core CPU activity"
        },
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
                            key: "SHIFT+H/L",
                            action: "Seek media backward / forward five seconds"
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
                            key: "SHIFT+G/N/B/O/F",
                            action: "Wallpaper spectrum / Reactive shell / Bar / Window transparency / Frosted glass"
                        },
                        {
                            key: "T / - (⇧T) / +",
                            action: "Night Light / warmer / cooler"
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

    signal helpScrollRequested(int steps)
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

    function prewarmDetails(): void {
        // Stage heavy views after the three primary tabs are ready. No timers
        // and no duplicate state: each Loader retains its constructed item.
        mixerView.prewarm();
        recordingsPanel.prewarm();
        resourcesPanel.prewarm();
        networkPanel.prewarm();
        bluetoothPanel.prewarm();
        wallpaperPanel.prewarm();
        themePanel.prewarm();
        sessionPanel.prewarm();
        trayMenu.prewarm();
    }

    onMixerOpenChanged: {
        if (mixerOpen)
            mixerView.finishLoading();
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

    function selectedMixerStream(): var {
        return mixerOpen && mixerView.panel ? mixerView.panel.selectedStream() : null;
    }
    function adjustMixerStream(delta: real): void {
        if (mixerOpen && mixerView.panel)
            mixerView.panel.adjustSelected(delta);
    }
    function toggleMixerMute(): void {
        if (mixerOpen && mixerView.panel)
            mixerView.panel.toggleSelectedMute();
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

                readonly property real entryWidth: Math.max(1, (width - helpButton.width - spacing * 3) / 3)

                ShellAction {
                    id: appearanceButton
                    headerEntry: true
                    anchors.verticalCenter: parent.verticalCenter
                    width: controlsHeading.entryWidth
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
                    headerEntry: true
                    anchors.verticalCenter: parent.verticalCenter
                    width: controlsHeading.entryWidth
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
                    headerEntry: true
                    anchors.verticalCenter: parent.verticalCenter
                    width: controlsHeading.entryWidth
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

            Grid {
                id: connectionTiles
                x: root.theme.spacing2
                width: Math.max(1, parent.width - root.theme.spacing2 * 2)
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
                    detail: root.system.networkConnected ? root.system.networkName : root.system.networkDevices.length === 0 ? "No network interface" : "No connection"
                    status: failed ? "CONNECTION FAILED" : pending ? networkPanel.pendingNetwork ? "AUTHENTICATION REQUIRED" : "UPDATING CONNECTION" : root.system.networkConnected ? (root.system.wifiConnected ? "WI-FI · CONNECTED" : "ETHERNET · CONNECTED") : unavailable ? "UNAVAILABLE" : "OFFLINE"
                    glyph: root.system.wifiConnected ? "󰤨" : root.system.networkConnected ? "󰈀" : "󰤭"
                    shortcut: "N"
                    connected: root.system.networkConnected
                    pending: networkPanel.open && (networkPanel.profileActionRunning || networkPanel.pendingNetwork !== null)
                    failed: networkPanel.open && networkPanel.statusError
                    unavailable: root.system.networkDevices.length === 0
                    onActivated: root.openNetwork()
                }

                ConnectivityTile {
                    width: connectionTiles.cellWidth
                    height: 84
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    title: "Bluetooth"
                    detail: unavailable ? "No Bluetooth adapter" : root.system.bluetoothEnabled ? root.system.bluetoothConnectedCount + " connected devices" : "Radio disabled"
                    status: failed ? "ACTION FAILED" : scanning ? "SCANNING FOR DEVICES" : pending ? "PAIRING DEVICE" : unavailable ? "UNAVAILABLE" : root.system.bluetoothEnabled ? "ADAPTER ON" : "RADIO OFF"
                    glyph: root.system.bluetoothEnabled ? "󰂯" : "󰂲"
                    shortcut: "B"
                    connected: root.system.bluetoothEnabled
                    scanning: root.system.bluetoothDiscovering
                    pending: root.system.bluetoothDevices.some(device => device && device.pairing)
                    failed: bluetoothPanel.open && bluetoothPanel.statusError
                    unavailable: !root.system.bluetoothAvailable
                    onActivated: root.openBluetooth()
                }
            }

            Row {
                width: parent.width
                height: 36

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "QUICK ACTIONS"
                    color: root.theme.readableRoleColor("attention")
                    font.family: root.runtime.fontMono
                    font.pixelSize: root.theme.fontPanelEyebrow
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.1
                }
            }

            Item {
                width: 1
                height: root.theme.spacing1
            }

            Flow {
                id: actionStrip
                x: root.theme.spacing2
                width: Math.max(1, parent.width - root.theme.spacing2 * 2)
                spacing: root.theme.spacing2
                readonly property int columns: width < 520 || root.theme.textScale >= 1.5 ? 2 : width < 680 || root.theme.textScale >= 1.3 ? 3 : 5

                function cellWidth(index: int): real {
                    const itemsInRow = Math.min(columns, 5 - Math.floor(index / columns) * columns);
                    return (width - spacing * (itemsInRow - 1)) / itemsInRow;
                }

                QuickSettingChip {
                    width: actionStrip.cellWidth(0)
                    height: 78
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    icon: root.notificationState.silent ? "󰂛" : "󰂚"
                    title: root.notificationState.silent ? "Silent" : "Alerts"
                    shortcut: "Q"
                    active: root.notificationState.silent
                    activeColor: root.notificationState.silent ? root.theme.roleColor("warning") : root.theme.roleColor("attention")
                    onActivated: root.notificationState.toggleSilent()
                }

                QuickSettingChip {
                    width: actionStrip.cellWidth(1)
                    height: 78
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    icon: "󰅶"
                    title: root.system.idleInhibited ? "Stay awake" : "Idle allowed"
                    shortcut: "I"
                    active: root.system.idleInhibited
                    activeColor: root.theme.roleColor("warmth")
                    onActivated: root.system.toggleIdleInhibited()
                }

                QuickSettingChip {
                    width: actionStrip.cellWidth(2)
                    height: 78
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    icon: "󰍛"
                    title: "Resources"
                    shortcut: "G"
                    activeColor: root.theme.roleColor("resources")
                    onActivated: root.openResources()
                }

                QuickSettingChip {
                    width: actionStrip.cellWidth(3)
                    height: 78
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    icon: root.system.batteryAvailable ? (root.system.batteryPercent <= 20 ? "󰁺" : "󰁹") : "󰐥"
                    title: (root.powerProfile.available ? root.powerProfile.label(root.powerProfile.current) : "Power") + (root.system.batteryAvailable ? " " + root.system.batteryPercent + "%" : "")
                    shortcut: "O"
                    enabled: root.powerProfile.available && !root.powerProfile.applying
                    active: root.powerProfile.current === "power-saver"
                    activeColor: root.powerProfile.current === "power-saver" ? root.theme.roleColor("warning") : root.theme.roleColor("positive")
                    onActivated: root.powerProfile.cycle()
                }

                QuickSettingChip {
                    width: actionStrip.cellWidth(4)
                    height: 78
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    icon: "󰕧"
                    title: "Recordings"
                    shortcut: "C"
                    activeColor: root.theme.roleColor("capture")
                    onActivated: root.openRecordings()
                }
            }

            Row {
                width: parent.width
                height: 36

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "VISUAL MODES"
                    color: root.theme.readableRoleColor("display")
                    font.family: root.runtime.fontMono
                    font.pixelSize: root.theme.fontPanelEyebrow
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.1
                }
            }

            Item {
                width: 1
                height: root.theme.spacing1
            }

            Flow {
                id: visualModeStrip
                x: root.theme.spacing2
                width: Math.max(1, parent.width - root.theme.spacing2 * 2)
                spacing: root.theme.spacing2
                readonly property int columns: width < 340 || root.theme.textScale >= 1.5 ? 1 : width < 560 ? 2 : 4

                function cellWidth(index: int): real {
                    const itemsInRow = Math.min(columns, 7 - Math.floor(index / columns) * columns);
                    return (width - spacing * (itemsInRow - 1)) / itemsInRow;
                }

                QuickSettingChip {
                    width: visualModeStrip.cellWidth(0)
                    height: 78
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    icon: "󰸉"
                    title: root.wallpaperSpectrumEnabled ? "Wallpaper spectrum" : "Spectrum off"
                    shortcut: "SHIFT+G"
                    active: root.wallpaperSpectrumEnabled
                    activeColor: root.theme.roleColor("workspace")
                    onActivated: root.wallpaperSpectrumToggleRequested()
                }

                QuickSettingChip {
                    width: visualModeStrip.cellWidth(1)
                    height: 78
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    icon: "♫"
                    title: root.musicReactiveEnabled ? "Audio reactive" : "Reactive off"
                    shortcut: "SHIFT+N"
                    active: root.musicReactiveEnabled
                    activeColor: root.theme.roleColor("audio")
                    onActivated: root.musicReactiveToggleRequested()
                }

                QuickSettingChip {
                    width: visualModeStrip.cellWidth(2)
                    height: 78
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    icon: "󰍹"
                    title: root.windowTransparencyEnabled ? "Windows translucent" : "Windows solid"
                    shortcut: "SHIFT+O"
                    active: root.windowTransparencyEnabled
                    activeColor: root.theme.roleColor("display")
                    onActivated: root.windowTransparencyToggleRequested()
                }

                QuickSettingChip {
                    width: visualModeStrip.cellWidth(3)
                    height: 78
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    icon: "󰊠"
                    title: root.shellGlassEnabled ? "Frosted glass" : "Glass off"
                    shortcut: "SHIFT+F"
                    active: root.shellGlassEnabled
                    activeColor: root.theme.roleColor("connectivity")
                    onActivated: root.shellGlassToggleRequested()
                }

                QuickSettingChip {
                    width: visualModeStrip.cellWidth(4)
                    height: 78
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    icon: "󰀻"
                    title: root.barVisible ? "Bar visible" : "Bar hidden"
                    shortcut: "SHIFT+B"
                    active: !root.barVisible
                    activeColor: root.theme.roleColor("positive")
                    onActivated: root.barToggleRequested()
                }
                QuickSettingChip {
                    width: visualModeStrip.cellWidth(5)
                    height: 78
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    icon: root.motion.enabled ? "󰔎" : "󰾅"
                    title: root.motion.enabled ? "Animations" : "Motion off"
                    shortcut: "R"
                    active: !root.motion.enabled
                    activeColor: root.theme.roleColor("warning")
                    onActivated: root.motion.toggle()
                }

                AdjustableSetting {
                    width: visualModeStrip.cellWidth(6)
                    height: 78
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    icon: root.nightLight.active ? "󰖔" : "󰖙"
                    label: "Night Light"
                    valueText: root.nightLight.supported ? root.nightLight.temperature + " K" : "Unavailable"
                    toggleShortcut: "T"
                    decrementShortcut: "-"
                    incrementShortcut: "+"
                    roleAccent: root.theme.roleColor("warmth")
                    active: root.nightLight.active
                    canToggle: root.nightLight.supported && !root.nightLight.busy
                    canDecrease: root.nightLight.supported && !root.nightLight.busy && root.nightLight.temperature > 2500
                    canIncrease: root.nightLight.supported && !root.nightLight.busy && root.nightLight.temperature < 6500
                    onToggleRequested: root.nightLight.toggle()
                    onDecreaseRequested: root.nightLight.warmer()
                    onIncreaseRequested: root.nightLight.cooler()
                }
            }

            ShellSurface {
                width: parent.width
                height: audioStack.implicitHeight + root.theme.spacing3 * 2
                theme: root.theme
                motion: root.motion
                surfaceLayer: ShellSurface.Group
                cornerRadius: theme.radiusLarge
                fillColor: root.theme.groupBase

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

            KeyHintStrip {
                width: parent.width
                runtime: root.runtime
                theme: root.theme
                hints: [
                    {
                        shortcut: "J/K",
                        label: "Select audio"
                    },
                    {
                        shortcut: "H/L",
                        label: "Level"
                    },
                    {
                        shortcut: "M",
                        label: "Mute"
                    },
                    {
                        shortcut: "X",
                        label: "Mic"
                    }
                ]
            }

            Column {
                width: parent.width
                spacing: root.theme.spacing2

                Text {
                    width: parent.width
                    height: 30
                    verticalAlignment: Text.AlignVCenter
                    text: root.media.available ? "MEDIA" : "MEDIA  ·  NO ACTIVE PLAYER"
                    color: root.theme.readableRoleColor("media")
                    font.family: root.runtime.fontMono
                    font.pixelSize: root.theme.fontSize(10)
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                }

                ShellSurface {
                    width: parent.width
                    height: root.media.available ? 250 : 0
                    visible: root.media.available
                    theme: root.theme
                    motion: root.motion
                    surfaceLayer: ShellSurface.Group
                    cornerRadius: theme.radiusLarge
                    luminous: true
                    lightIntensity: 1.25
                    luminousColor: root.theme.roleColor("media")
                    fillColor: root.theme.blend(root.theme.groupBase, root.theme.roleColor("media"), root.theme.dark ? 0.045 : 0.025)

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
                                width: Math.max(1, parent.width - 60 - parent.spacing - root.theme.spacing2)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: root.theme.spacing1

                                MarqueeText {
                                    text: root.media.available ? (root.media.identity || "Now playing") : "Open Now Playing  ↗"
                                    width: parent.width
                                    color: root.theme.accent
                                    font.family: root.runtime.fontMono
                                    font.pixelSize: root.theme.fontSize(10)
                                }

                                MarqueeText {
                                    text: root.media.available ? root.media.title : "No active media player"
                                    width: parent.width
                                    color: root.theme.textStrong
                                    font.family: root.runtime.fontMono
                                    font.pixelSize: root.theme.fontSize(16)
                                    font.weight: Font.DemiBold
                                }

                                MarqueeText {
                                    text: root.media.artist
                                    visible: root.media.available
                                    width: parent.width
                                    color: root.theme.textMuted
                                    font.family: root.runtime.fontMono
                                    font.pixelSize: root.theme.fontSize(10)
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            height: 38
                            spacing: root.theme.spacing3
                            visible: root.media.available
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

                KeyHintStrip {
                    width: 225
                    anchors.verticalCenter: parent.verticalCenter
                    runtime: root.runtime
                    theme: root.theme
                    hints: [
                        {
                            shortcut: "[ / ]",
                            label: "Tray"
                        },
                        {
                            shortcut: "ENTER",
                            label: "Open"
                        }
                    ]
                }
            }
        }

        DeferredDetail {
            id: mixerView
            anchors.fill: parent
            visible: root.mixerOpen
            sourceComponent: Component {
                AudioMixerContent {
                    active: root.engaged && root.mixerOpen
                    system: root.system
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    onCloseRequested: root.closeMixer()
                }
            }
        }

        DeferredDetail {
            id: recordingsPanel
            anchors.fill: parent
            sourceComponent: Component {
                RecordingLibrary {
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    onKeyboardRequested: keyboardFocus.forceActiveFocus()
                }
            }
        }

        DeferredDetail {
            id: resourcesPanel
            anchors.fill: parent
            sourceComponent: Component {
                ResourceDashboard {
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    resourceState: root.resourceState
                    onKeyboardRequested: keyboardFocus.forceActiveFocus()
                }
            }
        }

        DeferredDetail {
            id: networkPanel
            anchors.fill: parent
            sourceComponent: Component {
                NetworkPanel {
                    system: root.system
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    onKeyboardRequested: keyboardFocus.forceActiveFocus()
                }
            }
        }

        DeferredDetail {
            id: bluetoothPanel
            anchors.fill: parent
            sourceComponent: Component {
                BluetoothPanel {
                    system: root.system
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    onKeyboardRequested: keyboardFocus.forceActiveFocus()
                }
            }
        }

        DeferredDetail {
            id: wallpaperPanel
            anchors.fill: parent
            sourceComponent: Component {
                WallpaperPanel {
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    onKeyboardRequested: keyboardFocus.forceActiveFocus()
                }
            }
        }

        DeferredDetail {
            id: themePanel
            anchors.fill: parent
            sourceComponent: Component {
                ThemePanel {
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    onKeyboardRequested: keyboardFocus.forceActiveFocus()
                    onSwitchLaunched: root.themeTerminalActiveChanged(true)
                    onSwitchFinished: root.themeTerminalActiveChanged(false)
                }
            }
        }

        DeferredDetail {
            id: sessionPanel
            anchors.fill: parent
            sourceComponent: Component {
                SessionPanel {
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    onKeyboardRequested: keyboardFocus.forceActiveFocus()
                    onRevealSelection: (top, bottom) => root.revealContent(top, bottom)
                }
            }
        }

        DeferredDetail {
            id: trayMenu
            anchors.fill: parent
            sourceComponent: Component {
                TrayMenuView {
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
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
                    } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
                        root.helpScrollRequested(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
                        root.helpScrollRequested(-1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_D || event.key === Qt.Key_PageDown) {
                        root.helpScrollRequested(4);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_U || event.key === Qt.Key_PageUp) {
                        root.helpScrollRequested(-4);
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
                        wallpaperPanel.invoke("enterSearch");
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                        wallpaperPanel.invoke("moveSelection", -1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                        wallpaperPanel.invoke("moveSelection", 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                        wallpaperPanel.invoke("moveGrid", 0, -1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                        wallpaperPanel.invoke("moveGrid", 0, 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_U || event.key === Qt.Key_D) {
                        wallpaperPanel.invoke("moveHalfPage", event.key === Qt.Key_U ? -1 : 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_M) {
                        wallpaperPanel.invoke("cycleOutput");
                        event.accepted = true;
                    } else if (event.key === Qt.Key_F) {
                        wallpaperPanel.invoke("toggleFit");
                        event.accepted = true;
                    } else if (event.key === Qt.Key_R) {
                        wallpaperPanel.invoke("resetWallpaper");
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        wallpaperPanel.invoke("applySelected");
                        event.accepted = true;
                    }
                    return;
                }

                if (recordingsPanel.open) {
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
                        if (recordingsPanel.deletePending.length > 0)
                            recordingsPanel.invoke("cancelDelete");
                        else
                            recordingsPanel.closeView();
                    } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
                        recordingsPanel.invoke("moveSelection", 1);
                    } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
                        recordingsPanel.invoke("moveSelection", -1);
                    } else if (event.key === Qt.Key_U) {
                        recordingsPanel.invoke("moveSelection", -4);
                    } else if (event.key === Qt.Key_D && (event.modifiers & Qt.ShiftModifier)) {
                        recordingsPanel.invoke("moveSelection", 4);
                    } else if (event.key === Qt.Key_D) {
                        recordingsPanel.invoke("requestDelete");
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_O) {
                        recordingsPanel.invoke("openSelected");
                    } else if (event.key === Qt.Key_R) {
                        recordingsPanel.invoke("refresh");
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
                    } else if (event.key === Qt.Key_C) {
                        resourcesPanel.invoke("toggleCoreView");
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
                        bluetoothPanel.invoke("moveSelection", -1);
                        event.accepted = true;
                    } else if ((event.key === Qt.Key_Down || event.key === Qt.Key_J)) {
                        bluetoothPanel.invoke("moveSelection", 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_U || (event.key === Qt.Key_D && !(event.modifiers & Qt.ShiftModifier))) {
                        bluetoothPanel.invoke("moveHalfPage", event.key === Qt.Key_U ? -1 : 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        bluetoothPanel.invoke("activateSelected");
                        event.accepted = true;
                    } else if (event.key === Qt.Key_B) {
                        bluetoothPanel.invoke("toggleBluetooth");
                        event.accepted = true;
                    } else if (event.key === Qt.Key_D && (event.modifiers & Qt.ShiftModifier)) {
                        bluetoothPanel.invoke("toggleDiscovery");
                        event.accepted = true;
                    } else if (event.key === Qt.Key_P) {
                        bluetoothPanel.invoke("pairSelected");
                        event.accepted = true;
                    } else if (event.key === Qt.Key_T) {
                        bluetoothPanel.invoke("toggleTrust");
                        event.accepted = true;
                    } else if (event.key === Qt.Key_F) {
                        bluetoothPanel.invoke("forgetSelected");
                        event.accepted = true;
                    }

                    return;
                }

                if (sessionPanel.open) {
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
                        sessionPanel.closeView();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                        sessionPanel.invoke("moveGrid", 0, -1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                        sessionPanel.invoke("moveGrid", 0, 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                        sessionPanel.invoke("moveGrid", -1, 0);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                        sessionPanel.invoke("moveGrid", 1, 0);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        sessionPanel.invoke("activateSelected");
                        event.accepted = true;
                    }

                    return;
                }

                if (themePanel.open) {
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
                        themePanel.closeView();
                        event.accepted = true;
                    } else if ((event.key === Qt.Key_Up || event.key === Qt.Key_K)) {
                        themePanel.invoke("moveGrid", 0, -1);
                        event.accepted = true;
                    } else if ((event.key === Qt.Key_Down || event.key === Qt.Key_J)) {
                        themePanel.invoke("moveGrid", 0, 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
                        themePanel.invoke("moveGrid", -1, 0);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
                        themePanel.invoke("moveGrid", 1, 0);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_U || (event.key === Qt.Key_D && !(event.modifiers & Qt.ShiftModifier))) {
                        themePanel.invoke("moveHalfPage", event.key === Qt.Key_U ? -1 : 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_X && themePanel.operationRunning) {
                        themePanel.invoke("cancelOperation");
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        themePanel.invoke("activateSelected");
                        event.accepted = true;
                    }

                    return;
                }

                if (networkPanel.open) {
                    if (networkPanel.passwordPrompt)
                        return;

                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
                        if (networkPanel.detailView)
                            networkPanel.invoke("toggleDetailView");
                        else
                            networkPanel.closeView();
                        event.accepted = true;
                    } else if ((event.key === Qt.Key_Up || event.key === Qt.Key_K)) {
                        networkPanel.invoke("moveSelection", -1);
                        event.accepted = true;
                    } else if ((event.key === Qt.Key_Down || event.key === Qt.Key_J)) {
                        networkPanel.invoke("moveSelection", 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_U || (event.key === Qt.Key_D && !(event.modifiers & Qt.ShiftModifier))) {
                        networkPanel.invoke("moveHalfPage", event.key === Qt.Key_U ? -1 : 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        networkPanel.invoke("activateSelected");
                        event.accepted = true;
                    } else if (event.key === Qt.Key_I) {
                        networkPanel.invoke("toggleDetailView");
                        event.accepted = true;
                    } else if (event.key === Qt.Key_R && networkPanel.detailView) {
                        networkPanel.invoke("refreshDetails");
                        event.accepted = true;
                    } else if (event.key === Qt.Key_P && !networkPanel.detailView) {
                        networkPanel.invoke("toggleSavedView");
                        event.accepted = true;
                    } else if (event.key === Qt.Key_R && networkPanel.savedView && !networkPanel.detailView) {
                        networkPanel.invoke("refreshSaved");
                        event.accepted = true;
                    } else if (event.key === Qt.Key_W && !networkPanel.savedView) {
                        networkPanel.invoke("toggleWifi");
                        event.accepted = true;
                    } else if (event.key === Qt.Key_A) {
                        Quickshell.execDetached([root.runtime.networkConnectionEditor]);
                        event.accepted = true;
                    }

                    return;
                }

                if (trayMenu.open) {
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace || (event.key === Qt.Key_Left || event.key === Qt.Key_H)) {
                        trayMenu.invoke("goBack");
                        event.accepted = true;
                    } else if ((event.key === Qt.Key_Up || event.key === Qt.Key_K)) {
                        trayMenu.invoke("moveSelection", -1);
                        event.accepted = true;
                    } else if ((event.key === Qt.Key_Down || event.key === Qt.Key_J)) {
                        trayMenu.invoke("moveSelection", 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_U || (event.key === Qt.Key_D && !(event.modifiers & Qt.ShiftModifier))) {
                        trayMenu.invoke("moveHalfPage", event.key === Qt.Key_U ? -1 : 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || (event.key === Qt.Key_Right || event.key === Qt.Key_L)) {
                        trayMenu.invoke("activateSelected");
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
                } else if (event.key === Qt.Key_T && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                    if (event.modifiers & Qt.ShiftModifier)
                        root.nightLight.warmer();
                    else
                        root.nightLight.toggle();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Minus && event.modifiers === Qt.NoModifier) {
                    root.nightLight.warmer();
                    event.accepted = true;
                } else if ((event.key === Qt.Key_Plus || (event.key === Qt.Key_Equal && (event.modifiers & Qt.ShiftModifier))) && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                    root.nightLight.cooler();
                    event.accepted = true;
                } else if (event.key === Qt.Key_F && (event.modifiers & Qt.ShiftModifier)) {
                    root.shellGlassToggleRequested();
                    event.accepted = true;
                } else if (event.key === Qt.Key_O && (event.modifiers & Qt.ShiftModifier)) {
                    root.windowTransparencyToggleRequested();
                    event.accepted = true;
                } else if (event.key === Qt.Key_O && root.powerProfile.available) {
                    root.powerProfile.cycle();
                    event.accepted = true;
                } else if (event.key === Qt.Key_N && (event.modifiers & Qt.ShiftModifier)) {
                    root.musicReactiveToggleRequested();
                    event.accepted = true;
                } else if (event.key === Qt.Key_B && (event.modifiers & Qt.ShiftModifier)) {
                    root.barToggleRequested();
                    event.accepted = true;
                } else if (event.key === Qt.Key_G && (event.modifiers & Qt.ShiftModifier)) {
                    root.wallpaperSpectrumToggleRequested();
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

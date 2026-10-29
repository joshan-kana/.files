//@ pragma ShellId linux-desktop
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property RuntimeConfig runtimeRef: runtime
    readonly property Theme themeRef: theme
    readonly property Motion motionRef: motion
    readonly property MediaState mediaRef: media
    readonly property SpectrumState spectrumRef: spectrum
    readonly property SystemState systemRef: system
    readonly property ResourceState resourcesRef: resources
    readonly property PowerProfileState powerProfileRef: powerProfile
    readonly property BrightnessState brightnessRef: brightness
    readonly property NightLightState nightLightRef: nightLight
    readonly property WeatherState weatherRef: weather
    readonly property NotificationState notificationsRef: notifications

    readonly property bool wallpaperSpectrumEnabled: appearance.wallpaperSpectrumEnabled
    readonly property bool musicReactiveEnabled: appearance.musicReactiveEnabled

    function toggleBar(): void {
        appearance.toggleBar();
    }

    AppearancePreferences {
        id: appearance
        runtime: runtime
        expansionGlassExposed: expansionState.hasCurrent || expansionHost.closing
        modalGlassExposed: modalHost.contentVisible
        notificationGlassExposed: notifications.popupVisible || notificationPopup.closing
        osdGlassExposed: osd.visible || osdPopup.closing
    }

    RuntimeConfig {
        id: runtime
    }

    Theme {
        id: theme
        runtime: runtime
        musicReactiveEnabled: root.musicReactiveEnabled
        shellGlassEnabled: appearance.shellGlassEnabled
        musicReactiveEnergy: reactive.sustain
        musicReactiveBeat: reactive.beatPulse
        musicReactiveTreble: reactive.treble
    }

    Motion {
        id: motion
        runtime: runtime
    }

    ScreenRouter {
        id: screens
    }

    PolkitDialog {
        runtime: root.runtimeRef
        theme: root.themeRef
        motion: root.motionRef
        screens: screens
    }

    WeatherState {
        id: weather
        runtime: runtime
    }

    ShellExpansionState {
        id: expansionState
    }

    // Retain the outgoing view until the host finishes its closing morph.
    // Otherwise nested details reset mid-animation and redraw as Controls.
    Component {
        id: mediaExpansionComponent

        MediaContent {
            appearance: appearance
            media: root.mediaRef
            spectrum: root.spectrumRef
            runtime: root.runtimeRef
            theme: root.themeRef
            motion: root.motionRef
            engaged: expansionState.currentName === "media"
            returnToControls: expansionState.backDestination === "controls"
            onCloseRequested: expansionState.back()
        }
    }

    Component {
        id: calendarExpansionComponent

        CalendarContent {
            runtime: root.runtimeRef
            theme: root.themeRef
            motion: root.motionRef
            weather: root.weatherRef
            engaged: expansionState.currentName === "calendar"
            onForecastRequested: actions.toggleWeather()
            onCloseRequested: expansionState.close()
        }
    }

    Component {
        id: weatherExpansionComponent

        WeatherContent {
            runtime: root.runtimeRef
            theme: root.themeRef
            motion: root.motionRef
            weather: root.weatherRef
            engaged: expansionState.currentName === "weather"
            onCalendarRequested: actions.toggleCalendar(expansionState.screen)
            onCloseRequested: expansionState.back()
        }
    }

    Component {
        id: systemExpansionComponent

        SystemContent {
            runtime: root.runtimeRef
            theme: root.themeRef
            motion: root.motionRef
            system: root.systemRef
            media: root.mediaRef
            spectrum: root.spectrumRef
            notificationState: root.notificationsRef
            brightness: root.brightnessRef
            nightLight: root.nightLightRef
            resourceState: root.resourcesRef
            powerProfile: root.powerProfileRef
            wallpaperSpectrumEnabled: root.wallpaperSpectrumEnabled
            musicReactiveEnabled: root.musicReactiveEnabled
            barVisible: appearance.barVisible
            windowTransparencyEnabled: appearance.windowTransparencyEnabled
            shellGlassEnabled: appearance.shellGlassEnabled
            engaged: expansionState.currentName === "system"
            onWallpaperSpectrumToggleRequested: appearance.toggleWallpaperSpectrum()
            onMusicReactiveToggleRequested: appearance.toggleMusicReactive()
            onBarToggleRequested: appearance.toggleBar()
            onWindowTransparencyToggleRequested: appearance.toggleWindowTransparency()
            onShellGlassToggleRequested: appearance.toggleShellGlass()
            requestedView: expansionState.currentView
            returnToControls: expansionState.backDestination === "controls"
            onBackRequested: expansionState.back()
            onDetailRequested: view => expansionState.enterDetail(view)
            onCloseRequested: expansionState.close()
            onMediaRequested: actions.toggleMedia()
        }
    }

    Component {
        id: activityExpansionComponent

        NotificationContent {
            notificationState: root.notificationsRef
            runtime: root.runtimeRef
            theme: root.themeRef
            motion: root.motionRef
            engaged: expansionState.currentName === "activity"
            onCloseRequested: expansionState.close()
        }
    }

    ShellExpansionHost {
        id: expansionHost
        runtime: runtime
        theme: theme
        motion: motion
        expansionState: expansionState
        barWindows: ambientBar.instances
        mediaComponent: mediaExpansionComponent
        systemComponent: systemExpansionComponent
        calendarComponent: calendarExpansionComponent
        weatherComponent: weatherExpansionComponent
        activityComponent: activityExpansionComponent
    }

    MediaState {
        id: media
    }

    SystemState {
        id: system
    }

    PowerProfileState {
        id: powerProfile
        runtime: root.runtimeRef
        active: true
    }

    ResourceState {
        id: resources
        runtime: runtime
        active: expansionState.hasCurrent && expansionState.currentName === "system" && expansionHost.systemContent !== null && expansionHost.systemContent.resourcesOpen
    }

    BrightnessState {
        id: brightness
        runtime: runtime
    }

    NightLightState {
        id: nightLight
        runtime: runtime
    }

    OsdState {
        id: osd
        system: system
        brightness: brightness
        runtime: runtime
    }

    NotificationState {
        id: notifications
        runtime: runtime
    }

    RecordingState {
        id: recording
    }

    SpectrumState {
        id: spectrum
        // No DSP client unless a visible spectrum consumer needs live audio.
        active: (media.playing && (ambientBar.shown || (expansionState.hasCurrent && expansionState.currentName === "system"))) || (expansionState.hasCurrent && expansionState.currentName === "media") || (motion.enabled && (root.wallpaperSpectrumEnabled || root.musicReactiveEnabled))
    }

    MusicReactiveState {
        id: reactive
        spectrum: root.spectrumRef
        enabled: root.musicReactiveEnabled && motion.enabled
    }

    WallpaperSpectrum {
        id: wallpaperSpectrum
        spectrum: root.spectrumRef
        theme: root.themeRef
        motion: root.motionRef
        enabled: root.wallpaperSpectrumEnabled
    }

    AmbientBar {
        id: ambientBar
        shown: appearance.barVisible
        runtime: runtime
        theme: theme
        motion: motion
        media: media
        spectrum: spectrum
        system: system
        powerProfile: powerProfile
        notificationState: notifications
        recordingState: recording
        onRecordingStopRequested: actions.toggleRecording()
        onMediaRequested: (screen, origin) => actions.toggleMedia(screen, origin)
        onSystemRequested: (screen, origin) => actions.toggleSystem(screen, origin)
        onTrayMenuRequested: (screen, origin, index) => actions.showSystem(screen, origin, "tray:" + index)
        onCalendarRequested: (screen, origin) => actions.toggleCalendar(screen, origin)
        onNotificationsRequested: (screen, origin) => actions.toggleNotifications(screen, origin)
    }

    ModalSurfaceHost {
        id: modalHost
        screens: screens
        clipboardPanel: clipboardPanel
        launcher: launcher
        overviewPanel: overviewPanel
        cheatsheet: cheatsheet
    }

    // Capture needs a full display, unlike the compact persistent modal. Map
    // its own correctly sized layer only for selection, never resize the modal.
    PanelWindow {
        id: captureHost
        readonly property bool open: screenshotPicker.open
        property bool geometryStable: false
        function checkGeometry(): void {
            geometryStable = width >= implicitWidth - 1 && height >= implicitHeight - 1;
        }
        onWidthChanged: checkGeometry()
        onHeightChanged: checkGeometry()
        onScreenChanged: checkGeometry()
        Component.onCompleted: checkGeometry()
        screen: screenshotPicker.captureScreen || screens.focusedScreen || Quickshell.screens[0]
        visible: open
        implicitWidth: screen ? screen.width : 2560
        implicitHeight: screen ? screen.height : 1440
        color: "transparent"
        focusable: open
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            left: true
        }
        WlrLayershell.namespace: "linux-desktop-capture"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: focusable ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        PopupFocusGrab {
            popup: captureHost
            onDismissed: screenshotPicker.dismiss(true)
        }
    }

    // A single-pixel noninteractive Top layer triggers compositor dimming
    // behind modals. The shared popup stays at Overlay level, so it retains
    // its full brightness and stable backing viewport.
    PanelWindow {
        screen: modalHost.screen
        visible: modalHost.dimActive
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        focusable: false
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            left: true
        }
        WlrLayershell.namespace: "linux-desktop-modal-dim"
        WlrLayershell.layer: WlrLayer.Top
        mask: Region {
            item: dimInputMask
        }

        Item {
            id: dimInputMask
            width: 0
            height: 0
            visible: false
        }
    }

    ShortcutCheatsheet {
        id: cheatsheet
        parent: modalHost.contentItem
        screen: screens.focusedScreen
        runtime: runtime
        theme: theme
        motion: motion
    }

    ClipboardPanel {
        id: clipboardPanel
        parent: modalHost.contentItem
        screen: screens.focusedScreen
        runtime: runtime
        theme: theme
        motion: motion
    }

    ScreenshotPicker {
        id: screenshotPicker
        parent: captureHost.contentItem
        surfaceReady: captureHost.geometryStable
        runtime: runtime
        theme: theme
        motion: motion
        onSnapshotReady: actions.hideTransient("")
    }

    OverviewPanel {
        id: overviewPanel
        parent: modalHost.contentItem
        screen: screens.focusedScreen
        runtime: runtime
        theme: theme
        motion: motion
    }

    ResizeOverlay {
        id: resizeOverlay
        screen: screens.focusedScreen
        runtime: runtime
        theme: theme
        motion: motion
    }

    NotificationPopup {
        id: notificationPopup
        screen: screens.focusedScreen
        notificationState: notifications
        runtime: runtime
        theme: theme
        motion: motion
        onCenterRequested: actions.showNotifications()
    }

    OsdPopup {
        id: osdPopup
        screen: screens.focusedScreen
        osd: osd
        runtime: runtime
        theme: theme
        motion: motion
    }

    CommandPalette {
        id: launcher
        parent: modalHost.contentItem
        clipboardPanel: clipboardPanel
        screen: screens.focusedScreen
        runtime: runtime
        theme: theme
        motion: motion
        audioAvailable: system.audioAvailable
        brightnessAvailable: brightness.supported
        commands: [
            {
                id: "media.wallpaperSpectrum",
                name: root.wallpaperSpectrumEnabled ? "Disable Wallpaper Spectrum" : "Enable Wallpaper Spectrum",
                description: "Show the live audio spectrum over the wallpaper",
                icon: "audio-x-generic",
                keywords: ["spectrum", "wallpaper", "music", "visualiser", "audio", "reactive"]
            },
            {
                id: "media.reactiveShell",
                name: root.musicReactiveEnabled ? "Disable Music-reactive Shell" : "Enable Music-reactive Shell",
                description: "Light up shell surfaces using live music frequencies",
                icon: "audio-x-generic",
                keywords: ["reactive", "visual", "music", "effects", "audio", "shell"]
            },
            {
                id: "overview.toggle",
                name: "Workspaces & Window Overview",
                description: "Browse live window previews and switch workspaces",
                icon: "view-grid",
                keywords: ["overview", "mission control", "windows", "workspaces", "switch", "preview"]
            },
            {
                id: "clipboard.toggle",
                name: "Clipboard History",
                description: "Search and restore clipboard entries",
                icon: "edit-paste",
                keywords: ["copy", "paste", "cliphist"]
            },
            {
                id: "nightLight.toggle",
                name: "Toggle Night Light",
                description: "Warm the display using Hyprland colour temperature",
                icon: "weather-clear-night",
                keywords: ["night", "light", "warm", "display", "temperature", "blue"]
            },
            {
                id: "nightLight.warmer",
                name: "Night Light Warmer",
                description: "Reduce Night Light colour temperature by 500K",
                icon: "weather-clear-night",
                keywords: ["night", "light", "warm", "kelvin", "temperature"]
            },
            {
                id: "nightLight.cooler",
                name: "Night Light Cooler",
                description: "Increase Night Light colour temperature by 500K",
                icon: "weather-clear",
                keywords: ["night", "light", "cool", "kelvin", "temperature"]
            },
            {
                id: "colour.pick",
                name: "Pick Colour to Clipboard",
                description: "Select a screen pixel and copy its HEX colour",
                icon: "color-picker",
                keywords: ["colour", "color", "eyedropper", "hex", "sample", "picker", "clipboard"]
            },
            {
                id: "capture.region",
                name: "Copy Frozen Screen Region",
                description: "Freeze the focused display, select pixels and copy them",
                icon: "camera-photo",
                keywords: ["screenshot", "capture", "snip", "clipboard", "region", "image"]
            },
            {
                id: "capture.liveRegion",
                name: "Copy Live Screen Region",
                description: "Select a region directly from the live desktop",
                icon: "camera-photo",
                keywords: ["live", "screenshot", "region", "screen", "copy"]
            },
            {
                id: "capture.output",
                name: "Copy Display Screenshot",
                description: "Copy the focused monitor to the clipboard",
                icon: "camera-photo",
                keywords: ["screenshot", "capture", "screen", "display", "monitor", "copy", "clipboard"]
            },
            {
                id: "capture.saveOutput",
                name: "Save Display Screenshot",
                description: "Save a screenshot of the focused monitor",
                icon: "camera-photo",
                keywords: ["screenshot", "capture", "screen", "display", "monitor", "save", "file"]
            },
            {
                id: "capture.recordToggle",
                name: "Start / Stop Screen Recording",
                description: "Select live recording region and audio; use again to stop and save",
                icon: "media-record",
                keywords: ["screen", "record", "video", "capture", "screencast", "mp4"]
            },
            {
                id: "capture.saveRegion",
                name: "Save Frozen Screen Region",
                description: "Freeze the focused display, select pixels and save a PNG",
                icon: "camera-photo",
                keywords: ["screenshot", "capture", "save", "file", "region", "image"]
            },
            {
                id: "audio.mixer",
                name: "Application Mixer",
                description: "Control live PipeWire playback streams",
                icon: "multimedia-volume-control",
                keywords: ["audio", "volume", "apps", "pavucontrol", "pipewire"]
            },
            {
                id: "session.lock",
                name: "Lock Session",
                description: "Secure the current Wayland session",
                icon: "system-lock-screen",
                keywords: ["lock", "security", "password"]
            },
            {
                id: "session.toggle",
                name: "Power & Session",
                description: "Suspend, log out, reboot, or power off",
                icon: "system-shutdown",
                keywords: ["power", "session", "logout", "suspend", "reboot", "shutdown"]
            },
            {
                id: "media.toggle",
                name: "Now Playing",
                description: "Open media controls",
                icon: "multimedia-player",
                keywords: ["music", "spotify", "media"]
            },
            {
                id: "media.playPause",
                name: "Play / Pause",
                description: "Toggle the selected media player",
                icon: "media-playback-start",
                keywords: ["music", "media", "pause"]
            },
            {
                id: "media.next",
                name: "Next Track",
                description: "Skip to the next track",
                icon: "media-skip-forward",
                keywords: ["music", "media", "skip"]
            },
            {
                id: "media.previous",
                name: "Previous Track",
                description: "Return to the previous track",
                icon: "media-skip-backward",
                keywords: ["music", "media", "back"]
            },
            {
                id: "media.seekForward",
                name: "Seek Forward 10 Seconds",
                description: "Seek the selected player forward",
                icon: "media-seek-forward",
                keywords: ["music", "media", "seek"]
            },
            {
                id: "media.seekBackward",
                name: "Seek Backward 10 Seconds",
                description: "Seek the selected player backward",
                icon: "media-seek-backward",
                keywords: ["music", "media", "seek"]
            },
            {
                id: "media.shuffle",
                name: "Toggle Shuffle",
                description: "Toggle shuffle on the selected player",
                icon: "media-playlist-shuffle",
                keywords: ["music", "media", "random"]
            },
            {
                id: "media.cyclePlayer",
                name: "Cycle Media Player",
                description: "Control the next MPRIS player",
                icon: "media-playlist-repeat",
                keywords: ["music", "media", "player", "switch"]
            },
            {
                id: "resources.toggle",
                name: "Resource Monitor",
                description: "Live CPU and memory dashboard",
                icon: "utilities-system-monitor",
                keywords: ["cpu", "ram", "memory", "resources", "performance", "usage"]
            },
            {
                id: "controls.toggle",
                name: "System Controls",
                description: "Open audio and connectivity status",
                icon: "preferences-system",
                keywords: ["volume", "wifi", "network", "bluetooth", "battery", "tray", "status icons"]
            },
            {
                id: "theme.toggle",
                name: "Theme Picker",
                description: "Switch the active Stylix palette",
                icon: "preferences-desktop-theme",
                keywords: ["theme", "stylix", "palette", "colour", "color"]
            },
            {
                id: "weather.toggle",
                name: "Weather",
                description: "Current conditions and seven-day forecast",
                icon: "weather-clear",
                keywords: ["forecast", "temperature", "rain", "sunrise", "climate"]
            },
            {
                id: "home.toggle",
                name: "Calendar",
                description: "Browse months and select dates",
                icon: "x-office-calendar",
                keywords: ["clock", "date", "month", "today", "schedule"]
            },
            {
                id: "notifications.toggle",
                name: "Notifications",
                description: "Open notification history",
                icon: "preferences-system-notifications",
                keywords: ["alerts", "history", "messages"]
            },
            {
                id: "notifications.clear",
                name: "Clear Notifications",
                description: "Dismiss stored notification history",
                icon: "edit-clear-all",
                keywords: ["alerts", "dismiss", "history"]
            },
            {
                id: "launcher.toggleHistory",
                name: launcher.rememberRecents ? "Disable Palette Recent Usage" : "Enable Palette Recent Usage",
                description: "Opt out of recording recently executed application and command identities",
                icon: "preferences-system-privacy",
                keywords: ["history", "recent", "privacy", "launcher", "tracking"]
            },
            {
                id: "launcher.clearRecent",
                name: "Clear Recent Palette Items",
                description: "Forget locally stored command and application recency",
                icon: "edit-clear",
                keywords: ["history", "recent", "privacy", "clear", "launcher"]
            },
            {
                id: "audio.volumeUp",
                name: "Volume Up",
                description: "Increase output volume by 5%",
                icon: "audio-volume-high",
                keywords: ["audio", "sound", "louder"]
            },
            {
                id: "audio.volumeDown",
                name: "Volume Down",
                description: "Decrease output volume by 5%",
                icon: "audio-volume-low",
                keywords: ["audio", "sound", "quieter"]
            },
            {
                id: "audio.toggleMute",
                name: "Toggle Mute",
                description: "Mute or unmute output audio",
                icon: "audio-volume-muted",
                keywords: ["audio", "sound", "silence"]
            },
            {
                id: "shortcuts.toggle",
                name: "Keyboard Shortcuts",
                description: "Show the Hyprland key map",
                icon: "preferences-desktop-keyboard-shortcuts",
                keywords: ["keybinds", "cheatsheet"]
            },
            {
                id: "animations.toggle",
                name: "Toggle Animations",
                description: "Enable or disable desktop motion",
                icon: "preferences-desktop-effects",
                keywords: ["motion", "reduce motion"]
            },
            {
                id: "terminal.open",
                name: "Open Terminal",
                description: runtime.terminal,
                icon: "utilities-terminal",
                keywords: ["shell", "console"]
            }
        ].concat(system.audioAvailable ? [
            {
                id: "audio.setVolume",
                name: "Set Volume…",
                description: "Set output volume to a percentage",
                icon: "audio-volume-high",
                parameterMode: "percent",
                keywords: ["volume", "sound", "level", "percentage", "audio"]
            },
        ] : []).concat(brightness.supported ? [
            {
                id: "brightness.set",
                name: "Set Brightness…",
                description: "Set hardware brightness to a percentage",
                icon: "display-brightness",
                parameterMode: "percent",
                keywords: ["brightness", "backlight", "level", "percentage", "display"]
            },
            {
                id: "brightness.up",
                name: "Brightness Up",
                description: "Increase hardware backlight by 5%",
                icon: "display-brightness",
                keywords: ["display", "backlight", "brighter"]
            },
            {
                id: "brightness.down",
                name: "Brightness Down",
                description: "Decrease hardware backlight by 5%",
                icon: "display-brightness",
                keywords: ["display", "backlight", "dimmer"]
            }
        ] : [])
        onCommandTriggered: commandId => actions.invokeCommand(commandId)
        onArgumentCommandTriggered: (commandId, argument) => {
            const percent = Number(argument);
            if (!Number.isInteger(percent) || percent < 0 || percent > 100)
                return;
            if (commandId === "audio.setVolume" && system.audioAvailable)
                system.setVolume(percent / 100);
            else if (commandId === "brightness.set" && brightness.supported)
                brightness.adjust(percent - brightness.percent);
        }
    }

    Actions {
        id: actions
        runtime: runtime
        screenRouter: screens
        ambientBar: ambientBar
        expansionState: expansionState
        themePanelOpen: !!expansionHost.systemContent && expansionHost.systemContent.themeOpen
        sessionPanelOpen: !!expansionHost.systemContent && expansionHost.systemContent.sessionOpen
        resourcesPanelOpen: !!expansionHost.systemContent && expansionHost.systemContent.resourcesOpen
        cheatsheet: cheatsheet
        launcher: launcher
        clipboardPanel: clipboardPanel
        mixerDetailOpen: !!expansionHost.systemContent && expansionHost.systemContent.mixerOpen
        systemDetailOpen: expansionHost.detailVisible
        overviewPanel: overviewPanel
        mediaState: media
        systemState: system
        brightnessState: brightness
        nightLightState: nightLight
        notificationState: notifications
        notificationPopup: notificationPopup
        motion: motion
        onFrozenCaptureRequested: copy => screenshotPicker.begin(copy, screens.focusedScreen, "image")
        onRecordingSelectionRequested: {
            actions.hideTransient("");
            screenshotPicker.begin(false, screens.focusedScreen, "record");
        }
        onWallpaperSpectrumToggleRequested: appearance.toggleWallpaperSpectrum()
        onMusicReactiveToggleRequested: appearance.toggleMusicReactive()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "cheatsheet"
        description: "Show Hyprland keyboard shortcuts"
        onPressed: actions.toggleCheatsheet()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "launcher"
        description: "Open command palette"
        onPressed: actions.toggleLauncher()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "launcher-slot-1"
        description: "Open command palette result 1"
        onPressed: launcher.launchIndex(0)
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "launcher-slot-2"
        description: "Open command palette result 2"
        onPressed: launcher.launchIndex(1)
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "launcher-slot-3"
        description: "Open command palette result 3"
        onPressed: launcher.launchIndex(2)
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "launcher-slot-4"
        description: "Open command palette result 4"
        onPressed: launcher.launchIndex(3)
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "launcher-slot-5"
        description: "Open command palette result 5"
        onPressed: launcher.launchIndex(4)
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "launcher-slot-6"
        description: "Open command palette result 6"
        onPressed: launcher.launchIndex(5)
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "launcher-slot-7"
        description: "Open command palette result 7"
        onPressed: launcher.launchIndex(6)
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "launcher-slot-8"
        description: "Open command palette result 8"
        onPressed: launcher.launchIndex(7)
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "launcher-slot-9"
        description: "Open command palette result 9"
        onPressed: launcher.launchIndex(8)
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "overview"
        description: "Window and workspace overview"
        onPressed: actions.toggleOverview()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "keyboard-caps-lock"
        description: "Show Caps Lock state"
        onPressed: osd.refreshKeyboardLocks("caps")
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "keyboard-num-lock"
        description: "Show Num Lock state"
        onPressed: osd.refreshKeyboardLocks("num")
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "wallpaper-spectrum"
        description: "Toggle live wallpaper music spectrum"
        onPressed: appearance.toggleWallpaperSpectrum()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "music-reactive"
        description: "Toggle music-reactive desktop surfaces"
        onPressed: appearance.toggleMusicReactive()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "record-toggle"
        description: "Start or stop a selected screen recording"
        onPressed: actions.toggleRecording()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "capture-region"
        description: "Copy selected screen region to clipboard"
        onPressed: actions.captureRegion(true)
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "clipboard"
        description: "Open clipboard history"
        onPressed: actions.toggleClipboard()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "audio-mixer"
        description: "Open application audio mixer"
        onPressed: actions.toggleAudioMixer()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "lock"
        description: "Lock the current session"
        onPressed: actions.lockSession()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "session"
        description: "Open power and session controls"
        onPressed: actions.showSession()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "theme"
        description: "Open theme picker"
        onPressed: actions.showTheme()
    }
    GlobalShortcut {
        appid: "linux-desktop"
        name: "colour-pick"
        description: "Pick a screen colour and copy its HEX value"
        onPressed: actions.pickColour()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "window-effects"
        description: "Toggle transparent windows"
        onPressed: appearance.toggleWindowTransparency()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "bar"
        description: "Toggle top bar"
        onPressed: root.toggleBar()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "media"
        description: "Open now playing"
        onPressed: actions.toggleMedia()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "resize-mode"
        description: "Show resize mode hints"
        onPressed: resizeOverlay.open = true
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "resize-mode-exit"
        description: "Hide resize mode hints"
        onPressed: resizeOverlay.open = false
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "media-play-pause"
        description: "Play or pause the selected media player"
        onPressed: actions.mediaPlayPause()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "media-next"
        description: "Skip to the next track"
        onPressed: actions.mediaNext()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "media-previous"
        description: "Return to the previous track"
        onPressed: actions.mediaPrevious()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "media-seek-forward"
        description: "Seek forward ten seconds"
        onPressed: actions.mediaSeekForward()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "media-seek-backward"
        description: "Seek backward ten seconds"
        onPressed: actions.mediaSeekBackward()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "media-shuffle"
        description: "Toggle shuffle for the selected media player"
        onPressed: actions.mediaToggleShuffle()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "media-cycle-player"
        description: "Select the next media player"
        onPressed: actions.mediaCyclePlayer()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "home"
        description: "Open Home"
        onPressed: actions.toggleCalendar()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "controls"
        description: "Open Controls"
        onPressed: actions.toggleSystem()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "system"
        description: "Open system controls"
        onPressed: actions.toggleSystem()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "volume-up"
        description: "Increase output volume"
        onPressed: actions.volumeUp()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "volume-down"
        description: "Decrease output volume"
        onPressed: actions.volumeDown()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "volume-mute"
        description: "Toggle output mute"
        onPressed: actions.toggleMute()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "brightness-up"
        description: "Increase display brightness"
        onPressed: actions.brightnessUp()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "brightness-down"
        description: "Decrease display brightness"
        onPressed: actions.brightnessDown()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "animations"
        description: "Toggle desktop animations"
        onPressed: actions.toggleAnimations()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "notifications"
        description: "Open notification history"
        onPressed: actions.toggleNotifications()
    }

    IpcHandler {
        target: "desktop"

        function toggleCheatsheet(): void {
            actions.toggleCheatsheet();
        }

        function toggleLauncher(): void {
            actions.toggleLauncher();
        }

        function toggleClipboard(): void {
            actions.toggleClipboard();
        }

        function clipboardOpen(): bool {
            return clipboardPanel.open;
        }

        function clipboardCount(): int {
            return clipboardPanel.entries.length;
        }

        function toggleAudioMixer(): void {
            actions.toggleAudioMixer();
        }
        function toggleOverview(): void {
            actions.toggleOverview();
        }

        function overviewOpen(): bool {
            return overviewPanel.open;
        }

        function audioMixerOpen(): bool {
            return !!expansionHost.systemContent && expansionHost.systemContent.mixerOpen;
        }

        function audioStreamCount(): int {
            return system.audioStreams.length;
        }

        function selectedAudioStreamVolume(): int {
            const stream = expansionHost.systemContent ? expansionHost.systemContent.selectedMixerStream() : null;
            return stream && stream.audio ? Math.round(stream.audio.volume * 100) : -1;
        }

        function selectedAudioStreamMuted(): bool {
            const stream = expansionHost.systemContent ? expansionHost.systemContent.selectedMixerStream() : null;
            return stream && stream.audio ? stream.audio.muted : false;
        }

        function adjustSelectedAudioStream(deltaPercent: int): void {
            if (expansionHost.systemContent)
                expansionHost.systemContent.adjustMixerStream(deltaPercent / 100);
        }

        function toggleSelectedAudioStreamMute(): void {
            if (expansionHost.systemContent)
                expansionHost.systemContent.toggleMixerMute();
        }

        function toggleMedia(): void {
            actions.toggleMedia();
        }

        function mediaPlayerCount(): int {
            return media.players.length;
        }

        function mediaPlayerIdentity(): string {
            return media.available ? media.identity : "";
        }

        function mediaPlayerId(): string {
            return media.available ? media.playerId(media.player) : "";
        }

        function mediaPlaying(): bool {
            return media.playing;
        }

        function mediaPositionSeconds(): int {
            return media.available ? Math.round(media.position) : -1;
        }

        function mediaShuffleSupported(): bool {
            return media.available && media.player.shuffleSupported;
        }

        function mediaShuffle(): bool {
            return media.available && media.player.shuffleSupported ? media.player.shuffle : false;
        }

        function mediaPlayPause(): void {
            actions.mediaPlayPause();
        }

        function mediaNext(): void {
            actions.mediaNext();
        }

        function mediaPrevious(): void {
            actions.mediaPrevious();
        }

        function mediaSeekForward(): void {
            actions.mediaSeekForward();
        }

        function mediaSeekBackward(): void {
            actions.mediaSeekBackward();
        }

        function mediaToggleShuffle(): void {
            actions.mediaToggleShuffle();
        }

        function mediaCyclePlayer(): void {
            actions.mediaCyclePlayer();
        }

        function toggleSystem(): void {
            actions.toggleSystem();
        }

        function toggleCalendar(): void {
            actions.toggleCalendar();
        }

        function toggleWeather(): void {
            actions.toggleWeather();
        }

        function weatherOpen(): bool {
            return expansionState.hasCurrent && expansionState.currentName === "weather";
        }

        function weatherAvailable(): bool {
            return weather.available;
        }

        function weatherCity(): string {
            return weather.city;
        }

        function weatherTemperature(): string {
            return weather.available ? weather.temperatureText(weather.temperature) : weather.status;
        }

        function weatherForecastCount(): int {
            return weather.forecast.length;
        }

        function calendarOpen(): bool {
            return expansionState.hasCurrent && expansionState.currentName === "calendar";
        }

        function showResources(): void {
            actions.showResources();
        }

        function showTheme(): void {
            actions.showTheme();
        }

        function themeOpen(): bool {
            return expansionState.hasCurrent && expansionState.currentName === "system" && expansionHost.systemContent ? expansionHost.systemContent.themeOpen : false;
        }

        function showSession(): void {
            actions.showSession();
        }

        function sessionOpen(): bool {
            return expansionState.hasCurrent && expansionState.currentName === "system" && expansionHost.systemContent ? expansionHost.systemContent.sessionOpen : false;
        }

        function toggleNotifications(): void {
            actions.toggleNotifications();
        }

        function notificationsOpen(): bool {
            return expansionState.hasCurrent && expansionState.currentName === "activity";
        }

        function notificationCount(): int {
            return notifications.count;
        }

        function notificationsSilent(): bool {
            return notifications.silent;
        }

        function barShown(): bool {
            return ambientBar.shown;
        }

        function toggleBar(): void {
            root.toggleBar();
        }

        function toggleWindowEffects(): void {
            appearance.toggleWindowTransparency();
        }

        function toggleShellGlass(): void {
            appearance.toggleShellGlass();
        }

        function shellGlassEnabled(): bool {
            return appearance.shellGlassEnabled;
        }

        function windowEffectsEnabled(): bool {
            return appearance.windowTransparencyEnabled;
        }

        function idleInhibited(): bool {
            return system.idleInhibited;
        }

        function powerProfileCurrent(): string {
            return powerProfile.current;
        }

        function powerProfileCount(): int {
            return powerProfile.profiles.length;
        }

        function cyclePowerProfile(): void {
            powerProfile.cycle();
        }

        function toggleIdleInhibited(): void {
            system.toggleIdleInhibited();
        }

        function clearNotifications(): void {
            actions.clearNotifications();
        }

        function toggleAnimations(): void {
            actions.toggleAnimations();
        }

        function animationsEnabled(): bool {
            return motion.enabled;
        }

        function mediaOpen(): bool {
            return expansionState.hasCurrent && expansionState.currentName === "media";
        }

        function spectrumConnected(): bool {
            return spectrum.connected;
        }

        function spectrumSequence(): int {
            return spectrum.sequence;
        }

        function musicReactiveOn(): bool {
            return root.musicReactiveEnabled;
        }

        function musicReactiveBassLevel(): real {
            return reactive.sustain;
        }

        function musicReactiveBeatLevel(): real {
            return reactive.beatPulse;
        }

        function wallpaperSpectrumOn(): bool {
            return root.wallpaperSpectrumEnabled;
        }

        function systemOpen(): bool {
            return expansionState.hasCurrent && expansionState.currentName === "system";
        }

        function volumePercent(): int {
            return system.volumePercent;
        }

        function audioMuted(): bool {
            return system.muted;
        }

        function volumeUp(): void {
            actions.volumeUp();
        }

        function volumeDown(): void {
            actions.volumeDown();
        }

        function toggleMute(): void {
            actions.toggleMute();
        }

        function brightnessUp(): void {
            actions.brightnessUp();
        }

        function brightnessDown(): void {
            actions.brightnessDown();
        }

        function brightnessSupported(): bool {
            return brightness.supported;
        }

        function brightnessPercent(): int {
            return brightness.percent;
        }

        function osdVisible(): bool {
            return osd.visible;
        }

        function osdKind(): string {
            return osd.kind;
        }

        function osdValue(): int {
            return osd.value;
        }

        function networkName(): string {
            return system.networkName;
        }

        function bluetoothConnectedCount(): int {
            return system.bluetoothConnectedCount;
        }

        function batteryAvailable(): bool {
            return system.batteryAvailable;
        }

        function batteryPercent(): int {
            return system.batteryPercent;
        }

        function trayCount(): int {
            return system.trayCount;
        }

        function trayMenuOpen(): bool {
            return expansionState.hasCurrent && expansionState.currentName === "system" && expansionHost.systemContent ? expansionHost.systemContent.trayMenuOpen : false;
        }

        function trayMenuItemCount(): int {
            return expansionState.hasCurrent && expansionState.currentName === "system" && expansionHost.systemContent ? expansionHost.systemContent.trayMenuItemCount : 0;
        }

        function openSelectedTrayItem(): void {
            if (expansionState.hasCurrent && expansionState.currentName === "system" && expansionHost.loadedContent)
                expansionHost.systemContent.activateTrayItem();
        }

        function launchTerminal(): void {
            actions.launchTerminal();
        }

        function terminal(): string {
            return runtime.terminal;
        }
    }
}

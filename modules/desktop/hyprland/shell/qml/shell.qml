//@ pragma ShellId desktop-shell
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property Actions actionsRef: actions
    readonly property RuntimeConfig runtimeRef: qmlRuntime
    readonly property Theme themeRef: qmlTheme
    readonly property Motion motionRef: qmlMotion
    readonly property MediaState mediaRef: qmlMedia
    readonly property SpectrumState spectrumRef: qmlSpectrum
    readonly property SystemState systemRef: qmlSystem
    readonly property ResourceState resourcesRef: resources
    readonly property PowerProfileState powerProfileRef: qmlPowerProfile
    readonly property BrightnessState brightnessRef: qmlBrightness
    readonly property NightLightState nightLightRef: nightLight
    readonly property WeatherState weatherRef: weather
    readonly property NotificationState notificationsRef: qmlNotifications

    readonly property bool wallpaperSpectrumEnabled: qmlAppearance.wallpaperSpectrumEnabled
    readonly property bool musicReactiveEnabled: qmlAppearance.musicReactiveEnabled

    // A saved appearance preference is not a reason to animate invisible UI.
    // Demand comes from the actual shared shell surfaces that can be seen.
    readonly property bool musicReactiveSurfaceVisible: musicReactiveEnabled && (desktopFrame.glassExposed || qmlAmbientBar.shown || qmlExpansionState.hasCurrent || expansionHost.closing || modalHost.contentVisible || qmlNotifications.popupVisible || qmlOsd.visible || osdPopup.closing || resizeOverlay.open || resizeOverlay.closing)

    property var statusTargetScreen: null
    property var resizeTargetScreen: null
    function toggleStatusInspection(targetScreen: var): void {
        if (resizeOverlay.open) {
            resizeOverlay.inspectOpen = !resizeOverlay.inspectOpen;
            if (resizeOverlay.inspectOpen)
                qmlKeyboard.refresh("inspect");
            return;
        }
        if (statusPeek.open) {
            statusPeek.open = false;
            return;
        }
        statusTargetScreen = targetScreen || qmlScreens.focusedScreen;
        statusPeek.open = true;
    }
    function toggleBar(): void {
        qmlAppearance.toggleBar();
    }

    AppearancePreferences {
        id: qmlAppearance
        runtime: qmlRuntime
        frameGlassExposed: desktopFrame.glassExposed
        // The shared frame already blurs connected hub surfaces.
        expansionGlassExposed: (qmlExpansionState.hasCurrent || expansionHost.closing) && !expansionHost.frameVisible
        modalGlassExposed: modalHost.contentVisible
        // Popup ownership includes closing cards until their exit completes.
        // NotificationPopup has no separate closing property.
        notificationGlassExposed: qmlNotifications.popupVisible
        osdGlassExposed: qmlOsd.visible || osdPopup.closing
        resizeGlassExposed: resizeOverlay.open || resizeOverlay.closing
    }

    RuntimeConfig {
        id: qmlRuntime
    }

    SceneState {
        id: qmlScenes
        appearance: qmlAppearance
        motion: qmlMotion
        notifications: qmlNotifications
    }

    Theme {
        id: qmlTheme
        runtime: qmlRuntime
        musicReactiveEnabled: root.musicReactiveSurfaceVisible
        shellGlassEnabled: qmlAppearance.shellGlassEnabled
        glassOpacity: qmlAppearance.glassOpacity
        barIslandHeight: qmlAppearance.barIslandHeight
        frameThickness: qmlAppearance.frameThickness
        musicReactiveEnergy: reactive.sustain
        musicReactiveBeat: reactive.beatPulse
        musicReactiveIntensity: qmlAppearance.musicReactiveIntensity
    }

    Motion {
        id: qmlMotion
        runtime: qmlRuntime
    }

    ScreenRouter {
        id: qmlScreens
    }

    PolkitDialog {
        runtime: root.runtimeRef
        theme: root.themeRef
        motion: root.motionRef
        screens: qmlScreens
    }

    WeatherState {
        id: weather
        runtime: qmlRuntime
    }

    ShellExpansionState {
        id: qmlExpansionState
    }

    // Retain the outgoing view until the host finishes its closing morph.
    // Otherwise nested details reset mid-animation and redraw as Controls.
    Component {
        id: mediaExpansionComponent

        MediaContent {
            appearance: qmlAppearance
            media: root.mediaRef
            spectrum: root.spectrumRef
            runtime: root.runtimeRef
            theme: root.themeRef
            motion: root.motionRef
            engaged: qmlExpansionState.currentName === "media"
            returnToControls: qmlExpansionState.backDestination === "controls"
            onCloseRequested: qmlExpansionState.back()
        }
    }

    Component {
        id: calendarExpansionComponent

        CalendarContent {
            runtime: root.runtimeRef
            theme: root.themeRef
            motion: root.motionRef
            weather: root.weatherRef
            engaged: qmlExpansionState.currentName === "calendar"
            presentationActive: qmlExpansionState.hasCurrent && qmlExpansionState.currentName === "calendar"
            onForecastRequested: actions.toggleWeather()
            onCloseRequested: qmlExpansionState.close()
        }
    }

    Component {
        id: weatherExpansionComponent

        WeatherContent {
            runtime: root.runtimeRef
            theme: root.themeRef
            motion: root.motionRef
            weather: root.weatherRef
            engaged: qmlExpansionState.currentName === "weather"
            onCloseRequested: qmlExpansionState.back()
        }
    }

    Component {
        id: systemExpansionComponent

        SystemContent {
            shellActions: root.actionsRef
            appearance: qmlAppearance
            scenes: qmlScenes
            runtime: root.runtimeRef
            theme: root.themeRef
            motion: root.motionRef
            system: root.systemRef
            media: root.mediaRef
            spectrum: root.spectrumRef
            notificationState: root.notificationsRef
            brightness: root.brightnessRef
            keyboard: qmlKeyboard
            recording: qmlRecording
            statusMode: qmlInteractionMode.passthroughActive ? "Passthrough" : resizeOverlay.open ? "Resize window" : "Normal"
            nightLight: root.nightLightRef
            resourceState: root.resourcesRef
            powerProfile: root.powerProfileRef
            wallpaperSpectrumEnabled: root.wallpaperSpectrumEnabled
            musicReactiveEnabled: root.musicReactiveEnabled
            barVisible: qmlAppearance.barVisible
            frameVisible: qmlAppearance.frameVisible
            windowTransparencyEnabled: qmlAppearance.windowTransparencyEnabled
            shellGlassEnabled: qmlAppearance.shellGlassEnabled
            engaged: qmlExpansionState.currentName === "system"
            presentationActive: qmlExpansionState.hasCurrent && qmlExpansionState.currentName === "system"
            onWallpaperSpectrumToggleRequested: qmlAppearance.toggleWallpaperSpectrum()
            onMusicReactiveToggleRequested: qmlAppearance.toggleMusicReactive()
            onBarToggleRequested: qmlAppearance.toggleBar()
            onFrameToggleRequested: qmlAppearance.toggleFrame()
            onWindowTransparencyToggleRequested: qmlAppearance.toggleWindowTransparency()
            onShellGlassToggleRequested: qmlAppearance.toggleShellGlass()
            onDisplaySettingsRequested: {
                qmlExpansionState.close();
                if (qmlRuntime.displaySettings.length > 0)
                    Quickshell.execDetached([qmlRuntime.displaySettings]);
            }
            requestedView: qmlExpansionState.currentView
            returnToControls: qmlExpansionState.backDestination === "controls"
            onBackRequested: qmlExpansionState.back()
            onDetailRequested: view => qmlExpansionState.enterDetail(view)
            onCloseRequested: qmlExpansionState.close()
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
            engaged: qmlExpansionState.currentName === "activity"
            onCloseRequested: qmlExpansionState.close()
        }
    }

    ShellExpansionHost {
        id: expansionHost
        runtime: qmlRuntime
        theme: qmlTheme
        motion: qmlMotion
        frameEnabled: qmlAppearance.frameVisible
        barVisible: qmlAppearance.barVisible
        recordingState: qmlRecording
        onRecordingStopRequested: actions.toggleRecording()
        dockOrigin: qmlAmbientBar.originFor(qmlExpansionState.screen || Quickshell.screens[0], "system")
        expansionState: qmlExpansionState
        barWindows: qmlAmbientBar.instances
        mediaComponent: mediaExpansionComponent
        systemComponent: systemExpansionComponent
        calendarComponent: calendarExpansionComponent
        weatherComponent: weatherExpansionComponent
        activityComponent: activityExpansionComponent
    }

    MediaState {
        id: qmlMedia
        appearance: qmlAppearance
    }

    SystemState {
        id: qmlSystem
        runtime: qmlRuntime
    }

    PowerProfileState {
        id: qmlPowerProfile
        active: true
    }

    ResourceState {
        id: resources
        runtime: qmlRuntime
        active: qmlExpansionState.hasCurrent && qmlExpansionState.currentName === "system" && expansionHost.systemContent !== null && expansionHost.systemContent.resourcesOpen
    }

    BrightnessState {
        id: qmlBrightness
        runtime: qmlRuntime
    }

    NightLightState {
        id: nightLight
        runtime: qmlRuntime
    }

    KeyboardState {
        id: qmlKeyboard
        runtime: qmlRuntime
    }

    InteractionModeState {
        id: qmlInteractionMode
    }

    OsdState {
        id: qmlOsd
        system: qmlSystem
        brightness: qmlBrightness
        keyboard: qmlKeyboard
        interactionMode: qmlInteractionMode
        screens: qmlScreens
        runtime: qmlRuntime
    }

    NotificationState {
        id: qmlNotifications
        runtime: qmlRuntime
        preferredOutput: qmlScreens.focusedScreen ? qmlScreens.focusedScreen.name : ""
        outputFullscreen: !!(Hyprland.monitorFor(qmlScreens.focusedScreen)?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 0) ?? false)
    }

    Connections {
        target: qmlNotifications
        function onLockedChanged(): void {
            if (qmlNotifications.locked)
                actions.hideTransient("");
        }
    }

    RecordingState {
        id: qmlRecording
    }

    EventNotifications {
        id: eventNotifications
        runtime: qmlRuntime
        system: qmlSystem
        powerProfile: qmlPowerProfile
        notifications: qmlNotifications
        onDisplaySettingsRequested: if (qmlRuntime.displaySettings.length > 0)
            Quickshell.execDetached([qmlRuntime.displaySettings])
        onNetworkSettingsRequested: actions.showSystem(null, null, "network")
        onAudioSettingsRequested: microphone => actions.toggleAudioMixer()
        onPowerSettingsRequested: actions.showSystem()
    }

    SpectrumState {
        id: qmlSpectrum
        sensitivity: qmlAppearance.spectrumSensitivity
        attackMultiplier: qmlAppearance.spectrumAttack
        releaseMultiplier: qmlAppearance.spectrumRelease
        // No DSP client unless a visible spectrum consumer needs live audio.
        active: (qmlMedia.playing && qmlAmbientBar.shown) || (qmlExpansionState.hasCurrent && (qmlExpansionState.currentName === "system" || qmlExpansionState.currentName === "media")) || root.wallpaperSpectrumEnabled || root.musicReactiveSurfaceVisible
    }

    MusicReactiveState {
        id: reactive
        spectrum: root.spectrumRef
        enabled: root.musicReactiveSurfaceVisible
        sensitivity: qmlAppearance.musicReactiveSensitivity
        attackMultiplier: qmlAppearance.musicReactiveAttack
        releaseMultiplier: qmlAppearance.musicReactiveRelease
        smoothing: qmlAppearance.musicReactiveSmoothing
        frequencyEmphasis: qmlAppearance.musicReactiveEmphasis
    }

    WallpaperSpectrum {
        id: wallpaperSpectrum
        spectrum: root.spectrumRef
        theme: root.themeRef
        enabled: root.wallpaperSpectrumEnabled
        intensity: qmlAppearance.wallpaperSpectrumOpacity
        barCount: qmlAppearance.wallpaperSpectrumBars
    }

    DesktopFrame {
        id: desktopFrame
        theme: root.themeRef
        motion: root.motionRef
        enabled: qmlAppearance.frameVisible
        barVisible: qmlAppearance.barVisible
        islands: qmlAmbientBar.frameIslands
        hub: expansionHost.frameBounds
        hubScreen: expansionHost.screen
        toastByOutput: qmlNotifications.frameDocksByOutput
        osd: osdPopup.frameBounds
        osdScreen: osdPopup.screen
        resize: resizeOverlay.frameBounds
        resizeScreen: resizeOverlay.screen
        inspection: statusPeek.frameBounds
        inspectionScreen: statusPeek.screen
        busy: !!expansionHost.loadingOperationVisible
        busyColor: expansionHost.loadingOperationColor
        busyScreen: qmlExpansionState.screen
    }

    AmbientBar {
        id: qmlAmbientBar
        onSystemStatusRequested: screen => root.toggleStatusInspection(screen)
        // The expanding hub consumes the clock island throughout the whole
        // opening and closing transition, not only while Controls is active.
        // Let the clock join the frame while the hub finishes retracting.
        controlsExpanded: qmlExpansionState.hasCurrent || (expansionHost.closing && expansionHost.clockReveal < 0.05) || resizeOverlay.open || resizeOverlay.closing || statusPeek.open || (qmlOsd.visible && !osdPopup.suspended)
        hubBounds: expansionHost.frameBounds
        hubScreen: expansionHost.screen
        clockReveal: resizeOverlay.open || resizeOverlay.closing || statusPeek.open || (qmlOsd.visible && !osdPopup.suspended) ? 0 : expansionHost.clockReveal
        shown: qmlAppearance.barVisible
        frameVisible: qmlAppearance.frameVisible
        runtime: qmlRuntime
        theme: qmlTheme
        motion: qmlMotion
        media: qmlMedia
        spectrum: qmlSpectrum
        system: qmlSystem
        powerProfile: qmlPowerProfile
        notificationState: qmlNotifications
        recordingState: qmlRecording
        onRecordingStopRequested: actions.toggleRecording()
        onMediaRequested: (screen, origin) => actions.toggleMedia(screen, origin)
        onSystemRequested: (screen, origin) => actions.toggleSystem(screen, origin)
        onTrayMenuRequested: (screen, origin, index) => actions.showSystem(screen, origin, "tray:" + index)
        onCalendarRequested: (screen, origin) => actions.toggleCalendar(screen, origin)
        onNotificationsRequested: (screen, origin) => actions.toggleNotifications(screen, origin)
    }

    ModalSurfaceHost {
        id: modalHost
        screens: qmlScreens
        clipboardPanel: qmlClipboardPanel
        launcher: qmlLauncher
        overviewPanel: qmlOverviewPanel
        cheatsheet: qmlCheatsheet
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
        screen: screenshotPicker.captureScreen || qmlScreens.focusedScreen || Quickshell.screens[0]
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
        WlrLayershell.namespace: "desktop-shell-capture"
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
        WlrLayershell.namespace: "desktop-shell-modal-dim"
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
        id: qmlCheatsheet
        parent: modalHost.contentItem
        screen: qmlScreens.focusedScreen
        runtime: qmlRuntime
        theme: qmlTheme
        motion: qmlMotion
    }

    ClipboardPanel {
        id: qmlClipboardPanel
        parent: modalHost.contentItem
        screen: qmlScreens.focusedScreen
        runtime: qmlRuntime
        theme: qmlTheme
        motion: qmlMotion
    }

    ScreenshotPicker {
        id: screenshotPicker
        parent: captureHost.contentItem
        surfaceReady: captureHost.geometryStable
        runtime: qmlRuntime
        theme: qmlTheme
        motion: qmlMotion
        onSnapshotReady: actions.hideTransient("")
    }

    OverviewPanel {
        id: qmlOverviewPanel
        parent: modalHost.contentItem
        screen: qmlScreens.focusedScreen
        runtime: qmlRuntime
        theme: qmlTheme
        motion: qmlMotion
    }

    ResizeOverlay {
        id: resizeOverlay
        screen: root.resizeTargetScreen || qmlScreens.focusedScreen
        keyboard: qmlKeyboard
        system: qmlSystem
        frameEnabled: qmlAppearance.frameVisible
        barVisible: qmlAppearance.barVisible
        runtime: qmlRuntime
        theme: qmlTheme
        motion: qmlMotion
    }

    // A single freedesktop server serves bounded, independent toast layouts
    // on every compositor output. Existing cards stay on their origin when
    // keyboard focus changes; no popup Wayland surface teleports.
    NotificationPopups {
        notificationState: qmlNotifications
        runtime: qmlRuntime
        theme: qmlTheme
        motion: qmlMotion
        frameEnabled: qmlAppearance.frameVisible
        hubVisible: qmlExpansionState.hasCurrent || expansionHost.closing
        hubScreen: expansionHost.screen
        hubBounds: expansionHost.frameBounds
        onCenterRequested: screen => actions.showNotifications(screen)
    }

    StatusPeek {
        id: statusPeek
        screen: root.statusTargetScreen || qmlScreens.focusedScreen
        runtime: qmlRuntime
        theme: qmlTheme
        motion: qmlMotion
        system: qmlSystem
        keyboard: qmlKeyboard
        brightness: qmlBrightness
        recording: qmlRecording
        frameEnabled: qmlAppearance.frameVisible
        barVisible: qmlAppearance.barVisible
        hubVisible: qmlExpansionState.hasCurrent
        hubBounds: expansionHost.frameBounds
        modeName: qmlInteractionMode.passthroughActive ? "Passthrough" : resizeOverlay.open ? "Resize window" : "Normal"
        onCloseRequested: statusPeek.open = false
    }

    OsdPopup {
        id: osdPopup
        screen: qmlOsd.activeScreen || qmlScreens.focusedScreen
        osd: qmlOsd
        barVisible: qmlAppearance.barVisible
        suspended: statusPeek.open || resizeOverlay.open || qmlExpansionState.hasCurrent
        runtime: qmlRuntime
        theme: qmlTheme
        motion: qmlMotion
        frameEnabled: qmlAppearance.frameVisible
    }

    CommandPalette {
        id: qmlLauncher
        parent: modalHost.contentItem
        clipboardPanel: qmlClipboardPanel
        screen: qmlScreens.focusedScreen
        runtime: qmlRuntime
        theme: qmlTheme
        motion: qmlMotion
        audioAvailable: qmlSystem.audioAvailable
        brightnessAvailable: qmlBrightness.supported
        commands: actions.paletteCommands
        onCommandTriggered: commandId => actions.invokeCommand(commandId)
        onArgumentCommandTriggered: (commandId, argument) => {
            const percent = Number(argument);
            if (!Number.isInteger(percent) || percent < 0 || percent > 100)
                return;
            if (commandId === "audio.setVolume" && qmlSystem.audioAvailable)
                qmlSystem.setVolume(percent / 100);
            else if (commandId === "brightness.set" && qmlBrightness.supported)
                qmlBrightness.adjust(percent - qmlBrightness.percent);
        }
    }

    Actions {
        id: actions
        wallpaperSpectrumEnabled: root.wallpaperSpectrumEnabled
        musicReactiveEnabled: root.musicReactiveEnabled
        onStatusInspectionRequested: root.toggleStatusInspection()
        runtime: qmlRuntime
        screenRouter: qmlScreens
        ambientBar: qmlAmbientBar
        expansionState: qmlExpansionState
        themePanelOpen: !!expansionHost.systemContent && expansionHost.systemContent.themeOpen
        wallpaperPanelOpen: !!expansionHost.systemContent && expansionHost.systemContent.wallpaperOpen
        recordingsPanelOpen: !!expansionHost.systemContent && expansionHost.systemContent.recordingsOpen
        sessionPanelOpen: !!expansionHost.systemContent && expansionHost.systemContent.sessionOpen
        resourcesPanelOpen: !!expansionHost.systemContent && expansionHost.systemContent.resourcesOpen
        cheatsheet: qmlCheatsheet
        launcher: qmlLauncher
        clipboardPanel: qmlClipboardPanel
        mixerDetailOpen: !!expansionHost.systemContent && expansionHost.systemContent.mixerOpen
        systemDetailOpen: expansionHost.detailVisible
        overviewPanel: qmlOverviewPanel
        mediaState: qmlMedia
        systemState: qmlSystem
        brightnessState: qmlBrightness
        nightLightState: nightLight
        notificationState: qmlNotifications
        motion: qmlMotion
        appearance: qmlAppearance
        scenes: qmlScenes
        resources: root.resourcesRef
        weather: root.weatherRef
        capture: screenshotPicker
        onFrozenCaptureRequested: copy => screenshotPicker.begin(copy, qmlScreens.focusedScreen, "image")
        onRecordingSelectionRequested: {
            actions.hideTransient("");
            screenshotPicker.begin(false, qmlScreens.focusedScreen, "record");
        }
        onWallpaperSpectrumToggleRequested: qmlAppearance.toggleWallpaperSpectrum()
        onMusicReactiveToggleRequested: qmlAppearance.toggleMusicReactive()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "cheatsheet"
        description: "Show Hyprland keyboard shortcuts"
        onPressed: actions.toggleCheatsheet()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "launcher"
        description: "Open command palette"
        onPressed: actions.toggleLauncher()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "launcher-slot-1"
        description: "Open command palette result 1"
        onPressed: qmlLauncher.launchIndex(0)
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "launcher-slot-2"
        description: "Open command palette result 2"
        onPressed: qmlLauncher.launchIndex(1)
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "launcher-slot-3"
        description: "Open command palette result 3"
        onPressed: qmlLauncher.launchIndex(2)
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "launcher-slot-4"
        description: "Open command palette result 4"
        onPressed: qmlLauncher.launchIndex(3)
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "launcher-slot-5"
        description: "Open command palette result 5"
        onPressed: qmlLauncher.launchIndex(4)
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "launcher-slot-6"
        description: "Open command palette result 6"
        onPressed: qmlLauncher.launchIndex(5)
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "launcher-slot-7"
        description: "Open command palette result 7"
        onPressed: qmlLauncher.launchIndex(6)
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "launcher-slot-8"
        description: "Open command palette result 8"
        onPressed: qmlLauncher.launchIndex(7)
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "launcher-slot-9"
        description: "Open command palette result 9"
        onPressed: qmlLauncher.launchIndex(8)
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "overview"
        description: "Window and workspace overview"
        onPressed: actions.toggleOverview()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "keyboard-caps-lock"
        description: "Show Caps Lock state"
        onPressed: qmlOsd.refreshKeyboardLocks("caps")
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "keyboard-num-lock"
        description: "Show Num Lock state"
        onPressed: qmlOsd.refreshKeyboardLocks("num")
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "wallpaper-spectrum"
        description: "Toggle live wallpaper music spectrum"
        onPressed: qmlAppearance.toggleWallpaperSpectrum()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "music-reactive"
        description: "Toggle music-reactive desktop surfaces"
        onPressed: qmlAppearance.toggleMusicReactive()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "record-toggle"
        description: "Start or stop a selected screen recording"
        onPressed: actions.toggleRecording()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "capture-region"
        description: "Copy selected screen region to clipboard"
        onPressed: actions.captureRegion(true)
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "clipboard"
        description: "Open clipboard history"
        onPressed: actions.toggleClipboard()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "audio-mixer"
        description: "Open application audio mixer"
        onPressed: actions.toggleAudioMixer()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "lock"
        description: "Lock the current session"
        onPressed: actions.lockSession()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "session"
        description: "Open power and session controls"
        onPressed: actions.showSession()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "theme"
        description: "Open theme picker"
        onPressed: actions.showTheme()
    }
    GlobalShortcut {
        appid: "desktop-shell"
        name: "wallpaper"
        description: "Open wallpaper gallery"
        onPressed: actions.showWallpaper()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "captures"
        description: "Open capture history"
        onPressed: actions.showCaptures()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "colour-pick"
        description: "Pick a screen colour and copy its HEX value"
        onPressed: actions.pickColour()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "window-effects"
        description: "Toggle transparent windows"
        onPressed: qmlAppearance.toggleWindowTransparency()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "bar"
        description: "Toggle top bar"
        onPressed: root.toggleBar()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "media"
        description: "Open now playing"
        onPressed: actions.toggleMedia()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "resize-mode"
        description: "Open keyboard-driven window resize controls"
        onPressed: {
            if (!resizeOverlay.open)
                root.resizeTargetScreen = qmlScreens.focusedScreen;
            resizeOverlay.open = !resizeOverlay.open;
        }
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "microphone-mute"
        description: "Toggle default microphone mute"
        onPressed: qmlSystem.toggleMicrophoneMute()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "status-peek"
        description: "Inspect current system status without changing it"
        onPressed: root.toggleStatusInspection()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "media-play-pause"
        description: "Play or pause the selected media player"
        onPressed: actions.mediaPlayPause()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "media-next"
        description: "Skip to the next track"
        onPressed: actions.mediaNext()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "media-previous"
        description: "Return to the previous track"
        onPressed: actions.mediaPrevious()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "media-seek-forward"
        description: "Seek forward by the configured interval"
        onPressed: actions.mediaSeekForward()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "media-seek-backward"
        description: "Seek backward by the configured interval"
        onPressed: actions.mediaSeekBackward()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "media-shuffle"
        description: "Toggle shuffle for the selected media player"
        onPressed: actions.mediaToggleShuffle()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "media-cycle-player"
        description: "Select the next media player"
        onPressed: actions.mediaCyclePlayer()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "home"
        description: "Open Home"
        onPressed: actions.toggleCalendar()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "controls"
        description: "Open Controls"
        onPressed: actions.toggleSystem()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "system"
        description: "Open system controls"
        onPressed: actions.toggleSystem()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "volume-up"
        description: "Increase output volume"
        onPressed: actions.volumeUp()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "volume-down"
        description: "Decrease output volume"
        onPressed: actions.volumeDown()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "volume-mute"
        description: "Toggle output mute"
        onPressed: actions.toggleMute()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "brightness-up"
        description: "Increase display brightness"
        onPressed: actions.brightnessUp()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "brightness-down"
        description: "Decrease display brightness"
        onPressed: actions.brightnessDown()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "animations"
        description: "Toggle desktop animations"
        onPressed: actions.toggleAnimations()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "notifications"
        description: "Open notification history"
        onPressed: actions.toggleNotifications()
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "notifications-act"
        description: "Activate latest notification"
        onPressed: {
            if (!qmlNotifications.locked && !qmlNotifications.invokeLatest())
                actions.showNotifications();
        }
    }

    GlobalShortcut {
        appid: "desktop-shell"
        name: "notifications-dismiss"
        description: "Dismiss latest visible notification"
        onPressed: qmlNotifications.dismissLatestPopup()
    }

    IpcHandler {
        target: "desktop"

        function toggleStatusInspection(): void {
            root.toggleStatusInspection();
        }

        function statusInspectionOpen(): bool {
            return statusPeek.open;
        }

        function resizeModeOpen(): bool {
            return resizeOverlay.open;
        }

        function activeInputMode(): string {
            return qmlInteractionMode.submap;
        }

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
            return qmlClipboardPanel.open;
        }

        function clipboardCount(): int {
            return qmlClipboardPanel.entries.length;
        }

        function toggleAudioMixer(): void {
            actions.toggleAudioMixer();
        }
        function toggleOverview(): void {
            actions.toggleOverview();
        }

        function overviewOpen(): bool {
            return qmlOverviewPanel.open;
        }

        function audioMixerOpen(): bool {
            return !!expansionHost.systemContent && expansionHost.systemContent.mixerOpen;
        }

        function audioStreamCount(): int {
            return qmlSystem.audioStreams.length;
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
            return qmlMedia.players.length;
        }

        function mediaPlayerIdentity(): string {
            return qmlMedia.available ? qmlMedia.identity : "";
        }

        function mediaPlayerId(): string {
            return qmlMedia.available ? qmlMedia.playerId(qmlMedia.player) : "";
        }

        function mediaPlaying(): bool {
            return qmlMedia.playing;
        }

        function mediaPositionSeconds(): int {
            return qmlMedia.available ? Math.round(qmlMedia.position) : -1;
        }

        function mediaShuffleSupported(): bool {
            return qmlMedia.available && qmlMedia.player.shuffleSupported;
        }

        function mediaShuffle(): bool {
            return qmlMedia.available && qmlMedia.player.shuffleSupported ? qmlMedia.player.shuffle : false;
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
            return qmlExpansionState.hasCurrent && qmlExpansionState.currentName === "weather";
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
            return qmlExpansionState.hasCurrent && qmlExpansionState.currentName === "calendar";
        }

        function showResources(): void {
            actions.showResources();
        }

        function showTheme(): void {
            actions.showTheme();
        }

        function themeOpen(): bool {
            return qmlExpansionState.hasCurrent && qmlExpansionState.currentName === "system" && expansionHost.systemContent ? expansionHost.systemContent.themeOpen : false;
        }

        function showSession(): void {
            actions.showSession();
        }

        function sessionOpen(): bool {
            return qmlExpansionState.hasCurrent && qmlExpansionState.currentName === "system" && expansionHost.systemContent ? expansionHost.systemContent.sessionOpen : false;
        }

        function showCaptureText(name: string): void {
            if (!/^(?:Screenshot-[0-9]{8}-[0-9]{6}-[0-9]+\.(?:png|jpg)|Recording-[0-9]{8}-[0-9]{6}-[0-9]+\.(?:mp4|mkv))$/.test(name))
                return;
            actions.showSystem(null, null, "recordings:" + name);
        }

        function toggleNotifications(): void {
            actions.toggleNotifications();
        }

        function notificationsOpen(): bool {
            return !qmlNotifications.locked && qmlExpansionState.hasCurrent && qmlExpansionState.currentName === "activity";
        }

        function notificationCount(): int {
            return qmlNotifications.locked ? 0 : qmlNotifications.count;
        }

        function notificationsSilent(): bool {
            return qmlNotifications.silent;
        }

        function barShown(): bool {
            return qmlAmbientBar.shown;
        }

        function toggleBar(): void {
            root.toggleBar();
        }

        function frameShown(): bool {
            return qmlAppearance.frameVisible;
        }

        function toggleFrame(): void {
            qmlAppearance.toggleFrame();
        }

        function toggleWindowEffects(): void {
            qmlAppearance.toggleWindowTransparency();
        }

        function toggleShellGlass(): void {
            qmlAppearance.toggleShellGlass();
        }

        function shellGlassEnabled(): bool {
            return qmlAppearance.shellGlassEnabled;
        }

        function windowEffectsEnabled(): bool {
            return qmlAppearance.windowTransparencyEnabled;
        }

        function idleInhibited(): bool {
            return qmlSystem.idleInhibited;
        }

        function powerProfileCurrent(): string {
            return qmlPowerProfile.current;
        }

        function powerProfileCount(): int {
            return qmlPowerProfile.profiles.length;
        }

        function cyclePowerProfile(): void {
            qmlPowerProfile.cycle();
        }

        function toggleIdleInhibited(): void {
            qmlSystem.toggleIdleInhibited();
        }

        function clearNotifications(): void {
            actions.clearNotifications();
        }

        function toggleAnimations(): void {
            actions.toggleAnimations();
        }

        function animationsEnabled(): bool {
            return qmlMotion.enabled;
        }

        function mediaOpen(): bool {
            return qmlExpansionState.hasCurrent && qmlExpansionState.currentName === "media";
        }

        function spectrumConnected(): bool {
            return qmlSpectrum.connected;
        }

        function spectrumSequence(): int {
            return qmlSpectrum.sequence;
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
            return qmlExpansionState.hasCurrent && qmlExpansionState.currentName === "system";
        }

        function controlsSelectedSlider(): string {
            return qmlExpansionState.currentName === "system" && expansionHost.systemContent ? expansionHost.systemContent.selectedSlider : "";
        }

        function volumePercent(): int {
            return qmlSystem.volumePercent;
        }

        function audioMuted(): bool {
            return qmlSystem.muted;
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
            return qmlBrightness.supported;
        }

        function brightnessPercent(): int {
            return qmlBrightness.percent;
        }

        function osdVisible(): bool {
            return qmlOsd.visible;
        }

        function osdKind(): string {
            return qmlOsd.kind;
        }

        function osdValue(): int {
            return qmlOsd.value;
        }

        function networkName(): string {
            return qmlSystem.networkName;
        }

        function bluetoothConnectedCount(): int {
            return qmlSystem.bluetoothConnectedCount;
        }

        function batteryAvailable(): bool {
            return qmlSystem.batteryAvailable;
        }

        function batteryPercent(): int {
            return qmlSystem.batteryPercent;
        }

        function trayCount(): int {
            return qmlSystem.trayCount;
        }

        function trayMenuOpen(): bool {
            return qmlExpansionState.hasCurrent && qmlExpansionState.currentName === "system" && expansionHost.systemContent ? expansionHost.systemContent.trayMenuOpen : false;
        }

        function trayMenuItemCount(): int {
            return qmlExpansionState.hasCurrent && qmlExpansionState.currentName === "system" && expansionHost.systemContent ? expansionHost.systemContent.trayMenuItemCount : 0;
        }

        function openSelectedTrayItem(): void {
            if (qmlExpansionState.hasCurrent && qmlExpansionState.currentName === "system" && expansionHost.loadedContent)
                expansionHost.systemContent.activateTrayItem();
        }

        function launchTerminal(): void {
            actions.launchTerminal();
        }

        function terminal(): string {
            return qmlRuntime.terminal;
        }
    }
}

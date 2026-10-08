//@ pragma ShellId linux-desktop
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

ShellRoot {
    id: root

    readonly property RuntimeConfig runtimeRef: runtime
    readonly property Theme themeRef: theme
    readonly property Motion motionRef: motion
    readonly property MediaState mediaRef: media
    readonly property SpectrumState spectrumRef: spectrum
    readonly property SystemState systemRef: system
    readonly property BrightnessState brightnessRef: brightness

    RuntimeConfig {
        id: runtime
    }

    Theme {
        id: theme
        runtime: runtime
    }

    Motion {
        id: motion
        runtime: runtime
    }

    ScreenRouter {
        id: screens
    }

    ShellExpansionState {
        id: expansionState
    }

    Component {
        id: mediaExpansionComponent

        MediaContent {
            media: root.mediaRef
            spectrum: root.spectrumRef
            runtime: root.runtimeRef
            theme: root.themeRef
            motion: root.motionRef
            engaged: expansionState.hasCurrent && expansionState.currentName === "media"
            onCloseRequested: expansionState.close()
        }
    }

    Component {
        id: calendarExpansionComponent

        CalendarContent {
            runtime: root.runtimeRef
            theme: root.themeRef
            motion: root.motionRef
            engaged: expansionState.hasCurrent && expansionState.currentName === "calendar"
            onCloseRequested: expansionState.close()
        }
    }

    Component {
        id: systemExpansionComponent

        SystemContent {
            runtime: root.runtimeRef
            theme: root.themeRef
            motion: root.motionRef
            system: root.systemRef
            brightness: root.brightnessRef
            engaged: expansionState.hasCurrent && expansionState.currentName === "system"
            requestedView: expansionState.currentView
            onCloseRequested: expansionState.close()
        }
    }

    ShellExpansionHost {
        id: expansionHost
        runtime: runtime
        theme: theme
        motion: motion
        expansionState: expansionState
        mediaComponent: mediaExpansionComponent
        systemComponent: systemExpansionComponent
        calendarComponent: calendarExpansionComponent
    }

    WallpaperLayer {
        runtime: runtime
        theme: theme
    }

    MediaState {
        id: media
    }

    SystemState {
        id: system
    }

    BrightnessState {
        id: brightness
        runtime: runtime
    }

    OsdState {
        id: osd
        system: system
        brightness: brightness
    }

    NotificationState {
        id: notifications
    }

    SpectrumState {
        id: spectrum
        active: media.playing || (expansionState.hasCurrent && expansionState.currentName === "media")
    }

    AmbientBar {
        id: ambientBar
        runtime: runtime
        theme: theme
        motion: motion
        media: media
        spectrum: spectrum
        system: system
        notificationState: notifications
        onMediaRequested: (screen, origin) => actions.toggleMedia(screen, origin)
        onSystemRequested: (screen, origin) => actions.toggleSystem(screen, origin)
        onCalendarRequested: (screen, origin) => actions.toggleCalendar(screen, origin)
        onNotificationsRequested: actions.toggleNotifications()
    }

    ShortcutCheatsheet {
        id: cheatsheet
        screen: screens.focusedScreen
        runtime: runtime
        theme: theme
        motion: motion
    }

    ClipboardPanel {
        id: clipboardPanel
        screen: screens.focusedScreen
        runtime: runtime
        theme: theme
        motion: motion
    }

    AudioMixerPanel {
        id: audioMixerPanel
        screen: screens.focusedScreen
        system: system
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

    NotificationCenter {
        id: notificationCenter
        screen: screens.focusedScreen
        notificationState: notifications
        runtime: runtime
        theme: theme
        motion: motion
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
        screen: screens.focusedScreen
        runtime: runtime
        theme: theme
        motion: motion
        commands: [
            {
                id: "clipboard.toggle",
                name: "Clipboard History",
                description: "Search and restore clipboard entries",
                icon: "edit-paste",
                key: runtime.shortcut("clipboard.toggle"),
                keywords: ["copy", "paste", "cliphist"]
            },
            {
                id: "audio.mixer",
                name: "Application Mixer",
                description: "Control live PipeWire playback streams",
                icon: "multimedia-volume-control",
                key: runtime.shortcut("audio.mixer"),
                keywords: ["audio", "volume", "apps", "pavucontrol", "pipewire"]
            },
            {
                id: "session.lock",
                name: "Lock Session",
                description: "Secure the current Wayland session",
                icon: "system-lock-screen",
                key: runtime.shortcut("session.lock"),
                keywords: ["lock", "security", "password"]
            },
            {
                id: "session.toggle",
                name: "Power & Session",
                description: "Suspend, log out, reboot, or power off",
                icon: "system-shutdown",
                key: runtime.shortcut("session.toggle"),
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
                key: runtime.shortcut("media.playPause"),
                keywords: ["music", "media", "pause"]
            },
            {
                id: "media.next",
                name: "Next Track",
                description: "Skip to the next track",
                icon: "media-skip-forward",
                key: runtime.shortcut("media.next"),
                keywords: ["music", "media", "skip"]
            },
            {
                id: "media.previous",
                name: "Previous Track",
                description: "Return to the previous track",
                icon: "media-skip-backward",
                key: runtime.shortcut("media.previous"),
                keywords: ["music", "media", "back"]
            },
            {
                id: "media.seekForward",
                name: "Seek Forward 10 Seconds",
                description: "Seek the selected player forward",
                icon: "media-seek-forward",
                key: runtime.shortcut("media.seekForward"),
                keywords: ["music", "media", "seek"]
            },
            {
                id: "media.seekBackward",
                name: "Seek Backward 10 Seconds",
                description: "Seek the selected player backward",
                icon: "media-seek-backward",
                key: runtime.shortcut("media.seekBackward"),
                keywords: ["music", "media", "seek"]
            },
            {
                id: "media.shuffle",
                name: "Toggle Shuffle",
                description: "Toggle shuffle on the selected player",
                icon: "media-playlist-shuffle",
                key: runtime.shortcut("media.shuffle"),
                keywords: ["music", "media", "random"]
            },
            {
                id: "media.cyclePlayer",
                name: "Cycle Media Player",
                description: "Control the next MPRIS player",
                icon: "media-playlist-repeat",
                key: runtime.shortcut("media.cyclePlayer"),
                keywords: ["music", "media", "player", "switch"]
            },
            {
                id: "system.toggle",
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
                id: "calendar.toggle",
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
                key: runtime.shortcut("notifications.toggle"),
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
                id: "audio.volumeUp",
                name: "Volume Up",
                description: "Increase output volume by 5%",
                icon: "audio-volume-high",
                key: runtime.shortcut("audio.volumeUp"),
                keywords: ["audio", "sound", "louder"]
            },
            {
                id: "audio.volumeDown",
                name: "Volume Down",
                description: "Decrease output volume by 5%",
                icon: "audio-volume-low",
                key: runtime.shortcut("audio.volumeDown"),
                keywords: ["audio", "sound", "quieter"]
            },
            {
                id: "audio.toggleMute",
                name: "Toggle Mute",
                description: "Mute or unmute output audio",
                icon: "audio-volume-muted",
                key: runtime.shortcut("audio.toggleMute"),
                keywords: ["audio", "sound", "silence"]
            },
            {
                id: "shortcuts.toggle",
                name: "Keyboard Shortcuts",
                description: "Show the Hyprland key map",
                icon: "preferences-desktop-keyboard-shortcuts",
                key: runtime.shortcut("shortcuts.toggle"),
                keywords: ["keybinds", "cheatsheet"]
            },
            {
                id: "animations.toggle",
                name: "Toggle Animations",
                description: "Enable or disable desktop motion",
                icon: "preferences-desktop-effects",
                key: runtime.shortcut("animations.toggle"),
                keywords: ["motion", "reduce motion"]
            },
            {
                id: "terminal.open",
                name: "Open Terminal",
                description: runtime.terminal,
                icon: "utilities-terminal",
                key: runtime.shortcut("terminal.open"),
                keywords: ["shell", "console"]
            }
        ].concat(brightness.supported ? [
            {
                id: "brightness.up",
                name: "Brightness Up",
                description: "Increase hardware backlight by 5%",
                icon: "display-brightness",
                key: runtime.shortcut("brightness.up"),
                keywords: ["display", "backlight", "brighter"]
            },
            {
                id: "brightness.down",
                name: "Brightness Down",
                description: "Decrease hardware backlight by 5%",
                icon: "display-brightness",
                key: runtime.shortcut("brightness.down"),
                keywords: ["display", "backlight", "dimmer"]
            }
        ] : [])
        onCommandTriggered: commandId => actions.invokeCommand(commandId)
    }

    Actions {
        id: actions
        runtime: runtime
        screenRouter: screens
        ambientBar: ambientBar
        expansionState: expansionState
        cheatsheet: cheatsheet
        launcher: launcher
        clipboardPanel: clipboardPanel
        audioMixerPanel: audioMixerPanel
        mediaState: media
        systemState: system
        brightnessState: brightness
        notificationCenter: notificationCenter
        notificationState: notifications
        motion: motion
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
        name: "bar"
        description: "Toggle top bar"
        onPressed: ambientBar.shown = !ambientBar.shown
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

        function audioMixerOpen(): bool {
            return audioMixerPanel.open;
        }

        function audioStreamCount(): int {
            return system.audioStreams.length;
        }

        function selectedAudioStreamVolume(): int {
            const stream = audioMixerPanel.selectedStream();
            return stream && stream.audio ? Math.round(stream.audio.volume * 100) : -1;
        }

        function selectedAudioStreamMuted(): bool {
            const stream = audioMixerPanel.selectedStream();
            return stream && stream.audio ? stream.audio.muted : false;
        }

        function adjustSelectedAudioStream(deltaPercent: int): void {
            audioMixerPanel.adjustSelected(deltaPercent / 100);
        }

        function toggleSelectedAudioStreamMute(): void {
            audioMixerPanel.toggleSelectedMute();
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

        function calendarOpen(): bool {
            return expansionState.hasCurrent && expansionState.currentName === "calendar";
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
            return notificationCenter.open;
        }

        function notificationCount(): int {
            return notifications.count;
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

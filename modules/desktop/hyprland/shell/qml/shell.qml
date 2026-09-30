//@ pragma ShellId linux-desktop

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

ShellRoot {
    id: root

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
        active: media.playing || mediaPanel.open
    }

    AmbientBar {
        id: ambientBar
        runtime: runtime
        theme: theme
        motion: motion
        media: media
        system: system
        onMediaRequested: actions.toggleMedia()
        onSystemRequested: actions.toggleSystem()
    }

    PrototypeSurface {
        id: prototype
        runtime: runtime
        theme: theme
    }

    ShortcutCheatsheet {
        id: cheatsheet
        runtime: runtime
        theme: theme
        motion: motion
    }

    ClipboardPanel {
        id: clipboardPanel
        runtime: runtime
        theme: theme
        motion: motion
    }

    AudioMixerPanel {
        id: audioMixerPanel
        system: system
        runtime: runtime
        theme: theme
        motion: motion
    }

    MediaPanel {
        id: mediaPanel
        media: media
        spectrum: spectrum
        runtime: runtime
        theme: theme
        motion: motion
    }

    SystemPanel {
        id: systemPanel
        system: system
        brightness: brightness
        runtime: runtime
        theme: theme
        motion: motion
    }

    NotificationPopup {
        id: notificationPopup
        notificationState: notifications
        runtime: runtime
        theme: theme
        motion: motion
        onCenterRequested: actions.showNotifications()
    }

    NotificationCenter {
        id: notificationCenter
        notificationState: notifications
        runtime: runtime
        theme: theme
        motion: motion
    }

    OsdPopup {
        id: osdPopup
        osd: osd
        runtime: runtime
        theme: theme
        motion: motion
    }

    CommandPalette {
        id: launcher
        runtime: runtime
        theme: theme
        motion: motion
        commands: [
            { id: "clipboard.toggle", name: "Clipboard History", description: "Search and restore clipboard entries", icon: "edit-paste", key: "SUPER + V", keywords: ["copy", "paste", "cliphist"] },
            { id: "audio.mixer", name: "Application Mixer", description: "Control live PipeWire playback streams", icon: "multimedia-volume-control", key: "SUPER + SHIFT + V", keywords: ["audio", "volume", "apps", "pavucontrol", "pipewire"] },
            { id: "media.toggle", name: "Now Playing", description: "Open media controls", icon: "multimedia-player", keywords: ["music", "spotify", "media"] },
            { id: "system.toggle", name: "System Controls", description: "Open audio and connectivity status", icon: "preferences-system", keywords: ["volume", "wifi", "network", "bluetooth", "battery", "tray", "status icons"] },
            { id: "notifications.toggle", name: "Notifications", description: "Open notification history", icon: "preferences-system-notifications", keywords: ["alerts", "history", "messages"] },
            { id: "notifications.clear", name: "Clear Notifications", description: "Dismiss stored notification history", icon: "edit-clear-all", keywords: ["alerts", "dismiss", "history"] },
            { id: "audio.volumeUp", name: "Volume Up", description: "Increase output volume by 5%", icon: "audio-volume-high", key: "VOLUME +", keywords: ["audio", "sound", "louder"] },
            { id: "audio.volumeDown", name: "Volume Down", description: "Decrease output volume by 5%", icon: "audio-volume-low", key: "VOLUME −", keywords: ["audio", "sound", "quieter"] },
            { id: "audio.toggleMute", name: "Toggle Mute", description: "Mute or unmute output audio", icon: "audio-volume-muted", key: "MUTE", keywords: ["audio", "sound", "silence"] },
            { id: "shortcuts.toggle", name: "Keyboard Shortcuts", description: "Show the Hyprland key map", icon: "preferences-desktop-keyboard-shortcuts", key: "SUPER + /", keywords: ["keybinds", "cheatsheet"] },
            { id: "animations.toggle", name: "Toggle Animations", description: "Enable or disable desktop motion", icon: "preferences-desktop-effects", keywords: ["motion", "reduce motion"] },
            { id: "terminal.open", name: "Open Terminal", description: runtime.terminal, icon: "utilities-terminal", keywords: ["shell", "console"] }
        ].concat(brightness.supported ? [
            { id: "brightness.up", name: "Brightness Up", description: "Increase hardware backlight by 5%", icon: "display-brightness", key: "BRIGHTNESS +", keywords: ["display", "backlight", "brighter"] },
            { id: "brightness.down", name: "Brightness Down", description: "Decrease hardware backlight by 5%", icon: "display-brightness", key: "BRIGHTNESS −", keywords: ["display", "backlight", "dimmer"] }
        ] : [])
        onCommandTriggered: commandId => actions.invokeCommand(commandId)
    }

    Actions {
        id: actions
        runtime: runtime
        prototype: prototype
        cheatsheet: cheatsheet
        launcher: launcher
        clipboardPanel: clipboardPanel
        audioMixerPanel: audioMixerPanel
        mediaPanel: mediaPanel
        mediaState: media
        systemPanel: systemPanel
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
        name: "media"
        description: "Open now playing"
        onPressed: actions.toggleMedia()
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
        name: "notifications"
        description: "Open notification history"
        onPressed: actions.toggleNotifications()
    }

    IpcHandler {
        target: "desktop"

        function showPrototype(): void {
            actions.showPrototype();
        }

        function hidePrototype(): void {
            actions.hidePrototype();
        }

        function togglePrototype(): void {
            actions.togglePrototype();
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
            return mediaPanel.open;
        }

        function spectrumConnected(): bool {
            return spectrum.connected;
        }

        function spectrumSequence(): int {
            return spectrum.sequence;
        }

        function systemOpen(): bool {
            return systemPanel.open;
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
            return systemPanel.trayMenuOpen;
        }

        function trayMenuItemCount(): int {
            return systemPanel.trayMenuItemCount;
        }

        function openSelectedTrayItem(): void {
            systemPanel.activateTrayItem();
        }

        function launchTerminal(): void {
            actions.launchTerminal();
        }

        function terminal(): string {
            return runtime.terminal;
        }
    }
}

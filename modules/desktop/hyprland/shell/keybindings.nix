# Canonical assigned keys for shell-local interaction. The symbolic slot
# identifies an interaction position, not the physical key assigned to it.
{
  base = {
    "0" = "0";
    "1" = "1";
    "2" = "2";
    "3" = "3";
    "4" = "4";
    "5" = "5";
    "6" = "6";
    "7" = "7";
    "8" = "8";
    "9" = "9";
    A = "A";
    Alt = "ALT";
    AltGr = "AltGr";
    B = "B";
    Backspace = "BACKSPACE";
    Backtab = "SHIFT+TAB";
    BracketLeft = "[";
    BracketRight = "]";
    C = "C";
    Comma = ",";
    Control = "CTRL";
    D = "D";
    Delete = "DEL";
    Down = "DOWN";
    E = "E";
    Enter = "NUMENTER";
    Equal = "=";
    Escape = "ESC";
    F = "F";
    G = "G";
    H = "H";
    I = "I";
    J = "J";
    K = "K";
    L = "L";
    Left = "LEFT";
    M = "M";
    Meta = "SUPER";
    Minus = "-";
    N = "N";
    O = "O";
    P = "P";
    PageDown = "PGDN";
    PageUp = "PGUP";
    Period = ".";
    Plus = "+";
    Q = "Q";
    Question = "?";
    R = "R";
    Return = "ENTER";
    Right = "RIGHT";
    S = "S";
    Shift = "SHIFT";
    Slash = "/";
    Space = "SPACE";
    T = "T";
    Tab = "TAB";
    U = "U";
    Underscore = "_";
    Up = "UP";
    V = "V";
    W = "W";
    X = "X";
    Y = "Y";
    Z = "Z";
  };

  # Optional scope-specific slot overrides. Keep unrelated panels independent.
  overrides = { };

  # Action-specific assignments take precedence over shared slot defaults.
  # Changing an action must not silently remap every use of the same letter.
  actions = {
    "SystemContent.bar" = "SHIFT+A";
    "SystemContent.frame" = "SHIFT+S";
    "SystemContent.nightLight" = "T";
    "SystemContent.shellGlass" = "SHIFT+R";
  };

  # Action-owned keyhints. Display strings resolve their symbols through base
  # and scope overrides, not through duplicated labels in QML.
  hints = {
    "AudioMixerContent.level" = {
      scope = "mixer";
      template = "H/L";
    };
    "AudioMixerContent.select" = {
      scope = "mixer";
      template = "J/K";
    };
    "BluetoothPanel.activate" = {
      scope = "controls";
      template = "ENTER";
    };
    "BluetoothPanel.forget" = {
      scope = "controls";
      template = "F";
    };
    "BluetoothPanel.pair" = {
      scope = "controls";
      template = "P";
    };
    "BluetoothPanel.radio" = {
      scope = "controls";
      template = "B";
    };
    "BluetoothPanel.scan" = {
      scope = "controls";
      template = "SHIFT+D";
    };
    "BluetoothPanel.select" = {
      scope = "controls";
      template = "J/K";
    };
    "BluetoothPanel.trust" = {
      scope = "controls";
      template = "T";
    };
    "CalendarContent.calendars" = {
      scope = "calendar";
      template = "C";
    };
    "CalendarContent.closeCalendars" = {
      scope = "calendar";
      template = "ESC";
    };
    "CalendarContent.days" = {
      scope = "calendar";
      template = "H/L";
    };
    "CalendarContent.events" = {
      scope = "calendar";
      template = "U/D";
    };
    "CalendarContent.months" = {
      scope = "calendar";
      template = "J/K";
    };
    "CalendarContent.selectCalendar" = {
      scope = "calendar";
      template = "J/K";
    };
    "CalendarContent.today" = {
      scope = "calendar";
      template = "T";
    };
    "CalendarContent.toggleCalendar" = {
      scope = "calendar";
      template = "SPACE";
    };
    "ClipboardPanel.close" = {
      scope = "clipboard";
      template = "ESC";
    };
    "ClipboardPanel.copy" = {
      scope = "clipboard";
      template = "ENTER";
    };
    "ClipboardPanel.copySearch" = {
      scope = "clipboard";
      template = "ENTER";
    };
    "ClipboardPanel.halfPage" = {
      scope = "clipboard";
      template = "U/D · PGUP/PGDN";
    };
    "ClipboardPanel.navigateSearch" = {
      scope = "clipboard";
      template = "J/K";
    };
    "CommandPalette.actionMenu" = {
      scope = "palette";
      template = "ALT+ENTER";
    };
    "CommandPalette.actions" = {
      scope = "palette";
      template = "ALT+3";
    };
    "CommandPalette.apps" = {
      scope = "palette";
      template = "ALT+2";
    };
    "CommandPalette.back" = {
      scope = "palette";
      template = "ESC";
    };
    "CommandPalette.closeAll" = {
      scope = "palette";
      template = "SHIFT+ESC";
    };
    "CommandPalette.emoji" = {
      scope = "palette";
      template = "ALT+4";
    };
    "CommandPalette.execute" = {
      scope = "palette";
      template = "ENTER";
    };
    "CommandPalette.navigate" = {
      scope = "palette";
      template = "TAB";
    };
    "CommandPalette.pageResults" = {
      scope = "palette";
      template = "U/D";
    };
    "CommandPalette.resultActions" = {
      scope = "palette";
      template = "ALT+ENTER";
    };
    "CommandPalette.resultBack" = {
      scope = "palette";
      template = "ESC";
    };
    "CommandPalette.select" = {
      scope = "palette";
      template = "J/K";
    };
    "CommandPalette.selectResults" = {
      scope = "palette";
      template = "J/K";
    };
    "CommandPalette.unified" = {
      scope = "palette";
      template = "ALT+1";
    };
    "ControlsMediaCard.repeat" = {
      scope = "controls";
      template = "B";
    };
    "ControlsMediaCard.shuffle" = {
      scope = "controls";
      template = "Z";
    };
    "HubTabs.help" = {
      scope = "hub";
      template = "?";
    };
    "MediaContent.longer" = {
      scope = "media";
      template = "+";
    };
    "MediaContent.lyrics" = {
      scope = "media";
      template = "Y";
    };
    "MediaContent.player" = {
      scope = "media";
      template = "P";
    };
    "MediaContent.repeat" = {
      scope = "media";
      template = "R";
    };
    "MediaContent.shorter" = {
      scope = "media";
      template = "-";
    };
    "MediaContent.shuffle" = {
      scope = "media";
      template = "S";
    };
    "MediaContent.visualizer" = {
      scope = "media";
      template = "V";
    };
    "NetworkPanel.advanced" = {
      scope = "controls";
      template = "A";
    };
    "NetworkPanel.connect" = {
      scope = "controls";
      template = "ENTER";
    };
    "NetworkPanel.connectNetwork" = {
      scope = "controls";
      template = "ENTER";
    };
    "NetworkPanel.connectProfile" = {
      scope = "controls";
      template = "ENTER";
    };
    "NetworkPanel.detail" = {
      scope = "controls";
      template = "V";
    };
    "NetworkPanel.listScroll" = {
      scope = "controls";
      template = "J/K";
    };
    "NetworkPanel.passwordCancel" = {
      scope = "controls";
      template = "ESC";
    };
    "NetworkPanel.passwordSubmit" = {
      scope = "controls";
      template = "ENTER";
    };
    "NetworkPanel.refresh" = {
      scope = "controls";
      template = "R";
    };
    "NetworkPanel.saved" = {
      scope = "controls";
      template = "P";
    };
    "NetworkPanel.select" = {
      scope = "controls";
      template = "J/K";
    };
    "NetworkPanel.toggleWifi" = {
      scope = "controls";
      template = "W";
    };
    "NotificationContent.clearAll" = {
      scope = "activity";
      template = "C";
    };
    "NotificationContent.expand" = {
      scope = "activity";
      template = "E";
    };
    "NotificationContent.groups" = {
      scope = "activity";
      template = "H/L · ARROWS";
    };
    "NotificationContent.history" = {
      scope = "activity";
      template = "SHIFT+H";
    };
    "NotificationContent.markAllRead" = {
      scope = "activity";
      template = "SHIFT+M";
    };
    "NotificationContent.markAllUnread" = {
      scope = "activity";
      template = "SHIFT+N";
    };
    "NotificationContent.navigate" = {
      scope = "activity";
      template = "J/K · ARROWS";
    };
    "NotificationContent.presentation" = {
      scope = "activity";
      template = "P";
    };
    "NotificationContent.silent" = {
      scope = "activity";
      template = "S";
    };
    "OverviewPanel.all" = {
      scope = "overview";
      template = "A";
    };
    "OverviewPanel.close" = {
      scope = "overview";
      template = "ESC";
    };
    "OverviewPanel.destination" = {
      scope = "overview";
      template = "1–0";
    };
    "OverviewPanel.move" = {
      scope = "overview";
      template = "M";
    };
    "OverviewPanel.moveCancel" = {
      scope = "overview";
      template = "ESC";
    };
    "OverviewPanel.moveConfirm" = {
      scope = "overview";
      template = "ENTER";
    };
    "OverviewPanel.navigate" = {
      scope = "overview";
      template = "H/J/K/L";
    };
    "OverviewPanel.open" = {
      scope = "overview";
      template = "ENTER";
    };
    "OverviewPanel.target" = {
      scope = "overview";
      template = "H/L";
    };
    "OverviewPanel.toggleFloating" = {
      scope = "overview";
      template = "F";
    };
    "OverviewPanel.togglePin" = {
      scope = "overview";
      template = "P";
    };
    "OverviewPanel.workspace" = {
      scope = "overview";
      template = "1–0";
    };
    "PolkitDialog.authorize" = {
      scope = "polkit";
      template = "ENTER";
    };
    "PolkitDialog.cancel" = {
      scope = "polkit";
      template = "ESC";
    };
    "PolkitDialog.identity" = {
      scope = "polkit";
      template = "I";
    };
    "RecordingLibrary.choose" = {
      scope = "controls";
      template = "J/K";
    };
    "RecordingLibrary.copy" = {
      scope = "controls";
      template = "C";
    };
    "RecordingLibrary.delete" = {
      scope = "controls";
      template = "D";
    };
    "RecordingLibrary.edit" = {
      scope = "controls";
      template = "E";
    };
    "RecordingLibrary.open" = {
      scope = "controls";
      template = "ENTER";
    };
    "RecordingLibrary.page" = {
      scope = "controls";
      template = "U/D";
    };
    "RecordingLibrary.refresh" = {
      scope = "controls";
      template = "R";
    };
    "ResizeOverlay.balance" = {
      scope = "resize";
      template = "B";
    };
    "ResizeOverlay.done" = {
      scope = "resize";
      template = "ESC";
    };
    "ResizeOverlay.inspect" = {
      scope = "resize";
      template = "S";
    };
    "ResizeOverlay.reverse" = {
      scope = "resize";
      template = "SHIFT";
    };
    "ResourceDashboard.refresh" = {
      scope = "controls";
      template = "R";
    };
    "ResourceDashboard.toggleCores" = {
      scope = "controls";
      template = "C";
    };
    "ResourceDashboard.toggleCoresHint" = {
      scope = "controls";
      template = "C";
    };
    "ScreenshotPicker.cancel" = {
      scope = "capture";
      template = "ESC";
    };
    "ScreenshotPicker.capture" = {
      scope = "capture";
      template = "ENTER";
    };
    "ScreenshotPicker.display" = {
      scope = "capture";
      template = "TAB";
    };
    "ScreenshotPicker.edit" = {
      scope = "capture";
      template = "E";
    };
    "ScreenshotPicker.full" = {
      scope = "capture";
      template = "F";
    };
    "ScreenshotPicker.move" = {
      scope = "capture";
      template = "H/J/K/L · ARROWS";
    };
    "ScreenshotPicker.resize" = {
      scope = "capture";
      template = "SHIFT+HJKL/ARROWS";
    };
    "SessionPanel.confirm" = {
      scope = "controls";
      template = "ENTER";
    };
    "SessionPanel.lock" = {
      scope = "controls";
      template = "Q";
    };
    "SessionPanel.logout" = {
      scope = "controls";
      template = "E";
    };
    "SessionPanel.move" = {
      scope = "controls";
      template = "HJKL";
    };
    "SessionPanel.reboot" = {
      scope = "controls";
      template = "A";
    };
    "SessionPanel.restoreWindows" = {
      scope = "controls";
      template = "D";
    };
    "SessionPanel.shutdown" = {
      scope = "controls";
      template = "S";
    };
    "SessionPanel.suspend" = {
      scope = "controls";
      template = "W";
    };
    "ShellExpansionHost.back" = {
      scope = "hub";
      template = "ESC";
    };
    "ShellExpansionHost.closeAll" = {
      scope = "hub";
      template = "SHIFT+ESC";
    };
    "ShellExpansionHost.page" = {
      scope = "hub";
      template = "PGUP/PGDN";
    };
    "ShellExpansionHost.scroll" = {
      scope = "hub";
      template = "U/D";
    };
    "ShortcutCheatsheet.back" = {
      scope = "help";
      template = "ESC";
    };
    "ShortcutCheatsheet.close" = {
      scope = "help";
      template = "ESC";
    };
    "ShortcutCheatsheet.halfPage" = {
      scope = "help";
      template = "U/D";
    };
    "ShortcutCheatsheet.navigate" = {
      scope = "help";
      template = "TAB";
    };
    "ShortcutCheatsheet.page" = {
      scope = "help";
      template = "PGUP/PGDN";
    };
    "ShortcutCheatsheet.scroll" = {
      scope = "help";
      template = "J/K";
    };
    "ShortcutCheatsheet.search" = {
      scope = "help";
      template = "/";
    };
    "StatusContent.close" = {
      scope = "status";
      template = "ESC";
    };
    "StatusContent.refresh" = {
      scope = "status";
      template = "R";
    };
    "SystemContent.alerts" = {
      scope = "controls";
      template = "A";
    };
    "SystemContent.audioAdjust" = {
      scope = "controls";
      template = "H/L";
    };
    "SystemContent.audioLevel" = {
      scope = "controls";
      template = "H/L";
    };
    "SystemContent.audioSelect" = {
      scope = "controls";
      template = "J/K";
    };
    "SystemContent.bar" = {
      scope = "controls";
      template = "SHIFT+A";
    };
    "SystemContent.bluetooth" = {
      scope = "controls";
      template = "G";
    };
    "SystemContent.captures" = {
      scope = "controls";
      template = "C";
    };
    "SystemContent.frame" = {
      scope = "controls";
      template = "SHIFT+S";
    };
    "SystemContent.motion" = {
      scope = "controls";
      template = "SHIFT+E";
    };
    "SystemContent.musicReactive" = {
      scope = "controls";
      template = "SHIFT+G";
    };
    "SystemContent.network" = {
      scope = "controls";
      template = "F";
    };
    "SystemContent.nightLight" = {
      scope = "controls";
      template = "T";
    };
    "SystemContent.powerProfile" = {
      scope = "controls";
      template = "V";
    };
    "SystemContent.reset" = {
      scope = "controls";
      template = "SHIFT+C";
    };
    "SystemContent.resetCancel" = {
      scope = "controls";
      template = "ESC";
    };
    "SystemContent.resetConfirm" = {
      scope = "controls";
      template = "ENTER";
    };
    "SystemContent.resources" = {
      scope = "controls";
      template = "R";
    };
    "SystemContent.rowSelect" = {
      scope = "controls";
      template = "J/K";
    };
    "SystemContent.session" = {
      scope = "controls";
      template = "E";
    };
    "SystemContent.shellGlass" = {
      scope = "controls";
      template = "SHIFT+R";
    };
    "SystemContent.stayAwake" = {
      scope = "controls";
      template = "S";
    };
    "SystemContent.tabSelect" = {
      scope = "controls";
      template = "TAB";
    };
    "SystemContent.themes" = {
      scope = "controls";
      template = "Q";
    };
    "SystemContent.trayNavigate" = {
      scope = "controls";
      template = "[ / ]";
    };
    "SystemContent.trayOpen" = {
      scope = "controls";
      template = "ENTER";
    };
    "SystemContent.wallpaper" = {
      scope = "controls";
      template = "W";
    };
    "SystemContent.wallpaperSpectrum" = {
      scope = "controls";
      template = "SHIFT+F";
    };
    "SystemContent.windowTransparency" = {
      scope = "controls";
      template = "SHIFT+D";
    };
    "ThemePanel.apply" = {
      scope = "controls";
      template = "ENTER";
    };
    "ThemePanel.cancel" = {
      scope = "controls";
      template = "X";
    };
    "ThemePanel.columns" = {
      scope = "controls";
      template = "H/L";
    };
    "ThemePanel.page" = {
      scope = "controls";
      template = "U/D";
    };
    "ThemePanel.rows" = {
      scope = "controls";
      template = "J/K";
    };
    "ThemePanel.search" = {
      scope = "controls";
      template = "/";
    };
    "WallpaperPanel.columns" = {
      scope = "controls";
      template = "H/L";
    };
    "WallpaperPanel.default" = {
      scope = "controls";
      template = "R";
    };
    "WallpaperPanel.display" = {
      scope = "controls";
      template = "M";
    };
    "WallpaperPanel.fit" = {
      scope = "controls";
      template = "F";
    };
    "WallpaperPanel.page" = {
      scope = "controls";
      template = "U/D";
    };
    "WallpaperPanel.rows" = {
      scope = "controls";
      template = "J/K";
    };
    "WallpaperPanel.search" = {
      scope = "controls";
      template = "/";
    };
    "WallpaperPanel.set" = {
      scope = "controls";
      template = "ENTER";
    };
    "WeatherContent.calendar" = {
      scope = "weather";
      template = "C";
    };
    "WeatherContent.days" = {
      scope = "weather";
      template = "J/K";
    };
    "WeatherContent.refresh" = {
      scope = "weather";
      template = "R";
    };
    "WeatherSummary.forecast" = {
      scope = "calendar";
      template = "F";
    };
    "CommandPalette.confirm" = {
      scope = "palette";
      template = "ENTER";
    };
    "CommandPalette.help" = {
      scope = "palette";
      template = "?";
    };
    "MediaContent.legend.cycle_connected_media_players" = {
      scope = "media";
      template = "P";
    };
    "MediaContent.legend.esc" = {
      scope = "media";
      template = "ESC";
    };
    "MediaContent.legend.overlay_local_synchronised_lyrics_lrc" = {
      scope = "media";
      template = "Y";
    };
    "MediaContent.legend.previous_next_track" = {
      scope = "media";
      template = ", / .";
    };
    "MediaContent.legend.r" = {
      scope = "media";
      template = "R";
    };
    "MediaContent.legend.s" = {
      scope = "media";
      template = "S";
    };
    "MediaContent.legend.seek" = {
      scope = "media";
      template = "H/L · ←/→";
    };
    "MediaContent.legend.seek_1" = {
      scope = "media";
      template = "SPACE";
    };
    "MediaContent.legend.seek_interval" = {
      scope = "media";
      template = "- / +";
    };
    "MediaContent.legend.switch_visualizer" = {
      scope = "media";
      template = "V";
    };
    "MediaTransport.back" = {
      scope = "media";
      template = "H";
    };
    "MediaTransport.backCompact" = {
      scope = "media";
      template = "SHIFT+H";
    };
    "MediaTransport.forward" = {
      scope = "media";
      template = "L";
    };
    "MediaTransport.forwardCompact" = {
      scope = "media";
      template = "SHIFT+L";
    };
    "MediaTransport.next" = {
      scope = "media";
      template = ".";
    };
    "MediaTransport.play" = {
      scope = "media";
      template = "Space";
    };
    "MediaTransport.previous" = {
      scope = "media";
      template = ",";
    };
    "ResizeOverlay.legend.move" = {
      scope = "resize";
      template = "L";
    };
    "ResizeOverlay.legend.move_1" = {
      scope = "resize";
      template = "H";
    };
    "ResizeOverlay.legend.move_2" = {
      scope = "resize";
      template = "J";
    };
    "ResizeOverlay.legend.move_3" = {
      scope = "resize";
      template = "K";
    };
    "ShellExpansionHost.controlsPageDown" = {
      scope = "hub";
      template = "D";
    };
    "ShellExpansionHost.controlsPageUp" = {
      scope = "hub";
      template = "U";
    };
    "ShellExpansionHost.helpArrowDown" = {
      scope = "hub";
      template = "Down";
    };
    "ShellExpansionHost.helpArrowUp" = {
      scope = "hub";
      template = "Up";
    };
    "ShellExpansionHost.helpClose" = {
      scope = "hub";
      template = "Esc";
    };
    "ShellExpansionHost.helpDown" = {
      scope = "hub";
      template = "J";
    };
    "ShellExpansionHost.helpOpen" = {
      scope = "hub";
      template = "?";
    };
    "ShellExpansionHost.helpPageDown" = {
      scope = "hub";
      template = "D";
    };
    "ShellExpansionHost.helpPageUp" = {
      scope = "hub";
      template = "U";
    };
    "ShellExpansionHost.helpPgDown" = {
      scope = "hub";
      template = "PgDown";
    };
    "ShellExpansionHost.helpPgUp" = {
      scope = "hub";
      template = "PgUp";
    };
    "ShellExpansionHost.helpUp" = {
      scope = "hub";
      template = "K";
    };
    "ShellExpansionHost.legend.browse_forecast_days" = {
      scope = "hub";
      template = "H/L · J/K · ARROWS";
    };
    "ShellExpansionHost.legend.choose_visible_calendars" = {
      scope = "hub";
      template = "C";
    };
    "ShellExpansionHost.legend.close_home" = {
      scope = "hub";
      template = "ESC";
    };
    "ShellExpansionHost.legend.close_weather" = {
      scope = "hub";
      template = "ESC";
    };
    "ShellExpansionHost.legend.dismiss_selected_notification" = {
      scope = "hub";
      template = "DEL / BACKSPACE";
    };
    "ShellExpansionHost.legend.esc" = {
      scope = "hub";
      template = "ESC";
    };
    "ShellExpansionHost.legend.expand_group_or_open_selected_notification" = {
      scope = "hub";
      template = "E / ENTER";
    };
    "ShellExpansionHost.legend.go_to_today" = {
      scope = "hub";
      template = "T";
    };
    "ShellExpansionHost.legend.navigate_notifications" = {
      scope = "hub";
      template = "J/K · ↑/↓";
    };
    "ShellExpansionHost.legend.open_forecast" = {
      scope = "hub";
      template = "F / ENTER";
    };
    "ShellExpansionHost.legend.previous_next_day" = {
      scope = "hub";
      template = "H/L · ←/→";
    };
    "ShellExpansionHost.legend.previous_next_month" = {
      scope = "hub";
      template = "J/K · ↑/↓ · PGUP/PGDN";
    };
    "ShellExpansionHost.legend.refresh_agenda" = {
      scope = "hub";
      template = "R";
    };
    "ShellExpansionHost.legend.refresh_forecast" = {
      scope = "hub";
      template = "R";
    };
    "ShellExpansionHost.legend.return_to_calendar" = {
      scope = "hub";
      template = "C / BACKSPACE";
    };
    "ShellExpansionHost.legend.select_a_notification_group" = {
      scope = "hub";
      template = "H/L · ←/→";
    };
    "ShellExpansionHost.legend.toggle_read_mark_all_read" = {
      scope = "hub";
      template = "M / SHIFT+M";
    };
    "ShellExpansionHost.legend.toggle_silence_clear_history" = {
      scope = "hub";
      template = "S / C";
    };
    "ShellExpansionHost.pageDown" = {
      scope = "hub";
      template = "PgDown";
    };
    "ShellExpansionHost.pageUp" = {
      scope = "hub";
      template = "PgUp";
    };
    "ShellExpansionHost.stopRecording" = {
      scope = "hub";
      template = "Shift+Q";
    };
    "ShortcutCheatsheet.legend.focus_search" = {
      scope = "help";
      template = "/";
    };
    "ShortcutCheatsheet.legend.half_page_up_down" = {
      scope = "help";
      template = "U / D";
    };
    "ShortcutCheatsheet.legend.leave_search_then_close" = {
      scope = "help";
      template = "Esc";
    };
    "ShortcutCheatsheet.legend.scroll_by_page" = {
      scope = "help";
      template = "PgUp / PgDn";
    };
    "ShortcutCheatsheet.legend.scroll_down_up" = {
      scope = "help";
      template = "J / K";
    };
    "ShortcutCheatsheet.legend.switch_search_navigation" = {
      scope = "help";
      template = "Tab";
    };
    "ShortcutCheatsheet.legend.toggle_these_controls" = {
      scope = "help";
      template = "?";
    };
    "SystemContent.legend.activate_confirm" = {
      scope = "controls";
      template = "ENTER";
    };
    "SystemContent.legend.activate_open_submenu" = {
      scope = "controls";
      template = "ENTER / →";
    };
    "SystemContent.legend.activate_selected_setting_exit_parameter_focus" = {
      scope = "controls";
      template = "ENTER / ESC";
    };
    "SystemContent.legend.adjust_selected_level" = {
      scope = "controls";
      template = "H/L · ←/→";
    };
    "SystemContent.legend.advanced_network_editor" = {
      scope = "controls";
      template = "A";
    };
    "SystemContent.legend.alerts_stay_awake_power_profile" = {
      scope = "controls";
      template = "A / S / V";
    };
    "SystemContent.legend.apply_selected_theme_cancel_applying" = {
      scope = "controls";
      template = "ENTER / X";
    };
    "SystemContent.legend.apply_to_selected_output" = {
      scope = "controls";
      template = "ENTER";
    };
    "SystemContent.legend.back" = {
      scope = "controls";
      template = "← / ESC";
    };
    "SystemContent.legend.bluetooth_radio_discovery" = {
      scope = "controls";
      template = "B / SHIFT+D";
    };
    "SystemContent.legend.cancel_deletion_back_to_controls" = {
      scope = "controls";
      template = "ESC";
    };
    "SystemContent.legend.choose_audio_device_mute_microphone" = {
      scope = "controls";
      template = "P / X";
    };
    "SystemContent.legend.choose_monitor_all_outputs" = {
      scope = "controls";
      template = "M";
    };
    "SystemContent.legend.choose_theme_in_the_grid" = {
      scope = "controls";
      template = "H/J/K/L · ARROWS";
    };
    "SystemContent.legend.choose_thumbnail" = {
      scope = "controls";
      template = "H/J/K/L · ARROWS";
    };
    "SystemContent.legend.close" = {
      scope = "controls";
      template = "ESC";
    };
    "SystemContent.legend.confirm_move_to_trash" = {
      scope = "controls";
      template = "D · ENTER";
    };
    "SystemContent.legend.connect_disconnect" = {
      scope = "controls";
      template = "ENTER";
    };
    "SystemContent.legend.cycle_available_brightness_window_glass_and_night_light_sliders" = {
      scope = "controls";
      template = "TAB / SHIFT+TAB";
    };
    "SystemContent.legend.details_refresh_current_view" = {
      scope = "controls";
      template = "I / R";
    };
    "SystemContent.legend.edit_or_copy_selected_image" = {
      scope = "controls";
      template = "E / C";
    };
    "SystemContent.legend.esc" = {
      scope = "controls";
      template = "ESC";
    };
    "SystemContent.legend.esc_13" = {
      scope = "controls";
      template = "ESC";
    };
    "SystemContent.legend.esc_18" = {
      scope = "controls";
      template = "ESC";
    };
    "SystemContent.legend.esc_26" = {
      scope = "controls";
      template = "ESC";
    };
    "SystemContent.legend.esc_32" = {
      scope = "controls";
      template = "ESC";
    };
    "SystemContent.legend.esc_37" = {
      scope = "controls";
      template = "ESC";
    };
    "SystemContent.legend.fit_fill_reset" = {
      scope = "controls";
      template = "F / R";
    };
    "SystemContent.legend.h_l" = {
      scope = "controls";
      template = "H/L · ←/→";
    };
    "SystemContent.legend.hardware_display_brightness_and_volume_style_osd" = {
      scope = "controls";
      template = "BRIGHTNESS UP/DOWN";
      literal = true;
    };
    "SystemContent.legend.join_disconnect" = {
      scope = "controls";
      template = "ENTER";
    };
    "SystemContent.legend.move_half_a_page" = {
      scope = "controls";
      template = "U/D · PGUP/PGDN";
    };
    "SystemContent.legend.mute_selected_output_input_or_stream" = {
      scope = "controls";
      template = "M / ENTER";
    };
    "SystemContent.legend.mute_stream_mute_mic_choose_device" = {
      scope = "controls";
      template = "M / X / P";
    };
    "SystemContent.legend.navigate_actions" = {
      scope = "controls";
      template = "H/J/K/L · ARROWS";
    };
    "SystemContent.legend.night_light_warmer_cooler" = {
      scope = "controls";
      template = "T / - (⇧T) / +";
    };
    "SystemContent.legend.now_playing_application_mixer" = {
      scope = "controls";
      template = "N / SHIFT+M";
    };
    "SystemContent.legend.open_corresponding_system_control" = {
      scope = "controls";
      template = "Q/W/E/F/G/R/C";
    };
    "SystemContent.legend.open_selected_capture" = {
      scope = "controls";
      template = "ENTER / O";
    };
    "SystemContent.legend.page_selection" = {
      scope = "controls";
      template = "U/D · PGUP/PGDN";
    };
    "SystemContent.legend.pair_trust_forget" = {
      scope = "controls";
      template = "P / T / F";
    };
    "SystemContent.legend.play_pause_previous_next_media" = {
      scope = "controls";
      template = "SPACE / , / .";
    };
    "SystemContent.legend.refresh_captures" = {
      scope = "controls";
      template = "R";
    };
    "SystemContent.legend.refresh_now" = {
      scope = "controls";
      template = "R";
    };
    "SystemContent.legend.restore_defaults_then_confirm" = {
      scope = "controls";
      template = "SHIFT+C · ENTER";
    };
    "SystemContent.legend.scroll_controls" = {
      scope = "controls";
      template = "U/D · PGUP/PGDN";
    };
    "SystemContent.legend.search_themes" = {
      scope = "controls";
      template = "/";
    };
    "SystemContent.legend.search_wallpapers" = {
      scope = "controls";
      template = "/";
    };
    "SystemContent.legend.seek_backward_forward" = {
      scope = "controls";
      template = "SHIFT+H/L";
    };
    "SystemContent.legend.select_activate_tray_app" = {
      scope = "controls";
      template = "[ / ] · ENTER";
    };
    "SystemContent.legend.select_clip_half_page" = {
      scope = "controls";
      template = "J/K · U/⇧D · PGUP/PGDN";
    };
    "SystemContent.legend.select_device" = {
      scope = "controls";
      template = "J/K · U/D · PGUP/PGDN";
    };
    "SystemContent.legend.select_device_21" = {
      scope = "controls";
      template = "ESC";
    };
    "SystemContent.legend.select_item" = {
      scope = "controls";
      template = "J/K · U/D · PGUP/PGDN";
    };
    "SystemContent.legend.select_network" = {
      scope = "controls";
      template = "J/K · U/D · PGUP/PGDN";
    };
    "SystemContent.legend.select_output_input_or_stream_half_page" = {
      scope = "controls";
      template = "J/K · TAB/SHIFT+TAB · U/D · PGUP/PGDN";
    };
    "SystemContent.legend.shuffle_repeat_choose_player" = {
      scope = "controls";
      template = "Z / B / SHIFT+P";
    };
    "SystemContent.legend.spectrum_reactive_windows_glass_bar_frame_motion" = {
      scope = "controls";
      template = "SHIFT+F/G/D/R/A/S/E";
    };
    "SystemContent.legend.switch_between_sampled_resource_history_and_per_core_cpu_activity" = {
      scope = "controls";
      template = "C";
    };
    "SystemContent.legend.toggle_wi_fi_saved_connections" = {
      scope = "controls";
      template = "W / P";
    };
    "AdjustableSetting.level" = {
      scope = "controls";
      template = "H/L";
    };
    "AudioDeviceControl.chooser" = {
      scope = "controls";
      template = "P";
    };
    "AudioDeviceControl.mute" = {
      scope = "controls";
      template = "M";
    };
    "AudioDeviceControl.muteMicrophone" = {
      scope = "controls";
      template = "X";
    };
    "AudioStreamControl.mute" = {
      scope = "mixer";
      template = "M";
    };
    "ClipboardPanel.focusSearch" = {
      scope = "clipboard";
      template = "TAB";
    };
    "CommandPalette.legendEnter" = {
      scope = "palette";
      template = "ENTER";
    };
    "CommandPalette.legendModes" = {
      scope = "palette";
      template = "ALT+1–4";
    };
    "CommandPalette.legendPage" = {
      scope = "palette";
      template = "U/D";
    };
    "CommandPalette.legendSelect" = {
      scope = "palette";
      template = "J/K";
    };
    "CommandPalette.legendShiftEnter" = {
      scope = "palette";
      template = "SHIFT+ENTER";
    };
    "CommandPalette.legendTab" = {
      scope = "palette";
      template = "TAB";
    };
    "NotificationCard.dismiss" = {
      scope = "activity";
      template = "DEL";
    };
    "NotificationCard.history" = {
      scope = "activity";
      template = "ALT+H";
    };
    "NotificationCard.mark" = {
      scope = "activity";
      template = "M";
    };
    "NotificationCard.popup" = {
      scope = "activity";
      template = "ALT+P";
    };
    "NotificationCard.reply" = {
      scope = "activity";
      template = "R";
    };
    "NotificationCard.silent" = {
      scope = "activity";
      template = "ALT+S";
    };
    "NotificationCard.submit" = {
      scope = "activity";
      template = "ENTER";
    };
    "OpacitySetting.level" = {
      scope = "controls";
      template = "H/L";
    };
    "ScreenshotPicker.toggleRecord" = {
      scope = "capture";
      template = "Z";
    };
    "SystemContent.legend.slider_selection" = {
      scope = "controls";
      template = "J/K · TAB/SHIFT+TAB";
    };
    "SystemContent.legend.audio_selection" = {
      scope = "controls";
      template = "J/K · ↑/↓";
    };
  };
}

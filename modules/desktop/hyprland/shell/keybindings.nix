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

  inherit ((import ../keybindings.nix)) navigation;

  # Optional scope-specific slot overrides. Keep unrelated panels independent.
  overrides = { };

  # Action-specific assignments take precedence over shared slot defaults.
  # Changing an action must not silently remap every use of the same letter.
  actions = {
    "SystemContent.bar" = "SHIFT+A";
    "SystemContent.frame" = "SHIFT+S";
    "SystemContent.nightLight" = "T";
    "SystemContent.shellGlass" = "SHIFT+R";
    "SystemContent.vhsTune" = "SHIFT+V";
    "SystemContent.vhsToggle" = "ALT+V";
    "SystemContent.networkDetails" = "ALT+F";
    "SystemContent.bluetoothDetails" = "ALT+G";
    "SystemContent.alertsDetails" = "ALT+A";
    "SystemContent.stayDetails" = "ALT+S";
    "SystemContent.powerDetails" = "ALT+SHIFT+V";
    "SystemContent.windowsDetails" = "ALT+SHIFT+D";
    "SystemContent.glassDetails" = "ALT+SHIFT+R";
    "SystemContent.nightLightDetails" = "ALT+T";

  };

  # Action-owned keyhints. Display strings resolve their symbols through base
  # and scope overrides, not through duplicated labels in QML.
  hints =
    let
      # Assign a key once per action, grouped by the UI context that owns it.
      # Only unusual hints need a structured value.
      byScope = {
        activity = {
          "NotificationCard.dismiss" = "DEL";
          "NotificationCard.history" = "ALT+H";
          "NotificationCard.mark" = "M";
          "NotificationCard.popup" = "ALT+P";
          "NotificationCard.reply" = "R";
          "NotificationCard.silent" = "ALT+S";
          "NotificationCard.submit" = "ENTER";
          "NotificationContent.clearAll" = "C";
          "NotificationContent.expand" = "E";
          "NotificationContent.groups" = "NAV_HORIZONTAL";
          "NotificationContent.history" = "SHIFT+H";
          "NotificationContent.markAllRead" = "SHIFT+M";
          "NotificationContent.markAllUnread" = "SHIFT+N";
          "NotificationContent.navigate" = "NAV_VERTICAL";
          "NotificationContent.presentation" = "P";
          "NotificationContent.silent" = "S";
        };
        calendar = {
          "CalendarContent.calendars" = "C";
          "CalendarContent.closeCalendars" = "ESC";
          "CalendarContent.days" = "NAV_HORIZONTAL";
          "CalendarContent.events" = "U/D";
          "CalendarContent.months" = "NAV_VERTICAL · PGUP/PGDN";
          "CalendarContent.selectCalendar" = "NAV_VERTICAL";
          "CalendarContent.today" = "T";
          "CalendarContent.toggleCalendar" = "SPACE";
          "WeatherSummary.forecast" = "F";
        };
        capture = {
          "ScreenshotPicker.cancel" = "ESC";
          "ScreenshotPicker.capture" = "ENTER";
          "ScreenshotPicker.display" = "TAB";
          "ScreenshotPicker.edit" = "E";
          "ScreenshotPicker.full" = "F";
          "ScreenshotPicker.move" = "NAV_ALL";
          "ScreenshotPicker.resize" = "NAV_ALL_SHIFT";
          "ScreenshotPicker.toggleRecord" = "Z";
        };
        clipboard = {
          "ClipboardPanel.actionMenu" = "ALT+ENTER";
          "ClipboardPanel.close" = "ESC";
          "ClipboardPanel.copy" = "ENTER";
          "ClipboardPanel.focusSearch" = "TAB";
          "ClipboardPanel.halfPage" = "U/D · PGUP/PGDN";
          "ClipboardPanel.navigateList" = "NAV_VERTICAL";
          "ClipboardPanel.navigateSearch" = "NAV_VERTICAL_ARROWS";
        };
        controls = {
          "AdjustableSetting.level" = "NAV_HORIZONTAL";
          "AudioDeviceControl.chooser" = "P";
          "AudioDeviceControl.mute" = "M";
          "AudioDeviceControl.muteMicrophone" = "X";
          "AudioMixerContent.open" = "SHIFT+M";
          "BluetoothPanel.activate" = "ENTER";
          "BluetoothPanel.forget" = "F";
          "BluetoothPanel.pair" = "P";
          "BluetoothPanel.radio" = "B";
          "BluetoothPanel.scan" = "SHIFT+D";
          "BluetoothPanel.select" = "NAV_VERTICAL";
          "BluetoothPanel.trust" = "T";
          "ControlsMediaCard.open" = "N";
          "ControlsMediaCard.repeat" = "B";
          "ControlsMediaCard.shuffle" = "Z";
          "NetworkPanel.advanced" = "A";
          "NetworkPanel.connect" = "ENTER";
          "NetworkPanel.connectNetwork" = "ENTER";
          "NetworkPanel.connectProfile" = "ENTER";
          "NetworkPanel.detail" = "V";
          "NetworkPanel.listScroll" = "NAV_VERTICAL";
          "NetworkPanel.passwordCancel" = "ESC";
          "NetworkPanel.passwordSubmit" = "ENTER";
          "NetworkPanel.refresh" = "R";
          "NetworkPanel.saved" = "P";
          "NetworkPanel.select" = "NAV_VERTICAL";
          "NetworkPanel.toggleWifi" = "W";
          "OpacitySetting.level" = "NAV_HORIZONTAL";
          "RecordingLibrary.choose" = "NAV_VERTICAL";
          "RecordingLibrary.copy" = "C";
          "RecordingLibrary.delete" = "D";
          "RecordingLibrary.edit" = "E";
          "RecordingLibrary.extend" = "NAV_HORIZONTAL_SHIFT";
          "RecordingLibrary.ocr" = "SHIFT+O";
          "RecordingLibrary.open" = "ENTER";
          "RecordingLibrary.page" = "U/D";
          "RecordingLibrary.refresh" = "R";
          "RecordingLibrary.word" = "NAV_HORIZONTAL";
          "ResourceDashboard.refresh" = "R";
          "ResourceDashboard.toggleCores" = "C";
          "SessionPanel.confirm" = "ENTER";
          "SessionPanel.lock" = "Q";
          "SessionPanel.logout" = "E";
          "SessionPanel.move" = "NAV_ALL";
          "SessionPanel.reboot" = "A";
          "SessionPanel.restoreWindows" = "D";
          "SessionPanel.shutdown" = "S";
          "SessionPanel.suspend" = "W";
          "SettingsDetail.toggle" = "T";
          "SettingsDetail.blur" = "B";
          "SettingsDetail.reset" = "R";
          "SettingsDetail.adjust" = "NAV_HORIZONTAL";
          "SettingsDetail.presentation" = "P";
          "SettingsDetail.history" = "Y";
          "SystemContent.alerts" = "A";
          "SystemContent.audioAdjust" = "NAV_HORIZONTAL";
          "SystemContent.audioLevel" = "NAV_HORIZONTAL";
          "SystemContent.audioSelect" = "NAV_VERTICAL";
          "SystemContent.bluetooth" = "G";
          "SystemContent.captures" = "C";
          "SystemContent.displays" = "D";
          "SystemContent.legend.activate_confirm" = "ENTER";
          "SystemContent.legend.activate_open_submenu" = "ENTER / →";
          "SystemContent.legend.activate_selected_setting_exit_parameter_focus" = "ENTER / ESC";
          "SystemContent.legend.adjust_selected_level" = "NAV_HORIZONTAL";
          "SystemContent.legend.advanced_network_editor" = "A";
          "SystemContent.legend.alerts_stay_awake_power_profile" = "A / S / V";
          "SystemContent.legend.apply_selected_theme_cancel_applying" = "ENTER / X";
          "SystemContent.legend.apply_to_selected_output" = "ENTER";
          "SystemContent.legend.audio_selection" = "NAV_VERTICAL";
          "SystemContent.legend.back" = "← / ESC";
          "SystemContent.legend.bluetooth_radio_discovery" = "B / SHIFT+D";
          "SystemContent.legend.cancel_deletion_back_to_controls" = "ESC";
          "SystemContent.legend.choose_audio_device_mute_microphone" = "P / X";
          "SystemContent.legend.choose_monitor_all_outputs" = "M";
          "SystemContent.legend.choose_theme_in_the_grid" = "NAV_ALL";
          "SystemContent.legend.choose_thumbnail" = "NAV_ALL";
          "SystemContent.legend.close" = "ESC";
          "SystemContent.legend.confirm_move_to_trash" = "D · ENTER";
          "SystemContent.legend.connect_disconnect" = "ENTER";
          "SystemContent.legend.cycle_available_brightness_window_glass_and_night_light_sliders" =
            "TAB / SHIFT+TAB";
          "SystemContent.legend.details_refresh_current_view" = "I / R";
          "SystemContent.legend.edit_or_copy_selected_image" = "E / C";
          "SystemContent.legend.esc" = "ESC";
          "SystemContent.legend.esc_13" = "ESC";
          "SystemContent.legend.esc_18" = "ESC";
          "SystemContent.legend.esc_26" = "ESC";
          "SystemContent.legend.esc_32" = "ESC";
          "SystemContent.legend.esc_37" = "ESC";
          "SystemContent.legend.fit_fill_reset" = "F / R";
          "SystemContent.legend.h_l" = "NAV_HORIZONTAL";
          "SystemContent.legend.hardware_display_brightness_and_volume_style_osd" = {
            template = "BRIGHTNESS UP/DOWN";
            literal = true;
          };
          "SystemContent.legend.join_disconnect" = "ENTER";
          "SystemContent.legend.move_half_a_page" = "U/D · PGUP/PGDN";
          "SystemContent.legend.mute_selected_output_input_or_stream" = "M / ENTER";
          "SystemContent.legend.mute_stream_mute_mic_choose_device" = "M / X / P";
          "SystemContent.legend.navigate_actions" = "NAV_ALL";
          "SystemContent.legend.night_light_warmer_cooler" = "T / - (⇧T) / +";
          "SystemContent.legend.open_corresponding_system_control" = "Q/W/E/F/G/R/C/D/I";
          "SystemContent.legend.open_selected_capture" = "ENTER / O";
          "SystemContent.legend.page_selection" = "U/D · PGUP/PGDN";
          "SystemContent.legend.pair_trust_forget" = "P / T / F";
          "SystemContent.legend.play_pause_previous_next_media" = "SPACE / , / .";
          "SystemContent.legend.refresh_captures" = "R";
          "SystemContent.legend.refresh_now" = "R";
          "SystemContent.legend.restore_defaults_then_confirm" = "SHIFT+C · ENTER";
          "SystemContent.legend.scroll_controls" = "U/D · PGUP/PGDN";
          "SystemContent.legend.search_themes" = "/";
          "SystemContent.legend.search_wallpapers" = "/";
          "SystemContent.legend.seek_backward_forward" = "NAV_HORIZONTAL_PRIMARY_SHIFT";
          "SystemContent.legend.select_activate_tray_app" = "[ / ] · ENTER";
          "SystemContent.legend.select_clip_half_page" = "NAV_VERTICAL · U/⇧D · PGUP/PGDN";
          "SystemContent.legend.select_device" = "NAV_VERTICAL · U/D · PGUP/PGDN";
          "SystemContent.legend.select_device_21" = "ESC";
          "SystemContent.legend.select_item" = "NAV_VERTICAL · U/D · PGUP/PGDN";
          "SystemContent.legend.select_network" = "NAV_VERTICAL · U/D · PGUP/PGDN";
          "SystemContent.legend.select_output_input_or_stream_half_page" =
            "NAV_VERTICAL · TAB/SHIFT+TAB · U/D · PGUP/PGDN";
          "SystemContent.legend.shuffle_repeat_choose_player" = "Z / B / SHIFT+P";
          "SystemContent.legend.slider_selection" = "NAV_VERTICAL · TAB/SHIFT+TAB";
          "SystemContent.legend.spectrum_reactive_windows_glass_bar_frame_motion" = "SHIFT+F/G/D/R/A/S/E";
          "SystemContent.legend.switch_between_sampled_resource_history_and_per_core_cpu_activity" = "C";
          "SystemContent.legend.toggle_wi_fi_saved_connections" = "W / P";
          "SystemContent.motion" = "SHIFT+E";
          "SystemContent.musicReactive" = "SHIFT+G";
          "SystemContent.network" = "F";
          "SystemContent.powerProfile" = "V";
          "SystemContent.reset" = "SHIFT+C";
          "SystemContent.resetCancel" = "ESC";
          "SystemContent.resetConfirm" = "ENTER";
          "SystemContent.resources" = "R";
          "SystemContent.rowSelect" = "NAV_VERTICAL";
          "SystemContent.session" = "E";
          "SystemContent.statusInspection" = "SHIFT+I";
          "SystemContent.stayAwake" = "S";
          "SystemContent.tabSelect" = "TAB";
          "SystemContent.themes" = "Q";
          "SystemContent.trayNavigate" = "[ / ]";
          "SystemContent.trayOpen" = "ENTER";
          "SystemContent.wallpaper" = "W";
          "SystemContent.wallpaperSpectrum" = "SHIFT+F";
          "VhsPanel.adjust" = "NAV_HORIZONTAL";
          "VhsPanel.toggle" = "T";
          "VhsPanel.select" = "NAV_VERTICAL · TAB/SHIFT+TAB";
          "SystemContent.windowTransparency" = "SHIFT+D";
          "ThemePanel.apply" = "ENTER";
          "ThemePanel.cancel" = "X";
          "ThemePanel.columns" = "NAV_HORIZONTAL";
          "ThemePanel.page" = "U/D";
          "ThemePanel.rows" = "NAV_VERTICAL";
          "ThemePanel.search" = "/";
          "WallpaperPanel.columns" = "NAV_HORIZONTAL";
          "WallpaperPanel.default" = "R";
          "WallpaperPanel.display" = "M";
          "WallpaperPanel.fit" = "F";
          "WallpaperPanel.page" = "U/D";
          "WallpaperPanel.rows" = "NAV_VERTICAL";
          "WallpaperPanel.search" = "/";
          "WallpaperPanel.set" = "ENTER";
        };
        help = {
          "ShortcutCheatsheet.back" = "ESC";
          "ShortcutCheatsheet.close" = "ESC";
          "ShortcutCheatsheet.halfPage" = "U/D";
          "ShortcutCheatsheet.legend.focus_search" = "/";
          "ShortcutCheatsheet.legend.half_page_up_down" = "U / D";
          "ShortcutCheatsheet.legend.leave_search_then_close" = "Esc";
          "ShortcutCheatsheet.legend.scroll_by_page" = "PgUp / PgDn";
          "ShortcutCheatsheet.legend.scroll_down_up" = "NAV_VERTICAL";
          "ShortcutCheatsheet.legend.switch_search_navigation" = "Tab";
          "ShortcutCheatsheet.legend.toggle_these_controls" = "?";
          "ShortcutCheatsheet.navigate" = "TAB";
          "ShortcutCheatsheet.page" = "PGUP/PGDN";
          "ShortcutCheatsheet.scroll" = "NAV_VERTICAL";
          "ShortcutCheatsheet.scrollSearch" = "NAV_VERTICAL_ARROWS";
          "ShortcutCheatsheet.search" = "/";
        };
        hub = {
          "HubTabs.help" = "?";
          "ShellExpansionHost.back" = "ESC";
          "ShellExpansionHost.closeAll" = "SHIFT+ESC";
          "ShellExpansionHost.controlsPageDown" = "D";
          "ShellExpansionHost.controlsPageUp" = "U";
          "ShellExpansionHost.helpArrowDown" = "NAV_KEY_DOWN_ARROW";
          "ShellExpansionHost.helpArrowUp" = "NAV_KEY_UP_ARROW";
          "ShellExpansionHost.helpClose" = "Esc";
          "ShellExpansionHost.helpDown" = "NAV_KEY_DOWN_PRIMARY";
          "ShellExpansionHost.helpOpen" = "?";
          "ShellExpansionHost.helpPage" = "U/D · PGUP/PGDN";
          "ShellExpansionHost.helpPageDown" = "D";
          "ShellExpansionHost.helpPageUp" = "U";
          "ShellExpansionHost.helpPgDown" = "PgDown";
          "ShellExpansionHost.helpPgUp" = "PgUp";
          "ShellExpansionHost.helpScroll" = "NAV_VERTICAL";
          "ShellExpansionHost.helpUp" = "NAV_KEY_UP_PRIMARY";
          "ShellExpansionHost.legend.browse_forecast_days" = "NAV_ALL";
          "ShellExpansionHost.legend.choose_visible_calendars" = "C";
          "ShellExpansionHost.legend.close_home" = "ESC";
          "ShellExpansionHost.legend.close_weather" = "ESC";
          "ShellExpansionHost.legend.dismiss_selected_notification" = "DEL / BACKSPACE";
          "ShellExpansionHost.legend.esc" = "ESC";
          "ShellExpansionHost.legend.expand_group_or_open_selected_notification" = "E / ENTER";
          "ShellExpansionHost.legend.go_to_today" = "T";
          "ShellExpansionHost.legend.navigate_notifications" = "NAV_VERTICAL";
          "ShellExpansionHost.legend.open_forecast" = "F / ENTER";
          "ShellExpansionHost.legend.previous_next_day" = "NAV_HORIZONTAL";
          "ShellExpansionHost.legend.previous_next_month" = "NAV_VERTICAL · PGUP/PGDN";
          "ShellExpansionHost.legend.refresh_agenda" = "R";
          "ShellExpansionHost.legend.refresh_forecast" = "R";
          "ShellExpansionHost.legend.return_to_calendar" = "C / BACKSPACE";
          "ShellExpansionHost.legend.select_a_notification_group" = "NAV_HORIZONTAL";
          "ShellExpansionHost.legend.toggle_read_mark_all_read" = "M / SHIFT+M";
          "ShellExpansionHost.legend.toggle_silence_clear_history" = "S / C";
          "ShellExpansionHost.page" = "PGUP/PGDN";
          "ShellExpansionHost.pageDown" = "PgDown";
          "ShellExpansionHost.pageUp" = "PgUp";
          "ShellExpansionHost.scroll" = "U/D";
          "ShellExpansionHost.stopRecording" = "Shift+Q";
        };
        media = {
          "MediaContent.legend.cycle_connected_media_players" = "P";
          "MediaContent.legend.esc" = "ESC";
          "MediaContent.legend.overlay_local_synchronised_lyrics_lrc" = "Y";
          "MediaContent.legend.previous_next_track" = ", / .";
          "MediaContent.legend.r" = "R";
          "MediaContent.legend.s" = "S";
          "MediaContent.legend.seek" = "NAV_HORIZONTAL";
          "MediaContent.legend.seek_1" = "SPACE";
          "MediaContent.legend.seek_interval" = "- / +";
          "MediaContent.legend.switch_visualizer" = "V";
          "MediaContent.longer" = "+";
          "MediaContent.lyrics" = "Y";
          "MediaContent.player" = "P";
          "MediaContent.repeat" = "R";
          "MediaContent.shorter" = "-";
          "MediaContent.shuffle" = "S";
          "MediaContent.visualizer" = "V";
          "MediaTransport.back" = "NAV_KEY_LEFT_PRIMARY";
          "MediaTransport.backCompact" = "NAV_KEY_LEFT_PRIMARY_SHIFT";
          "MediaTransport.forward" = "NAV_KEY_RIGHT_PRIMARY";
          "MediaTransport.forwardCompact" = "NAV_KEY_RIGHT_PRIMARY_SHIFT";
          "MediaTransport.next" = ".";
          "MediaTransport.play" = "Space";
          "MediaTransport.previous" = ",";
        };
        mixer = {
          "AudioMixerContent.level" = "NAV_HORIZONTAL";
          "AudioMixerContent.select" = "NAV_VERTICAL";
          "AudioStreamControl.mute" = "M";
        };
        overview = {
          "OverviewPanel.all" = "A";
          "OverviewPanel.close" = "ESC";
          "OverviewPanel.destination" = "1–0";
          "OverviewPanel.move" = "M";
          "OverviewPanel.moveCancel" = "ESC";
          "OverviewPanel.moveConfirm" = "ENTER";
          "OverviewPanel.navigate" = "NAV_ALL";
          "OverviewPanel.open" = "ENTER";
          "OverviewPanel.target" = "NAV_HORIZONTAL";
          "OverviewPanel.toggleFloating" = "F";
          "OverviewPanel.togglePin" = "P";
          "OverviewPanel.workspace" = "1–0";
        };
        palette = {
          "CommandPalette.actionMenu" = "ALT+ENTER";
          "CommandPalette.actions" = "ALT+3";
          "CommandPalette.apps" = "ALT+2";
          "CommandPalette.back" = "ESC";
          "CommandPalette.closeAll" = "SHIFT+ESC";
          "CommandPalette.confirm" = "ENTER";
          "CommandPalette.emoji" = "ALT+4";
          "CommandPalette.execute" = "ENTER";
          "CommandPalette.help" = "?";
          "CommandPalette.legendEnter" = "ENTER";
          "CommandPalette.legendModes" = "ALT+1–4";
          "CommandPalette.legendPage" = "U/D";
          "CommandPalette.legendSelect" = "NAV_VERTICAL";
          "CommandPalette.legendShiftEnter" = "SHIFT+ENTER";
          "CommandPalette.legendTab" = "TAB";
          "CommandPalette.navigate" = "TAB";
          "CommandPalette.navigateSearch" = "NAV_VERTICAL_ARROWS";
          "CommandPalette.pageResults" = "U/D";
          "CommandPalette.resultActions" = "ALT+ENTER";
          "CommandPalette.resultBack" = "ESC";
          "CommandPalette.select" = "NAV_VERTICAL";
          "CommandPalette.selectResults" = "NAV_VERTICAL";
          "CommandPalette.unified" = "ALT+1";
        };
        polkit = {
          "PolkitDialog.authorize" = "ENTER";
          "PolkitDialog.cancel" = "ESC";
          "PolkitDialog.identity" = "I";
        };
        resize = {
          "ResizeOverlay.balance" = "B";
          "ResizeOverlay.done" = "ESC";
          "ResizeOverlay.inspect" = "S";
          "ResizeOverlay.legend.move" = "NAV_KEY_RIGHT_PRIMARY";
          "ResizeOverlay.legend.move_1" = "NAV_KEY_LEFT_PRIMARY";
          "ResizeOverlay.legend.move_2" = "NAV_KEY_DOWN_PRIMARY";
          "ResizeOverlay.legend.move_3" = "NAV_KEY_UP_PRIMARY";
          "ResizeOverlay.reverse" = "SHIFT";
        };
        status = {
          "StatusContent.close" = "ESC";
          "StatusContent.refresh" = "R";
        };
        weather = {
          "WeatherContent.calendar" = "C";
          "WeatherContent.days" = "NAV_ALL";
          "WeatherContent.refresh" = "R";
        };
      };
    in
    builtins.listToAttrs (
      builtins.concatMap (
        scope:
        map (
          action:
          let
            binding = byScope.${scope}.${action};
          in
          {
            name = action;
            value = {
              inherit scope;
            }
            // (if builtins.isAttrs binding then binding else { template = binding; });
          }
        ) (builtins.attrNames byScope.${scope})
      ) (builtins.attrNames byScope)
    );
}

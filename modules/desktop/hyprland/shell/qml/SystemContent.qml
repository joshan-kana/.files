pragma ComponentBehavior: Bound
import QtQuick
import "DesktopIcons.js" as DesktopIcons
import Quickshell
import Quickshell.Io

FocusScope {
    id: root

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property AppearancePreferences appearance
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
    required property bool frameVisible
    required property bool windowTransparencyEnabled
    required property bool shellGlassEnabled

    signal wallpaperSpectrumToggleRequested
    signal musicReactiveToggleRequested
    signal barToggleRequested
    signal frameToggleRequested
    signal windowTransparencyToggleRequested
    signal shellGlassToggleRequested
    signal restoreDefaultsRequested

    property bool engaged: false
    property bool mixerOpen: false
    property real dashboardWidthBudget: theme.controlsDetailWidth
    readonly property int dashboardTileHeight: 72
    readonly property int dashboardBrightnessHeight: 90
    readonly property bool detailsVisible: trayMenu.open || networkPanel.open || bluetoothPanel.open || themePanel.open || wallpaperPanel.open || sessionPanel.open || resourcesPanel.open || mixerOpen || recordingsPanel.open
    property bool resetConfirmPending: false
    property bool resetRunning: false
    property string resetStatus: ""
    property var resetOutputs: []
    property int resetIndex: 0

    Process {
        id: wallpaperReset
        onExited: (code, status) => {
            if (code !== 0) {
                root.resetRunning = false;
                root.resetStatus = "Wallpaper reset failed. Other preferences were restored.";
                return;
            }
            root.resetIndex++;
            root.resetNextWallpaper();
        }
    }

    function startDefaultReset(): void {
        if (!resetConfirmPending || resetRunning)
            return;
        resetConfirmPending = false;
        resetRunning = true;
        resetStatus = "Restoring declared desktop preferences…";
        restoreDefaultsRequested();
        sessionPanel.invoke("resetToDeclared");
        notificationState.resetToDeclared();
        resetOutputs = Quickshell.screens.map(screen => screen.name).filter(name => !!name).concat(["all"]);
        resetIndex = 0;
        resetNextWallpaper();
    }

    function resetNextWallpaper(): void {
        if (resetIndex >= resetOutputs.length) {
            resetRunning = false;
            resetStatus = "Declared desktop defaults restored";
            return;
        }
        if (!runtime.wallpaperLibrary) {
            resetRunning = false;
            resetStatus = "Wallpaper reset unavailable. Other preferences were restored.";
            return;
        }
        wallpaperReset.exec([runtime.wallpaperLibrary, "reset", resetOutputs[resetIndex]]);
    }

    property string requestedView: ""
    required property bool returnToControls
    property bool helpOpen: false
    property int trayIndex: 0
    // One Controls-wide slider selection mode. Tab cycles only available
    // sliders; H/L and arrows edit the selected value without stealing the
    // existing audio keys outside this mode.
    property string selectedSlider: ""
    readonly property bool sliderNavigationEnabled: engaged && !resetConfirmPending && !helpOpen && !mixerOpen && !audioChooserOpen && !themeOpen && !wallpaperOpen && !sessionOpen && !networkOpen && !bluetoothOpen && !resourcesOpen && !recordingsOpen && !trayMenuOpen
    readonly property var sliderTargets: (brightness.supported ? ["brightness"] : []).concat(["windows", "glass"], nightLight.supported ? ["nightLight"] : [])

    function selectSlider(target: string): void {
        selectedSlider = target;
        keyboardFocus.forceActiveFocus();
    }

    function cycleSlider(direction: int): void {
        const targets = sliderTargets;
        if (!targets.length)
            return;
        const index = targets.indexOf(selectedSlider);
        selectedSlider = targets[(index < 0 ? (direction > 0 ? 0 : targets.length - 1) : (index + direction + targets.length) % targets.length)];
        keyboardFocus.forceActiveFocus();
    }

    function adjustSlider(direction: int): void {
        if (selectedSlider === "brightness" && brightness.supported)
            brightness.adjust(direction * 5);
        else if (selectedSlider === "windows")
            appearance.setWindowOpacity(Math.max(0.20, Math.min(1, Math.round((appearance.windowOpacity + direction * 0.05) * 100) / 100)));
        else if (selectedSlider === "glass")
            appearance.setGlassOpacity(Math.max(0.20, Math.min(1, Math.round((appearance.glassOpacity + direction * 0.05) * 100) / 100)));
        else if (selectedSlider === "nightLight" && nightLight.supported)
            nightLight.adjustTemperature(direction * 200);
    }

    function activateSlider(): void {
        if (selectedSlider === "windows")
            windowTransparencyToggleRequested();
        else if (selectedSlider === "glass")
            shellGlassToggleRequested();
        else if (selectedSlider === "nightLight")
            nightLight.toggle();
        else if (selectedSlider === "brightness")
            brightness.refresh();
    }
    readonly property bool audioChooserOpen: audioDeck.deviceChooserOpen

    readonly property bool trayMenuOpen: trayMenu.open
    readonly property int trayMenuItemCount: trayMenu.itemCount
    readonly property bool networkOpen: networkPanel.open
    readonly property bool networkPasswordPending: networkPanel.open && networkPanel.passwordPrompt
    readonly property bool recordingDeletePending: recordingsPanel.open && recordingsPanel.deletePending.length > 0
    readonly property bool detailSearchFocused: (themePanel.open && themePanel.panel && themePanel.panel.searching) || (wallpaperPanel.open && wallpaperPanel.panel && wallpaperPanel.panel.searching)
    readonly property bool bluetoothOpen: bluetoothPanel.open
    readonly property bool themeOpen: themePanel.open
    readonly property bool themeOperationRunning: themePanel.open && themePanel.operationRunning
    readonly property bool wallpaperOpen: wallpaperPanel.open
    readonly property bool wallpaperOperationRunning: wallpaperPanel.open && wallpaperPanel.busy
    readonly property bool captureEditorRequestRunning: recordingsPanel.open && recordingsPanel.editorRequestRunning
    // Only foreground actions with an observable lifetime use the shared busy
    // contour. Passive scans, polling and gallery incubation stay local.
    readonly property bool maintenanceOperationRunning: resetRunning || (networkPanel.open && networkPanel.profileActionRunning) || (recordingsPanel.open && recordingsPanel.captureTrashRunning)
    readonly property string maintenanceOperationRole: recordingsPanel.open && recordingsPanel.captureTrashRunning ? "capture" : networkPanel.open && networkPanel.profileActionRunning ? "connectivity" : ""
    readonly property bool sessionOpen: sessionPanel.open
    readonly property bool sessionConfirmationPending: sessionPanel.open && sessionPanel.armedAction.length > 0
    readonly property bool resourcesOpen: resourcesPanel.open
    readonly property bool recordingsOpen: recordingsPanel.open
    readonly property string helpTitle: recordingsPanel.open ? "Captures" : wallpaperPanel.open ? "Wallpaper library" : mixerOpen ? "Application mixer" : resourcesPanel.open ? "Resource monitor" : (bluetoothPanel.open ? "Bluetooth controls" : (networkPanel.open ? "Network controls" : (themePanel.open ? "Theme controls" : (sessionPanel.open ? "Session controls" : (trayMenu.open ? "Tray menu controls" : "System controls")))))
    readonly property var helpBindings: recordingsPanel.open ? [
        {
            key: root.runtime.shellHint("SystemContent.legend.select_clip_half_page"),
            action: "Select clip / half-page"
        },
        {
            key: root.runtime.shellHint("SystemContent.legend.open_selected_capture"),
            action: "Open selected capture"
        },
        {
            key: root.runtime.shellHint("SystemContent.legend.edit_or_copy_selected_image"),
            action: "Edit or copy selected image"
        },
        {
            key: root.runtime.shellHint("SystemContent.legend.confirm_move_to_trash"),
            action: "Confirm move to Trash"
        },
        {
            key: root.runtime.shellHint("SystemContent.legend.refresh_captures"),
            action: "Refresh captures"
        },
        {
            key: root.runtime.shellHint("SystemContent.legend.cancel_deletion_back_to_controls"),
            action: "Cancel deletion / back to Controls"
        }
    ] : wallpaperPanel.open ? [
        {
            key: root.runtime.shellHint("SystemContent.legend.choose_thumbnail"),
            action: "Choose thumbnail"
        },
        {
            key: root.runtime.shellHint("SystemContent.legend.page_selection"),
            action: "Page selection"
        },
        {
            key: root.runtime.shellHint("SystemContent.legend.search_wallpapers"),
            action: "Search wallpapers"
        },
        {
            key: root.runtime.shellHint("SystemContent.legend.apply_to_selected_output"),
            action: "Apply to selected output"
        },
        {
            key: root.runtime.shellHint("SystemContent.legend.choose_monitor_all_outputs"),
            action: "Choose monitor / all outputs"
        },
        {
            key: root.runtime.shellHint("SystemContent.legend.fit_fill_reset"),
            action: "Fit/fill / reset"
        },
        {
            key: root.runtime.shellHint("SystemContent.legend.esc_13"),
            action: root.returnToControls ? "Back to Controls" : "Close"
        }
    ] : mixerOpen ? [
        {
            key: root.runtime.shellHint("SystemContent.legend.select_output_input_or_stream_half_page"),
            action: "Select output, input or stream / half page"
        },
        {
            key: root.runtime.shellHint("SystemContent.legend.adjust_selected_level"),
            action: "Adjust selected level"
        },
        {
            key: root.runtime.shellHint("SystemContent.legend.mute_selected_output_input_or_stream"),
            action: "Mute selected output, input or stream"
        },
        {
            key: root.runtime.shellHint("SystemContent.legend.choose_audio_device_mute_microphone"),
            action: "Choose audio device / mute microphone"
        },
        {
            key: root.runtime.shellHint("SystemContent.legend.esc_18"),
            action: root.returnToControls ? "Back to Controls" : "Close"
        }
    ] : resourcesPanel.open ? [
        {
            key: root.runtime.shellHint("SystemContent.legend.switch_between_sampled_resource_history_and_per_core_cpu_activity"),
            action: "Switch between sampled resource history and per-core CPU activity"
        },
        {
            key: root.runtime.shellHint("SystemContent.legend.refresh_now"),
            action: "Refresh now"
        },
        {
            key: root.runtime.shellHint("SystemContent.legend.select_device_21"),
            action: root.returnToControls ? "Back to Controls" : "Close"
        }
    ] : bluetoothPanel.open ? [
        {
            key: root.runtime.shellHint("SystemContent.legend.select_device"),
            action: "Select device"
        },
        {
            key: root.runtime.shellHint("SystemContent.legend.connect_disconnect"),
            action: "Connect / disconnect"
        },
        {
            key: root.runtime.shellHint("SystemContent.legend.bluetooth_radio_discovery"),
            action: "Bluetooth radio / discovery"
        },
        {
            key: root.runtime.shellHint("SystemContent.legend.pair_trust_forget"),
            action: "Pair / trust / forget"
        },
        {
            key: root.runtime.shellHint("SystemContent.legend.esc_26"),
            action: root.returnToControls ? "Back to Controls" : "Close"
        }
    ] : (networkPanel.open ? [
            {
                key: root.runtime.shellHint("SystemContent.legend.select_network"),
                action: "Select network"
            },
            {
                key: root.runtime.shellHint("SystemContent.legend.join_disconnect"),
                action: "Join / disconnect"
            },
            {
                key: root.runtime.shellHint("SystemContent.legend.toggle_wi_fi_saved_connections"),
                action: "Toggle Wi-Fi / saved connections"
            },
            {
                key: root.runtime.shellHint("SystemContent.legend.details_refresh_current_view"),
                action: "Details / refresh current view"
            },
            {
                key: root.runtime.shellHint("SystemContent.legend.advanced_network_editor"),
                action: "Advanced network editor"
            },
            {
                key: root.runtime.shellHint("SystemContent.legend.esc_32"),
                action: root.returnToControls ? "Back to Controls" : "Close"
            }
        ] : (themePanel.open ? [
                {
                    key: root.runtime.shellHint("SystemContent.legend.choose_theme_in_the_grid"),
                    action: "Choose theme in the grid"
                },
                {
                    key: root.runtime.shellHint("SystemContent.legend.move_half_a_page"),
                    action: "Move half a page"
                },
                {
                    key: root.runtime.shellHint("SystemContent.legend.search_themes"),
                    action: "Search themes"
                },
                {
                    key: root.runtime.shellHint("SystemContent.legend.apply_selected_theme_cancel_applying"),
                    action: "Apply selected theme / cancel applying"
                },
                {
                    key: root.runtime.shellHint("SystemContent.legend.esc_37"),
                    action: root.returnToControls ? "Back to Controls" : "Close"
                }
            ] : (sessionPanel.open ? [
                    {
                        key: root.runtime.shellHint("SystemContent.legend.navigate_actions"),
                        action: "Navigate actions"
                    },
                    {
                        key: sessionPanel.actionShortcutLegend,
                        action: "Activate the matching session tile (confirm power actions twice)"
                    },
                    {
                        key: root.runtime.shellHint("SystemContent.legend.activate_confirm"),
                        action: "Activate / confirm"
                    },
                    {
                        key: root.runtime.shellHint("SystemContent.legend.esc"),
                        action: sessionPanel.armedAction.length > 0 ? "Cancel confirmation" : root.returnToControls ? "Back to Controls" : "Close"
                    }
                ] : (trayMenu.open ? [
                        {
                            key: root.runtime.shellHint("SystemContent.legend.select_item"),
                            action: "Select item"
                        },
                        {
                            key: root.runtime.shellHint("SystemContent.legend.activate_open_submenu"),
                            action: "Activate / open submenu"
                        },
                        {
                            key: root.runtime.shellHint("SystemContent.legend.back"),
                            action: "Back"
                        }
                    ] : [
                        {
                            key: root.selectedSlider.length > 0 ? root.runtime.shellHint("SystemContent.legend.slider_selection") : root.runtime.shellHint("SystemContent.legend.audio_selection"),
                            action: root.selectedSlider.length > 0 ? "Select the next available adjustment" : "Select output or microphone"
                        },
                        {
                            key: root.runtime.shellHint("SystemContent.legend.h_l"),
                            action: root.selectedSlider.length > 0 ? "Adjust selected slider" : "Adjust selected device level"
                        },
                        {
                            key: root.runtime.shellHint("SystemContent.legend.cycle_available_brightness_window_glass_and_night_light_sliders"),
                            action: "Cycle available brightness, window, glass and Night Light sliders"
                        },
                        {
                            key: root.runtime.shellHint("SystemContent.legend.activate_selected_setting_exit_parameter_focus"),
                            action: "Activate selected setting / exit parameter focus"
                        },
                        {
                            key: root.runtime.shellHint("SystemContent.legend.scroll_controls"),
                            action: "Scroll Controls"
                        },
                        {
                            key: root.runtime.shellHint("SystemContent.legend.mute_stream_mute_mic_choose_device"),
                            action: "Mute stream / mute mic / choose device"
                        },
                        {
                            key: root.runtime.shellHint("SystemContent.legend.open_corresponding_system_control"),
                            action: "Open corresponding system control"
                        },
                        {
                            key: root.runtime.shellHint("SystemContent.legend.now_playing_application_mixer"),
                            action: "Now Playing / application mixer"
                        },
                        {
                            key: root.runtime.shellHint("SystemContent.legend.alerts_stay_awake_power_profile"),
                            action: "Alerts / stay awake / power profile"
                        },
                        {
                            key: root.runtime.shellHint("SystemContent.legend.play_pause_previous_next_media"),
                            action: "Play-pause / previous / next media"
                        },
                        {
                            key: root.runtime.shellHint("SystemContent.legend.shuffle_repeat_choose_player"),
                            action: "Shuffle / repeat / choose player"
                        },
                        {
                            key: root.runtime.shellHint("SystemContent.legend.seek_backward_forward"),
                            action: "Seek backward / forward " + root.media.seekSeconds + " seconds"
                        },
                        {
                            key: root.runtime.shellHint("SystemContent.legend.spectrum_reactive_windows_glass_bar_frame_motion"),
                            action: "Spectrum / reactive / windows / glass / bar / frame / motion"
                        },
                        {
                            key: root.runtime.shellHint("SystemContent.legend.restore_defaults_then_confirm"),
                            action: "Restore defaults, then confirm"
                        },
                        {
                            key: root.runtime.shellHint("SystemContent.legend.night_light_warmer_cooler"),
                            action: "Night Light / warmer / cooler"
                        },
                        {
                            key: root.runtime.shellHint("SystemContent.legend.hardware_display_brightness_and_volume_style_osd"),
                            action: "Hardware display brightness and volume-style OSD"
                        },
                        {
                            key: root.runtime.shellHint("SystemContent.legend.select_activate_tray_app"),
                            action: "Select / activate tray app"
                        },
                        {
                            key: root.runtime.shellHint("SystemContent.legend.close"),
                            action: "Close"
                        }
                    ]))))

    signal helpScrollRequested(int steps)
    signal closeRequested
    signal backRequested
    signal detailRequested(string view)
    signal themeTerminalActiveChanged(bool active)
    signal mediaRequested
    signal revealContent(real top, real bottom)

    implicitWidth: sessionPanel.open ? sessionPanel.implicitWidth : detailsVisible ? theme.controlsDetailWidth : dashboardWidthBudget
    implicitHeight: recordingsPanel.open ? recordingsPanel.implicitHeight : wallpaperPanel.open ? wallpaperPanel.implicitHeight : mixerOpen ? mixerView.implicitHeight : sessionPanel.open ? sessionPanel.implicitHeight : resourcesPanel.open ? resourcesPanel.implicitHeight : networkPanel.open ? networkPanel.implicitHeight : bluetoothPanel.open ? bluetoothPanel.implicitHeight : themePanel.open ? themePanel.implicitHeight : content.implicitHeight
    focus: engaged

    function closeDetails(): void {
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

    function backFromDetail(): void {
        backRequested();
        keyboardFocus.forceActiveFocus();
    }

    function navigateBack(): void {
        // One action for the header and Escape. Resolve nested interactions
        // before changing pages or closing the hub.
        if (resetConfirmPending) {
            resetConfirmPending = false;
        } else if (helpOpen) {
            if (sessionPanel.open && sessionPanel.armedAction.length > 0)
                sessionPanel.invoke("cancelConfirmation");
            helpOpen = false;
        } else if (themePanel.open && themePanel.panel && themePanel.panel.searching) {
            themePanel.invoke("leaveSearch");
        } else if (wallpaperPanel.open && wallpaperPanel.panel && wallpaperPanel.panel.searching) {
            wallpaperPanel.invoke("leaveSearch");
        } else if (mixerOpen) {
            mixerView.finishLoading();
            if (!mixerView.panel || !mixerView.panel.handleKey(Qt.Key_Escape, Qt.NoModifier))
                backFromDetail();
        } else if (audioChooserOpen) {
            audioDeck.handleKey(Qt.Key_Escape, Qt.NoModifier);
        } else if (networkPanel.open && networkPanel.passwordPrompt) {
            networkPanel.invoke("cancelPassword");
        } else if (recordingsPanel.open && recordingsPanel.deletePending.length > 0) {
            recordingsPanel.invoke("cancelDelete");
        } else if (sessionPanel.open && sessionPanel.armedAction.length > 0) {
            sessionPanel.invoke("cancelConfirmation");
        } else if (networkPanel.open && networkPanel.detailView) {
            networkPanel.invoke("toggleDetailView");
        } else if (trayMenu.open) {
            if (trayMenu.panel && trayMenu.panel.stack.length <= 1) {
                trayMenu.closeMenu();
                if (requestedView.startsWith("tray:"))
                    detailRequested("controls");
                keyboardFocus.forceActiveFocus();
            } else {
                trayMenu.invoke("goBack");
            }
        } else if (!detailsVisible && selectedSlider.length > 0) {
            selectedSlider = "";
            keyboardFocus.forceActiveFocus();
        } else if (detailsVisible) {
            backFromDetail();
        } else {
            closeRequested();
        }
    }

    function markDetail(view: string): void {
        if (requestedView !== view)
            detailRequested(view);
    }

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
        } else if (requestedView === "controls" || requestedView.length === 0) {
            const leavingDetail = detailsVisible;
            closeDetails();
            if (leavingDetail)
                keyboardFocus.forceActiveFocus();
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
        if (mixerOpen) {
            mixerView.finishLoading();
            Qt.callLater(() => {
                if (root.engaged && root.mixerOpen)
                    keyboardFocus.forceActiveFocus();
            });
        }
    }

    onEngagedChanged: {
        if (engaged) {
            trayIndex = Math.max(0, Math.min(trayIndex, Math.max(0, system.trayCount - 1)));
            helpOpen = false;
            selectedSlider = "";
            keyboardFocus.forceActiveFocus();
            nightLight.refresh();
            requestedViewTimer.restart();
        } else {
            helpOpen = false;
            selectedSlider = "";
            closeDetails();
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
        markDetail("network");
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
        markDetail("bluetooth");
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
        markDetail("wallpaper");
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
        markDetail("theme");
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
        markDetail("session");
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
        markDetail("resources");
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
        markDetail("mixer");
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
        markDetail("recordings");
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
        audioDeck.moveAudioSelection(direction);
    }

    function adjustSelectedAudio(delta: real): void {
        audioDeck.adjustSelected(delta);
    }

    function toggleSelectedAudioDeviceChooser(): void {
        audioDeck.toggleSelectedDeviceChooser();
    }

    function muteSelectedAudio(): void {
        audioDeck.toggleSelectedMute();
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
            enabled: !root.detailsVisible
            opacity: root.detailsVisible ? 0 : 1
            Behavior on opacity {
                NumberAnimation {
                    duration: root.motion.contentFade
                    easing.type: root.detailsVisible ? root.motion.exitType : root.motion.enterType
                    easing.bezierCurve: root.detailsVisible ? root.motion.exitCurve : root.motion.enterCurve
                }
            }
            spacing: root.theme.spacing3

            // Live state, actions and parameters share one adaptive surface.
            Row {
                id: controlsClock
                visible: true
                width: parent.width
                height: 30
                spacing: root.theme.spacing2
                SystemClock {
                    id: controlsDateTime
                    precision: SystemClock.Minutes
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(controlsDateTime.date, "ddd d MMM yyyy")
                    color: root.theme.textMuted
                    font.family: root.runtime.fontMono
                    font.pixelSize: root.theme.fontSize(12)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(controlsDateTime.date, "h:mm AP")
                    color: root.theme.textStrong
                    font.family: root.runtime.fontMono
                    font.pixelSize: root.theme.fontSize(16)
                    font.weight: Font.Bold
                }
            }

            Row {
                id: controlsHeading
                width: parent.width
                height: 40
                spacing: root.theme.spacing2

                readonly property real entryWidth: Math.max(1, (width - spacing * 2) / 3)

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
                    icon: DesktopIcons.glyphFor("theme")
                    title: "Themes"
                    shortcut: root.runtime.shellHint("SystemContent.themes")
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
                    icon: DesktopIcons.glyphFor("wallpaper")
                    title: "Wallpaper"
                    shortcut: root.runtime.shellHint("SystemContent.wallpaper")
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
                    icon: DesktopIcons.glyphFor("session")
                    title: "Session"
                    shortcut: root.runtime.shellHint("SystemContent.session")
                    onActivated: root.openSession()
                }
            }

            Grid {
                id: commandMatrix
                width: parent.width
                columns: width >= 860 && root.theme.textScale < 1.4 ? 2 : 1
                columnSpacing: root.theme.spacing4
                rowSpacing: root.theme.spacing4
                readonly property real cellWidth: Math.max(1, (width - columnSpacing * (columns - 1)) / columns)

                ShellSection {
                    id: appearanceSection
                    width: commandMatrix.cellWidth
                    runtime: root.runtime
                    theme: root.theme
                    title: "Appearance & display"
                    emphasized: true
                    accentRole: "display"

                    ShellSurface {
                        width: parent.width
                        height: root.dashboardBrightnessHeight
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
                            title: "Display brightness"
                            detail: root.brightness.supported ? root.brightness.percent + "%" : "Hardware unavailable"

                            Row {
                                width: parent.width
                                spacing: root.theme.spacing2
                                ShellSlider {
                                    width: Math.max(1, parent.width - (root.selectedSlider === "brightness" ? brightnessHint.implicitWidth + parent.spacing : 0))
                                    theme: root.theme
                                    motion: root.motion
                                    from: 1
                                    to: 100
                                    value: root.brightness.percent
                                    enabled: root.brightness.supported
                                    accentColor: root.theme.roleColor("display")
                                    trackHeight: 12
                                    handleSize: 20
                                    onInteractionStarted: root.selectSlider("brightness")
                                    onValueRequested: next => root.brightness.setPercent(next)
                                }
                                KeyHint {
                                    id: brightnessHint
                                    visible: root.selectedSlider === "brightness"
                                    shortcut: root.runtime.shellHint("SystemContent.audioLevel")
                                    compact: true
                                    runtime: root.runtime
                                    theme: root.theme
                                    emphasized: true
                                    emphasisColor: root.theme.positive
                                }
                            }
                        }
                    }
                }

                ShellSection {
                    width: commandMatrix.cellWidth
                    runtime: root.runtime
                    theme: root.theme
                    title: "Connectivity"
                    emphasized: true
                    accentRole: "connectivity"

                    Grid {
                        id: connectionTiles
                        width: parent.width
                        columns: width < 380 || root.theme.textScale >= 1.5 ? 1 : 2
                        columnSpacing: root.theme.spacing3
                        rowSpacing: root.theme.spacing3
                        readonly property real cellWidth: (width - columnSpacing * (columns - 1)) / columns

                        ConnectivityTile {
                            width: connectionTiles.cellWidth
                            height: root.dashboardBrightnessHeight
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            title: "Network"
                            detail: root.system.networkDevices.length === 0 ? "Hardware unavailable" : root.system.networkConnected ? root.system.networkName : "No connection"
                            status: failed ? "CONNECTION FAILED" : pending ? networkPanel.pendingNetwork ? "AUTHENTICATION REQUIRED" : "UPDATING CONNECTION" : unavailable ? "" : root.system.networkConnected ? (root.system.wifiConnected ? "WI-FI · CONNECTED" : "ETHERNET · CONNECTED") : "OFFLINE"
                            glyph: root.system.wifiConnected ? "󰤨" : root.system.networkConnected ? "󰈀" : "󰤭"
                            shortcut: root.runtime.shellHint("SystemContent.network")
                            connected: root.system.networkConnected
                            pending: networkPanel.open && (networkPanel.profileActionRunning || networkPanel.pendingNetwork !== null)
                            failed: networkPanel.open && networkPanel.statusError
                            unavailable: root.system.networkDevices.length === 0
                            onActivated: root.openNetwork()
                        }

                        ConnectivityTile {
                            width: connectionTiles.cellWidth
                            height: root.dashboardBrightnessHeight
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            title: "Bluetooth"
                            detail: unavailable ? "Hardware unavailable" : root.system.bluetoothEnabled ? root.system.bluetoothConnectedCount + " connected devices" : "Radio disabled"
                            status: failed ? "ACTION FAILED" : scanning ? "SCANNING FOR DEVICES" : pending ? "PAIRING DEVICE" : unavailable ? "" : root.system.bluetoothEnabled ? "ADAPTER ON" : "RADIO OFF"
                            glyph: root.system.bluetoothEnabled ? "󰂯" : "󰂲"
                            shortcut: root.runtime.shellHint("SystemContent.bluetooth")
                            connected: root.system.bluetoothEnabled
                            scanning: root.system.bluetoothDiscovering
                            pending: root.system.bluetoothDevices.some(device => device && device.pairing)
                            failed: bluetoothPanel.open && bluetoothPanel.statusError
                            unavailable: !root.system.bluetoothAvailable
                            onActivated: root.openBluetooth()
                        }
                    }
                }
            }

            Column {
                id: tileCanvas
                width: parent.width
                spacing: root.theme.spacing4

                Column {
                    id: visualModesGroup
                    width: parent.width
                    spacing: root.theme.spacing2

                    Row {
                        width: parent.width
                        height: 24
                        spacing: root.theme.spacing2
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "VISUAL MODES"
                            color: root.theme.readableRoleColor("display")
                            font.family: root.runtime.fontMono
                            font.pixelSize: root.theme.fontPanelEyebrow
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.0
                        }
                        Item {
                            width: Math.max(0, parent.width - parent.children[0].implicitWidth - sliderSelectionHint.implicitWidth - (sliderNavigationHint.visible ? sliderNavigationHint.implicitWidth + parent.spacing : 0) - parent.spacing * 2)
                            height: 1
                        }
                        KeyHint {
                            id: sliderSelectionHint
                            anchors.verticalCenter: parent.verticalCenter
                            shortcut: root.runtime.shellHint("SystemContent.tabSelect")
                            label: root.selectedSlider.length > 0 ? "Next slider" : "Select slider"
                            compact: true
                            runtime: root.runtime
                            theme: root.theme
                            emphasized: root.selectedSlider.length > 0
                        }
                        KeyHint {
                            id: sliderNavigationHint
                            visible: root.selectedSlider.length > 0
                            anchors.verticalCenter: parent.verticalCenter
                            shortcut: root.runtime.shellHint("SystemContent.rowSelect")
                            label: "Select"
                            compact: true
                            runtime: root.runtime
                            theme: root.theme
                        }
                    }

                    BalancedTileFlow {
                        id: visualTiles
                        width: parent.width
                        spacing: root.theme.spacing2
                        textScale: root.theme.textScale

                        QuickSettingChip {
                            width: visualTiles.cellWidth(this)
                            height: root.dashboardTileHeight
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: "󰸉"
                            title: root.wallpaperSpectrumEnabled ? "Wallpaper spectrum" : "Spectrum off"
                            shortcut: root.runtime.shellHint("SystemContent.wallpaperSpectrum")
                            active: root.wallpaperSpectrumEnabled
                            activeColor: root.theme.roleColor("workspace")
                            onActivated: root.wallpaperSpectrumToggleRequested()
                        }

                        QuickSettingChip {
                            width: visualTiles.cellWidth(this)
                            height: root.dashboardTileHeight
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: DesktopIcons.glyphFor("audioMixer")
                            title: root.musicReactiveEnabled ? "Audio reactive" : "Reactive off"
                            shortcut: root.runtime.shellHint("SystemContent.musicReactive")
                            active: root.musicReactiveEnabled
                            activeColor: root.theme.roleColor("audio")
                            onActivated: root.musicReactiveToggleRequested()
                        }

                        OpacitySetting {
                            width: visualTiles.cellWidth(this)
                            height: root.dashboardTileHeight
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: "󰍹"
                            label: "Windows"
                            opacityValue: root.appearance.windowOpacity
                            shortcut: root.runtime.shellHint("SystemContent.windowTransparency")
                            active: root.windowTransparencyEnabled
                            keyboardSelected: root.selectedSlider === "windows"
                            onSliderActivated: root.selectSlider("windows")
                            roleAccent: root.theme.roleColor("display")
                            onToggleRequested: root.windowTransparencyToggleRequested()
                            onOpacityRequested: value => root.appearance.setWindowOpacity(value)
                        }

                        OpacitySetting {
                            width: visualTiles.cellWidth(this)
                            height: root.dashboardTileHeight
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: "󰊠"
                            label: "Frosted glass"
                            opacityValue: root.appearance.glassOpacity
                            shortcut: root.runtime.shellHint("SystemContent.shellGlass")
                            active: root.shellGlassEnabled
                            keyboardSelected: root.selectedSlider === "glass"
                            onSliderActivated: root.selectSlider("glass")
                            roleAccent: root.theme.roleColor("connectivity")
                            onToggleRequested: root.shellGlassToggleRequested()
                            onOpacityRequested: value => root.appearance.setGlassOpacity(value)
                        }

                        QuickSettingChip {
                            width: visualTiles.cellWidth(this)
                            height: root.dashboardTileHeight
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: "󰀻"
                            title: root.barVisible ? "Bar visible" : "Bar hidden"
                            shortcut: root.runtime.shellHint("SystemContent.bar")
                            active: root.barVisible
                            activeColor: root.theme.roleColor("positive")
                            onActivated: root.barToggleRequested()
                        }
                        QuickSettingChip {
                            width: visualTiles.cellWidth(this)
                            height: root.dashboardTileHeight
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: root.frameVisible ? "󰏗" : "󰏖"
                            title: root.frameVisible ? "Frame visible" : "Frame hidden"
                            shortcut: root.runtime.shellHint("SystemContent.frame")
                            active: root.frameVisible
                            activeColor: root.theme.roleColor("display")
                            onActivated: root.frameToggleRequested()
                        }

                        QuickSettingChip {
                            width: visualTiles.cellWidth(this)
                            height: root.dashboardTileHeight
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: root.motion.enabled ? "󰐊" : "󰏤"
                            title: root.motion.enabled ? "Animations" : "Reduced motion"
                            shortcut: root.runtime.shellHint("SystemContent.motion")
                            active: root.motion.enabled
                            activeColor: root.theme.roleColor("display")
                            onActivated: root.motion.toggle()
                        }

                        AdjustableSetting {
                            width: visualTiles.cellWidth(this)
                            height: root.dashboardTileHeight
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: root.nightLight.active ? "󰖔" : "󰖙"
                            label: "Night Light"
                            valueText: root.nightLight.supported ? root.nightLight.temperature + " K" : "Unavailable"
                            keyboardSelected: root.selectedSlider === "nightLight"
                            onSliderActivated: root.selectSlider("nightLight")
                            value: root.nightLight.temperature
                            from: 2500
                            to: 6500
                            onValueRequested: value => root.nightLight.setTemperature(value)
                            toggleShortcut: root.runtime.shellHint("SystemContent.nightLight")
                            roleAccent: root.theme.roleColor("warmth")
                            active: root.nightLight.active
                            canToggle: root.nightLight.supported && !root.nightLight.busy
                            canAdjust: root.nightLight.supported
                            onToggleRequested: root.nightLight.toggle()
                        }
                    }
                }

                ShellSection {
                    id: quickActionsSection
                    width: parent.width
                    runtime: root.runtime
                    theme: root.theme
                    title: "Quick Actions"
                    emphasized: true
                    accentRole: "attention"

                    BalancedTileFlow {
                        id: actionTiles
                        width: parent.width
                        spacing: root.theme.spacing2
                        textScale: root.theme.textScale

                        QuickSettingChip {
                            width: actionTiles.cellWidth(this)
                            height: root.dashboardTileHeight
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: root.notificationState.silent ? "󰂛" : "󰂚"
                            title: root.notificationState.silent ? "Silent" : "Alerts"
                            shortcut: root.runtime.shellHint("SystemContent.alerts")
                            active: root.notificationState.silent
                            activeColor: root.notificationState.silent ? root.theme.roleColor("warning") : root.theme.roleColor("attention")
                            onActivated: root.notificationState.toggleSilent()
                        }

                        QuickSettingChip {
                            width: actionTiles.cellWidth(this)
                            height: root.dashboardTileHeight
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: root.system.idleInhibited ? "󰅶" : "󰒲"
                            title: root.system.idleInhibited ? "Stay awake" : "Idle allowed"
                            shortcut: root.runtime.shellHint("SystemContent.stayAwake")
                            active: root.system.idleInhibited
                            activeColor: root.theme.roleColor("warmth")
                            onActivated: root.system.toggleIdleInhibited()
                        }

                        QuickSettingChip {
                            width: actionTiles.cellWidth(this)
                            height: root.dashboardTileHeight
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: root.system.batteryAvailable ? root.system.batteryLevelIcon : "󰐥"
                            title: (root.powerProfile.available ? root.powerProfile.label(root.powerProfile.current) : "Power") + (root.system.batteryAvailable ? " " + root.system.batteryPercent + "%" : "")
                            shortcut: root.runtime.shellHint("SystemContent.powerProfile")
                            enabled: root.powerProfile.available && !root.powerProfile.applying
                            active: root.powerProfile.current === "power-saver"
                            activeColor: root.theme.powerProfileColor(root.powerProfile.current)
                            onActivated: root.powerProfile.cycle()
                        }

                        QuickSettingChip {
                            width: actionTiles.cellWidth(this)
                            height: root.dashboardTileHeight
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: DesktopIcons.glyphFor("resources")
                            title: "Resources"
                            shortcut: root.runtime.shellHint("SystemContent.resources")
                            activeColor: root.theme.roleColor("resources")
                            onActivated: root.openResources()
                        }

                        QuickSettingChip {
                            width: actionTiles.cellWidth(this)
                            height: root.dashboardTileHeight
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: DesktopIcons.glyphFor("captures")
                            title: "Captures"
                            shortcut: root.runtime.shellHint("SystemContent.captures")
                            activeColor: root.theme.roleColor("capture")
                            onActivated: root.openRecordings()
                        }

                        QuickSettingChip {
                            width: actionTiles.cellWidth(this)
                            height: root.dashboardTileHeight
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: "󰑓"
                            title: root.resetRunning ? "Restoring…" : "Restore defaults"
                            shortcut: root.runtime.shellHint("SystemContent.reset")
                            active: root.resetConfirmPending
                            enabled: !root.resetRunning
                            activeColor: root.theme.roleColor("warning")
                            onActivated: root.resetConfirmPending = !root.resetConfirmPending
                        }
                    }

                    ShellSurface {
                        visible: root.resetConfirmPending || root.resetRunning || root.resetStatus.length > 0
                        width: parent.width
                        height: visible ? resetContents.implicitHeight + root.theme.spacing3 * 2 : 0
                        theme: root.theme
                        motion: root.motion
                        surfaceLayer: ShellSurface.Group
                        cornerRadius: root.theme.radiusMedium
                        fillColor: root.theme.groupBase

                        Column {
                            id: resetContents
                            width: parent.width - root.theme.spacing3 * 2
                            anchors.centerIn: parent
                            spacing: root.theme.spacing2
                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: root.resetConfirmPending ? "Restore Nix defaults for appearance, motion, notifications, captures and wallpapers? Personal files and the active system generation stay intact." : root.resetStatus
                                color: root.resetConfirmPending ? root.theme.textStrong : root.theme.textMuted
                                font.family: root.runtime.fontMono
                                font.pixelSize: root.theme.fontSize(11)
                            }
                            KeyHintStrip {
                                visible: root.resetConfirmPending
                                width: parent.width
                                runtime: root.runtime
                                theme: root.theme
                                hints: [
                                    {
                                        shortcut: root.runtime.shellHint("SystemContent.resetConfirm"),
                                        label: "Restore"
                                    },
                                    {
                                        shortcut: root.runtime.shellHint("SystemContent.resetCancel"),
                                        label: "Cancel"
                                    }
                                ]
                            }
                        }
                    }
                }
            }

            Grid {
                id: mediaMatrix
                width: parent.width
                columns: width >= 860 && root.theme.textScale < 1.4 ? 2 : 1
                columnSpacing: root.theme.spacing4
                rowSpacing: root.theme.spacing4
                readonly property real cellWidth: Math.max(1, (width - columnSpacing * (columns - 1)) / columns)

                ShellSection {
                    id: audioSection
                    width: mediaMatrix.cellWidth
                    runtime: root.runtime
                    theme: root.theme
                    title: "Audio & levels"
                    emphasized: true
                    accentRole: "audio"
                    hints: root.selectedSlider.length === 0 ? [
                        {
                            shortcut: root.runtime.shellHint("SystemContent.audioSelect"),
                            label: "Select"
                        },
                        {
                            shortcut: root.runtime.shellHint("SystemContent.audioAdjust"),
                            label: "Level"
                        }
                    ] : []

                    AudioMixerContent {
                        id: audioDeck
                        width: parent.width
                        height: Math.max(implicitHeight, mediaCard.implicitHeight)
                        compact: true
                        active: root.engaged && !root.detailsVisible && audioSection.visible
                        runtime: root.runtime
                        theme: root.theme
                        motion: root.motion
                        system: root.system
                        onExpandRequested: root.openMixer()
                    }
                }

                ShellSection {
                    width: mediaMatrix.cellWidth
                    runtime: root.runtime
                    theme: root.theme
                    title: "Media"
                    emphasized: true
                    accentRole: "media"

                    ControlsMediaCard {
                        id: mediaCard
                        width: parent.width
                        height: Math.max(implicitHeight, audioDeck.implicitHeight)
                        active: root.engaged && !root.detailsVisible
                        media: root.media
                        spectrum: root.spectrum
                        runtime: root.runtime
                        theme: root.theme
                        motion: root.motion
                        onFullRequested: root.mediaRequested()
                    }
                }
            }

            Row {
                id: trayRow
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

                Item {
                    id: trayChoices
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.system.trayCount * 98 + Math.max(0, root.system.trayCount - 1) * root.theme.spacing2
                    height: 36
                    clip: true

                    ShellSurface {
                        id: traySelection
                        x: Math.max(0, Math.min(root.trayIndex, root.system.trayCount - 1)) * (98 + root.theme.spacing2)
                        width: 98
                        height: parent.height
                        theme: root.theme
                        motion: root.motion
                        surfaceLayer: ShellSurface.Control
                        selected: true
                        cornerRadius: root.theme.radiusSmall

                        Behavior on x {
                            NumberAnimation {
                                duration: root.motion.spatialFast
                                easing.type: root.motion.spatialType
                                easing.bezierCurve: root.motion.spatialCurve
                            }
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

                                width: 98
                                height: 36
                                theme: root.theme
                                motion: root.motion
                                surfaceLayer: ShellSurface.Control
                                selected: false
                                fillColor: "transparent"
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
                                    selected: false
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
                    }
                }

                KeyHintStrip {
                    width: 225
                    anchors.verticalCenter: parent.verticalCenter
                    runtime: root.runtime
                    theme: root.theme
                    hints: [
                        {
                            shortcut: root.runtime.shellHint("SystemContent.trayNavigate"),
                            label: "Tray"
                        },
                        {
                            shortcut: root.runtime.shellHint("SystemContent.trayOpen"),
                            label: "Open"
                        }
                    ]
                }
            }
        }

        DeferredDetail {
            id: mixerView
            motion: root.motion
            anchors.fill: parent
            visible: root.mixerOpen
            sourceComponent: Component {
                AudioMixerContent {
                    active: root.engaged && root.mixerOpen
                    system: root.system
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    onCloseRequested: root.backFromDetail()
                    onKeyboardRequested: keyboardFocus.forceActiveFocus()
                }
            }
        }

        DeferredDetail {
            id: recordingsPanel
            motion: root.motion
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
            motion: root.motion
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
            motion: root.motion
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
            motion: root.motion
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
            motion: root.motion
            anchors.fill: parent
            sourceComponent: Component {
                WallpaperPanel {
                    appearance: root.appearance
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    onKeyboardRequested: keyboardFocus.forceActiveFocus()
                }
            }
        }

        DeferredDetail {
            id: themePanel
            motion: root.motion
            anchors.fill: parent
            sourceComponent: Component {
                ThemePanel {
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    returnToControls: root.returnToControls
                    onKeyboardRequested: keyboardFocus.forceActiveFocus()
                    onSwitchLaunched: root.themeTerminalActiveChanged(true)
                    onSwitchFinished: root.themeTerminalActiveChanged(false)
                }
            }
        }

        DeferredDetail {
            id: sessionPanel
            motion: root.motion
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
            motion: root.motion
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

            // Both Tab directions share one owner. Capture Backtab before Qt
            // can interpret Shift+Tab as ordinary focus traversal; a held key
            // repeats through the same path as an individual press.
            Keys.onShortcutOverride: event => {
                if ((root.sliderNavigationEnabled || root.mixerOpen) && (event.key === root.runtime.shellKeyCode("controls", "Tab") || event.key === root.runtime.shellKeyCode("controls", "Backtab")))
                    event.accepted = true;
            }

            Keys.onPressed: event => {
                if (event.key === root.runtime.shellKeyCode("controls", "Escape")) {
                    root.navigateBack();
                    event.accepted = true;
                    return;
                }
                if (root.resetConfirmPending) {
                    if (event.key === root.runtime.shellKeyCode("controls", "Return") || event.key === root.runtime.shellKeyCode("controls", "Enter"))
                        root.startDefaultReset();
                    else if (event.key === root.runtime.shellKeyCode("controls", "Backspace") || (event.key === root.runtime.shellKeyCode("controls", "C") && (root.runtime.shellModifier("controls", "Shift", event.modifiers))))
                        root.resetConfirmPending = false;
                    event.accepted = true;
                    return;
                }
                const helpKey = event.key === root.runtime.shellKeyCode("controls", "Question") || (event.key === root.runtime.shellKeyCode("controls", "Slash") && (root.runtime.shellModifier("controls", "Shift", event.modifiers)));

                if (root.helpOpen) {
                    if (helpKey || event.key === root.runtime.shellKeyCode("controls", "Backspace")) {
                        if ((event.key === root.runtime.shellKeyCode("controls", "Backspace")) && sessionPanel.open && sessionPanel.armedAction.length > 0)
                            sessionPanel.invoke("cancelConfirmation");
                        root.helpOpen = false;
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "J") || event.key === root.runtime.shellKeyCode("controls", "Down")) {
                        root.helpScrollRequested(1);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "K") || event.key === root.runtime.shellKeyCode("controls", "Up")) {
                        root.helpScrollRequested(-1);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "D") || event.key === root.runtime.shellKeyCode("controls", "PageDown")) {
                        root.helpScrollRequested(4);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "U") || event.key === root.runtime.shellKeyCode("controls", "PageUp")) {
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

                if (root.mixerOpen) {
                    mixerView.finishLoading();
                    if (mixerView.panel && mixerView.panel.handleKey(event.key, event.modifiers))
                        event.accepted = true;
                    return;
                }

                if (audioDeck.deviceChooserOpen) {
                    if (audioDeck.handleKey(event.key, event.modifiers))
                        event.accepted = true;
                    return;
                }

                if (wallpaperPanel.open) {
                    if (event.key === root.runtime.shellKeyCode("controls", "Backspace")) {
                        root.backFromDetail();
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Slash")) {
                        wallpaperPanel.invoke("enterSearch");
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Left") || event.key === root.runtime.shellKeyCode("controls", "H")) {
                        wallpaperPanel.invoke("moveSelection", -1);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Right") || event.key === root.runtime.shellKeyCode("controls", "L")) {
                        wallpaperPanel.invoke("moveSelection", 1);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Up") || event.key === root.runtime.shellKeyCode("controls", "K")) {
                        wallpaperPanel.invoke("moveGrid", 0, -1);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Down") || event.key === root.runtime.shellKeyCode("controls", "J")) {
                        wallpaperPanel.invoke("moveGrid", 0, 1);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "U") || event.key === root.runtime.shellKeyCode("controls", "PageUp") || event.key === root.runtime.shellKeyCode("controls", "D") || event.key === root.runtime.shellKeyCode("controls", "PageDown")) {
                        wallpaperPanel.invoke("moveHalfPage", (event.key === root.runtime.shellKeyCode("controls", "U") || event.key === root.runtime.shellKeyCode("controls", "PageUp")) ? -1 : 1);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "M")) {
                        wallpaperPanel.invoke("cycleOutput");
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "F")) {
                        wallpaperPanel.invoke("toggleFit");
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "R")) {
                        wallpaperPanel.invoke("resetWallpaper");
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Return") || event.key === root.runtime.shellKeyCode("controls", "Enter")) {
                        wallpaperPanel.invoke("applySelected");
                        event.accepted = true;
                    }
                    return;
                }

                if (recordingsPanel.open) {
                    if (event.key === root.runtime.shellKeyCode("controls", "Backspace")) {
                        if (recordingsPanel.deletePending.length > 0)
                            recordingsPanel.invoke("cancelDelete");
                        else
                            root.backFromDetail();
                    } else if (event.key === root.runtime.shellKeyCode("controls", "J") || event.key === root.runtime.shellKeyCode("controls", "Down")) {
                        recordingsPanel.invoke("moveSelection", 1);
                    } else if (event.key === root.runtime.shellKeyCode("controls", "K") || event.key === root.runtime.shellKeyCode("controls", "Up")) {
                        recordingsPanel.invoke("moveSelection", -1);
                    } else if (event.key === root.runtime.shellKeyCode("controls", "U") || event.key === root.runtime.shellKeyCode("controls", "PageUp")) {
                        recordingsPanel.invoke("moveSelection", -4);
                    } else if (event.key === root.runtime.shellKeyCode("controls", "PageDown") || (event.key === root.runtime.shellKeyCode("controls", "D") && (root.runtime.shellModifier("controls", "Shift", event.modifiers)))) {
                        recordingsPanel.invoke("moveSelection", 4);
                    } else if (event.key === root.runtime.shellKeyCode("controls", "D")) {
                        recordingsPanel.invoke("requestDelete");
                    } else if (event.key === root.runtime.shellKeyCode("controls", "E")) {
                        recordingsPanel.invoke("editSelected");
                    } else if (event.key === root.runtime.shellKeyCode("controls", "C")) {
                        recordingsPanel.invoke("copySelected");
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Return") || event.key === root.runtime.shellKeyCode("controls", "Enter")) {
                        recordingsPanel.invoke("openSelected");
                    } else if (event.key === root.runtime.shellKeyCode("controls", "R")) {
                        recordingsPanel.invoke("refresh");
                    } else {
                        return;
                    }
                    event.accepted = true;
                    return;
                }

                if (resourcesPanel.open) {
                    if (event.key === root.runtime.shellKeyCode("controls", "Backspace")) {
                        root.backFromDetail();
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "C")) {
                        resourcesPanel.invoke("toggleCoreView");
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "R")) {
                        root.resourceState.refresh();
                        event.accepted = true;
                    }
                    return;
                }

                if (bluetoothPanel.open) {
                    if (event.key === root.runtime.shellKeyCode("controls", "Backspace")) {
                        root.backFromDetail();
                        event.accepted = true;
                    } else if ((event.key === root.runtime.shellKeyCode("controls", "Up") || event.key === root.runtime.shellKeyCode("controls", "K"))) {
                        bluetoothPanel.invoke("moveSelection", -1);
                        event.accepted = true;
                    } else if ((event.key === root.runtime.shellKeyCode("controls", "Down") || event.key === root.runtime.shellKeyCode("controls", "J"))) {
                        bluetoothPanel.invoke("moveSelection", 1);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "U") || event.key === root.runtime.shellKeyCode("controls", "PageUp") || event.key === root.runtime.shellKeyCode("controls", "PageDown") || (event.key === root.runtime.shellKeyCode("controls", "D") && !(root.runtime.shellModifier("controls", "Shift", event.modifiers)))) {
                        bluetoothPanel.invoke("moveHalfPage", (event.key === root.runtime.shellKeyCode("controls", "U") || event.key === root.runtime.shellKeyCode("controls", "PageUp")) ? -1 : 1);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Return") || event.key === root.runtime.shellKeyCode("controls", "Enter")) {
                        bluetoothPanel.invoke("activateSelected");
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "B")) {
                        bluetoothPanel.invoke("toggleBluetooth");
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "D") && (root.runtime.shellModifier("controls", "Shift", event.modifiers))) {
                        bluetoothPanel.invoke("toggleDiscovery");
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "P")) {
                        bluetoothPanel.invoke("pairSelected");
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "T")) {
                        bluetoothPanel.invoke("toggleTrust");
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "F")) {
                        bluetoothPanel.invoke("forgetSelected");
                        event.accepted = true;
                    }

                    return;
                }

                if (sessionPanel.open) {
                    if (sessionPanel.invoke("activateShortcut", event.key, event.modifiers) === true) {
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Backspace")) {
                        if (sessionPanel.armedAction.length > 0)
                            sessionPanel.invoke("cancelConfirmation");
                        else
                            root.backFromDetail();
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Up") || event.key === root.runtime.shellKeyCode("controls", "K")) {
                        sessionPanel.invoke("moveGrid", 0, -1);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Down") || event.key === root.runtime.shellKeyCode("controls", "J")) {
                        sessionPanel.invoke("moveGrid", 0, 1);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Left") || event.key === root.runtime.shellKeyCode("controls", "H")) {
                        sessionPanel.invoke("moveGrid", -1, 0);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Right") || event.key === root.runtime.shellKeyCode("controls", "L")) {
                        sessionPanel.invoke("moveGrid", 1, 0);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Return") || event.key === root.runtime.shellKeyCode("controls", "Enter")) {
                        sessionPanel.invoke("activateSelected");
                        event.accepted = true;
                    }

                    return;
                }

                if (themePanel.open) {
                    if (event.key === root.runtime.shellKeyCode("controls", "Slash")) {
                        themePanel.invoke("enterSearch");
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Backspace")) {
                        root.backFromDetail();
                        event.accepted = true;
                    } else if ((event.key === root.runtime.shellKeyCode("controls", "Up") || event.key === root.runtime.shellKeyCode("controls", "K"))) {
                        themePanel.invoke("moveGrid", 0, -1);
                        event.accepted = true;
                    } else if ((event.key === root.runtime.shellKeyCode("controls", "Down") || event.key === root.runtime.shellKeyCode("controls", "J"))) {
                        themePanel.invoke("moveGrid", 0, 1);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "H") || event.key === root.runtime.shellKeyCode("controls", "Left")) {
                        themePanel.invoke("moveGrid", -1, 0);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "L") || event.key === root.runtime.shellKeyCode("controls", "Right")) {
                        themePanel.invoke("moveGrid", 1, 0);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "U") || event.key === root.runtime.shellKeyCode("controls", "PageUp") || event.key === root.runtime.shellKeyCode("controls", "PageDown") || (event.key === root.runtime.shellKeyCode("controls", "D") && !(root.runtime.shellModifier("controls", "Shift", event.modifiers)))) {
                        themePanel.invoke("moveHalfPage", (event.key === root.runtime.shellKeyCode("controls", "U") || event.key === root.runtime.shellKeyCode("controls", "PageUp")) ? -1 : 1);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "X") && themePanel.operationRunning) {
                        themePanel.invoke("cancelOperation");
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Return") || event.key === root.runtime.shellKeyCode("controls", "Enter")) {
                        themePanel.invoke("activateSelected");
                        event.accepted = true;
                    }

                    return;
                }

                if (networkPanel.open) {
                    if (networkPanel.passwordPrompt)
                        return;

                    if (event.key === root.runtime.shellKeyCode("controls", "Backspace")) {
                        if (networkPanel.detailView)
                            networkPanel.invoke("toggleDetailView");
                        else
                            root.backFromDetail();
                        event.accepted = true;
                    } else if ((event.key === root.runtime.shellKeyCode("controls", "Up") || event.key === root.runtime.shellKeyCode("controls", "K"))) {
                        networkPanel.invoke("moveSelection", -1);
                        event.accepted = true;
                    } else if ((event.key === root.runtime.shellKeyCode("controls", "Down") || event.key === root.runtime.shellKeyCode("controls", "J"))) {
                        networkPanel.invoke("moveSelection", 1);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "U") || event.key === root.runtime.shellKeyCode("controls", "PageUp") || event.key === root.runtime.shellKeyCode("controls", "PageDown") || (event.key === root.runtime.shellKeyCode("controls", "D") && !(root.runtime.shellModifier("controls", "Shift", event.modifiers)))) {
                        networkPanel.invoke("moveHalfPage", (event.key === root.runtime.shellKeyCode("controls", "U") || event.key === root.runtime.shellKeyCode("controls", "PageUp")) ? -1 : 1);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Return") || event.key === root.runtime.shellKeyCode("controls", "Enter")) {
                        networkPanel.invoke("activateSelected");
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "V")) {
                        networkPanel.invoke("toggleDetailView");
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "R") && networkPanel.detailView) {
                        networkPanel.invoke("refreshDetails");
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "P") && !networkPanel.detailView) {
                        networkPanel.invoke("toggleSavedView");
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "R") && networkPanel.savedView && !networkPanel.detailView) {
                        networkPanel.invoke("refreshSaved");
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "W") && !networkPanel.savedView) {
                        networkPanel.invoke("toggleWifi");
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "A")) {
                        Quickshell.execDetached([root.runtime.networkConnectionEditor]);
                        event.accepted = true;
                    }

                    return;
                }

                if (trayMenu.open) {
                    if (event.key === root.runtime.shellKeyCode("controls", "Backspace") || (event.key === root.runtime.shellKeyCode("controls", "Left") || event.key === root.runtime.shellKeyCode("controls", "H"))) {
                        if ((event.key === root.runtime.shellKeyCode("controls", "Backspace")) && trayMenu.panel && trayMenu.panel.stack.length <= 1) {
                            // A tray menu opened inside Controls has no hub
                            // navigation history. Dismiss it locally instead
                            // of letting expansionState.back() close the hub.
                            trayMenu.closeMenu();
                            if (root.requestedView.startsWith("tray:"))
                                root.detailRequested("controls");
                            keyboardFocus.forceActiveFocus();
                        } else {
                            trayMenu.invoke("goBack");
                        }
                        event.accepted = true;
                    } else if ((event.key === root.runtime.shellKeyCode("controls", "Up") || event.key === root.runtime.shellKeyCode("controls", "K"))) {
                        trayMenu.invoke("moveSelection", -1);
                        event.accepted = true;
                    } else if ((event.key === root.runtime.shellKeyCode("controls", "Down") || event.key === root.runtime.shellKeyCode("controls", "J"))) {
                        trayMenu.invoke("moveSelection", 1);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "U") || event.key === root.runtime.shellKeyCode("controls", "PageUp") || event.key === root.runtime.shellKeyCode("controls", "PageDown") || (event.key === root.runtime.shellKeyCode("controls", "D") && !(root.runtime.shellModifier("controls", "Shift", event.modifiers)))) {
                        trayMenu.invoke("moveHalfPage", (event.key === root.runtime.shellKeyCode("controls", "U") || event.key === root.runtime.shellKeyCode("controls", "PageUp")) ? -1 : 1);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Return") || event.key === root.runtime.shellKeyCode("controls", "Enter") || (event.key === root.runtime.shellKeyCode("controls", "Right") || event.key === root.runtime.shellKeyCode("controls", "L"))) {
                        trayMenu.invoke("activateSelected");
                        event.accepted = true;
                    }

                    return;
                }

                const shifted = !!(root.runtime.shellModifier("controls", "Shift", event.modifiers));
                // Shift release/press is not a command. Previously pressing
                // Shift by itself cleared selectedSlider, so the next Backtab
                // restarted selection at the final (Night Light) slider.
                if (event.key === root.runtime.shellKeyCode("controls", "Shift") || event.key === root.runtime.shellKeyCode("controls", "Control") || event.key === root.runtime.shellKeyCode("controls", "Alt") || event.key === root.runtime.shellKeyCode("controls", "Meta") || event.key === root.runtime.shellKeyCode("controls", "AltGr")) {
                    event.accepted = true;
                    return;
                }
                if (root.sliderNavigationEnabled && (event.key === root.runtime.shellKeyCode("controls", "Tab") || event.key === root.runtime.shellKeyCode("controls", "Backtab"))) {
                    root.cycleSlider(event.key === root.runtime.shellKeyCode("controls", "Backtab") || shifted ? -1 : 1);
                    event.accepted = true;
                    return;
                }
                if (root.selectedSlider.length > 0) {
                    if (event.key === root.runtime.shellKeyCode("controls", "Backspace")) {
                        root.selectedSlider = "";
                    } else if (!shifted && (event.key === root.runtime.shellKeyCode("controls", "K") || event.key === root.runtime.shellKeyCode("controls", "Up"))) {
                        root.cycleSlider(-1);
                    } else if (!shifted && (event.key === root.runtime.shellKeyCode("controls", "J") || event.key === root.runtime.shellKeyCode("controls", "Down"))) {
                        root.cycleSlider(1);
                    } else if (!shifted && (event.key === root.runtime.shellKeyCode("controls", "H") || event.key === root.runtime.shellKeyCode("controls", "Left"))) {
                        root.adjustSlider(-1);
                    } else if (!shifted && (event.key === root.runtime.shellKeyCode("controls", "L") || event.key === root.runtime.shellKeyCode("controls", "Right"))) {
                        root.adjustSlider(1);
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Return") || event.key === root.runtime.shellKeyCode("controls", "Enter")) {
                        root.activateSlider();
                    } else {
                        // Other direct-action shortcuts keep their normal
                        // semantics; only editing keys belong to the slider.
                        root.selectedSlider = "";
                    }
                    if (event.key === root.runtime.shellKeyCode("controls", "Backspace") || (!shifted && (event.key === root.runtime.shellKeyCode("controls", "H") || event.key === root.runtime.shellKeyCode("controls", "Left") || event.key === root.runtime.shellKeyCode("controls", "L") || event.key === root.runtime.shellKeyCode("controls", "Right") || event.key === root.runtime.shellKeyCode("controls", "K") || event.key === root.runtime.shellKeyCode("controls", "Up") || event.key === root.runtime.shellKeyCode("controls", "J") || event.key === root.runtime.shellKeyCode("controls", "Down"))) || event.key === root.runtime.shellKeyCode("controls", "Return") || event.key === root.runtime.shellKeyCode("controls", "Enter")) {
                        event.accepted = true;
                        return;
                    }
                }
                if (shifted && event.key === root.runtime.shellKeyCode("controls", "C")) {
                    root.resetConfirmPending = true;
                    root.resetStatus = "";
                } else if (shifted && event.key === root.runtime.shellKeyCode("controls", "F")) {
                    root.wallpaperSpectrumToggleRequested();
                } else if (shifted && event.key === root.runtime.shellKeyCode("controls", "G")) {
                    root.musicReactiveToggleRequested();
                } else if (shifted && event.key === root.runtime.shellKeyCode("controls", "D")) {
                    root.windowTransparencyToggleRequested();
                } else if (root.runtime.shellMatchesHint("SystemContent.shellGlass", event.key, event.modifiers)) {
                    root.shellGlassToggleRequested();
                } else if (root.runtime.shellMatchesHint("SystemContent.bar", event.key, event.modifiers)) {
                    root.barToggleRequested();
                } else if (root.runtime.shellMatchesHint("SystemContent.frame", event.key, event.modifiers)) {
                    root.frameToggleRequested();
                } else if (shifted && event.key === root.runtime.shellKeyCode("controls", "E")) {
                    root.motion.toggle();
                } else if (shifted && event.key === root.runtime.shellKeyCode("controls", "M")) {
                    root.openMixer();
                } else if (shifted && event.key === root.runtime.shellKeyCode("controls", "P")) {
                    root.media.cyclePlayer();
                } else if (shifted && event.key === root.runtime.shellKeyCode("controls", "T")) {
                    root.nightLight.warmer();
                } else if (shifted && event.key === root.runtime.shellKeyCode("controls", "H")) {
                    root.media.seekStep(-1);
                } else if (shifted && event.key === root.runtime.shellKeyCode("controls", "L")) {
                    root.media.seekStep(1);
                } else if ((event.key === root.runtime.shellKeyCode("controls", "H") || event.key === root.runtime.shellKeyCode("controls", "Left"))) {
                    root.adjustSelectedAudio(-0.05);
                } else if ((event.key === root.runtime.shellKeyCode("controls", "L") || event.key === root.runtime.shellKeyCode("controls", "Right"))) {
                    root.adjustSelectedAudio(0.05);
                } else if ((event.key === root.runtime.shellKeyCode("controls", "K") || event.key === root.runtime.shellKeyCode("controls", "Up"))) {
                    root.moveAudioSelection(-1);
                } else if ((event.key === root.runtime.shellKeyCode("controls", "J") || event.key === root.runtime.shellKeyCode("controls", "Down"))) {
                    root.moveAudioSelection(1);
                } else if (event.key === root.runtime.shellKeyCode("controls", "Q")) {
                    root.openTheme();
                } else if (event.key === root.runtime.shellKeyCode("controls", "W")) {
                    root.openWallpaper();
                } else if (event.key === root.runtime.shellKeyCode("controls", "E")) {
                    root.openSession();
                } else if (event.key === root.runtime.shellKeyCode("controls", "R")) {
                    root.openResources();
                } else if (event.key === root.runtime.shellKeyCode("controls", "F")) {
                    root.openNetwork();
                } else if (event.key === root.runtime.shellKeyCode("controls", "G")) {
                    root.openBluetooth();
                } else if (event.key === root.runtime.shellKeyCode("controls", "A")) {
                    root.notificationState.toggleSilent();
                } else if (event.key === root.runtime.shellKeyCode("controls", "S")) {
                    root.system.toggleIdleInhibited();
                } else if (event.key === root.runtime.shellKeyCode("controls", "C")) {
                    root.openRecordings();
                } else if (event.key === root.runtime.shellKeyCode("controls", "V") && root.powerProfile.available) {
                    root.powerProfile.cycle();
                } else if (event.key === root.runtime.shellKeyCode("controls", "N")) {
                    root.mediaRequested();
                } else if (event.key === root.runtime.shellKeyCode("controls", "M")) {
                    root.muteSelectedAudio();
                } else if (event.key === root.runtime.shellKeyCode("controls", "Z")) {
                    root.media.toggleShuffle();
                } else if (event.key === root.runtime.shellKeyCode("controls", "B")) {
                    root.media.toggleRepeat();
                } else if (event.key === root.runtime.shellKeyCode("controls", "X")) {
                    root.system.toggleMicrophoneMute();
                } else if (event.key === root.runtime.shellKeyCode("controls", "P")) {
                    root.toggleSelectedAudioDeviceChooser();
                } else if (root.runtime.shellMatchesHint("SystemContent.nightLight", event.key, event.modifiers)) {
                    root.nightLight.toggle();
                } else if (event.key === root.runtime.shellKeyCode("controls", "Minus") && event.modifiers === Qt.NoModifier) {
                    root.nightLight.warmer();
                } else if ((event.key === root.runtime.shellKeyCode("controls", "Plus") || (event.key === root.runtime.shellKeyCode("controls", "Equal") && shifted)) && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                    root.nightLight.cooler();
                } else if (event.key === root.runtime.shellKeyCode("controls", "Space")) {
                    root.media.togglePlaying();
                } else if (event.key === root.runtime.shellKeyCode("controls", "Comma")) {
                    root.media.previous();
                } else if (event.key === root.runtime.shellKeyCode("controls", "Period")) {
                    root.media.next();
                } else if (event.key === root.runtime.shellKeyCode("controls", "BracketLeft") && root.system.trayCount > 0) {
                    root.trayIndex = (root.trayIndex - 1 + root.system.trayCount) % root.system.trayCount;
                } else if (event.key === root.runtime.shellKeyCode("controls", "BracketRight") && root.system.trayCount > 0) {
                    root.trayIndex = (root.trayIndex + 1) % root.system.trayCount;
                } else if ((event.key === root.runtime.shellKeyCode("controls", "Return") || event.key === root.runtime.shellKeyCode("controls", "Enter")) && root.system.trayCount > 0) {
                    root.activateTrayItem();
                } else {
                    return;
                }
                event.accepted = true;
            }
        }
    }
}

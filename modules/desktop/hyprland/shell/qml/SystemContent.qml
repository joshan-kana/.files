pragma ComponentBehavior: Bound
import QtQuick
import "ClockFormatting.js" as ClockFormatting
import "DesktopIcons.js" as DesktopIcons
import Quickshell

FocusScope {
    id: root

    required property RuntimeConfig runtime
    required property Actions shellActions
    required property Theme theme
    required property Motion motion
    required property AppearancePreferences appearance
    required property SceneState scenes
    required property SystemState system
    required property MediaState media
    required property SpectrumState spectrum
    required property NotificationState notificationState
    required property BrightnessState brightness
    required property KeyboardState keyboard
    required property RecordingState recording
    property string statusMode: "Normal"
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
    signal displaySettingsRequested

    property bool engaged: false
    property bool presentationActive: false
    readonly property bool geometryReady: !requestedViewTimer.running
    property bool mixerOpen: false
    property real dashboardWidthBudget: theme.controlsDetailWidth
    property real detailWidthLimit: theme.controlsDetailWidth
    readonly property real detailLayoutWidth: Math.max(1, Math.min(detailWidthLimit, theme.controlsDetailWidth))
    readonly property int dashboardTileHeight: 72
    // Connectivity keeps its three readback lines readable at larger
    // text scales without shortening icons or truncating the last row.
    readonly property int dashboardBrightnessHeight: Math.max(90, theme.fontSize(66) + theme.spacing3 * 2)
    property string settingKind: ""
    readonly property string presentedDetail: settingsPanel.open ? settingKind : vhsPanel.open ? "vhs" : themePanel.open ? "theme" : wallpaperPanel.open ? "wallpaper" : networkPanel.open ? "network" : bluetoothPanel.open ? "bluetooth" : sessionPanel.open ? "session" : resourcesPanel.open ? "resources" : statusOpen ? "status" : mixerOpen ? "mixer" : recordingsPanel.open ? "recordings" : ""
    readonly property bool detailsVisible: settingsPanel.open || vhsPanel.open || trayMenu.open || networkPanel.open || bluetoothPanel.open || themePanel.open || wallpaperPanel.open || sessionPanel.open || resourcesPanel.open || statusOpen || mixerOpen || recordingsPanel.open
    property bool resetConfirmPending: false
    readonly property bool resetRunning: shellActions.resetRunning
    readonly property string resetStatus: shellActions.resetStatus

    function findDashboardAction(key: int, modifiers: int): var {
        for (const section of [controlsHeading, connectionTiles, actionTiles, visualTiles]) {
            for (const item of section.children) {
                if (item.actionId && runtime.shellMatchesHint(item.actionId, key, modifiers))
                    return {
                        item: item,
                        detail: false
                    };
                if (item.detailActionId && runtime.shellMatchesHint(item.detailActionId, key, modifiers))
                    return {
                        item: item,
                        detail: true
                    };
            }
        }
        return null;
    }

    function startDefaultReset(): void {
        if (!resetConfirmPending || resetRunning)
            return;
        resetConfirmPending = false;
        shellActions.restoreDesktopDefaults();
    }

    property string requestedView: ""
    required property bool returnToControls
    property bool helpOpen: false
    property int trayIndex: 0
    // One Controls-wide slider selection mode. Tab cycles only available
    // sliders; H/L and arrows edit the selected value without stealing the
    // existing audio keys outside this mode.
    property string selectedSlider: ""
    readonly property bool sliderNavigationEnabled: engaged && !resetConfirmPending && !helpOpen && !mixerOpen && !audioChooserOpen && !themeOpen && !wallpaperOpen && !sessionOpen && !networkOpen && !bluetoothOpen && !resourcesOpen && !statusOpen && !recordingsOpen && !trayMenuOpen && !vhsPanel.open && !settingsPanel.open
    readonly property var sliderTargets: brightness.supported ? ["brightness"] : []
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
        if (selectedSlider === "brightness" && brightness.supported) {
            brightnessSlider.beginKeyboardAdjustment();
            brightness.adjust(direction * brightness.adjustmentStep);
        }
    }

    function activateSlider(): void {
        if (selectedSlider === "brightness")
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
    readonly property bool wallpaperOpen: wallpaperPanel.open
    // Detail loaders retain their operation state, but only the logically
    // exposed detail can drive the panel contour. The dashboard uses its
    // owning tiles instead, including when several operations overlap.
    readonly property var foregroundSource: Array.from(viewStack.children).find(source => source.exposed === true && source.foregroundBusy === true) || null
    readonly property bool dashboardExposed: presentationActive && engaged && !detailsVisible
    readonly property bool foregroundBusy: !!foregroundSource || (mixerOpen && audioDeck.foregroundBusy)
    readonly property bool displayBusy: !!settingsPanel.panel?.displayOperationBusy
    readonly property bool nightLightBusy: nightLight.foregroundBusy
    readonly property bool sessionOpen: sessionPanel.open
    readonly property bool sessionConfirmationPending: sessionPanel.open && sessionPanel.armedAction.length > 0
    readonly property bool resourcesOpen: resourcesPanel.open
    readonly property bool statusOpen: statusPanel.open
    readonly property bool settingsOpen: settingsPanel.open
    readonly property bool vhsOpen: vhsPanel.open
    // List/gallery views own their own paging. Static editors share the hub
    // viewport when their measured content exceeds the monitor budget.
    readonly property bool detailUsesHostPaging: settingsOpen || vhsOpen || statusOpen || sessionOpen || resourcesOpen || mixerOpen || (wallpaperOpen && !!wallpaperPanel.panel?.policyView)
    readonly property bool recordingsOpen: recordingsPanel.open
    readonly property string helpTitle: settingsPanel.open ? "Settings" : statusOpen ? "System status" : recordingsPanel.open ? "Captures" : wallpaperPanel.open ? "Wallpaper library" : mixerOpen ? "Audio mixer" : resourcesPanel.open ? "Resource monitor" : (bluetoothPanel.open ? "Bluetooth controls" : (networkPanel.open ? "Network controls" : (themePanel.open ? "Theme controls" : (sessionPanel.open ? "Session controls" : (trayMenu.open ? "Tray menu controls" : "System controls")))))
    readonly property var helpBindings: settingsPanel.open ? [
        {
            key: root.runtime.shellHint("SettingsDetail.toggle"),
            action: "Enable / disable",
            visible: !!settingsPanel.panel?.hasMaster
        },
        {
            key: root.runtime.shellHint("SettingsDetail.adjust"),
            action: "Adjust selected parameter",
            visible: (settingsPanel.panel?.parameters.length || 0) > 0
        },
        {
            key: root.runtime.shellHint("SettingsDetail.select"),
            action: "Select parameter",
            visible: (settingsPanel.panel?.parameters.length || 0) > 1
        },
        {
            key: root.runtime.shellHint("SettingsDetail.reset"),
            action: "Restore defaults",
            visible: !!settingsPanel.panel?.hasReset
        },
        {
            key: root.runtime.shellHint("SettingsDetail.resetParameter"),
            action: "Restore selected parameter",
            visible: (settingsPanel.panel?.parameters.length || 0) > 1
        },
        {
            key: root.runtime.shellHint("SystemContent.legend.back"),
            action: "Back to Controls"
        },
        ...(settingsPanel.panel?.kind === "scenes" ? [
                {
                    key: root.runtime.shellHint("ScenePanel.select"),
                    action: "Select saved scene"
                },
                {
                    key: root.runtime.shellHint("ScenePanel.apply"),
                    action: "Activate scene"
                },
                {
                    key: root.runtime.shellHint("ScenePanel.save"),
                    action: "Save current switches"
                },
                {
                    key: root.runtime.shellHint("ScenePanel.stop"),
                    action: "Restore underlying preferences"
                },
                {
                    key: root.runtime.shellHint("ScenePanel.remove"),
                    action: "Remove selected inactive scene"
                }
            ] : []), ...(settingsPanel.panel?.kind === "displays" ? [
                {
                    key: root.runtime.shellHint("DisplaySettings.mode"),
                    action: "Choose resolution"
                },
                {
                    key: root.runtime.shellHint("DisplaySettings.refreshRate"),
                    action: "Choose refresh rate"
                },
                {
                    key: root.runtime.shellHint("DisplaySettings.saveProfile"),
                    action: "Save current display layout"
                },
                {
                    key: root.runtime.shellHint("DisplaySettings.nextProfile"),
                    action: "Choose saved layout"
                },
                {
                    key: root.runtime.shellHint("DisplaySettings.previewProfile"),
                    action: "Preview selected layout"
                },
                {
                    key: root.runtime.shellHint("DisplaySettings.deleteProfile"),
                    action: "Remove selected layout"
                }
            ] : []), ...(settingsPanel.panel?.kind === "stay" ? [
                {
                    key: root.runtime.shellHint("SettingsDetail.inhibitorsRefresh"),
                    action: "Refresh system inhibitor locks"
                }
            ] : []), ...(settingsPanel.panel?.kind === "power" ? root.powerProfile.profiles.map((profile, index) => ({
                        key: root.runtime.shellChoiceHint(index),
                        action: root.powerProfile.label(profile)
                    })) : []), ...(settingsPanel.panel?.kind === "spectrum" ? root.appearance.spectrumSurfaces.map((surface, index) => ({
                        key: root.runtime.shellChoiceHint(index),
                        action: "Preview " + surface.title.toLowerCase()
                    })).concat(settingsPanel.panel.spectrumModeActions.map(mode => ({
                        key: root.runtime.shellHint(mode.action),
                        action: "Set visualiser to " + mode.title
                    }))) : [])].filter(entry => entry.visible !== false) : vhsPanel.open ? [
        {
            key: root.runtime.shellHint("VhsPanel.select"),
            action: "Select VHS parameter"
        },
        {
            key: root.runtime.shellHint("VhsPanel.adjust"),
            action: "Adjust selected parameter"
        },
        {
            key: root.runtime.shellHint("VhsPanel.toggle"),
            action: "Toggle VHS"
        },
        {
            key: root.runtime.shellHint("VhsPanel.defaults"),
            action: "Restore VHS defaults"
        },
        {
            key: root.runtime.shellHint("VhsPanel.reset"),
            action: "Restore selected parameter"
        },
        {
            key: root.runtime.shellHint("SystemContent.legend.back"),
            action: root.returnToControls ? "Back to Controls" : "Close"
        }
    ] : statusOpen ? [
        {
            key: root.runtime.shellHint("StatusContent.close"),
            action: root.returnToControls ? "Back to Controls" : "Close"
        }
    ] : recordingsPanel.open ? [
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
            key: root.runtime.shellHint("RecordingLibrary.ocr"),
            action: "Select text or code in this capture"
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
        ...(wallpaperPanel.panel?.policyView ? wallpaperPanel.panel.scheduleActions : wallpaperPanel.panel?.galleryPolicyActions || []).map(entry => ({
                    key: root.runtime.shellHint(entry.action),
                    action: entry.title
                })),
        {
            key: root.runtime.shellHint("SystemContent.legend.esc_13"),
            action: root.returnToControls ? "Back to Controls" : "Close"
        }
    ] : mixerOpen && mixerView.panel?.hardwareOpen ? [
        {
            key: root.runtime.shellHint("AudioHardwareSettings.device"),
            action: "Previous / next audio device"
        },
        {
            key: root.runtime.shellHint("AudioHardwareSettings.devicePicker"),
            action: "Choose audio device"
        },
        {
            key: root.runtime.shellHint("AudioHardwareSettings.select"),
            action: "Select profile or physical port field"
        },
        {
            key: root.runtime.shellHint("AudioHardwareSettings.apply"),
            action: "Select / apply"
        },
        {
            key: root.runtime.shellHint("AudioHardwareSettings.refresh"),
            action: "Refresh devices"
        },
        {
            key: root.runtime.shellHint("SystemContent.legend.esc_18"),
            action: "Back to mixer"
        }
    ] : mixerOpen ? [
        {
            key: root.runtime.shellHint("AudioMixerContent.hardware"),
            action: "Device profiles and ports"
        },
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
            key: root.runtime.shellHint("ResourceDashboard.disk"),
            action: "Choose storage filesystem"
        },
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
                key: root.runtime.shellHint("NetworkPanel.checkConnectivity"),
                action: "Run configured NetworkManager connectivity check"
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
                ...(themePanel.panel?.galleryActions || []).map(entry => ({
                            key: root.runtime.shellHint(entry.action),
                            action: entry.title
                        })),
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
                        key: root.runtime.shellHint("SessionPanel.scenes"),
                        action: "Desktop scenes"
                    },
                    {
                        key: root.runtime.shellHint("SessionPanel.defaults"),
                        action: "Restore session defaults"
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
                            key: [root.runtime.shellHint("ControlsMediaCard.open"), root.runtime.shellHint("AudioMixerContent.open")].filter(Boolean).join(" / "),
                            action: "Now Playing / application mixer"
                        },
                        {
                            key: root.runtime.shellHint("SystemContent.legend.alerts_stay_awake_power_profile"),
                            action: "Alerts / stay awake / power profile"
                        },
                        {
                            key: [root.runtime.shellHint("MediaTransport.playCompact"), root.runtime.shellHint("MediaTransport.previousCompact"), root.runtime.shellHint("MediaTransport.nextCompact")].join(" / "),
                            action: "Play / pause · previous / next track"
                        },
                        {
                            key: root.runtime.shellHint("SystemContent.legend.shuffle_repeat_choose_player"),
                            action: "Shuffle / repeat"
                        },
                        {
                            key: [root.runtime.shellHint("MediaTransport.backCompact"), root.runtime.shellHint("MediaTransport.forwardCompact")].join(" / "),
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
                            action: "Night Light toggle / details"
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

    // The exposed detail owns its measured destination. Keep each outgoing
    // loader at its own width while the expansion host clips the crossfade.
    readonly property Item currentDetail: settingsPanel.open ? settingsPanel : vhsPanel.open ? vhsPanel : statusOpen ? statusPanel : recordingsPanel.open ? recordingsPanel : wallpaperPanel.open ? wallpaperPanel : mixerOpen ? mixerView : sessionPanel.open ? sessionPanel : resourcesPanel.open ? resourcesPanel : networkPanel.open ? networkPanel : bluetoothPanel.open ? bluetoothPanel : themePanel.open ? themePanel : null
    implicitWidth: currentDetail ? currentDetail.width : detailsVisible ? theme.controlsDetailWidth : dashboardWidthBudget
    implicitHeight: currentDetail ? currentDetail.implicitHeight : content.implicitHeight
    focus: engaged

    function closeDetails(): void {
        settingsPanel.closeView();
        vhsPanel.closeView();
        trayMenu.closeMenu();
        wallpaperPanel.closeView();
        networkPanel.closeView();
        bluetoothPanel.closeView();
        themePanel.closeView();
        sessionPanel.closeView();
        resourcesPanel.closeView();
        recordingsPanel.closeView();
        statusPanel.closeView();
        mixerOpen = false;
    }

    function backFromDetail(): void {
        if (settingsPanel.open && settingKind === "scenes")
            openSession();
        else
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
        } else if (wallpaperPanel.open && wallpaperPanel.panel && wallpaperPanel.panel.policyView) {
            wallpaperPanel.invoke("togglePolicyView");
        } else if (settingsPanel.open && settingsPanel.panel && settingsPanel.panel.cancelNested()) {
            return;
        } else if (resourcesPanel.open && resourcesPanel.panel && resourcesPanel.panel.cancelNested()) {
            return;
        } else if (mixerOpen) {
            mixerView.finishLoading();
            if (!mixerView.panel || !mixerView.panel.handleKey(Qt.Key_Escape, Qt.NoModifier))
                backFromDetail();
        } else if (audioChooserOpen) {
            audioDeck.handleKey(Qt.Key_Escape, Qt.NoModifier);
        } else if (networkPanel.open && networkPanel.panel && networkPanel.panel.profileTextEditing) {
            networkPanel.invoke("finishProfileText", false);
        } else if (networkPanel.open && networkPanel.panel && networkPanel.panel.profileEditing) {
            networkPanel.invoke("closeProfileEditor");
        } else if (networkPanel.open && networkPanel.passwordPrompt) {
            networkPanel.invoke("cancelPassword");
        } else if (recordingsPanel.open && recordingsPanel.panel && recordingsPanel.panel.ocrVisible) {
            recordingsPanel.invoke("closeText");
            keyboardFocus.forceActiveFocus();
        } else if (recordingsPanel.open && recordingsPanel.deletePending.length > 0) {
            recordingsPanel.invoke("cancelDelete");
        } else if (sessionPanel.open && sessionPanel.armedAction.length > 0) {
            sessionPanel.invoke("cancelConfirmation");
        } else if (bluetoothPanel.open && bluetoothPanel.panel && bluetoothPanel.panel.renaming) {
            bluetoothPanel.invoke("finishRename", false);
        } else if (bluetoothPanel.open && bluetoothPanel.panel && bluetoothPanel.panel.deviceDetail) {
            bluetoothPanel.invoke("toggleDeviceDetail");
        } else if (bluetoothPanel.open && bluetoothPanel.panel && bluetoothPanel.panel.forgetAddress.length > 0) {
            bluetoothPanel.invoke("clearTransientState");
        } else if (networkPanel.open && networkPanel.detailView) {
            networkPanel.invoke("toggleDetailView");
        } else if (networkPanel.open && networkPanel.savedView) {
            networkPanel.invoke("toggleSavedView");
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
        if (view !== "status")
            statusPanel.closeView();
        if (requestedView !== view)
            detailRequested(view);
    }

    function applyRequestedView(): void {
        if (!engaged)
            return;
        // A direct tile action already opened its destination. Synchronising
        // the navigation state must not close and reopen the same panel.
        if (requestedView.length > 0 && requestedView === presentedDetail)
            return;

        if (["windows", "glass", "nightLight", "alerts", "stay", "power", "reactive", "spectrum", "bar", "frame", "motion", "displays", "scenes"].includes(requestedView))
            openSetting(requestedView);
        else if (requestedView === "vhs")
            openVhs();
        else if (requestedView === "theme")
            openTheme();
        else if (requestedView === "session")
            openSession();
        else if (requestedView === "network")
            openNetwork();
        else if (requestedView === "bluetooth")
            openBluetooth();
        else if (requestedView === "resources")
            openResources();
        else if (requestedView === "status")
            openStatus();
        else if (requestedView === "mixer")
            openMixer();
        else if (requestedView === "wallpaper")
            openWallpaper();
        else if (requestedView.startsWith("recordings:")) {
            const filename = requestedView.slice("recordings:".length);
            openRecordings();
            recordingsPanel.invoke("queueText", filename);
        } else if (requestedView === "recordings")
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
        settingsPanel.prewarm();
        vhsPanel.prewarm();
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
            root.motion.endKeyboardAdjustment();
            helpOpen = false;
            selectedSlider = "";
            if (!visible)
                closeDetails();
        }
    }

    // An outgoing detail keeps its layout until the page fade completes.
    onVisibleChanged: if (!visible && !engaged)
        closeDetails()

    onRequestedViewChanged: requestedViewTimer.restart()

    function openSetting(name: string): void {
        if (!["windows", "glass", "nightLight", "alerts", "stay", "power", "reactive", "spectrum", "bar", "frame", "motion", "displays", "scenes"].includes(name))
            return;
        helpOpen = false;
        closeDetails();
        selectedSlider = "";
        settingKind = name;
        settingsPanel.openView();
        markDetail(name);
    }

    function openNetwork(): void {
        helpOpen = false;
        closeDetails();
        networkPanel.openView();
        markDetail("network");
    }

    function openBluetooth(): void {
        helpOpen = false;
        closeDetails();
        bluetoothPanel.openView();
        markDetail("bluetooth");
    }

    function openWallpaper(): void {
        helpOpen = false;
        closeDetails();
        wallpaperPanel.openView();
        markDetail("wallpaper");
    }

    function openVhs(): void {
        helpOpen = false;
        selectedSlider = "";
        closeDetails();
        vhsPanel.openView();
        markDetail("vhs");
    }

    function openTheme(): void {
        helpOpen = false;
        closeDetails();
        themePanel.openView();
        markDetail("theme");
    }

    function showTheme(): void {
        openTheme();
    }

    function openSession(): void {
        helpOpen = false;
        closeDetails();
        sessionPanel.openView();
        markDetail("session");
    }

    function showSession(): void {
        openSession();
    }

    function openResources(): void {
        helpOpen = false;
        closeDetails();
        resourcesPanel.openView();
        markDetail("resources");
    }

    function refreshStatus(): void {
        keyboard.refresh("inspect");
        brightness.refresh();
    }

    function openStatus(): void {
        helpOpen = false;
        closeDetails();
        statusPanel.openView();
        markDetail("status");
        keyboardFocus.forceActiveFocus();
    }

    function openMixer(): void {
        helpOpen = false;
        closeDetails();
        mixerOpen = true;
        markDetail("mixer");
    }

    function openRecordings(): void {
        helpOpen = false;
        closeDetails();
        recordingsPanel.openView();
        if (!requestedView.startsWith("recordings:"))
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
        audioDeck.triggerSelectedDeviceChooser();
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
        id: viewStack
        anchors.fill: parent

        Column {
            id: content
            // Keep the outgoing dashboard's grid at its own destination
            // size. The host clips it against the animated silhouette.
            width: root.dashboardWidthBudget
            x: (parent.width - width) / 2
            visible: !root.detailsVisible || opacity > 0.01
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
                    font.family: root.runtime.fontSans
                    font.pixelSize: root.theme.fontSize(12)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ClockFormatting.wallClock(controlsDateTime.date)
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
                    iconColor: root.theme.roleColor("display")
                    title: "Themes"
                    actionId: "SystemContent.themes"
                    foregroundBusy: root.dashboardExposed && themePanel.foregroundBusy
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
                    iconColor: root.theme.roleColor("wallpaper")
                    title: "Wallpaper"
                    actionId: "SystemContent.wallpaper"
                    foregroundBusy: root.dashboardExposed && wallpaperPanel.foregroundBusy
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
                    iconColor: root.theme.roleColor("resources")
                    title: "Session"
                    actionId: "SystemContent.session"
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
                                    id: brightnessSlider
                                    width: Math.max(1, parent.width - (root.brightness.supported ? brightnessHint.implicitWidth + parent.spacing : 0))
                                    theme: root.theme
                                    motion: root.motion
                                    from: 1
                                    to: 100
                                    value: root.brightness.percent
                                    enabled: root.brightness.supported
                                    density: ShellSlider.Prominent
                                    onInteractionStarted: root.selectSlider("brightness")
                                    onValueRequested: next => root.brightness.setPercent(next)
                                }
                                KeyHint {
                                    id: brightnessHint
                                    visible: root.brightness.supported
                                    shortcut: root.selectedSlider === "brightness" ? root.runtime.shellHint("SystemContent.audioLevel") : root.runtime.shellHint("SystemContent.brightnessFocus")
                                    label: root.selectedSlider === "brightness" ? "Adjust" : "Focus"
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
                            glyph: DesktopIcons.capabilityGlyph("network", {
                                wifiConnected: root.system.wifiConnected,
                                networkConnected: root.system.networkConnected
                            })
                            actionId: "SystemContent.network"
                            foregroundBusy: root.dashboardExposed && networkPanel.foregroundBusy
                            detailActionId: "SystemContent.networkDetails"
                            connected: root.system.networkConnected
                            primaryAvailable: root.system.wifiAvailable
                            pending: networkPanel.open && (networkPanel.profileActionRunning || networkPanel.pendingNetwork !== null)
                            failed: networkPanel.open && networkPanel.statusError
                            unavailable: root.system.networkDevices.length === 0
                            onActivated: {
                                if (root.system.wifiAvailable)
                                    root.system.setWifiEnabled(!root.system.wifiEnabled);
                            }
                            onDetailsRequested: root.openNetwork()
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
                            glyph: DesktopIcons.capabilityGlyph("bluetooth", {
                                active: root.system.bluetoothEnabled
                            })
                            actionId: "SystemContent.bluetooth"
                            foregroundBusy: root.dashboardExposed && bluetoothPanel.foregroundBusy
                            detailActionId: "SystemContent.bluetoothDetails"
                            connected: root.system.bluetoothEnabled
                            scanning: root.system.bluetoothDiscovering
                            pending: root.system.bluetoothDevices.some(device => device && device.pairing)
                            failed: bluetoothPanel.open && bluetoothPanel.statusError
                            unavailable: !root.system.bluetoothAvailable
                            onActivated: {
                                if (root.system.bluetoothAvailable)
                                    root.system.setBluetoothEnabled(!root.system.bluetoothEnabled);
                            }
                            onDetailsRequested: root.openBluetooth()
                        }
                    }
                }
            }

            Column {
                id: tileCanvas
                width: parent.width
                spacing: root.theme.spacing4

                ShellSection {
                    id: quickActionsSection
                    width: parent.width
                    runtime: root.runtime
                    theme: root.theme
                    title: "Quick Actions"
                    emphasized: true

                    BalancedTileFlow {
                        id: actionTiles
                        width: parent.width
                        spacing: root.theme.spacing2
                        textScale: root.theme.textScale

                        QuickSettingChip {
                            width: actionTiles.cellWidth(this)
                            height: Math.max(root.dashboardTileHeight, implicitHeight)
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: DesktopIcons.capabilityGlyph("alerts", {
                                active: !root.notificationState.silent
                            })
                            title: root.notificationState.silent ? "Silent" : "Alerts"
                            actionId: "SystemContent.alerts"
                            detailActionId: "SystemContent.alertsDetails"
                            onDetailsRequested: root.openSetting("alerts")
                            active: root.notificationState.silent
                            activeColor: root.notificationState.silent ? root.theme.roleColor("warning") : root.theme.roleColor("attention")
                            onActivated: root.notificationState.toggleSilent()
                        }

                        QuickSettingChip {
                            width: actionTiles.cellWidth(this)
                            height: Math.max(root.dashboardTileHeight, implicitHeight)
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: DesktopIcons.capabilityGlyph("stay", {
                                active: root.system.idleInhibited
                            })
                            title: root.system.idleInhibited ? "Stay awake" : "Idle allowed"
                            actionId: "SystemContent.stayAwake"
                            detailActionId: "SystemContent.stayDetails"
                            onDetailsRequested: root.openSetting("stay")
                            active: root.system.idleInhibited
                            activeColor: root.theme.roleColor("inhibition")
                            onActivated: root.system.toggleIdleInhibited()
                        }

                        QuickSettingChip {
                            width: actionTiles.cellWidth(this)
                            height: Math.max(root.dashboardTileHeight, implicitHeight)
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: DesktopIcons.capabilityGlyph("power", {
                                batteryAvailable: root.system.batteryAvailable,
                                batteryLevelIcon: root.system.batteryLevelIcon
                            })
                            title: (root.powerProfile.available ? root.powerProfile.label(root.powerProfile.current) : "Power") + (root.system.batteryAvailable ? " " + root.system.batteryPercent + "%" : "")
                            actionId: "SystemContent.powerProfile"
                            primaryAvailable: root.powerProfile.available
                            detailActionId: "SystemContent.powerDetails"
                            onDetailsRequested: root.openSetting("power")
                            active: root.powerProfile.current === "power-saver"
                            activeColor: root.theme.powerProfileColor(root.powerProfile.current)
                            onActivated: root.powerProfile.cycle()
                        }

                        QuickSettingChip {
                            width: actionTiles.cellWidth(this)
                            height: Math.max(root.dashboardTileHeight, implicitHeight)
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: DesktopIcons.glyphFor("resources")
                            title: "Resources"
                            detailActionId: "SystemContent.resources"
                            activeColor: root.theme.roleColor("resources")
                            onDetailsRequested: root.openResources()
                        }

                        QuickSettingChip {
                            width: actionTiles.cellWidth(this)
                            height: Math.max(root.dashboardTileHeight, implicitHeight)
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: DesktopIcons.glyphFor("captures")
                            title: "Captures"
                            detailActionId: "SystemContent.captures"
                            foregroundBusy: root.dashboardExposed && recordingsPanel.foregroundBusy
                            activeColor: root.theme.roleColor("capture")
                            onDetailsRequested: root.openRecordings()
                        }

                        QuickSettingChip {
                            width: actionTiles.cellWidth(this)
                            height: Math.max(root.dashboardTileHeight, implicitHeight)
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: DesktopIcons.glyphFor("displays")
                            title: "Displays"
                            detailActionId: "SystemContent.displays"
                            foregroundBusy: root.dashboardExposed && root.displayBusy
                            activeColor: root.theme.roleColor("display")
                            enabled: root.runtime.displaySettings.length > 0
                            onDetailsRequested: root.openSetting("displays")
                        }

                        QuickSettingChip {
                            width: actionTiles.cellWidth(this)
                            height: Math.max(root.dashboardTileHeight, implicitHeight)
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: DesktopIcons.glyphFor("status")
                            title: "Status"
                            detailActionId: "SystemContent.statusInspection"
                            activeColor: root.theme.roleColor(root.theme.capabilityRole("status"))
                            onDetailsRequested: root.openStatus()
                        }

                        QuickSettingChip {
                            width: actionTiles.cellWidth(this)
                            height: Math.max(root.dashboardTileHeight, implicitHeight)
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: DesktopIcons.actionGlyph("reset")
                            title: root.resetRunning ? "Restoring…" : "Restore defaults"
                            actionId: "SystemContent.reset"
                            foregroundBusy: root.dashboardExposed && root.resetRunning
                            active: root.resetConfirmPending
                            enabled: !root.resetRunning
                            activeColor: root.theme.roleColor("warning")
                            onActivated: {
                                root.resetConfirmPending = true;
                                root.shellActions.resetStatus = "";
                            }
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
                                text: root.resetConfirmPending ? "Restore desktop defaults, including Night Light, weather, capture locations and wallpaper schedules? Personal files, favourites and notification history will be kept." : root.resetStatus
                                color: root.resetConfirmPending ? root.theme.textStrong : root.theme.textMuted
                                font.family: root.runtime.fontSans
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
                            font.family: root.runtime.fontSans
                            font.pixelSize: root.theme.fontPanelEyebrow
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.0
                        }
                    }

                    BalancedTileFlow {
                        id: visualTiles
                        width: parent.width
                        spacing: root.theme.spacing2
                        textScale: root.theme.textScale

                        QuickSettingChip {
                            width: visualTiles.cellWidth(this)
                            height: Math.max(root.dashboardTileHeight, implicitHeight)
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: DesktopIcons.glyphFor("spectrum")
                            title: "Spectrum"
                            detailActionId: "SystemContent.spectrumDetails"
                            detailName: "Spectrum"
                            onDetailsRequested: root.openSetting("spectrum")
                            activeColor: root.theme.roleColor("spectrum")
                        }

                        QuickSettingChip {
                            width: visualTiles.cellWidth(this)
                            height: Math.max(root.dashboardTileHeight, implicitHeight)
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: DesktopIcons.glyphFor("audioMixer")
                            title: root.musicReactiveEnabled ? "Audio reactive" : "Reactive off"
                            actionId: "SystemContent.musicReactive"
                            detailActionId: "SystemContent.musicReactiveDetails"
                            detailName: "Reactive audio tuning"
                            onDetailsRequested: root.openSetting("reactive")
                            active: root.musicReactiveEnabled
                            activeColor: root.theme.roleColor("reactive")
                            onActivated: root.musicReactiveToggleRequested()
                        }

                        QuickSettingChip {
                            width: visualTiles.cellWidth(this)
                            height: Math.max(root.dashboardTileHeight, implicitHeight)
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: DesktopIcons.glyphFor("windows")
                            title: "Windows " + Math.round(root.appearance.windowOpacity * 100) + "%"
                            actionId: "SystemContent.windowTransparency"
                            detailActionId: "SystemContent.windowsDetails"
                            detailName: "Window transparency details"
                            active: root.windowTransparencyEnabled
                            activeColor: root.theme.roleColor("display")
                            onActivated: root.windowTransparencyToggleRequested()
                            onDetailsRequested: root.openSetting("windows")
                        }

                        QuickSettingChip {
                            width: visualTiles.cellWidth(this)
                            height: Math.max(root.dashboardTileHeight, implicitHeight)
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: DesktopIcons.glyphFor("glass")
                            title: "Glass " + Math.round(root.appearance.glassOpacity * 100) + "%"
                            actionId: "SystemContent.shellGlass"
                            detailActionId: "SystemContent.glassDetails"
                            detailName: "Frosted glass details"
                            active: root.shellGlassEnabled
                            activeColor: root.theme.roleColor("connectivity")
                            onActivated: root.shellGlassToggleRequested()
                            onDetailsRequested: root.openSetting("glass")
                        }

                        QuickSettingChip {
                            width: visualTiles.cellWidth(this)
                            height: Math.max(root.dashboardTileHeight, implicitHeight)
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: DesktopIcons.glyphFor("vhs")
                            title: "VHS " + Math.round(root.appearance.vhsIntensity * 100) + "%"
                            actionId: "SystemContent.vhsToggle"
                            detailActionId: "SystemContent.vhsTune"
                            detailName: "VHS tuning"
                            active: root.appearance.vhsEnabled
                            activeColor: root.theme.roleColor("reactive")
                            onActivated: root.appearance.toggleVhs()
                            onDetailsRequested: root.openVhs()
                        }

                        QuickSettingChip {
                            width: visualTiles.cellWidth(this)
                            height: Math.max(root.dashboardTileHeight, implicitHeight)
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: DesktopIcons.glyphFor("bar")
                            title: root.barVisible ? "Bar visible" : "Bar hidden"
                            actionId: "SystemContent.bar"
                            detailActionId: "SystemContent.barDetails"
                            detailName: "Bar settings"
                            onDetailsRequested: root.openSetting("bar")
                            active: root.barVisible
                            activeColor: root.theme.roleColor("workspace")
                            onActivated: root.barToggleRequested()
                        }
                        QuickSettingChip {
                            width: visualTiles.cellWidth(this)
                            height: Math.max(root.dashboardTileHeight, implicitHeight)
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: DesktopIcons.capabilityGlyph("frame", {
                                active: root.frameVisible
                            })
                            title: root.frameVisible ? "Frame visible" : "Frame hidden"
                            actionId: "SystemContent.frame"
                            detailActionId: "SystemContent.frameDetails"
                            detailName: "Frame settings"
                            onDetailsRequested: root.openSetting("frame")
                            active: root.frameVisible
                            activeColor: root.theme.roleColor("display")
                            onActivated: root.frameToggleRequested()
                        }

                        QuickSettingChip {
                            width: visualTiles.cellWidth(this)
                            height: Math.max(root.dashboardTileHeight, implicitHeight)
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: DesktopIcons.capabilityGlyph("motion", {
                                active: root.motion.enabled
                            })
                            title: root.motion.enabled ? "Animations" : "Reduced motion"
                            actionId: "SystemContent.motion"
                            detailActionId: "SystemContent.motionDetails"
                            detailName: "Motion settings"
                            onDetailsRequested: root.openSetting("motion")
                            active: root.motion.enabled
                            activeColor: root.theme.roleColor("motion")
                            onActivated: root.motion.toggle()
                        }

                        QuickSettingChip {
                            width: visualTiles.cellWidth(this)
                            height: Math.max(root.dashboardTileHeight, implicitHeight)
                            runtime: root.runtime
                            theme: root.theme
                            motion: root.motion
                            icon: DesktopIcons.capabilityGlyph("nightLight", {
                                active: root.nightLight.active
                            })
                            title: root.nightLight.supported ? "Night " + root.nightLight.temperature + " K" : "Night unavailable"
                            actionId: "SystemContent.nightLight"
                            primaryAvailable: root.nightLight.supported && !root.nightLight.busy
                            foregroundBusy: root.dashboardExposed && root.nightLightBusy
                            detailActionId: "SystemContent.nightLightDetails"
                            detailName: "Night Light details"
                            active: root.nightLight.active
                            activeColor: root.theme.roleColor("warmth")
                            onActivated: if (root.nightLight.supported && !root.nightLight.busy)
                                root.nightLight.toggle()
                            onDetailsRequested: root.openSetting("nightLight")
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
                        destinationBusy: mixerView.foregroundBusy
                        foregroundOutlineVisible: root.dashboardExposed
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
                    font.family: root.runtime.fontSans
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
                                        font.family: root.runtime.fontSans
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

        Item {
            id: statusPanel
            width: root.detailLayoutWidth
            x: (parent.width - width) / 2
            height: implicitHeight
            property bool open: false
            opacity: open ? 1 : 0
            visible: open || opacity > 0.01
            enabled: open
            Behavior on opacity {
                Anim {
                    motion: root.motion
                    type: Anim.FastEffects
                }
            }
            implicitWidth: statusContent.implicitWidth
            implicitHeight: statusContent.implicitHeight
            function openView(): void {
                open = true;
                root.refreshStatus();
            }
            function closeView(): void {
                open = false;
            }

            StatusContent {
                id: statusContent
                anchors.fill: parent
                runtime: root.runtime
                theme: root.theme
                motion: root.motion
                system: root.system
                keyboard: root.keyboard
                brightness: root.brightness
                recording: root.recording
                modeName: root.statusMode
                onRefreshRequested: root.refreshStatus()
            }
        }

        DeferredDetail {
            id: mixerView
            motion: root.motion
            width: root.detailLayoutWidth
            x: (parent.width - width) / 2
            height: Math.max(1, implicitHeight)
            requested: root.mixerOpen
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
            width: root.detailLayoutWidth
            x: (parent.width - width) / 2
            height: Math.max(1, implicitHeight)
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
            width: Math.min(root.detailLayoutWidth, root.theme.richDetailWidth)
            x: (parent.width - width) / 2
            height: Math.max(1, implicitHeight)
            sourceComponent: Component {
                ResourceDashboard {
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    resourceState: root.resourceState
                    onRevealSelection: (top, bottom) => root.revealContent(top, bottom)
                    onKeyboardRequested: keyboardFocus.forceActiveFocus()
                }
            }
        }

        DeferredDetail {
            id: networkPanel
            motion: root.motion
            width: Math.min(root.detailLayoutWidth, root.theme.standardDetailWidth)
            x: (parent.width - width) / 2
            height: Math.max(1, implicitHeight)
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
            width: Math.min(root.detailLayoutWidth, root.theme.standardDetailWidth)
            x: (parent.width - width) / 2
            height: Math.max(1, implicitHeight)
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
            width: root.detailLayoutWidth
            x: (parent.width - width) / 2
            height: Math.max(1, implicitHeight)
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
            id: settingsPanel
            motion: root.motion
            width: Math.min(root.detailLayoutWidth, panel?.implicitWidth || root.theme.richDetailWidth)
            x: (parent.width - width) / 2
            height: Math.max(1, implicitHeight)
            sourceComponent: Component {
                SettingsDetail {
                    kind: root.settingKind
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    appearance: root.appearance
                    scenes: root.scenes
                    nightLight: root.nightLight
                    notifications: root.notificationState
                    powerProfile: root.powerProfile
                    system: root.system
                    spectrum: root.spectrum
                    wallpaperSpectrumEnabled: root.wallpaperSpectrumEnabled
                    musicReactiveEnabled: root.musicReactiveEnabled
                    barVisible: root.barVisible
                    frameVisible: root.frameVisible
                    onNativeDisplayEditorRequested: root.displaySettingsRequested()
                    onRevealSelection: (top, bottom) => root.revealContent(top, bottom)
                    onWallpaperSpectrumToggleRequested: root.wallpaperSpectrumToggleRequested()
                    onMusicReactiveToggleRequested: root.musicReactiveToggleRequested()
                    onBarToggleRequested: root.barToggleRequested()
                    onFrameToggleRequested: root.frameToggleRequested()
                    onKeyboardRequested: keyboardFocus.forceActiveFocus()
                }
            }
        }

        DeferredDetail {
            id: vhsPanel
            motion: root.motion
            width: Math.min(root.detailLayoutWidth, root.theme.richDetailWidth)
            x: (parent.width - width) / 2
            height: Math.max(1, implicitHeight)
            sourceComponent: Component {
                VhsPanel {
                    runtime: root.runtime
                    theme: root.theme
                    motion: root.motion
                    appearance: root.appearance
                    onKeyboardRequested: keyboardFocus.forceActiveFocus()
                    onRevealSelection: (top, bottom) => root.revealContent(top, bottom)
                }
            }
        }

        DeferredDetail {
            id: themePanel
            motion: root.motion
            width: root.detailLayoutWidth
            x: (parent.width - width) / 2
            height: Math.max(1, implicitHeight)
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
            width: Math.max(1, Math.min(root.detailWidthLimit, Math.max(600, implicitWidth)))
            x: (parent.width - width) / 2
            height: Math.max(1, implicitHeight)
            sourceComponent: Component {
                SessionPanel {
                    scenes: root.scenes
                    system: root.system
                    onScenesRequested: root.openSetting("scenes")
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
            width: root.detailLayoutWidth
            x: (parent.width - width) / 2
            height: content.implicitHeight
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
                if ((root.sliderNavigationEnabled || root.mixerOpen || vhsPanel.open || settingsPanel.open) && (event.key === root.runtime.shellKeyCode("controls", "Tab") || event.key === root.runtime.shellKeyCode("controls", "Backtab")))
                    event.accepted = true;
            }

            onActiveFocusChanged: if (!activeFocus)
                root.motion.endKeyboardAdjustment()

            Keys.onReleased: event => {
                if (!event.isAutoRepeat && root.motion.releaseAdjustmentKey(event.key))
                    event.accepted = true;
            }

            Keys.onPressed: event => {
                root.motion.noteKeyDown(event.key);
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
                    } else if (root.runtime.shellNavigates("controls", "down", event.key)) {
                        root.helpScrollRequested(1);
                        event.accepted = true;
                    } else if (root.runtime.shellNavigates("controls", "up", event.key)) {
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

                if (settingsPanel.open) {
                    if (event.key === root.runtime.shellKeyCode("controls", "Backspace")) {
                        root.navigateBack();
                        event.accepted = true;
                    } else if (settingsPanel.invoke("handleKey", event.key, event.modifiers, event.isAutoRepeat)) {
                        event.accepted = true;
                    }
                    return;
                }

                if (vhsPanel.open) {
                    if (event.key === root.runtime.shellKeyCode("controls", "Backspace")) {
                        root.backFromDetail();
                        event.accepted = true;
                    } else if (vhsPanel.invoke("handleKey", event.key, event.modifiers, event.isAutoRepeat)) {
                        event.accepted = true;
                    }
                    return;
                }

                if (root.statusOpen) {
                    if (event.key === root.runtime.shellKeyCode("controls", "Backspace")) {
                        root.backFromDetail();
                        event.accepted = true;
                    } else if (root.runtime.shellMatchesHint("StatusContent.copy", event.key, event.modifiers)) {
                        if (!event.isAutoRepeat)
                            statusContent.triggerCopy();
                        event.accepted = true;
                    } else if (root.runtime.shellMatchesHint("StatusContent.refresh", event.key, event.modifiers)) {
                        if (!event.isAutoRepeat)
                            statusContent.triggerRefresh();
                        event.accepted = true;
                    }
                    return;
                }

                if (root.mixerOpen) {
                    mixerView.finishLoading();
                    if (mixerView.panel && mixerView.panel.handleKey(event.key, event.modifiers, event.isAutoRepeat))
                        event.accepted = true;
                    return;
                }

                if (audioDeck.deviceChooserOpen) {
                    if (audioDeck.handleKey(event.key, event.modifiers, event.isAutoRepeat))
                        event.accepted = true;
                    return;
                }

                if (wallpaperPanel.open) {
                    if (wallpaperPanel.panel && wallpaperPanel.panel.handlePolicyKey(event.key, event.modifiers, event.isAutoRepeat)) {
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Backspace")) {
                        root.navigateBack();
                        event.accepted = true;
                    } else if (wallpaperPanel.panel && wallpaperPanel.panel.policyView) {
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Slash")) {
                        wallpaperPanel.invoke("enterSearch");
                        event.accepted = true;
                    } else if (root.runtime.shellNavigates("controls", "left", event.key)) {
                        wallpaperPanel.invoke("moveSelection", -1);
                        event.accepted = true;
                    } else if (root.runtime.shellNavigates("controls", "right", event.key)) {
                        wallpaperPanel.invoke("moveSelection", 1);
                        event.accepted = true;
                    } else if (root.runtime.shellNavigates("controls", "up", event.key)) {
                        wallpaperPanel.invoke("moveGrid", 0, -1);
                        event.accepted = true;
                    } else if (root.runtime.shellNavigates("controls", "down", event.key)) {
                        wallpaperPanel.invoke("moveGrid", 0, 1);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "U") || event.key === root.runtime.shellKeyCode("controls", "PageUp") || event.key === root.runtime.shellKeyCode("controls", "D") || event.key === root.runtime.shellKeyCode("controls", "PageDown")) {
                        wallpaperPanel.invoke("moveHalfPage", (event.key === root.runtime.shellKeyCode("controls", "U") || event.key === root.runtime.shellKeyCode("controls", "PageUp")) ? -1 : 1);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Return") || event.key === root.runtime.shellKeyCode("controls", "Enter")) {
                        if (!event.isAutoRepeat)
                            wallpaperPanel.invoke("applySelected");
                        event.accepted = true;
                    }
                    return;
                }

                if (recordingsPanel.open) {
                    if (recordingsPanel.panel && recordingsPanel.panel.handleLocationKey(event.key, event.modifiers, event.isAutoRepeat)) {
                        event.accepted = true;
                        return;
                    }
                    if (recordingsPanel.panel && recordingsPanel.panel.ocrVisible) {
                        const shifted = !!root.runtime.shellModifier("controls", "Shift", event.modifiers);
                        const control = !!root.runtime.shellModifier("controls", "Control", event.modifiers);
                        if (event.key === root.runtime.shellKeyCode("controls", "Backspace") || root.runtime.shellMatchesHint("RecordingLibrary.ocr", event.key, event.modifiers)) {
                            recordingsPanel.invoke("closeText");
                            keyboardFocus.forceActiveFocus();
                        } else if (root.runtime.shellMatchesHint("RecordingLibrary.ocrSelectAll", event.key, event.modifiers)) {
                            recordingsPanel.invoke("selectAllWords");
                        } else if (root.runtime.shellMatchesHint("RecordingLibrary.ocrCopy", event.key, event.modifiers) || root.runtime.shellMatchesHint("RecordingLibrary.copy", event.key, event.modifiers)) {
                            recordingsPanel.invoke("copyHighlightedText");
                        } else if (!control && (root.runtime.shellNavigates("controls", "left", event.key))) {
                            recordingsPanel.invoke("moveWordSelection", -1, shifted);
                        } else if (!control && (root.runtime.shellNavigates("controls", "right", event.key))) {
                            recordingsPanel.invoke("moveWordSelection", 1, shifted);
                        } else {
                            return;
                        }
                        event.accepted = true;
                        return;
                    }
                    if (event.key === root.runtime.shellKeyCode("controls", "Backspace")) {
                        if (recordingsPanel.deletePending.length > 0)
                            recordingsPanel.invoke("cancelDelete");
                        else
                            root.backFromDetail();
                    } else if (root.runtime.shellNavigates("controls", "down", event.key)) {
                        recordingsPanel.invoke("moveSelection", 1);
                    } else if (root.runtime.shellNavigates("controls", "up", event.key)) {
                        recordingsPanel.invoke("moveSelection", -1);
                    } else if (root.runtime.shellMatchesHint("RecordingLibrary.pageUp", event.key, event.modifiers) || event.key === root.runtime.shellKeyCode("controls", "PageUp")) {
                        recordingsPanel.invoke("moveSelection", -4);
                    } else if (event.key === root.runtime.shellKeyCode("controls", "PageDown") || root.runtime.shellMatchesHint("RecordingLibrary.pageDown", event.key, event.modifiers)) {
                        recordingsPanel.invoke("moveSelection", 4);
                    } else if (root.runtime.shellMatchesHint("RecordingLibrary.delete", event.key, event.modifiers)) {
                        recordingsPanel.invoke("requestDelete");
                    } else if (root.runtime.shellMatchesHint("RecordingLibrary.edit", event.key, event.modifiers)) {
                        recordingsPanel.invoke("editSelected");
                    } else if (root.runtime.shellMatchesHint("RecordingLibrary.copy", event.key, event.modifiers)) {
                        recordingsPanel.invoke("copySelected");
                    } else if (root.runtime.shellMatchesHint("RecordingLibrary.ocr", event.key, event.modifiers)) {
                        recordingsPanel.invoke("showText");
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Return") || event.key === root.runtime.shellKeyCode("controls", "Enter")) {
                        recordingsPanel.invoke("openSelected");
                    } else if (root.runtime.shellMatchesHint("RecordingLibrary.refresh", event.key, event.modifiers)) {
                        if (!event.isAutoRepeat)
                            recordingsPanel.invoke("triggerRefresh");
                    } else {
                        return;
                    }
                    event.accepted = true;
                    return;
                }

                if (resourcesPanel.open) {
                    if (event.key === root.runtime.shellKeyCode("controls", "Backspace")) {
                        root.navigateBack();
                        event.accepted = true;
                    } else if (resourcesPanel.invoke("handleKey", event.key, event.modifiers, event.isAutoRepeat)) {
                        event.accepted = true;
                    }
                    return;
                }

                if (bluetoothPanel.open) {
                    if (bluetoothPanel.panel && bluetoothPanel.panel.renaming)
                        return;
                    if (root.runtime.shellMatchesHint("BluetoothPanel.detail", event.key, event.modifiers)) {
                        if (!event.isAutoRepeat)
                            bluetoothPanel.invoke("toggleDeviceDetail");
                        event.accepted = true;
                        return;
                    }
                    if (bluetoothPanel.panel && bluetoothPanel.panel.deviceDetail) {
                        if (root.runtime.shellMatchesHint("BluetoothPanel.rename", event.key, event.modifiers)) {
                            if (!event.isAutoRepeat)
                                bluetoothPanel.invoke("renameDevice");
                        } else if (root.runtime.shellMatchesHint("BluetoothPanel.wake", event.key, event.modifiers)) {
                            if (!event.isAutoRepeat)
                                bluetoothPanel.invoke("toggleWake");
                        } else if (event.key === root.runtime.shellKeyCode("controls", "Backspace")) {
                            bluetoothPanel.invoke("toggleDeviceDetail");
                        } else {
                            return;
                        }
                        event.accepted = true;
                        return;
                    }
                    if (event.key === root.runtime.shellKeyCode("controls", "Backspace")) {
                        root.navigateBack();
                        event.accepted = true;
                    } else if ((root.runtime.shellNavigates("controls", "up", event.key))) {
                        bluetoothPanel.invoke("moveSelection", -1);
                        event.accepted = true;
                    } else if ((root.runtime.shellNavigates("controls", "down", event.key))) {
                        bluetoothPanel.invoke("moveSelection", 1);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "U") || event.key === root.runtime.shellKeyCode("controls", "PageUp") || event.key === root.runtime.shellKeyCode("controls", "PageDown") || (event.key === root.runtime.shellKeyCode("controls", "D") && !(root.runtime.shellModifier("controls", "Shift", event.modifiers)))) {
                        bluetoothPanel.invoke("moveHalfPage", (event.key === root.runtime.shellKeyCode("controls", "U") || event.key === root.runtime.shellKeyCode("controls", "PageUp")) ? -1 : 1);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Return") || event.key === root.runtime.shellKeyCode("controls", "Enter")) {
                        bluetoothPanel.invoke("activateSelected");
                        event.accepted = true;
                    } else if (root.runtime.shellMatchesHint("BluetoothPanel.radio", event.key, event.modifiers)) {
                        bluetoothPanel.invoke("toggleBluetooth");
                        event.accepted = true;
                    } else if (root.runtime.shellMatchesHint("BluetoothPanel.scan", event.key, event.modifiers)) {
                        bluetoothPanel.invoke("toggleDiscovery");
                        event.accepted = true;
                    } else if (root.runtime.shellMatchesHint("BluetoothPanel.pair", event.key, event.modifiers)) {
                        bluetoothPanel.invoke("pairSelected");
                        event.accepted = true;
                    } else if (root.runtime.shellMatchesHint("BluetoothPanel.trust", event.key, event.modifiers)) {
                        bluetoothPanel.invoke("toggleTrust");
                        event.accepted = true;
                    } else if (root.runtime.shellMatchesHint("BluetoothPanel.forget", event.key, event.modifiers)) {
                        bluetoothPanel.invoke("forgetSelected");
                        event.accepted = true;
                    }

                    return;
                }

                if (sessionPanel.open) {
                    if (root.runtime.shellMatchesHint("SessionPanel.scenes", event.key, event.modifiers) && event.isAutoRepeat) {
                        event.accepted = true;
                    } else if (sessionPanel.invoke("activateShortcut", event.key, event.modifiers, event.isAutoRepeat) === true) {
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Backspace")) {
                        if (sessionPanel.armedAction.length > 0)
                            sessionPanel.invoke("cancelConfirmation");
                        else
                            root.backFromDetail();
                        event.accepted = true;
                    } else if (root.runtime.shellNavigates("controls", "up", event.key)) {
                        sessionPanel.invoke("moveGrid", 0, -1);
                        event.accepted = true;
                    } else if (root.runtime.shellNavigates("controls", "down", event.key)) {
                        sessionPanel.invoke("moveGrid", 0, 1);
                        event.accepted = true;
                    } else if (root.runtime.shellNavigates("controls", "left", event.key)) {
                        sessionPanel.invoke("moveGrid", -1, 0);
                        event.accepted = true;
                    } else if (root.runtime.shellNavigates("controls", "right", event.key)) {
                        sessionPanel.invoke("moveGrid", 1, 0);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Return") || event.key === root.runtime.shellKeyCode("controls", "Enter")) {
                        if (!event.isAutoRepeat)
                            sessionPanel.invoke("triggerSelected");
                        event.accepted = true;
                    }

                    return;
                }

                if (themePanel.open) {
                    if (themePanel.panel && themePanel.panel.handleGalleryKey(event.key, event.modifiers, event.isAutoRepeat)) {
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Slash")) {
                        themePanel.invoke("enterSearch");
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Backspace")) {
                        root.backFromDetail();
                        event.accepted = true;
                    } else if ((root.runtime.shellNavigates("controls", "up", event.key))) {
                        themePanel.invoke("moveGrid", 0, -1);
                        event.accepted = true;
                    } else if ((root.runtime.shellNavigates("controls", "down", event.key))) {
                        themePanel.invoke("moveGrid", 0, 1);
                        event.accepted = true;
                    } else if (root.runtime.shellNavigates("controls", "left", event.key)) {
                        themePanel.invoke("moveGrid", -1, 0);
                        event.accepted = true;
                    } else if (root.runtime.shellNavigates("controls", "right", event.key)) {
                        themePanel.invoke("moveGrid", 1, 0);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "U") || event.key === root.runtime.shellKeyCode("controls", "PageUp") || event.key === root.runtime.shellKeyCode("controls", "PageDown") || (event.key === root.runtime.shellKeyCode("controls", "D") && !(root.runtime.shellModifier("controls", "Shift", event.modifiers)))) {
                        themePanel.invoke("moveHalfPage", (event.key === root.runtime.shellKeyCode("controls", "U") || event.key === root.runtime.shellKeyCode("controls", "PageUp")) ? -1 : 1);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "X") && themePanel.operationRunning) {
                        if (!event.isAutoRepeat)
                            themePanel.invoke("cancelOperation");
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Return") || event.key === root.runtime.shellKeyCode("controls", "Enter")) {
                        if (!event.isAutoRepeat)
                            themePanel.invoke("activateSelected");
                        event.accepted = true;
                    }

                    return;
                }

                if (networkPanel.open) {
                    if (networkPanel.passwordPrompt || (networkPanel.panel && networkPanel.panel.profileTextEditing))
                        return;
                    if (networkPanel.panel && networkPanel.panel.profileEditing) {
                        if (root.runtime.shellMatchesHint("NetworkPanel.saveProfile", event.key, event.modifiers)) {
                            if (!event.isAutoRepeat)
                                networkPanel.invoke("saveProfile");
                        } else if (root.runtime.shellNavigates("controls", "up", event.key)) {
                            networkPanel.invoke("moveSelection", -1);
                        } else if (root.runtime.shellNavigates("controls", "down", event.key)) {
                            networkPanel.invoke("moveSelection", 1);
                        } else if (root.runtime.shellNavigates("controls", "left", event.key)) {
                            networkPanel.invoke("adjustProfileField", -1);
                        } else if (root.runtime.shellNavigates("controls", "right", event.key)) {
                            networkPanel.invoke("adjustProfileField", 1);
                        } else if ((event.key === root.runtime.shellKeyCode("controls", "Return") || event.key === root.runtime.shellKeyCode("controls", "Enter"))) {
                            if (!event.isAutoRepeat)
                                networkPanel.invoke("editProfileField");
                        } else if (event.key === root.runtime.shellKeyCode("controls", "Backspace")) {
                            networkPanel.invoke("closeProfileEditor");
                        } else {
                            return;
                        }
                        event.accepted = true;
                        return;
                    }
                    if (root.runtime.shellMatchesHint("NetworkPanel.checkConnectivity", event.key, event.modifiers)) {
                        if (!event.isAutoRepeat)
                            networkPanel.invoke("triggerConnectivityCheck");
                        event.accepted = true;
                        return;
                    }
                    if (root.runtime.shellMatchesHint("NetworkPanel.editProfile", event.key, event.modifiers) && networkPanel.detailView) {
                        if (!event.isAutoRepeat)
                            networkPanel.invoke("openProfileEditor");
                        event.accepted = true;
                        return;
                    }

                    if (event.key === root.runtime.shellKeyCode("controls", "Backspace")) {
                        root.navigateBack();
                        event.accepted = true;
                    } else if ((root.runtime.shellNavigates("controls", "up", event.key))) {
                        networkPanel.invoke("moveSelection", -1);
                        event.accepted = true;
                    } else if ((root.runtime.shellNavigates("controls", "down", event.key))) {
                        networkPanel.invoke("moveSelection", 1);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "U") || event.key === root.runtime.shellKeyCode("controls", "PageUp") || event.key === root.runtime.shellKeyCode("controls", "PageDown") || (event.key === root.runtime.shellKeyCode("controls", "D") && !(root.runtime.shellModifier("controls", "Shift", event.modifiers)))) {
                        networkPanel.invoke("moveHalfPage", (event.key === root.runtime.shellKeyCode("controls", "U") || event.key === root.runtime.shellKeyCode("controls", "PageUp")) ? -1 : 1);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Return") || event.key === root.runtime.shellKeyCode("controls", "Enter")) {
                        networkPanel.invoke("activateSelected");
                        event.accepted = true;
                    } else if (root.runtime.shellMatchesHint("NetworkPanel.detail", event.key, event.modifiers)) {
                        networkPanel.invoke("toggleDetailView");
                        event.accepted = true;
                    } else if (root.runtime.shellMatchesHint("NetworkPanel.refresh", event.key, event.modifiers) && networkPanel.detailView) {
                        if (!event.isAutoRepeat)
                            networkPanel.invoke("triggerRefresh");
                        event.accepted = true;
                    } else if (root.runtime.shellMatchesHint("NetworkPanel.saved", event.key, event.modifiers) && !networkPanel.detailView) {
                        networkPanel.invoke("toggleSavedView");
                        event.accepted = true;
                    } else if (root.runtime.shellMatchesHint("NetworkPanel.refresh", event.key, event.modifiers) && networkPanel.savedView && !networkPanel.detailView) {
                        if (!event.isAutoRepeat)
                            networkPanel.invoke("triggerRefresh");
                        event.accepted = true;
                    } else if (root.runtime.shellMatchesHint("NetworkPanel.toggleWifi", event.key, event.modifiers) && !networkPanel.savedView) {
                        networkPanel.invoke("toggleWifi");
                        event.accepted = true;
                    } else if (root.runtime.shellMatchesHint("NetworkPanel.advanced", event.key, event.modifiers)) {
                        Quickshell.execDetached([root.runtime.networkConnectionEditor]);
                        event.accepted = true;
                    }

                    return;
                }

                if (trayMenu.open) {
                    if (event.key === root.runtime.shellKeyCode("controls", "Backspace") || (root.runtime.shellNavigates("controls", "left", event.key))) {
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
                    } else if ((root.runtime.shellNavigates("controls", "up", event.key))) {
                        trayMenu.invoke("moveSelection", -1);
                        event.accepted = true;
                    } else if ((root.runtime.shellNavigates("controls", "down", event.key))) {
                        trayMenu.invoke("moveSelection", 1);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "U") || event.key === root.runtime.shellKeyCode("controls", "PageUp") || event.key === root.runtime.shellKeyCode("controls", "PageDown") || (event.key === root.runtime.shellKeyCode("controls", "D") && !(root.runtime.shellModifier("controls", "Shift", event.modifiers)))) {
                        trayMenu.invoke("moveHalfPage", (event.key === root.runtime.shellKeyCode("controls", "U") || event.key === root.runtime.shellKeyCode("controls", "PageUp")) ? -1 : 1);
                        event.accepted = true;
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Return") || event.key === root.runtime.shellKeyCode("controls", "Enter") || (root.runtime.shellNavigates("controls", "right", event.key))) {
                        trayMenu.invoke("activateSelected");
                        event.accepted = true;
                    }

                    return;
                }

                const dashboardAction = root.findDashboardAction(event.key, event.modifiers);
                if (dashboardAction && event.isAutoRepeat) {
                    event.accepted = true;
                    return;
                }
                const shifted = !!(root.runtime.shellModifier("controls", "Shift", event.modifiers));
                if (!dashboardAction && event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                    return;
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
                    } else if (!shifted && (root.runtime.shellNavigates("controls", "up", event.key))) {
                        root.cycleSlider(-1);
                    } else if (!shifted && (root.runtime.shellNavigates("controls", "down", event.key))) {
                        root.cycleSlider(1);
                    } else if (!shifted && (root.runtime.shellNavigates("controls", "left", event.key))) {
                        root.adjustSlider(-1);
                    } else if (!shifted && (root.runtime.shellNavigates("controls", "right", event.key))) {
                        root.adjustSlider(1);
                    } else if (event.key === root.runtime.shellKeyCode("controls", "Return") || event.key === root.runtime.shellKeyCode("controls", "Enter")) {
                        root.activateSlider();
                    } else {
                        // Other direct-action shortcuts keep their normal
                        // semantics; only editing keys belong to the slider.
                        root.selectedSlider = "";
                    }
                    if (event.key === root.runtime.shellKeyCode("controls", "Backspace") || (!shifted && (root.runtime.shellNavigates("controls", "left", event.key) || root.runtime.shellNavigates("controls", "right", event.key) || root.runtime.shellNavigates("controls", "up", event.key) || root.runtime.shellNavigates("controls", "down", event.key))) || event.key === root.runtime.shellKeyCode("controls", "Return") || event.key === root.runtime.shellKeyCode("controls", "Enter")) {
                        event.accepted = true;
                        return;
                    }
                }
                if (dashboardAction) {
                    if (dashboardAction.detail)
                        dashboardAction.item.triggerDetails();
                    else
                        dashboardAction.item.trigger();
                } else if (root.runtime.shellMatchesHint("SystemContent.brightnessFocus", event.key, event.modifiers) && root.brightness.supported) {
                    root.selectSlider("brightness");
                } else if (root.runtime.shellMatchesHint("AudioMixerContent.open", event.key, event.modifiers)) {
                    if (!event.isAutoRepeat)
                        audioDeck.triggerOpen();
                } else if (root.runtime.shellMatchesHint("MediaTransport.backCompact", event.key, event.modifiers)) {
                    mediaCard.triggerTransport("back", event.isAutoRepeat);
                } else if (root.runtime.shellMatchesHint("MediaTransport.forwardCompact", event.key, event.modifiers)) {
                    mediaCard.triggerTransport("forward", event.isAutoRepeat);
                } else if (event.modifiers === Qt.NoModifier && (root.runtime.shellNavigates("controls", "left", event.key))) {
                    root.adjustSelectedAudio(-root.system.volumeStep);
                } else if (event.modifiers === Qt.NoModifier && (root.runtime.shellNavigates("controls", "right", event.key))) {
                    root.adjustSelectedAudio(root.system.volumeStep);
                } else if (event.modifiers === Qt.NoModifier && (root.runtime.shellNavigates("controls", "up", event.key))) {
                    root.moveAudioSelection(-1);
                } else if (event.modifiers === Qt.NoModifier && (root.runtime.shellNavigates("controls", "down", event.key))) {
                    root.moveAudioSelection(1);
                } else if (root.runtime.shellMatchesHint("MediaTransport.playCompact", event.key, event.modifiers)) {
                    mediaCard.triggerTransport("play", event.isAutoRepeat);
                } else if (root.runtime.shellMatchesHint("MediaTransport.previousCompact", event.key, event.modifiers)) {
                    mediaCard.triggerTransport("previous", event.isAutoRepeat);
                } else if (root.runtime.shellMatchesHint("MediaTransport.nextCompact", event.key, event.modifiers)) {
                    mediaCard.triggerTransport("next", event.isAutoRepeat);
                } else if (root.runtime.shellMatchesHint("ControlsMediaCard.open", event.key, event.modifiers)) {
                    if (!event.isAutoRepeat)
                        mediaCard.triggerOpen();
                } else if (root.runtime.shellMatchesHint("AudioDeviceControl.mute", event.key, event.modifiers)) {
                    if (!event.isAutoRepeat)
                        root.muteSelectedAudio();
                } else if (root.runtime.shellMatchesHint("ControlsMediaCard.shuffle", event.key, event.modifiers)) {
                    if (!event.isAutoRepeat)
                        mediaCard.triggerShuffle();
                } else if (root.runtime.shellMatchesHint("ControlsMediaCard.repeat", event.key, event.modifiers)) {
                    if (!event.isAutoRepeat)
                        mediaCard.triggerRepeat();
                } else if (root.runtime.shellMatchesHint("AudioDeviceControl.muteMicrophone", event.key, event.modifiers)) {
                    if (!event.isAutoRepeat)
                        audioDeck.triggerMicrophoneMute();
                } else if (root.runtime.shellMatchesHint("AudioDeviceControl.chooser", event.key, event.modifiers)) {
                    if (!event.isAutoRepeat)
                        root.toggleSelectedAudioDeviceChooser();
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

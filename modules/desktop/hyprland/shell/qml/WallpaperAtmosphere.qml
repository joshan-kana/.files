pragma ComponentBehavior: Bound
import QtQuick
import "DesktopIcons.js" as DesktopIcons

// Wallpaper owns procedural backgrounds. Mode selection is separate from the
// enable switch: browsing never applies an effect that was switched off.
Column {
    id: panel
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property AppearancePreferences appearance
    required property MusicReactiveState reactive
    property bool open: false
    property int selectedParameter: 0
    property int selectedAudioParameter: 0
    property bool audioDetailsOpen: false
    readonly property var audioParameters: [
        {
            key: "sensitivity",
            title: "Sensitivity",
            constraint: "musicReactiveSensitivity"
        },
        {
            key: "attack",
            title: "Attack",
            constraint: "musicReactiveAttack"
        },
        {
            key: "release",
            title: "Release",
            constraint: "musicReactiveRelease"
        },
        {
            key: "smoothing",
            title: "Smoothing",
            constraint: "musicReactiveSmoothing"
        }
    ]
    readonly property var modes: runtime.constraints.appearance.atmosphereMode.values
    readonly property string mode: appearance.atmosphereMode
    readonly property var style: appearance.atmosphereStyle(mode)

    spacing: theme.spacing3

    function activateChoice(index: int): void {
        if (index < 0 || index >= modes.length)
            return;
        const choice = modeRepeater.itemAt(index) as ShellChoice;
        choice?.trigger();
    }
    function toggle(): void {
        masterAction.trigger();
    }
    function handleKey(key: int, modifiers: int, autoRepeat: bool): bool {
        if (!audioDetailsOpen && runtime.shellMatchesHint("WallpaperAtmosphere.toggle", key, modifiers)) {
            if (!autoRepeat)
                toggle();
            return true;
        }
        if (runtime.shellMatchesHint("WallpaperAtmosphere.audioDetails", key, modifiers)) {
            if (!autoRepeat)
                audioDetailsOpen = !audioDetailsOpen;
            return true;
        }
        if (runtime.shellMatchesHint("WallpaperAtmosphere.audio", key, modifiers)) {
            if (!autoRepeat) {
                if (audioDetailsOpen)
                    masterAction.trigger();
                else
                    audioButton.trigger();
            }
            return true;
        }
        if (runtime.shellMatchesHint("WallpaperAtmosphere.backdrop", key, modifiers)) {
            if (!autoRepeat)
                backdropButton.trigger();
            return true;
        }
        if (runtime.shellMatchesHint("WallpaperAtmosphere.reset", key, modifiers)) {
            if (!autoRepeat)
                resetButton.trigger();
            return true;
        }
        if (runtime.shellMatchesHint("WallpaperAtmosphere.resetParameter", key, modifiers)) {
            if (!autoRepeat)
                if (audioDetailsOpen) {
                    const parameter = audioParameters[selectedAudioParameter];
                    appearance.setAtmosphereReactiveParameter(parameter.key, runtime.appearanceDefaults.atmosphereReactive[parameter.key]);
                } else {
                    appearance.resetAtmosphereParameter(mode, selectedParameter === 0 ? "opacity" : "speed");
                }
            return true;
        }
        const choiceIndex = runtime.shellChoiceIndex(key, modifiers, audioDetailsOpen ? 4 : modes.length);
        if (choiceIndex >= 0) {
            if (!autoRepeat) {
                if (audioDetailsOpen)
                    appearance.setAtmosphereReactiveParameter("emphasis", ["balanced", "bass", "mid", "treble"][choiceIndex]);
                else
                    activateChoice(choiceIndex);
            }
            return true;
        }
        if (runtime.shellNavigates("controls", "up", key) || runtime.shellNavigates("controls", "down", key)) {
            const direction = runtime.shellNavigates("controls", "up", key) ? -1 : 1;
            if (audioDetailsOpen)
                selectedAudioParameter = (selectedAudioParameter + direction + audioParameters.length) % audioParameters.length;
            else
                selectedParameter = (selectedParameter + direction + 2) % 2;
            return true;
        }
        if (runtime.shellNavigates("controls", "left", key) || runtime.shellNavigates("controls", "right", key)) {
            const direction = runtime.shellNavigates("controls", "left", key) ? -1 : 1;
            if (audioDetailsOpen) {
                const parameter = audioParameters[selectedAudioParameter];
                const limits = runtime.constraints.appearance[parameter.constraint];
                const next = appearance.atmosphereReactive[parameter.key] + direction * 0.05;
                appearance.setAtmosphereReactiveParameter(parameter.key, Math.max(limits.min, Math.min(limits.max, Math.round(next * 100) / 100)));
            } else {
                const parameter = selectedParameter === 0 ? "opacity" : "speed";
                const limits = runtime.constraints.appearance[selectedParameter === 0 ? "atmosphereOpacity" : "atmosphereSpeed"];
                const increment = selectedParameter === 0 ? 0.05 : 0.1;
                appearance.setAtmosphereParameter(mode, parameter, Math.max(limits.min, Math.min(limits.max, Math.round((style[parameter] + increment * direction) * 100) / 100)));
            }
            return true;
        }
        return false;
    }

    DetailHero {
        width: parent.width
        runtime: panel.runtime
        theme: panel.theme
        motion: panel.motion
        glyph: DesktopIcons.glyphFor("wallpaper")
        glyphFont: "Symbols Nerd Font"
        glyphColor: panel.theme.roleColor("wallpaper")
        title: panel.audioDetailsOpen ? "Audio response" : "Atmospheres"
        detail: panel.audioDetailsOpen ? "Wallpaper audio" : (panel.mode === "flow" ? "Flow field" : panel.mode.charAt(0).toUpperCase() + panel.mode.slice(1)) + " · " + (panel.style.backdrop ? "Theme background" : "Over wallpaper")
        actions: [
            ShellAction {
                id: masterAction
                width: implicitWidth
                height: implicitHeight
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                iconOnly: true
                switchControl: true
                active: panel.audioDetailsOpen ? panel.appearance.atmosphereAudioEnabled : panel.appearance.atmosphereEnabled
                title: panel.audioDetailsOpen ? active ? "Disable audio sync" : "Enable audio sync" : active ? "Disable atmospheres" : "Enable atmospheres"
                shortcut: panel.runtime.shellHint(panel.audioDetailsOpen ? "WallpaperAtmosphere.audio" : "WallpaperAtmosphere.toggle")
                onActivated: {
                    if (panel.audioDetailsOpen)
                        panel.appearance.toggleAtmosphereAudio();
                    else
                        panel.appearance.toggleAtmosphere(panel.mode);
                }
            },
            ShellUtilityAction {
                id: resetButton
                width: implicitWidth
                height: implicitHeight
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                icon: DesktopIcons.actionGlyph("reset")
                title: "Restore selected atmosphere defaults"
                shortcut: panel.runtime.shellHint("WallpaperAtmosphere.reset")
                onActivated: {
                    if (panel.audioDetailsOpen)
                        panel.appearance.clearOverride("atmosphereReactive");
                    else
                        panel.appearance.resetAtmosphere(panel.mode);
                }
            }
        ]
    }

    ShellText {
        visible: !panel.audioDetailsOpen
        width: parent.width
        runtime: panel.runtime
        theme: panel.theme
        text: "Styles"
        textRole: ShellText.Section
    }

    Flow {
        id: modeFlow
        visible: !panel.audioDetailsOpen
        width: parent.width
        spacing: panel.theme.spacing2
        // Preserve the physical QWE/ASD/ZXC choice layout at every width.
        readonly property int columns: 3
        Repeater {
            id: modeRepeater
            model: panel.modes
            delegate: ShellChoice {
                required property int index
                required property string modelData
                width: (modeFlow.width - (modeFlow.columns - 1) * modeFlow.spacing) / modeFlow.columns
                height: Math.max(panel.theme.fontSize(60), implicitHeight)
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                choices: modeRepeater
                choiceIndex: index
                joined: false
                icon: DesktopIcons.effectGlyph(modelData)
                title: modelData === "flow" ? "Flow field" : modelData.charAt(0).toUpperCase() + modelData.slice(1)
                shortcut: panel.runtime.shellChoiceHint(index)
                active: panel.mode === modelData
                onActivated: panel.appearance.selectAtmosphere(modelData)
            }
        }
    }

    ShellText {
        visible: !panel.audioDetailsOpen
        width: parent.width
        runtime: panel.runtime
        theme: panel.theme
        text: "Preview"
        textRole: ShellText.Section
    }

    ShellSurface {
        visible: !panel.audioDetailsOpen
        width: parent.width
        height: panel.audioDetailsOpen ? 0 : panel.theme.fontSize(174)
        theme: panel.theme
        motion: panel.motion
        surfaceLayer: ShellSurface.Group
        cornerRadius: panel.theme.radiusLarge
        clipContentToShape: true
        fillColor: panel.theme.background
        Loader {
            anchors.fill: parent
            anchors.margins: panel.theme.spacing2
            active: panel.open
            sourceComponent: AtmosphereEffect {
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                reactive: panel.reactive
                mode: panel.mode
                intensity: panel.style.opacity
                speed: panel.style.speed
                audioSync: panel.style.audio
            }
        }
    }

    Row {
        visible: !panel.audioDetailsOpen
        width: parent.width
        height: panel.audioDetailsOpen ? 0 : Math.max(audioLabel.implicitHeight, audioButton.implicitHeight, audioDetailsButton.implicitHeight)
        spacing: panel.theme.spacing2

        ShellText {
            id: audioLabel
            width: Math.max(1, parent.width - audioButton.width - audioDetailsButton.width - parent.spacing * 2)
            anchors.verticalCenter: parent.verticalCenter
            runtime: panel.runtime
            theme: panel.theme
            text: "Audio sync"
            textRole: ShellText.Action
        }
        ShellAction {
            id: audioButton
            width: implicitWidth
            height: implicitHeight
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            compact: true
            iconOnly: true
            switchControl: true
            title: active ? "Disable audio sync" : "Enable audio sync"
            active: panel.appearance.atmosphereAudioEnabled
            shortcut: panel.runtime.shellHint("WallpaperAtmosphere.audio")
            onActivated: panel.appearance.toggleAtmosphereAudio()
        }
        ShellUtilityAction {
            id: audioDetailsButton
            width: implicitWidth
            height: implicitHeight
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            icon: DesktopIcons.actionGlyph("settings")
            title: panel.audioDetailsOpen ? "Back to atmospheres" : "Audio response settings"
            shortcut: panel.runtime.shellHint("WallpaperAtmosphere.audioDetails")
            onActivated: panel.audioDetailsOpen = !panel.audioDetailsOpen
        }
    }

    Row {
        visible: !panel.audioDetailsOpen
        width: parent.width
        height: panel.audioDetailsOpen ? 0 : Math.max(backdropLabel.implicitHeight, backdropButton.implicitHeight)
        spacing: panel.theme.spacing2

        ShellText {
            id: backdropLabel
            width: Math.max(1, parent.width - backdropButton.width - parent.spacing)
            anchors.verticalCenter: parent.verticalCenter
            runtime: panel.runtime
            theme: panel.theme
            text: "Theme background"
            textRole: ShellText.Action
        }
        ShellAction {
            id: backdropButton
            width: implicitWidth
            height: implicitHeight
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            compact: true
            iconOnly: true
            switchControl: true
            title: active ? "Use wallpaper overlay" : "Use theme background"
            active: panel.appearance.atmosphereBackdrop
            shortcut: panel.runtime.shellHint("WallpaperAtmosphere.backdrop")
            onActivated: panel.appearance.toggleAtmosphereBackdrop()
        }
    }

    Repeater {
        model: panel.audioDetailsOpen ? [] : [
            {
                key: "opacity",
                title: "Opacity",
                bounds: panel.runtime.constraints.appearance.atmosphereOpacity,
                step: 0.05
            },
            {
                key: "speed",
                title: "Speed",
                bounds: panel.runtime.constraints.appearance.atmosphereSpeed,
                step: 0.1
            }
        ]
        delegate: ParameterCard {
            required property int index
            required property var modelData
            width: panel.width
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            title: modelData.title
            description: modelData.key === "opacity" ? "Blend strength" : "Motion"
            readback: Math.round(panel.style[modelData.key] * 100) + "%"
            from: modelData.bounds.min * 100
            to: modelData.bounds.max * 100
            value: panel.style[modelData.key] * 100
            adjustShortcut: panel.runtime.shellHint("WallpaperAtmosphere.adjust")
            resetShortcut: panel.runtime.shellHint("WallpaperAtmosphere.resetParameter")
            selectedParameter: panel.selectedParameter === index
            onSelectedRequested: panel.selectedParameter = index
            onValueRequested: next => panel.appearance.setAtmosphereParameter(panel.mode, modelData.key, next / 100)
            onResetRequested: panel.appearance.resetAtmosphereParameter(panel.mode, modelData.key)
        }
    }

    Repeater {
        model: panel.audioDetailsOpen ? panel.audioParameters : []
        delegate: ParameterCard {
            required property int index
            required property var modelData
            width: panel.width
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            title: modelData.title
            description: "Audio response"
            readback: Math.round(panel.appearance.atmosphereReactive[modelData.key] * 100) + "%"
            from: panel.runtime.constraints.appearance[modelData.constraint].min * 100
            to: panel.runtime.constraints.appearance[modelData.constraint].max * 100
            value: panel.appearance.atmosphereReactive[modelData.key] * 100
            adjustShortcut: panel.runtime.shellHint("WallpaperAtmosphere.adjust")
            resetShortcut: panel.runtime.shellHint("WallpaperAtmosphere.resetParameter")
            selectedParameter: panel.selectedAudioParameter === index
            onSelectedRequested: panel.selectedAudioParameter = index
            onValueRequested: next => panel.appearance.setAtmosphereReactiveParameter(modelData.key, next / 100)
            onResetRequested: panel.appearance.setAtmosphereReactiveParameter(modelData.key, panel.runtime.appearanceDefaults.atmosphereReactive[modelData.key])
        }
    }

    Flow {
        width: parent.width
        visible: panel.audioDetailsOpen
        spacing: panel.theme.spacing2
        Repeater {
            model: ["balanced", "bass", "mid", "treble"]
            delegate: ShellChoice {
                required property int index
                required property string modelData
                width: (parent.width - panel.theme.spacing2 * 3) / 4
                height: implicitHeight
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                title: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                shortcut: panel.runtime.shellChoiceHint(index)
                active: panel.appearance.atmosphereReactive.emphasis === modelData
                onActivated: panel.appearance.setAtmosphereReactiveParameter("emphasis", modelData)
            }
        }
    }

    KeyHintStrip {
        width: parent.width
        runtime: panel.runtime
        theme: panel.theme
        hints: [
            {
                shortcut: panel.runtime.shellHint("WallpaperAtmosphere.select"),
                label: "Select parameter"
            },
            {
                shortcut: panel.runtime.shellHint("WallpaperAtmosphere.adjust"),
                label: "Adjust"
            }
        ]
    }
}

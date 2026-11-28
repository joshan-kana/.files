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
        if (runtime.shellMatchesHint("WallpaperAtmosphere.toggle", key, modifiers)) {
            if (!autoRepeat)
                toggle();
            return true;
        }
        if (runtime.shellMatchesHint("WallpaperAtmosphere.audio", key, modifiers)) {
            if (!autoRepeat)
                audioButton.trigger();
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
                appearance.resetAtmosphereParameter(mode, selectedParameter === 0 ? "opacity" : "speed");
            return true;
        }
        const choiceIndex = runtime.shellChoiceIndex(key, modifiers, modes.length);
        if (choiceIndex >= 0) {
            if (!autoRepeat)
                activateChoice(choiceIndex);
            return true;
        }
        if (runtime.shellNavigates("controls", "up", key) || runtime.shellNavigates("controls", "down", key)) {
            selectedParameter = (selectedParameter + (runtime.shellNavigates("controls", "up", key) ? -1 : 1) + 2) % 2;
            return true;
        }
        if (runtime.shellNavigates("controls", "left", key) || runtime.shellNavigates("controls", "right", key)) {
            const parameter = selectedParameter === 0 ? "opacity" : "speed";
            const limits = runtime.constraints.appearance[selectedParameter === 0 ? "atmosphereOpacity" : "atmosphereSpeed"];
            const increment = selectedParameter === 0 ? 0.05 : 0.1;
            const direction = runtime.shellNavigates("controls", "left", key) ? -1 : 1;
            appearance.setAtmosphereParameter(mode, parameter, Math.max(limits.min, Math.min(limits.max, Math.round((style[parameter] + increment * direction) * 100) / 100)));
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
        title: "Atmospheres"
        detail: (panel.mode === "flow" ? "Flow field" : panel.mode.charAt(0).toUpperCase() + panel.mode.slice(1)) + " · " + (panel.style.backdrop ? "Theme background" : "Over wallpaper")
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
                active: panel.appearance.atmosphereEnabled
                title: active ? "Disable atmospheres" : "Enable atmospheres"
                shortcut: panel.runtime.shellHint("WallpaperAtmosphere.toggle")
                onActivated: panel.appearance.toggleAtmosphere(panel.mode)
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
                onActivated: panel.appearance.resetAtmosphere(panel.mode)
            }
        ]
    }

    ShellText {
        width: parent.width
        runtime: panel.runtime
        theme: panel.theme
        text: "Styles"
        textRole: ShellText.Section
    }

    Flow {
        id: modeFlow
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
        width: parent.width
        runtime: panel.runtime
        theme: panel.theme
        text: "Preview"
        textRole: ShellText.Section
    }

    ShellSurface {
        width: parent.width
        height: panel.theme.fontSize(174)
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
        width: parent.width
        height: Math.max(audioLabel.implicitHeight, audioButton.implicitHeight)
        spacing: panel.theme.spacing2

        ShellText {
            id: audioLabel
            width: Math.max(1, parent.width - audioButton.width - parent.spacing)
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
    }

    Row {
        width: parent.width
        height: Math.max(backdropLabel.implicitHeight, backdropButton.implicitHeight)
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
        model: [
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

pragma ComponentBehavior: Bound
import QtQuick
import "DesktopIcons.js" as DesktopIcons

Column {
    id: panel
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property SceneState scenes
    property bool engaged: false
    property int selectedIndex: 0
    property bool naming: false
    property string error: ""
    signal keyboardRequested
    signal revealSelection(real top, real bottom)
    onSelectedIndexChanged: {
        const row = sceneRows.itemAt(selectedIndex);
        if (engaged && row) {
            const top = row.mapToItem(panel, 0, 0).y;
            revealSelection(top, top + row.height);
        }
    }

    spacing: theme.spacing2
    onEngagedChanged: {
        if (!engaged)
            naming = false;
        else
            selectedIndex = Math.max(0, Math.min(selectedIndex, scenes.profiles.length - 1));
        error = "";
    }

    function cancelNested(): bool {
        if (!naming)
            return false;
        naming = false;
        keyboardRequested();
        return true;
    }

    function startNaming(): void {
        naming = true;
        error = "";
        nameInput.text = "";
        nameInput.forceActiveFocus();
    }

    function saveScene(): void {
        if (!scenes.save(nameInput.text)) {
            error = "Use a unique name (1–40 characters); up to 12 scenes.";
            return;
        }
        selectedIndex = scenes.profiles.length - 1;
        naming = false;
        error = "";
        keyboardRequested();
    }

    function handleKey(key: int, modifiers: int, autoRepeat: bool): bool {
        if (naming)
            return false;
        if (runtime.shellMatchesHint("ScenePanel.save", key, modifiers)) {
            if (!autoRepeat)
                saveAction.trigger();
        } else if (runtime.shellMatchesHint("ScenePanel.stop", key, modifiers)) {
            if (!autoRepeat)
                stopAction.trigger();
        } else if (runtime.shellMatchesHint("ScenePanel.remove", key, modifiers)) {
            if (!autoRepeat)
                removeAction.trigger();
        } else if (runtime.shellNavigates("controls", "up", key)) {
            selectedIndex = Math.max(0, selectedIndex - 1);
        } else if (runtime.shellNavigates("controls", "down", key)) {
            selectedIndex = Math.max(0, Math.min(scenes.profiles.length - 1, selectedIndex + 1));
        } else if (runtime.shellMatchesHint("ScenePanel.apply", key, modifiers) || key === runtime.shellKeyCode("controls", "Enter")) {
            if (!autoRepeat)
                (sceneRows.itemAt(selectedIndex) as ShellAction)?.trigger();
        } else {
            return false;
        }
        return true;
    }

    ShellSurface {
        width: parent.width
        height: sceneStatus.implicitHeight + panel.theme.spacing3 * 2
        theme: panel.theme
        motion: panel.motion
        surfaceLayer: ShellSurface.Group
        fillColor: panel.scenes.active ? panel.theme.choiceFill(panel.theme.choiceColor) : panel.theme.groupBase
        Row {
            id: sceneStatus
            x: panel.theme.spacing3
            y: panel.theme.spacing3
            width: Math.max(1, parent.width - panel.theme.spacing3 * 2)
            spacing: panel.theme.spacing2
            Text {
                text: DesktopIcons.glyphFor("scenes")
                font.family: "Symbols Nerd Font"
                font.pixelSize: panel.theme.fontSize(24)
                color: panel.theme.roleColor("workspace")
                anchors.verticalCenter: parent.verticalCenter
            }
            Column {
                width: Math.max(1, parent.width - stopAction.width - panel.theme.fontSize(30) - parent.spacing * 2)
                ShellText {
                    width: parent.width
                    runtime: panel.runtime
                    theme: panel.theme
                    text: panel.scenes.active ? panel.scenes.activeName : "No active scene"
                    textRole: ShellText.Title
                    wrapMode: Text.WordWrap
                }
                ShellText {
                    width: parent.width
                    runtime: panel.runtime
                    theme: panel.theme
                    text: panel.scenes.active ? "Temporary overrides · Preferences preserved" : "Save a reusable combination of visual and notification modes."
                    textRole: ShellText.Supporting
                    wrapMode: Text.WordWrap
                }
            }
            ShellUtilityAction {
                id: stopAction
                visible: panel.scenes.active
                width: visible ? implicitWidth : 0
                anchors.verticalCenter: parent.verticalCenter
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                icon: DesktopIcons.actionGlyph("cancel")
                title: "Stop scene"
                shortcut: panel.runtime.shellHint("ScenePanel.stop")
                enabled: visible && !panel.naming
                onActivated: panel.scenes.stop()
            }
        }
    }
    ShellSection {
        width: parent.width
        runtime: panel.runtime
        theme: panel.theme
        title: "Saved scenes"
        actions: [
            ShellUtilityAction {
                id: saveAction
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                icon: DesktopIcons.actionGlyph("save")
                title: panel.naming ? "Save scene" : "Save current"
                shortcut: panel.naming ? panel.runtime.shellHint("ScenePanel.apply") : panel.runtime.shellHint("ScenePanel.save")
                enabled: panel.scenes.profiles.length < 12
                onActivated: panel.naming ? panel.saveScene() : panel.startNaming()
            }
        ]
        ShellText {
            visible: panel.scenes.profiles.length === 0 && !panel.naming
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            text: "No saved scenes"
            textRole: ShellText.Supporting
        }
        Repeater {
            id: sceneRows
            model: panel.scenes.profiles
            delegate: ShellChoice {
                required property int index
                required property var modelData
                width: parent.width
                height: Math.max(panel.theme.fontSize(66), implicitHeight)
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                joined: false
                compact: true
                enabled: !panel.naming
                title: modelData.name
                subtitle: [modelData.appearance.wallpaperSpectrumEnabled ? "Wallpaper spectrum" : "", modelData.appearance.musicReactiveEnabled ? "Reactive" : "", modelData.appearance.shellGlassEnabled ? "Glass" : "", modelData.appearance.vhsEnabled ? "VHS" : "", modelData.animations ? "Motion" : "Reduced motion", modelData.silent ? "Silent" : "", modelData.presentation ? "Presentation" : ""].filter(Boolean).join(" · ")
                icon: active ? DesktopIcons.actionGlyph("confirm") : DesktopIcons.glyphFor("scenes")
                active: panel.scenes.activeName === modelData.name
                highlighted: index === panel.selectedIndex
                shortcut: highlighted ? panel.runtime.shellHint("ScenePanel.apply") : ""
                onActivated: {
                    panel.selectedIndex = index;
                    panel.scenes.apply(index);
                }
            }
        }
        ShellSurface {
            visible: panel.naming
            width: parent.width
            height: visible ? Math.max(44, panel.theme.fontSize(42)) : 0
            theme: panel.theme
            motion: panel.motion
            surfaceLayer: ShellSurface.Control
            cornerRadius: panel.theme.radiusMedium
            TextInput {
                id: nameInput
                anchors.fill: parent
                anchors.margins: panel.theme.spacing3
                color: panel.theme.textStrong
                font.family: panel.runtime.fontSans
                font.pixelSize: panel.theme.fontSize(13)
                maximumLength: 40
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                Accessible.name: "Scene name"
                Keys.onPressed: event => {
                    if (event.key === panel.runtime.shellKeyCode("controls", "Escape")) {
                        panel.cancelNested();
                        event.accepted = true;
                    } else if (event.key === panel.runtime.shellKeyCode("controls", "Return") || event.key === panel.runtime.shellKeyCode("controls", "Enter")) {
                        if (!event.isAutoRepeat)
                            panel.saveScene();
                        event.accepted = true;
                    }
                }
            }
        }
        ShellText {
            visible: panel.naming
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            text: panel.error || "Enter a scene name, then Enter to save or Esc to cancel."
            textRole: ShellText.Supporting
            wrapMode: Text.WordWrap
        }
        Row {
            visible: panel.scenes.profiles.length > 0 && !panel.naming
            width: parent.width
            height: visible ? Math.max(removeAction.implicitHeight, selectionLabel.implicitHeight) : 0
            spacing: panel.theme.spacing2
            ShellText {
                id: selectionLabel
                width: Math.max(1, parent.width - removeAction.width - parent.spacing)
                anchors.verticalCenter: parent.verticalCenter
                runtime: panel.runtime
                theme: panel.theme
                text: panel.scenes.profiles[panel.selectedIndex] ? "Selected: " + panel.scenes.profiles[panel.selectedIndex].name : ""
                textRole: ShellText.Supporting
                elide: Text.ElideRight
            }
            ShellUtilityAction {
                id: removeAction
                visible: panel.scenes.profiles.length > 0 && !panel.naming
                width: visible ? implicitWidth : 0
                height: implicitHeight
                icon: DesktopIcons.actionGlyph("delete")
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                title: "Remove selected"
                activeColor: panel.theme.critical
                shortcut: panel.runtime.shellHint("ScenePanel.remove")
                enabled: visible && !!panel.scenes.profiles[panel.selectedIndex] && panel.scenes.profiles[panel.selectedIndex].name !== panel.scenes.activeName
                onActivated: {
                    panel.scenes.remove(panel.selectedIndex);
                    panel.selectedIndex = Math.max(0, Math.min(panel.selectedIndex, panel.scenes.profiles.length - 1));
                }
            }
        }
        KeyHintStrip {
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            visible: panel.scenes.profiles.length > 0 && !panel.naming
            hints: [
                {
                    shortcut: panel.runtime.shellHint("ScenePanel.select"),
                    label: "Select scene"
                }
            ]
        }
    }
}

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
        if (engaged && row)
            revealSelection(row.y, row.y + row.height);
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

    ShellText {
        width: parent.width
        runtime: panel.runtime
        theme: panel.theme
        text: panel.scenes.active ? "Active: " + panel.scenes.activeName + " · temporary until stopped or shell restart" : "No scene active"
        textRole: ShellText.Readback
        wrapMode: Text.WordWrap
    }
    ShellText {
        width: parent.width
        runtime: panel.runtime
        theme: panel.theme
        text: "Save the current visual switches, animations and manual notification modes. Scenes temporarily override these switches; stopping restores your underlying preferences. Schedules, display layouts, power and idle policy remain independent."
        textRole: ShellText.Supporting
        wrapMode: Text.WordWrap
    }
    Repeater {
        id: sceneRows
        model: panel.scenes.profiles
        delegate: ShellAction {
            required property int index
            required property var modelData
            width: parent.width
            height: Math.max(44, implicitHeight)
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            compact: true
            horizontalCompact: true
            enabled: !panel.naming
            title: modelData.name + (panel.scenes.activeName === modelData.name ? " · Active" : "")
            active: index === panel.selectedIndex
            shortcut: active ? panel.runtime.shellHint("ScenePanel.apply") : ""
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
        width: parent.width
        spacing: panel.theme.spacing2
        ShellAction {
            id: saveAction
            width: (parent.width - parent.spacing * 2) / 3
            height: Math.max(44, implicitHeight)
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            compact: true
            title: panel.naming ? "Save scene" : "Save current"
            shortcut: panel.naming ? panel.runtime.shellHint("ScenePanel.apply") : panel.runtime.shellHint("ScenePanel.save")
            enabled: panel.scenes.profiles.length < 12
            onActivated: panel.naming ? panel.saveScene() : panel.startNaming()
        }
        ShellAction {
            id: stopAction
            width: saveAction.width
            height: saveAction.height
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            compact: true
            title: "Stop scene"
            shortcut: panel.runtime.shellHint("ScenePanel.stop")
            enabled: panel.scenes.active && !panel.naming
            onActivated: panel.scenes.stop()
        }
        ShellAction {
            id: removeAction
            width: saveAction.width
            height: saveAction.height
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            compact: true
            title: "Remove selected"
            shortcut: panel.runtime.shellHint("ScenePanel.remove")
            enabled: !panel.naming && !!panel.scenes.profiles[panel.selectedIndex] && panel.scenes.profiles[panel.selectedIndex].name !== panel.scenes.activeName
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
        hints: [
            {
                shortcut: panel.runtime.shellHint("ScenePanel.select"),
                label: "Select scene"
            }
        ]
    }
}

pragma ComponentBehavior: Bound
import QtQuick
import "DesktopIcons.js" as DesktopIcons

Column {
    id: detail
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property AppearancePreferences appearance
    property string previewKey: "wallpaperVisualizerMode"
    readonly property int choiceCount: modes.count
    signal toggleWallpaperRequested
    readonly property var previewSurface: appearance.spectrumSurfaces.find(surface => surface.key === previewKey)
    function activateChoice(index: int): bool {
        const row = modes.itemAt(index) as PresentationRow;
        if (!row)
            return false;
        row.activate();
        return true;
    }
    function toggleWallpaper(): void {
        wallpaperToggle.trigger();
    }
    spacing: theme.spacing1

    ShellText {
        runtime: detail.runtime
        theme: detail.theme
        text: "Presentations"
        textRole: ShellText.Section
    }
    component PresentationRow: Row {
        required property ShellAction selector
        function activate(): void {
            selector.trigger();
        }
    }
    Repeater {
        id: modes
        model: detail.visible ? detail.appearance.spectrumSurfaces : []
        delegate: PresentationRow {
            id: modeRow
            required property int index
            required property var modelData
            width: detail.width
            selector: modeSelector
            spacing: detail.theme.spacing2
            ShellText {
                width: Math.max(1, parent.width - modeSelector.width - parent.spacing)
                anchors.verticalCenter: parent.verticalCenter
                runtime: detail.runtime
                theme: detail.theme
                text: modeRow.modelData.title
                textRole: ShellText.Action
                wrapMode: Text.WordWrap
            }
            ShellAction {
                id: modeSelector
                readonly property string mode: detail.appearance.spectrumMode(modeRow.modelData.key)
                width: Math.max(detail.theme.fontSize(150), implicitWidth)
                height: implicitHeight
                runtime: detail.runtime
                theme: detail.theme
                motion: detail.motion
                compact: true
                horizontalCompact: true
                title: mode === "curve" ? "Curve" : "Bars"
                icon: DesktopIcons.spectrumGlyph(mode)
                shortcut: detail.runtime.shellChoiceHint(modeRow.index)
                Accessible.description: modeRow.modelData.title + " spectrum style"
                onActivated: {
                    detail.previewKey = modeRow.modelData.key;
                    detail.appearance.toggleSpectrumMode(modeRow.modelData.key);
                }
            }
        }
    }
    Row {
        width: parent.width
        spacing: detail.theme.spacing2
        ShellText {
            width: Math.max(1, parent.width - wallpaperToggle.width - parent.spacing)
            anchors.verticalCenter: parent.verticalCenter
            runtime: detail.runtime
            theme: detail.theme
            text: "Wallpaper visualiser"
            textRole: ShellText.Action
        }
        ShellAction {
            id: wallpaperToggle
            width: implicitWidth
            height: implicitHeight
            runtime: detail.runtime
            theme: detail.theme
            motion: detail.motion
            compact: true
            iconOnly: true
            switchControl: true
            title: detail.appearance.wallpaperSpectrumEnabled ? "Disable wallpaper visualiser" : "Enable wallpaper visualiser"
            shortcut: detail.runtime.shellHint("SettingsDetail.toggle")
            active: detail.appearance.wallpaperSpectrumEnabled
            onActivated: detail.toggleWallpaperRequested()
        }
    }
}

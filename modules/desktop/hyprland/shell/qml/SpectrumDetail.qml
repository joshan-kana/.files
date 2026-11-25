pragma ComponentBehavior: Bound
import QtQuick

Column {
    id: detail
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property AppearancePreferences appearance
    readonly property var modeActions: [
        {
            value: "off",
            title: "Off",
            action: "SpectrumDetail.off"
        },
        {
            value: "bars",
            title: "Bars",
            action: "SpectrumDetail.bars"
        },
        {
            value: "curve",
            title: "Curve",
            action: "SpectrumDetail.curve"
        }
    ]
    property int previewIndex: 0
    readonly property int choiceCount: appearance.spectrumSurfaces.length
    readonly property var previewSurface: appearance.spectrumSurfaces[previewIndex]
    readonly property string previewKey: previewSurface.key
    function activateChoice(index: int): bool {
        const row = rows.itemAt(index) as PresentationRow;
        if (!row)
            return false;
        row.selectPreview();
        return true;
    }
    function chooseMode(index: int): bool {
        const row = rows.itemAt(previewIndex) as PresentationRow;
        return !!row && row.selectMode(index);
    }
    spacing: theme.spacing2

    component PresentationRow: Column {
        required property ShellAction previewAction
        required property Repeater modeChoices
        function selectPreview(): void {
            previewAction.trigger();
        }
        function selectMode(index: int): bool {
            const choice = modeChoices.itemAt(index) as ShellChoice;
            if (!choice)
                return false;
            choice.trigger();
            return true;
        }
    }

    ShellText {
        runtime: detail.runtime
        theme: detail.theme
        text: "Visualisers"
        textRole: ShellText.Section
    }

    Grid {
        id: presentationGrid
        width: parent.width
        columns: width >= detail.theme.fontSize(650) ? 2 : 1
        spacing: detail.theme.spacing2
        Repeater {
            id: rows
            model: detail.visible ? detail.appearance.spectrumSurfaces : []
            delegate: PresentationRow {
                id: row
                required property int index
                required property var modelData
                width: (presentationGrid.width - (presentationGrid.columns - 1) * presentationGrid.spacing) / presentationGrid.columns
                spacing: detail.theme.spacing1
                previewAction: previewButton
                modeChoices: modeRepeater
                ShellAction {
                    id: previewButton
                    width: parent.width
                    height: implicitHeight
                    runtime: detail.runtime
                    theme: detail.theme
                    motion: detail.motion
                    horizontalCompact: true
                    compact: true
                    quietAction: true
                    active: detail.previewIndex === row.index
                    title: row.modelData.title
                    shortcut: detail.runtime.shellChoiceHint(row.index)
                    Accessible.description: "Preview " + row.modelData.title.toLowerCase()
                    onActivated: detail.previewIndex = row.index
                }
                Row {
                    width: parent.width
                    spacing: detail.theme.spacing1
                    Repeater {
                        id: modeRepeater
                        model: detail.modeActions
                        delegate: ShellChoice {
                            required property int index
                            required property var modelData
                            width: (row.width - detail.theme.spacing1 * 2) / 3
                            height: implicitHeight
                            runtime: detail.runtime
                            theme: detail.theme
                            motion: detail.motion
                            horizontalCompact: true
                            compact: true
                            choices: modeRepeater
                            choiceIndex: index
                            title: modelData.title
                            shortcut: detail.previewIndex === row.index ? detail.runtime.shellHint(modelData.action) : ""
                            active: detail.appearance.spectrumPresentation(row.modelData.key) === modelData.value
                            Accessible.description: row.modelData.title + " · " + title
                            onActivated: {
                                detail.previewIndex = row.index;
                                detail.appearance.setSpectrumPresentation(row.modelData.key, modelData.value);
                            }
                        }
                    }
                }
            }
        }
    }
}

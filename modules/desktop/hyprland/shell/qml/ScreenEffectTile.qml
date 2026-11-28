pragma ComponentBehavior: Bound
import QtQuick
import "ScreenEffects.js" as ScreenEffects

QuickSettingChip {
    id: tile
    required property string mode
    required property AppearancePreferences appearance
    readonly property var descriptor: ScreenEffects.descriptor(mode)

    icon: descriptor?.glyph || ""
    title: descriptor?.title || ""
    detailName: title + " effect settings"
    detailActionId: "SystemContent." + mode + "Details"
    active: appearance.screenEffectEnabled(mode)
    activeColor: theme.roleColor("reactive")
}

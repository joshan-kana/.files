pragma ComponentBehavior: Bound
import QtQuick
import "NotificationPolicy.js" as Policy

Item {
    id: panel
    required property NotificationState notificationState
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    property int selectedIndex: 0
    readonly property var selectedApp: notificationState.managedApplications[selectedIndex] || null

    function move(delta: int): void {
        selectedIndex = Math.max(0, Math.min(notificationState.managedApplications.length - 1, selectedIndex + delta));
        appList.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function toggle(field: string): void {
        if (!selectedApp)
            return;
        const value = notificationState.applicationPreferences(selectedApp.key)[field];
        notificationState.setApplicationPreference(selectedApp.key, field, ["popups", "history"].includes(field) ? value === false : value !== true);
    }

    function reset(): void {
        if (selectedApp)
            notificationState.resetApplicationPreferences(selectedApp.key);
    }

    ShellText {
        anchors.centerIn: parent
        visible: panel.notificationState.managedApplications.length === 0
        runtime: panel.runtime
        theme: panel.theme
        text: "No application preferences"
        color: panel.theme.textMuted
    }

    ListView {
        id: appList
        anchors.fill: parent
        clip: true
        spacing: panel.theme.spacing2
        currentIndex: panel.selectedIndex
        model: panel.notificationState.managedApplications
        boundsBehavior: Flickable.StopAtBounds

        delegate: ShellSurface {
            id: entry
            required property int index
            required property var modelData
            readonly property var prefs: panel.notificationState.applicationPreferences(modelData.key)
            width: appList.width
            height: content.implicitHeight + panel.theme.spacing3 * 2
            theme: panel.theme
            motion: panel.motion
            surfaceLayer: ShellSurface.Control
            cornerRadius: panel.theme.radiusMedium
            outlined: index === panel.selectedIndex
            borderColor: index === panel.selectedIndex ? panel.theme.focusColor : "transparent"

            Column {
                id: content
                width: parent.width - panel.theme.spacing3 * 2
                anchors.centerIn: parent
                spacing: panel.theme.spacing2
                ShellText {
                    runtime: panel.runtime
                    theme: panel.theme
                    text: entry.modelData.name
                    textRole: ShellText.Section
                    width: parent.width
                    wrapMode: Text.WordWrap
                }
                Flow {
                    width: parent.width
                    spacing: panel.theme.spacing2
                    Repeater {
                        model: Policy.applicationFields()
                        delegate: ShellAction {
                            id: fieldAction
                            required property var modelData
                            width: implicitWidth
                            height: Math.max(40, implicitHeight)
                            runtime: panel.runtime
                            theme: panel.theme
                            motion: panel.motion
                            compact: true
                            horizontalCompact: true
                            switchControl: true
                            title: modelData.title
                            active: modelData.inverted ? entry.prefs[modelData.key] !== false : entry.prefs[modelData.key] === true
                            shortcut: entry.index === panel.selectedIndex ? panel.runtime.shellHint(modelData.action) : ""
                            onActivated: {
                                panel.selectedIndex = entry.index;
                                panel.notificationState.setApplicationPreference(entry.modelData.key, modelData.key, !active);
                            }
                        }
                    }
                    ShellAction {
                        width: implicitWidth
                        height: Math.max(40, implicitHeight)
                        runtime: panel.runtime
                        theme: panel.theme
                        motion: panel.motion
                        compact: true
                        horizontalCompact: true
                        title: "Reset"
                        shortcut: entry.index === panel.selectedIndex ? panel.runtime.shellHint("NotificationCard.defaults") : ""
                        onActivated: {
                            panel.selectedIndex = entry.index;
                            panel.notificationState.resetApplicationPreferences(entry.modelData.key);
                        }
                    }
                }
            }
        }
    }
}

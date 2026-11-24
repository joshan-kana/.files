pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    property string currentTab: ""
    readonly property int selectedIndex: currentTab === "home" ? 0 : currentTab === "activity" ? 2 : 1
    // Move in logical tab units, so the active selection stays aligned while
    // the shell changes its width during the measured-origin morph.
    property real animatedIndex: selectedIndex
    property bool initialized: false
    Component.onCompleted: initialized = true

    Behavior on animatedIndex {
        enabled: root.initialized && root.motion.enabled
        NumberAnimation {
            duration: root.motion.spatialSlow
            easing.type: root.motion.spatialType
            easing.bezierCurve: root.motion.spatialCurve
        }
    }

    signal tabRequested(string destination)
    signal helpRequested
    signal backRequested
    property bool helpOpen: false
    property string backLabel: "Back"

    implicitHeight: 46

    ShellSurface {
        id: track
        width: Math.max(0, parent.width - backButton.width - helpButton.width - root.theme.spacing2 * 2)
        height: 42
        anchors.left: backButton.right
        anchors.leftMargin: root.theme.spacing2
        theme: root.theme
        motion: root.motion
        surfaceLayer: ShellSurface.Control
        cornerRadius: root.theme.radiusLarge
        fillColor: root.theme.expressiveSurface

        SquircleSurface {
            id: slidingSelection
            x: root.theme.spacing1 + width * root.animatedIndex
            y: root.theme.spacing1
            width: Math.max(0, track.width - 2 * root.theme.spacing1) / 3
            height: track.height - 2 * root.theme.spacing1
            exponent: root.theme.squircleExponent
            cornerRadius: root.theme.radiusLarge
            fillColor: root.theme.selectedTabFill
            // Do not bloom the whole active tab with the accent colour.
            lightColor: root.theme.textStrong
            lightStrength: 0.025
        }

        Row {
            anchors {
                fill: parent
                margins: root.theme.spacing1
            }
            spacing: 0

            Repeater {
                model: [
                    {
                        label: "Home",
                        destination: "home"
                    },
                    {
                        label: "Controls",
                        destination: "controls"
                    },
                    {
                        label: "Activity",
                        destination: "activity"
                    }
                ]

                delegate: Item {
                    id: tab
                    required property var modelData
                    required property int index
                    readonly property bool chosen: root.selectedIndex === index
                    width: parent.width / 3
                    height: parent.height
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.label

                    Text {
                        id: tabLabel
                        scale: root.motion.enabled && tabPress.visualPressed ? root.motion.pressScaleNormal : 1
                        Behavior on scale {
                            enabled: root.motion.enabled
                            SpringAnimation {
                                spring: root.motion.pressSpring
                                damping: root.motion.pressDamping
                                epsilon: root.motion.pressEpsilon
                            }
                        }
                        anchors.centerIn: parent
                        text: tab.modelData.label
                        color: tab.chosen ? root.theme.textStrong : root.theme.textMuted
                        font.family: root.runtime.fontSans
                        font.pixelSize: root.theme.fontSize(12)
                        font.weight: tab.chosen ? Font.DemiBold : Font.Medium
                        Behavior on color {
                            ColorAnimation {
                                duration: root.motion.effectsFast
                            }
                        }
                    }

                    StateLayer {
                        id: tabPress
                        effectScaleX: tabLabel.scale
                        effectScaleY: tabLabel.scale
                        theme: root.theme
                        motion: root.motion
                        cornerRadius: root.theme.radiusMedium
                        stateColor: root.theme.textStrong
                        hoverOpacity: 0.13
                        pressOpacity: 0.20
                        disabled: root.helpOpen
                        Accessible.role: Accessible.Button
                        Accessible.name: tab.modelData.label
                        onActivated: root.tabRequested(tab.modelData.destination)
                    }
                }
            }
        }
    }

    // Back and Help flank the same three tabs on every hub page. Navigation
    // is dispatched by the active view, not by an extra header history.
    ShellSurface {
        id: backButton
        width: Math.max(64, backHint.implicitWidth + root.theme.fontSize(16) + root.theme.spacing2 * 2)
        height: 42
        scale: root.motion.enabled && backPress.visualPressed ? root.motion.pressScaleNormal : 1
        Behavior on scale {
            enabled: root.motion.enabled
            SpringAnimation {
                spring: root.motion.pressSpring
                damping: root.motion.pressDamping
                epsilon: root.motion.pressEpsilon
            }
        }
        anchors.left: parent.left
        theme: root.theme
        motion: root.motion
        surfaceLayer: ShellSurface.Control
        cornerRadius: root.theme.radiusLarge
        fillColor: root.theme.expressiveSurface
        Accessible.role: Accessible.Button
        Accessible.name: root.backLabel + " (" + root.runtime.shellHint("ShellExpansionHost.back") + ")"

        Row {
            anchors.centerIn: parent
            spacing: root.theme.spacing1

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "←"
                font.family: root.runtime.fontSans
                font.pixelSize: root.theme.fontSize(18)
                font.weight: Font.DemiBold
                color: root.theme.textStrong
            }

            KeyHint {
                id: backHint
                anchors.verticalCenter: parent.verticalCenter
                runtime: root.runtime
                theme: root.theme
                shortcut: root.runtime.shellHint("ShellExpansionHost.back")
                compact: true
            }
        }
    }

    // One discoverable contextual-help action for every hub page and detail.
    ShellSurface {
        id: helpButton
        width: 42
        height: 42
        scale: root.motion.enabled && helpPress.visualPressed ? root.motion.pressScaleNormal : 1
        Behavior on scale {
            enabled: root.motion.enabled
            SpringAnimation {
                spring: root.motion.pressSpring
                damping: root.motion.pressDamping
                epsilon: root.motion.pressEpsilon
            }
        }
        anchors.right: parent.right
        theme: root.theme
        motion: root.motion
        surfaceLayer: ShellSurface.Control
        cornerRadius: root.theme.radiusLarge
        selected: root.helpOpen
        fillColor: root.helpOpen ? root.theme.selectedTabFill : root.theme.expressiveSurface
        Accessible.role: Accessible.Button
        Accessible.name: "Keyboard help"

        KeyHint {
            anchors.centerIn: parent
            runtime: root.runtime
            theme: root.theme
            shortcut: root.runtime.shellHint("HubTabs.help")
            compact: true
            emphasized: root.helpOpen
        }
    }

    StateLayer {
        id: backPress
        anchors.fill: backButton
        effectScaleX: backButton.scale
        effectScaleY: backButton.scale
        theme: root.theme
        motion: root.motion
        cornerRadius: root.theme.radiusLarge
        Accessible.role: Accessible.Button
        Accessible.name: root.backLabel + " (" + root.runtime.shellHint("ShellExpansionHost.back") + ")"
        onActivated: root.backRequested()
    }

    StateLayer {
        id: helpPress
        anchors.fill: helpButton
        effectScaleX: helpButton.scale
        effectScaleY: helpButton.scale
        theme: root.theme
        motion: root.motion
        cornerRadius: root.theme.radiusLarge
        selected: root.helpOpen
        onActivated: root.helpRequested()
    }
}

pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import QtCore

Item {
    id: picker
    // Hosted by a dedicated full-display capture layer.
    property var screen: captureScreen
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    property var captureScreen: null
    property bool open: false
    property bool surfaceReady: true
    property bool pending: false
    property bool exporting: false
    property bool copying: true
    property string exportAction: "copy"
    property string selectionMode: "image"
    property string audioMode: "none"
    readonly property string audioLabel: audioMode === "system" ? "SYSTEM AUDIO" : audioMode === "microphone" ? "MICROPHONE" : "NO AUDIO"
    property string snapshotPath: ""
    property string statusText: ""
    readonly property bool freezeEnabled: capturePreferences.freezeEnabled
    property bool frozenForCapture: true
    property bool modeSnapshotPending: false
    property bool liveExportPending: false
    property Settings capturePreferences: Settings {
        id: capturePreferences
        location: "file://" + Quickshell.env("HOME") + "/.config/linux-desktop/preferences.ini"
        category: "Capture"
        property bool freezeEnabled: true
    }
    property real startX: 0
    property real startY: 0
    property real endX: 0
    property real endY: 0
    property bool dragging: false
    property bool initialiseSelection: true
    readonly property real leftEdge: Math.min(startX, endX)
    readonly property real topEdge: Math.min(startY, endY)
    readonly property real selectionWidth: Math.abs(endX - startX)
    readonly property real selectionHeight: Math.abs(endY - startY)
    // The Wayland selection is in logical units, while grim exports physical
    // pixels. One crop owns both the export arguments and displayed dimensions.
    readonly property var selectedPixels: {
        const ratio = captureScreen && captureScreen.devicePixelRatio ? captureScreen.devicePixelRatio : 1;
        const fullWidth = Math.max(1, frozen.implicitWidth > 1 ? frozen.implicitWidth : Math.ceil(picker.width * ratio));
        const fullHeight = Math.max(1, frozen.implicitHeight > 1 ? frozen.implicitHeight : Math.ceil(picker.height * ratio));
        const scaleX = fullWidth / Math.max(1, picker.width);
        const scaleY = fullHeight / Math.max(1, picker.height);
        const x = Math.max(0, Math.min(fullWidth - 1, Math.floor(picker.leftEdge * scaleX)));
        const y = Math.max(0, Math.min(fullHeight - 1, Math.floor(picker.topEdge * scaleY)));
        const w = Math.max(1, Math.min(fullWidth - x, Math.ceil(picker.selectionWidth * scaleX)));
        const h = Math.max(1, Math.min(fullHeight - y, Math.ceil(picker.selectionHeight * scaleY)));
        return {
            x,
            y,
            w,
            h
        };
    }
    signal snapshotReady

    visible: open && surfaceReady
    // Stay keyboard-active throughout the transparent screencopy pass.
    opacity: modeSnapshotPending ? 0 : 1
    anchors.fill: parent

    function clamp(value: real, minimum: real, maximum: real): real {
        return Math.max(minimum, Math.min(maximum, value));
    }

    function begin(copy: bool, target: var, mode: string): void {
        if (open || pending || exporting || !target || (mode !== "record" && runtime.frozenCapture.length === 0))
            return;
        captureScreen = target;
        copying = copy;
        selectionMode = mode;
        if (mode !== "record")
            audioMode = "none";
        initialiseSelection = true;
        statusText = "";
        frozenForCapture = mode !== "record" && freezeEnabled;
        liveExportPending = false;
        if (mode === "record") {
            // Screen recording selects a live region; only screenshots freeze.
            // No image capture or private snapshot file is created here.
            open = true;
            keyboard.forceActiveFocus();
            Qt.callLater(() => initialiseRect());
        } else if (frozenForCapture) {
            pending = true;
            snapshotProcess.exec([runtime.frozenCapture, "snapshot", target.name]);
        } else {
            // Live selection never displays an old frame. The final snapshot
            // is collected only after the shared modal has been hidden.
            snapshotReady();
            open = true;
            keyboard.forceActiveFocus();
            Qt.callLater(() => initialiseRect());
        }
    }

    function toggleFreeze(): void {
        if (selectionMode === "record" || exporting)
            return;
        capturePreferences.freezeEnabled = !capturePreferences.freezeEnabled;
        capturePreferences.setValue("freezeEnabled", capturePreferences.freezeEnabled);
        capturePreferences.sync();
        initialiseSelection = false;
        if (!capturePreferences.freezeEnabled) {
            modeSnapshotDelay.stop();
            modeRevealDelay.stop();
            modeSnapshotPending = false;
            pending = false;
            frozenForCapture = false;
            const oldPath = snapshotPath;
            snapshotPath = "";
            if (oldPath.length > 0)
                Quickshell.execDetached([runtime.frozenCapture, "clear", oldPath]);
            statusText = "LIVE REGION · CURRENT DESKTOP";
            keyboard.forceActiveFocus();
        } else if (open && captureScreen) {
            // Hide the overlay before sampling, then restore the same region.
            modeSnapshotPending = true;
            pending = true;
            frozenForCapture = true;
            statusText = "FREEZING CURRENT DESKTOP…";
            modeSnapshotDelay.restart();
        }
    }

    Timer {
        id: modeSnapshotDelay
        interval: 180
        repeat: false
        onTriggered: {
            if (picker.pending && picker.frozenForCapture && picker.captureScreen) {
                snapshotProcess.exec([picker.runtime.frozenCapture, "snapshot", picker.captureScreen.name]);
                modeRevealDelay.restart();
            }
        }
    }

    // grim copies the frame first and can spend much longer encoding a 4K
    // PNG. Restore the live region UI after screencopy has started; replace
    // its backdrop when the decoded frozen frame actually becomes ready.
    Timer {
        id: modeRevealDelay
        interval: 175
        repeat: false
        onTriggered: picker.modeSnapshotPending = false
    }

    function initialiseRect(): void {
        if (!open || !surfaceReady || !initialiseSelection || width <= 0 || height <= 0)
            return;
        // Recalculate when Wayland replaces its provisional 500px geometry.
        // Freeze the user's rectangle only after their first interaction.
        startX = width * 0.25;
        startY = height * 0.25;
        endX = width * 0.75;
        endY = height * 0.75;
    }

    onSurfaceReadyChanged: {
        if (surfaceReady && open)
            keyboard.forceActiveFocus();
        initialiseRect();
    }
    onWidthChanged: initialiseRect()
    onHeightChanged: initialiseRect()

    function showSnapshot(): void {
        if (frozen.status !== Image.Ready)
            return;
        if (liveExportPending) {
            liveExportPending = false;
            const pixels = selectedPixels;
            exportProcess.exec([runtime.frozenCapture, exportAction, snapshotPath, String(pixels.x), String(pixels.y), String(pixels.w), String(pixels.h)]);
            return;
        }
        if (!pending)
            return;
        pending = false;
        modeSnapshotPending = false;
        snapshotReady();
        open = true;
        keyboard.forceActiveFocus();
        Qt.callLater(() => initialiseRect());
    }

    function dismiss(clearFile: bool): void {
        if (exporting)
            return;
        modeSnapshotDelay.stop();
        modeRevealDelay.stop();
        const oldPath = snapshotPath;
        open = false;
        pending = false;
        dragging = false;
        snapshotPath = "";
        statusText = "";
        liveExportPending = false;
        modeSnapshotPending = false;
        if (clearFile && oldPath.length > 0)
            Quickshell.execDetached([runtime.frozenCapture, "clear", oldPath]);
    }

    function capture(action: string): void {
        if (!open || exporting || pending || selectionWidth < 5 || selectionHeight < 5)
            return;
        const pixelRect = selectedPixels;
        if (selectionMode === "record") {
            // Recorder geometry stays in compositor logical coordinates.
            const recordGeometry = String(Math.round(leftEdge + (captureScreen.x || 0))) + "," + String(Math.round(topEdge + (captureScreen.y || 0))) + " " + String(Math.ceil(selectionWidth)) + "x" + String(Math.ceil(selectionHeight));
            const outputName = captureScreen.name;
            const selectedAudio = audioMode;
            dismiss(true);
            Quickshell.execDetached([runtime.recordingToggle, "start", outputName, recordGeometry, selectedAudio]);
            return;
        }
        exportAction = action === "annotate" ? "annotate" : (copying ? "copy" : "save");
        exporting = true;
        if (!frozenForCapture) {
            // The modal must disappear before grim reads the live desktop;
            // leave the selection coordinates intact until export finishes.
            statusText = copying ? "CAPTURING LIVE FRAME…" : "SAVING LIVE FRAME…";
            if (snapshotPath.length > 0)
                Quickshell.execDetached([runtime.frozenCapture, "clear", snapshotPath]);
            snapshotPath = "";
            open = false;
            liveExportPending = true;
            liveCaptureDelay.restart();
        } else {
            statusText = exportAction === "annotate" ? "OPENING ANNOTATION…" : (copying ? "COPYING EXACT FRAME…" : "SAVING EXACT FRAME…");
            if (exportAction === "annotate")
                open = false;
            exportProcess.exec([runtime.frozenCapture, exportAction, snapshotPath, String(pixelRect.x), String(pixelRect.y), String(pixelRect.w), String(pixelRect.h)]);
        }
    }

    function moveSelection(dx: real, dy: real, resize: bool): void {
        initialiseSelection = false;
        if (resize) {
            endX = clamp(endX + dx, 0, width);
            endY = clamp(endY + dy, 0, height);
            return;
        }
        const rectWidth = selectionWidth;
        const rectHeight = selectionHeight;
        const newX = clamp(leftEdge + dx, 0, Math.max(0, width - rectWidth));
        const newY = clamp(topEdge + dy, 0, Math.max(0, height - rectHeight));
        startX = newX;
        startY = newY;
        endX = newX + rectWidth;
        endY = newY + rectHeight;
    }

    function nextMonitor(): void {
        if (!open || exporting || Quickshell.screens.length < 2)
            return;
        const index = Quickshell.screens.indexOf(captureScreen);
        const next = Quickshell.screens[(index + 1) % Quickshell.screens.length];
        const wasCopying = copying;
        const mode = selectionMode;
        dismiss(true);
        begin(wasCopying, next, mode);
    }

    Timer {
        id: liveCaptureDelay
        interval: 180
        repeat: false
        onTriggered: {
            if (picker.liveExportPending && picker.captureScreen)
                snapshotProcess.exec([picker.runtime.frozenCapture, "snapshot", picker.captureScreen.name]);
        }
    }

    StdioCollector {
        id: snapshotOutput
    }
    Process {
        id: snapshotProcess
        stdout: snapshotOutput
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                const wasModeSwitch = picker.modeSnapshotPending;
                picker.pending = false;
                if (wasModeSwitch) {
                    picker.frozenForCapture = false;
                    picker.modeSnapshotPending = false;
                    picker.open = true;
                    picker.statusText = "FREEZE FAILED · LIVE REGION AVAILABLE";
                    keyboard.forceActiveFocus();
                }
                if (picker.liveExportPending) {
                    picker.liveExportPending = false;
                    picker.exporting = false;
                    picker.open = true;
                    picker.statusText = "LIVE CAPTURE FAILED · ENTER RETRY · ESC CANCEL";
                    keyboard.forceActiveFocus();
                }
                console.warn("Screenshot snapshot failed with exit code", exitCode);
                return;
            }
            if (!picker.pending && !picker.liveExportPending) {
                const stale = snapshotOutput.text.trim();
                if (stale.length > 0)
                    Quickshell.execDetached([picker.runtime.frozenCapture, "clear", stale]);
                return;
            }
            picker.snapshotPath = snapshotOutput.text.trim();
            if (picker.modeSnapshotPending) {
                // Image loading must resume after the transparent capture pass;
                // leaving the entire picker invisible can suspend the decode.
                picker.modeSnapshotPending = false;
                keyboard.forceActiveFocus();
            }
        }
    }

    Process {
        id: exportProcess
        onExited: (exitCode, exitStatus) => {
            picker.exporting = false;
            if (exitCode === 0)
                picker.dismiss(false);
            else {
                if (!picker.frozenForCapture || picker.exportAction === "annotate") {
                    picker.open = true;
                    keyboard.forceActiveFocus();
                }
                picker.statusText = "CAPTURE FAILED · ENTER TO RETRY · ESC CANCEL";
            }
        }
    }

    Image {
        id: frozen
        anchors.fill: parent
        source: picker.selectionMode !== "record" && picker.snapshotPath.length > 0 ? "file://" + picker.snapshotPath : ""
        visible: picker.selectionMode !== "record" && picker.frozenForCapture
        fillMode: Image.Stretch
        asynchronous: true
        cache: false
        smooth: false
        onStatusChanged: picker.showSnapshot()
    }

    // Four lightweight rects, rather than an opaque fullscreen shader, keep
    // the selected source pixels unmodified and show what will be exported.
    Item {
        anchors.fill: parent
        visible: picker.open
        z: 1
        readonly property color scrim: picker.theme.dark ? picker.theme.background : picker.theme.textStrong
        readonly property real dim: 0.48

        Rectangle {
            x: 0
            y: 0
            width: parent.width
            height: Math.max(0, picker.topEdge)
            color: parent.scrim
            opacity: parent.dim
        }
        Rectangle {
            x: 0
            y: picker.topEdge
            width: Math.max(0, picker.leftEdge)
            height: picker.selectionHeight
            color: parent.scrim
            opacity: parent.dim
        }
        Rectangle {
            x: picker.leftEdge + picker.selectionWidth
            y: picker.topEdge
            width: Math.max(0, picker.width - x)
            height: picker.selectionHeight
            color: parent.scrim
            opacity: parent.dim
        }
        Rectangle {
            x: 0
            y: picker.topEdge + picker.selectionHeight
            width: parent.width
            height: Math.max(0, picker.height - y)
            color: parent.scrim
            opacity: parent.dim
        }
    }

    Rectangle {
        id: selectedArea
        x: picker.leftEdge
        y: picker.topEdge
        width: picker.selectionWidth
        height: picker.selectionHeight
        radius: 5
        color: Qt.rgba(picker.theme.roleColor("capture").r, picker.theme.roleColor("capture").g, picker.theme.roleColor("capture").b, 0.035)
        border.color: picker.theme.roleColor("capture")
        border.width: 2
        z: 2
        visible: picker.open
    }

    MouseArea {
        anchors.fill: parent
        z: 3
        cursorShape: Qt.CrossCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
                picker.dismiss(true);
                return;
            }
            if (picker.exporting)
                return;
            picker.dragging = true;
            picker.initialiseSelection = false;
            picker.startX = mouse.x;
            picker.startY = mouse.y;
            picker.endX = mouse.x;
            picker.endY = mouse.y;
        }
        onPositionChanged: mouse => {
            if (picker.dragging) {
                picker.endX = picker.clamp(mouse.x, 0, picker.width);
                picker.endY = picker.clamp(mouse.y, 0, picker.height);
            }
        }
        onReleased: mouse => {
            if (!picker.dragging)
                return;
            picker.dragging = false;
            picker.endX = picker.clamp(mouse.x, 0, picker.width);
            picker.endY = picker.clamp(mouse.y, 0, picker.height);
            picker.capture(mouse.modifiers & Qt.ShiftModifier ? "annotate" : "");
        }
    }

    ShellSurface {
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: picker.theme.spacing5
        }
        width: Math.min(picker.width - 48, 900)
        height: 78
        z: 5
        theme: picker.theme
        motion: picker.motion
        surfaceLayer: ShellSurface.Pane
        cornerRadius: picker.theme.radiusLarge
        Column {
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: picker.theme.spacing4
                rightMargin: picker.selectionMode === "record" ? picker.theme.spacing4 : 275
                verticalCenter: parent.verticalCenter
            }
            spacing: picker.theme.spacing2

            MarqueeText {
                width: parent.width
                text: (picker.selectionMode === "record" ? "VIDEO REGION · " + picker.audioLabel : (picker.frozenForCapture ? "FROZEN REGION · " : "LIVE REGION · ") + (picker.copying ? "COPY" : "SAVE")) + " · " + (picker.captureScreen ? picker.captureScreen.name : "")
                color: picker.theme.readableRoleColor("capture")
                font.family: picker.runtime.fontMono
                font.pixelSize: picker.theme.fontSize(12)
                font.weight: Font.DemiBold
            }

            MarqueeText {
                width: parent.width
                text: picker.statusText.length > 0 ? picker.statusText : "DRAG SELECT · ARROWS MOVE · SHIFT+ARROWS RESIZE · F FULL · TAB DISPLAY · " + (picker.selectionMode === "record" ? "A AUDIO · " : "Z FREEZE/LIVE · E EDIT · SHIFT+DRAG EDIT · ") + "ENTER CONFIRM · ESC CANCEL"
                color: picker.theme.textMuted
                font.family: picker.runtime.fontMono
                font.pixelSize: picker.theme.fontSize(9)
            }
        }

        Row {
            anchors {
                right: parent.right
                rightMargin: picker.theme.spacing2
                verticalCenter: parent.verticalCenter
            }
            visible: picker.selectionMode !== "record"
            spacing: picker.theme.spacing2

            ShellAction {
                width: 116
                height: 33
                runtime: picker.runtime
                theme: picker.theme
                motion: picker.motion
                horizontalCompact: true
                compact: true
                icon: "󰏫"
                title: "EDIT"
                shortcut: "E"
                onActivated: picker.capture("annotate")
            }
            ShellAction {
                width: 122
                height: 33
                runtime: picker.runtime
                theme: picker.theme
                motion: picker.motion
                horizontalCompact: true
                compact: true
                icon: "󰹑"
                title: picker.frozenForCapture ? "FROZEN" : "LIVE"
                shortcut: "Z"
                onActivated: picker.toggleFreeze()
            }
        }
    }

    Text {
        z: 5
        x: picker.leftEdge + picker.selectionWidth / 2 - implicitWidth / 2
        y: picker.topEdge + picker.selectionHeight + picker.theme.spacing2
        text: picker.selectionMode === "record" ? Math.ceil(picker.selectionWidth) + " × " + Math.ceil(picker.selectionHeight) + " REGION" : picker.selectedPixels.w + " × " + picker.selectedPixels.h + " PIXELS"
        color: picker.theme.textStrong
        font.family: picker.runtime.fontMono
        font.pixelSize: picker.theme.fontSize(11)
        visible: picker.open
    }

    FocusScope {
        id: keyboard
        anchors.fill: parent
        z: 4
        focus: picker.open
        Keys.onPressed: event => {
            if (!picker.open || picker.exporting)
                return;
            const resize = !!(event.modifiers & Qt.ShiftModifier);
            const step = resize ? 8 : 16;
            if (event.key === Qt.Key_Escape) {
                picker.dismiss(true);
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                picker.capture("");
            } else if (event.key === Qt.Key_Tab) {
                picker.nextMonitor();
            } else if (event.key === Qt.Key_A && picker.selectionMode === "record") {
                picker.audioMode = picker.audioMode === "none" ? "system" : picker.audioMode === "system" ? "microphone" : "none";
            } else if (event.key === Qt.Key_E && picker.selectionMode !== "record") {
                picker.capture("annotate");
            } else if (event.key === Qt.Key_Z && picker.selectionMode !== "record") {
                picker.toggleFreeze();
            } else if (event.key === Qt.Key_F) {
                picker.initialiseSelection = false;
                picker.startX = 0;
                picker.startY = 0;
                picker.endX = picker.width;
                picker.endY = picker.height;
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                picker.moveSelection(-step, 0, resize);
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                picker.moveSelection(step, 0, resize);
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                picker.moveSelection(0, -step, resize);
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                picker.moveSelection(0, step, resize);
            } else {
                return;
            }
            event.accepted = true;
        }
    }
}

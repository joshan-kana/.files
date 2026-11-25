pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "DesktopIcons.js" as DesktopIcons

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
    property bool annotateAfterCapture: false
    property string selectionMode: "image"
    readonly property var encodingPresets: selectionMode === "record" ? [
        {
            name: "Quality",
            values: {
                videoFormat: "mp4",
                codec: "libx264",
                frameRate: 60,
                videoQuality: 18
            }
        },
        {
            name: "Compact",
            values: {
                videoFormat: "mkv",
                codec: "libx265",
                frameRate: 30,
                videoQuality: 28
            }
        },
        {
            name: "Fast",
            values: {
                videoFormat: "mp4",
                codec: "libx264",
                frameRate: 30,
                videoQuality: 23
            }
        }
    ] : [
        {
            name: "Quality",
            values: {
                imageFormat: "png",
                jpegQuality: 95
            }
        },
        {
            name: "Compact",
            values: {
                imageFormat: "jpg",
                jpegQuality: 75
            }
        },
        {
            name: "Balanced",
            values: {
                imageFormat: "jpg",
                jpegQuality: 95
            }
        }
    ]
    readonly property int presetIndex: encodingPresets.findIndex(preset => Object.keys(preset.values).every(key => encoding(key) === preset.values[key]))
    readonly property string audioMode: String(encoding("audio"))
    property int remaining: 0
    readonly property bool countingDown: remaining > 0
    property bool frozenCursor: false
    property string encodingFieldKey: ""
    readonly property var selectedEncodingField: encodingFieldKey === "audio" ? {
        key: "audio",
        action: "ScreenshotPicker.edit",
        values: runtime.constraints.captureEncoding.audio.values
    } : encodingControls.find(field => field.key === encodingFieldKey) || null
    function encodingFieldLabel(key: string): string {
        return ({
                imageFormat: "Image format",
                jpegQuality: "JPEG quality",
                videoFormat: "Video container",
                codec: "Video codec",
                frameRate: "Frame rate",
                videoQuality: "Video quality",
                countdown: "Countdown",
                audio: "Audio source",
                preset: "Encoding preset"
            })[key] || "";
    }
    function encodingChoiceLabel(key: string, value: var): string {
        switch (key) {
        case "imageFormat":
        case "videoFormat":
            return String(value).toUpperCase();
        case "codec":
            return value === "libx265" ? "HEVC" : "H.264";
        case "frameRate":
            return value === 0 ? "Automatic" : value + " FPS";
        case "videoQuality":
            return "CRF " + value;
        case "jpegQuality":
            return value + "%";
        case "countdown":
            return value === 0 ? "None" : value + " seconds";
        case "audio":
            return value === "system" ? "System audio" : value === "microphone" ? "Microphone" : "No audio";
        default:
            return String(value);
        }
    }
    function openEncodingField(field: var): void {
        if (!field || countingDown || exporting || (selectionMode !== "record" && (copying || annotateAfterCapture) && ["imageFormat", "jpegQuality", "preset"].includes(field.key)))
            return;
        if (field.key === "cursor") {
            encodingSelector.cancel();
            setEncoding("cursor", !encoding("cursor"));
        } else if (field.key === "") {
            encodingSelector.cancel();
            resetToDeclared();
        } else if (encodingFieldKey === field.key && encodingSelector.expanded) {
            encodingSelector.cancel();
        } else {
            encodingSelector.cancel();
            encodingFieldKey = field.key;
            Qt.callLater(() => {
                if (picker.open && picker.encodingFieldKey === field.key)
                    encodingSelector.toggle();
            });
        }
    }
    function chooseEncoding(index: int): void {
        const field = selectedEncodingField;
        if (!field || index < 0 || index >= field.values.length)
            return;
        if (field.key === "preset")
            qmlCapturePreferences.setMany(encodingPresets[index].values);
        else
            setEncoding(field.key, field.values[index]);
        encodingFieldKey = "";
    }
    readonly property var encodingControls: {
        const record = selectionMode === "record";
        const lossless = copying || annotateAfterCapture;
        const fields = record ? [
            {
                key: "videoFormat",
                action: "ScreenshotPicker.format",
                title: String(encoding("videoFormat")).toUpperCase(),
                values: runtime.constraints.captureEncoding.videoFormat.values
            },
            {
                key: "codec",
                action: "ScreenshotPicker.codec",
                title: encoding("codec") === "libx265" ? "HEVC" : "H.264",
                values: runtime.constraints.captureEncoding.codec.values
            },
            {
                key: "frameRate",
                action: "ScreenshotPicker.fps",
                title: encoding("frameRate") === 0 ? "Auto FPS" : encoding("frameRate") + " FPS",
                values: runtime.constraints.captureEncoding.frameRate.values
            },
            {
                key: "videoQuality",
                action: "ScreenshotPicker.quality",
                title: "CRF " + encoding("videoQuality"),
                values: runtime.constraints.captureEncoding.videoQuality.values
            },
            {
                key: "countdown",
                action: "ScreenshotPicker.countdown",
                title: "Delay " + encoding("countdown") + "s",
                values: runtime.constraints.captureEncoding.countdown.values
            }
        ] : [
            {
                key: "imageFormat",
                action: "ScreenshotPicker.format",
                title: lossless ? "PNG export" : String(encoding("imageFormat")).toUpperCase(),
                values: runtime.constraints.captureEncoding.imageFormat.values
            },
            {
                key: "jpegQuality",
                action: "ScreenshotPicker.quality",
                title: "JPEG " + encoding("jpegQuality") + "%",
                values: runtime.constraints.captureEncoding.jpegQuality.values
            },
            {
                key: "cursor",
                action: "ScreenshotPicker.cursor",
                title: "Cursor " + (encoding("cursor") ? "on" : "off") + (frozenForCapture ? " · NEXT" : ""),
                values: [false, true]
            }
        ];
        return fields.concat([
            {
                key: "preset",
                action: "ScreenshotPicker.preset",
                title: presetIndex >= 0 ? encodingPresets[presetIndex].name : "Custom preset",
                values: encodingPresets.map(preset => preset.name)
            },
            {
                key: "",
                action: "ScreenshotPicker.resetEncoding",
                glyph: DesktopIcons.actionGlyph("reset"),
                title: "Restore defaults",
                values: []
            }
        ]);
    }
    function encoding(key: string): var {
        return qmlCapturePreferences.value(key);
    }
    function setEncoding(key: string, value: var): void {
        if (countingDown || exporting)
            return;
        qmlCapturePreferences.set(key, value);
    }
    function imageArguments(pixels: var): var {
        return [runtime.frozenCapture, exportAction, snapshotPath, String(pixels.x), String(pixels.y), String(pixels.w), String(pixels.h), String(encoding("imageFormat")), String(encoding("jpegQuality"))];
    }
    Timer {
        id: recordCountdown
        interval: 1000
        repeat: true
        onTriggered: {
            picker.remaining -= 1;
            if (picker.remaining <= 0) {
                stop();
                picker.captureNow();
            }
        }
    }
    readonly property string audioLabel: audioMode === "system" ? "SYSTEM AUDIO" : audioMode === "microphone" ? "MICROPHONE" : "NO AUDIO"
    property string snapshotPath: ""
    property string statusText: ""
    readonly property bool freezeEnabled: qmlCapturePreferences.value("freezeEnabled")
    property bool frozenForCapture: true
    property bool modeSnapshotPending: false
    property bool liveExportPending: false
    property PreferenceStore capturePreferences: PreferenceStore {
        id: qmlCapturePreferences
        category: "Capture"
        constraints: picker.runtime.constraints.captureEncoding
        defaults: Object.assign({
            freezeEnabled: picker.runtime.captureFreezeEnabled
        }, picker.runtime.captureEncoding)
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
        encodingSelector.cancel();
        encodingFieldKey = "";
        captureScreen = target;
        copying = copy;
        selectionMode = mode;
        annotateAfterCapture = false;
        frozenCursor = Boolean(encoding("cursor"));
        remaining = 0;
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
            snapshotProcess.exec([runtime.frozenCapture, "snapshot", target.name, frozenCursor ? "cursor" : "no-cursor"]);
        } else {
            // Live selection never displays an old frame. The final snapshot
            // is collected only after the shared modal has been hidden.
            snapshotReady();
            open = true;
            keyboard.forceActiveFocus();
            Qt.callLater(() => initialiseRect());
        }
    }

    Component.onCompleted: {
        const old = qmlCapturePreferences.objectFromJson(qmlCapturePreferences.legacy("encodingOverrides", "") || "{}");
        old.freezeEnabled = qmlCapturePreferences.legacyMarked("freezeEnabled", "preferenceSource");
        qmlCapturePreferences.initialize(old);
    }

    function resetToDeclared(): void {
        qmlCapturePreferences.resetAll();
    }

    function toggleFreeze(): void {
        if (selectionMode === "record" || exporting)
            return;
        qmlCapturePreferences.set("freezeEnabled", !freezeEnabled);
        initialiseSelection = false;
        if (!freezeEnabled) {
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
                snapshotProcess.exec([picker.runtime.frozenCapture, "snapshot", picker.captureScreen.name, picker.encoding("cursor") ? "cursor" : "no-cursor"]);
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
            exportProcess.exec(imageArguments(pixels));
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
        encodingSelector.cancel();
        encodingFieldKey = "";
        recordCountdown.stop();
        remaining = 0;
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

    function toggleAnnotation(): void {
        annotateAfterCapture = !annotateAfterCapture;
        statusText = annotateAfterCapture ? "ANNOTATE AFTER CAPTURE · " + picker.runtime.shellHint("ScreenshotPicker.capture") + " TO CONFIRM" : "CAPTURE ONLY · " + picker.runtime.shellHint("ScreenshotPicker.capture") + " TO CONFIRM";
    }

    function capture(action: string): void {
        if (!open || exporting || pending || selectionWidth < 5 || selectionHeight < 5)
            return;
        if (countingDown)
            return;
        if (selectionMode === "record" && Number(encoding("countdown")) > 0) {
            remaining = Number(encoding("countdown"));
            recordCountdown.start();
            return;
        }
        captureNow();
    }

    function captureNow(): void {
        if (!open || exporting || pending || selectionWidth < 5 || selectionHeight < 5)
            return;
        const pixelRect = selectedPixels;
        if (selectionMode === "record") {
            // Recorder geometry stays in compositor logical coordinates.
            const recordGeometry = String(Math.round(leftEdge + (captureScreen.x || 0))) + "," + String(Math.round(topEdge + (captureScreen.y || 0))) + " " + String(Math.ceil(selectionWidth)) + "x" + String(Math.ceil(selectionHeight));
            const outputName = captureScreen.name;
            const selectedAudio = audioMode;
            // Keep selection geometry for retry, but hide the overlay before
            // the recorder starts so its first frame cannot capture the picker.
            exporting = true;
            open = false;
            statusText = "STARTING RECORDING…";
            recordingStart.exec([runtime.recordingToggle, "start", outputName, recordGeometry, selectedAudio, String(encoding("videoFormat")), String(encoding("codec")), String(encoding("frameRate")), String(encoding("videoQuality"))]);
            return;
        }
        exportAction = annotateAfterCapture ? "annotate" : (copying ? "copy" : "save");
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
            exportProcess.exec(imageArguments(pixelRect));
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

    function openAudioChoices(): void {
        if (selectionMode === "record")
            openEncodingField({
                key: "audio",
                values: runtime.constraints.captureEncoding.audio.values
            });
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
                snapshotProcess.exec([picker.runtime.frozenCapture, "snapshot", picker.captureScreen.name, picker.encoding("cursor") ? "cursor" : "no-cursor"]);
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

    StdioCollector {
        id: recordingStartError
    }
    Process {
        id: recordingStart
        stderr: recordingStartError
        onExited: (exitCode, exitStatus) => {
            picker.exporting = false;
            if (exitCode === 0) {
                picker.dismiss(true);
            } else {
                picker.open = true;
                picker.statusText = "RECORDING START FAILED · " + picker.runtime.shellHint("ScreenshotPicker.capture") + " TO RETRY · " + picker.runtime.shellHint("ScreenshotPicker.cancel") + " CANCEL";
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
                picker.statusText = "CAPTURE FAILED · " + picker.runtime.shellHint("ScreenshotPicker.capture") + " TO RETRY · " + picker.runtime.shellHint("ScreenshotPicker.cancel") + " CANCEL";
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
        readonly property color scrim: picker.theme.scrimBase
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
            if (picker.exporting || picker.countingDown)
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
            picker.statusText = picker.selectionMode === "record" ? "REGION READY · " + picker.runtime.shellHint("ScreenshotPicker.capture") + " TO RECORD" : (picker.annotateAfterCapture ? "REGION READY · " + picker.runtime.shellHint("ScreenshotPicker.capture") + " TO CAPTURE + MARKUP" : "REGION READY · " + picker.runtime.shellHint("ScreenshotPicker.capture") + " TO CAPTURE");
            keyboard.forceActiveFocus();
        }
    }

    ShellSurface {
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: picker.theme.spacing5
        }
        width: Math.min(picker.width - 48, 1000)
        height: toolbarContent.implicitHeight + picker.theme.spacing3 * 2
        z: 5
        theme: picker.theme
        motion: picker.motion
        surfaceLayer: ShellSurface.Pane
        cornerRadius: picker.theme.radiusLarge

        Column {
            id: toolbarContent
            width: parent.width - picker.theme.spacing3 * 2
            anchors.centerIn: parent
            spacing: picker.theme.spacing2

            Flow {
                id: captureHeader
                width: parent.width
                spacing: picker.theme.spacing2

                Column {
                    width: actions.preferredWidth + picker.theme.fontSize(250) + captureHeader.spacing <= captureHeader.width ? captureHeader.width - actions.preferredWidth - captureHeader.spacing : captureHeader.width
                    spacing: 3
                    Text {
                        width: parent.width
                        text: picker.selectionMode === "record" ? "Record · " + picker.audioLabel : (picker.frozenForCapture ? "Frozen screenshot" : "Live screenshot")
                        color: picker.theme.readableRoleColor("capture")
                        font.family: picker.runtime.fontSans
                        font.pixelSize: picker.theme.fontSize(16)
                        font.weight: Font.DemiBold
                        wrapMode: Text.Wrap
                    }
                    Text {
                        width: parent.width
                        text: picker.countingDown ? "STARTING IN " + picker.remaining + "s · ESC CANCEL" : picker.statusText.length > 0 ? picker.statusText : "DRAG TO SELECT · RELEASE TO ADJUST"
                        color: picker.theme.textMuted
                        font.family: picker.runtime.fontSans
                        font.pixelSize: picker.theme.fontSize(11)
                        wrapMode: Text.Wrap
                    }
                }

                Flow {
                    id: actions
                    readonly property real preferredWidth: captureAction.implicitWidth + modeAction.implicitWidth + spacing + (picker.selectionMode !== "record" ? editAction.implicitWidth + spacing : 0)
                    width: Math.min(captureHeader.width, preferredWidth)
                    spacing: picker.theme.spacing1
                    ShellAction {
                        id: captureAction
                        width: Math.min(actions.width, implicitWidth)
                        height: implicitHeight
                        prominentAction: true
                        enabled: !encodingSelector.expanded && !picker.countingDown
                        runtime: picker.runtime
                        theme: picker.theme
                        motion: picker.motion
                        compact: true
                        horizontalCompact: true
                        icon: picker.selectionMode === "record" ? "󰕧" : "󰹑"
                        title: picker.selectionMode === "record" ? "Start recording" : picker.annotateAfterCapture ? "Markup" : picker.copying ? "Copy" : "Save"
                        shortcut: picker.runtime.shellHint("ScreenshotPicker.capture")
                        onActivated: picker.capture("")
                    }
                    ShellAction {
                        id: editAction
                        visible: picker.selectionMode !== "record"
                        width: visible ? Math.min(actions.width, implicitWidth) : 0
                        height: implicitHeight
                        runtime: picker.runtime
                        theme: picker.theme
                        motion: picker.motion
                        compact: true
                        horizontalCompact: true
                        icon: "󰏫"
                        title: picker.annotateAfterCapture ? "Markup on" : "Markup off"
                        active: picker.annotateAfterCapture
                        activeColor: theme.toggleColor
                        shortcut: picker.runtime.shellHint("ScreenshotPicker.edit")
                        onActivated: picker.toggleAnnotation()
                    }
                    ShellAction {
                        id: modeAction
                        width: Math.min(actions.width, implicitWidth)
                        height: implicitHeight
                        runtime: picker.runtime
                        theme: picker.theme
                        motion: picker.motion
                        compact: true
                        horizontalCompact: true
                        title: picker.selectionMode === "record" ? picker.audioLabel : picker.frozenForCapture ? "Frozen" : "Live"
                        shortcut: picker.selectionMode === "record" ? picker.runtime.shellHint("ScreenshotPicker.edit") : picker.runtime.shellHint("ScreenshotPicker.freeze")
                        onActivated: {
                            if (picker.selectionMode === "record")
                                picker.openAudioChoices();
                            else
                                picker.toggleFreeze();
                        }
                    }
                }
            }

            Flow {
                width: parent.width
                spacing: picker.theme.spacing1
                Repeater {
                    model: picker.encodingControls
                    delegate: ShellAction {
                        required property var modelData
                        width: Math.min(parent.width, implicitWidth)
                        height: implicitHeight
                        runtime: picker.runtime
                        theme: picker.theme
                        motion: picker.motion
                        compact: true
                        horizontalCompact: true
                        title: modelData.title
                        icon: modelData.glyph || (modelData.key === "cursor" ? DesktopIcons.toggleGlyph(picker.encoding("cursor")) : DesktopIcons.actionGlyph("expand"))
                        iconOnly: modelData.key === ""
                        inlineIconHint: iconOnly
                        active: encodingSelector.expanded && picker.encodingFieldKey === modelData.key
                        shortcut: picker.runtime.shellHint(modelData.action)
                        enabled: !picker.countingDown && !picker.exporting && !(picker.selectionMode !== "record" && (picker.copying || picker.annotateAfterCapture) && ["imageFormat", "jpegQuality", "preset"].includes(modelData.key))
                        onActivated: picker.openEncodingField(modelData)
                    }
                }
            }

            ShellValueSelector {
                id: encodingSelector
                showField: false
                visible: expanded
                width: parent.width
                runtime: picker.runtime
                theme: picker.theme
                motion: picker.motion
                title: picker.encodingFieldLabel(picker.encodingFieldKey)
                shortcut: picker.selectedEncodingField ? picker.runtime.shellHint(picker.selectedEncodingField.action) : ""
                confirmShortcut: picker.runtime.shellHint("ScreenshotPicker.capture")
                options: picker.selectedEncodingField?.values.map(value => picker.encodingChoiceLabel(picker.encodingFieldKey, value)) || []
                selectedIndex: picker.encodingFieldKey === "preset" ? picker.presetIndex : picker.selectedEncodingField?.values.indexOf(picker.encoding(picker.encodingFieldKey)) ?? -1
                enabled: !picker.countingDown && !picker.exporting
                onChosen: index => picker.chooseEncoding(index)
            }

            KeyHintStrip {
                id: pickerLegend
                width: parent.width
                runtime: picker.runtime
                theme: picker.theme
                hints: encodingSelector.expanded ? [
                    {
                        shortcut: picker.runtime.shellHint("ScreenshotPicker.options"),
                        label: "Browse choices"
                    },
                    {
                        shortcut: picker.runtime.shellHint("ScreenshotPicker.capture"),
                        label: "Select"
                    },
                    {
                        shortcut: picker.runtime.shellHint("ScreenshotPicker.cancel"),
                        label: "Back"
                    }
                ] : [
                    {
                        shortcut: picker.runtime.shellHint("ScreenshotPicker.move"),
                        label: "Move"
                    },
                    {
                        shortcut: picker.runtime.shellHint("ScreenshotPicker.resize"),
                        label: "Resize"
                    },
                    {
                        shortcut: picker.runtime.shellHint("ScreenshotPicker.full"),
                        label: "Full"
                    },
                    {
                        shortcut: picker.runtime.shellHint("ScreenshotPicker.display"),
                        label: "Display"
                    },
                    {
                        shortcut: picker.runtime.shellHint("ScreenshotPicker.cancel"),
                        label: "Cancel"
                    }
                ]
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
            if (event.isAutoRepeat && event.key === picker.runtime.shellKeyCode("capture", "Escape")) {
                event.accepted = true;
                return;
            }
            if (!picker.open || picker.exporting)
                return;
            if (picker.countingDown) {
                if (event.key === picker.runtime.shellKeyCode("capture", "Escape")) {
                    recordCountdown.stop();
                    picker.remaining = 0;
                    picker.statusText = "COUNTDOWN CANCELLED";
                }
                event.accepted = true;
                return;
            }
            for (const field of picker.encodingControls) {
                if (picker.runtime.shellMatchesHint(field.action, event.key, event.modifiers)) {
                    if (!event.isAutoRepeat)
                        picker.openEncodingField(field);
                    event.accepted = true;
                    return;
                }
            }
            if (encodingSelector.expanded) {
                if (event.key === picker.runtime.shellKeyCode("capture", "Escape")) {
                    encodingSelector.cancel();
                } else if (picker.runtime.shellNavigates("capture", "up", event.key)) {
                    encodingSelector.moveHighlight(-1);
                } else if (picker.runtime.shellNavigates("capture", "down", event.key)) {
                    encodingSelector.moveHighlight(1);
                } else if (event.key === picker.runtime.shellKeyCode("capture", "Return") || event.key === picker.runtime.shellKeyCode("capture", "Enter")) {
                    if (!event.isAutoRepeat)
                        encodingSelector.commit();
                } else if (picker.selectionMode === "record" && picker.runtime.shellMatchesHint("ScreenshotPicker.edit", event.key, event.modifiers)) {
                    if (!event.isAutoRepeat)
                        picker.openAudioChoices();
                }
                event.accepted = true;
                return;
            }
            const resize = !!(picker.runtime.shellModifier("capture", "Shift", event.modifiers));
            const step = resize ? 8 : 16;
            if (event.key === picker.runtime.shellKeyCode("capture", "Escape")) {
                picker.dismiss(true);
            } else if (event.key === picker.runtime.shellKeyCode("capture", "Return") || event.key === picker.runtime.shellKeyCode("capture", "Enter")) {
                if (!event.isAutoRepeat)
                    picker.capture("");
            } else if (event.key === picker.runtime.shellKeyCode("capture", "Tab")) {
                if (!event.isAutoRepeat)
                    picker.nextMonitor();
            } else if (picker.runtime.shellMatchesHint("ScreenshotPicker.edit", event.key, event.modifiers)) {
                if (!event.isAutoRepeat) {
                    if (picker.selectionMode === "record")
                        picker.openAudioChoices();
                    else
                        picker.toggleAnnotation();
                }
            } else if (picker.runtime.shellMatchesHint("ScreenshotPicker.freeze", event.key, event.modifiers) && picker.selectionMode !== "record") {
                if (!event.isAutoRepeat)
                    picker.toggleFreeze();
            } else if (picker.runtime.shellMatchesHint("ScreenshotPicker.full", event.key, event.modifiers)) {
                picker.initialiseSelection = false;
                picker.startX = 0;
                picker.startY = 0;
                picker.endX = picker.width;
                picker.endY = picker.height;
            } else if (picker.runtime.shellNavigates("capture", "left", event.key)) {
                picker.moveSelection(-step, 0, resize);
            } else if (picker.runtime.shellNavigates("capture", "right", event.key)) {
                picker.moveSelection(step, 0, resize);
            } else if (picker.runtime.shellNavigates("capture", "up", event.key)) {
                picker.moveSelection(0, -step, resize);
            } else if (picker.runtime.shellNavigates("capture", "down", event.key)) {
                picker.moveSelection(0, step, resize);
            } else {
                return;
            }
            event.accepted = true;
        }
    }
}

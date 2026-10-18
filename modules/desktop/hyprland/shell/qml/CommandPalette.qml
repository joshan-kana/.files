pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Qt.labs.settings
import "Calculator.js" as Calculator
import "SymbolLibrary.js" as SymbolLibrary
import "PaletteUtilities.js" as PaletteUtilities

Item {
    id: palette
    // Pre-constructed content hosted by the single permanent modal layer.
    property var screen: null

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property ClipboardPanel clipboardPanel

    property var commands: []
    // Alt+1–4 are launcher-local scopes; physical global keys stay in the keymap.
    property string searchScope: "unified"
    signal commandTriggered(string commandId)
    signal argumentCommandTriggered(string commandId, string argument)

    property bool actionMode: false
    property var actionTarget: null
    property var actionEntries: []
    property var parameterTarget: null
    property string priorQuery: ""
    property string selectionIdentity: ""
    property var quicklinks: PaletteUtilities.parseQuicklinks("")
    property var snippets: []
    readonly property var indexedSnippets: snippets.map(item => indexSearchEntry(Object.assign({}, item)))

    Settings {
        id: launcherPreferences
        fileName: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/linux-desktop/palette.ini"
        category: "Launcher"
        property string favourites: "[]"
        property string recent: "[]"
        property bool rememberRecent: true
    }

    readonly property var favouriteKeys: parsePreferenceKeys(launcherPreferences.favourites)
    readonly property var recentKeys: parsePreferenceKeys(launcherPreferences.recent)
    readonly property bool rememberRecents: launcherPreferences.rememberRecent

    function parsePreferenceKeys(value: string): var {
        try {
            const parsed = JSON.parse(value);
            return Array.isArray(parsed) ? parsed.filter(key => typeof key === "string").slice(0, 80) : [];
        } catch (error) {
            return [];
        }
    }

    function isFavourite(entry: var): bool {
        return favouriteKeys.includes(identity(entry));
    }

    function toggleFavourite(entry: var): void {
        const key = identity(entry);
        if (!["command", "application", "quicklink"].includes(entry.kind) || !key)
            return;
        launcherPreferences.favourites = JSON.stringify(isFavourite(entry) ? favouriteKeys.filter(current => current !== key) : [...favouriteKeys, key].slice(-60));
    }

    function rememberEntry(entry: var): void {
        if (!rememberRecents || !entry || !["command", "application", "quicklink"].includes(entry.kind))
            return;
        const key = identity(entry);
        launcherPreferences.recent = JSON.stringify([key, ...recentKeys.filter(current => current !== key)].slice(0, 30));
    }
    property var localResults: []
    property string activeFileQuery: ""
    property string queuedFileQuery: ""
    readonly property var indexedQuicklinks: quicklinks.map(link => indexSearchEntry(Object.assign({}, link)))
    readonly property var indexedWindows: Hyprland.toplevels.values.filter(win => win && win.workspace && win.workspace.id > 0 && (win.lastIpcObject || {}).address).map(win => indexSearchEntry({
            kind: "window",
            name: win.title || (win.lastIpcObject || {}).class || "Window",
            genericName: (win.lastIpcObject || {}).class + " · Workspace " + win.workspace.id,
            icon: (win.lastIpcObject || {}).class || "window",
            key: "",
            toplevel: win,
            address: String((win.lastIpcObject || {}).address),
            keywords: ["window", "switch", "focus"]
        }))
    readonly property var indexedWorkspaces: Array.from({
        length: 10
    }, (_, index) => index + 1).map(id => indexSearchEntry({
            kind: "workspace",
            name: "Workspace " + id,
            genericName: "Switch to workspace " + id,
            icon: "view-grid",
            key: "",
            workspaceId: id,
            keywords: ["desktop", "switch", "workspace"]
        }))

    function chooseScope(scope: string): void {
        if (!["unified", "apps", "actions", "emoji"].includes(scope))
            return;
        searchScope = scope;
        actionMode = false;
        parameterTarget = null;
        queueFileSearch();
        results.currentIndex = resultModel.values.length > 0 ? 0 : -1;
        search.forceActiveFocus();
    }

    function dismissOrReset(): void {
        if (helpOpen) {
            helpOpen = false;
            search.forceActiveFocus();
            return;
        }
        if (actionMode) {
            actionMode = false;
            actionTarget = null;
            results.currentIndex = resultModel.values.length > 0 ? 0 : -1;
            search.forceActiveFocus();
            return;
        }
        if (parameterTarget) {
            parameterTarget = null;
            search.text = priorQuery;
            search.forceActiveFocus();
            return;
        }
        // Dismissal never changes the selected search scope. When reopened,
        // the last selected category is still active.
        hide();
    }

    property bool open: false
    property bool closing: false
    property bool helpOpen: false
    property bool copyOnSuccessClose: false
    property string copyFeedback: ""
    property var unicodeEntries: []

    // Rebuild these indexes only when desktop entries or registered actions
    // change, not once per typed character or scope selection.
    readonly property var indexedCommands: (commands || []).map(command => indexSearchEntry({
            kind: "command",
            name: command.name,
            genericName: command.description || "Desktop action",
            icon: command.icon || "system-run",
            key: command.key || "",
            commandId: command.id,
            parameterMode: command.parameterMode || "",
            keywords: command.keywords || []
        }))
    readonly property var indexedApplications: [...DesktopEntries.applications.values].map(entry => indexSearchEntry({
            kind: "application",
            name: entry.name,
            genericName: entry.genericName || entry.comment || "Application",
            icon: entry.icon || "application-x-executable",
            key: "",
            desktopEntry: entry,
            keywords: entry.keywords || []
        }))

    function indexSearchEntry(entry): var {
        entry.searchName = entry.name.toLowerCase();
        entry.searchGeneric = (entry.genericName || "").toLowerCase();
        entry.searchWords = entry.searchName.split(/\s+/);
        entry.searchKeywords = entry.keywords.map(keyword => keyword.toLowerCase());
        entry.searchBinding = (entry.key || "").toLowerCase();
        return entry;
    }

    FileView {
        id: snippetsFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/linux-desktop/snippets.json"
        blockLoading: false
        watchChanges: true
        onLoaded: palette.snippets = PaletteUtilities.parseSnippets(text())
        onFileChanged: reload()
    }

    FileView {
        id: quicklinkFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/linux-desktop/quicklinks.json"
        blockLoading: false
        watchChanges: true
        onLoaded: palette.quicklinks = PaletteUtilities.parseQuicklinks(text())
        onFileChanged: reload()
    }

    StdioCollector {
        id: fileQueryOutput
    }

    Timer {
        id: fileSearchDebounce
        interval: 85
        onTriggered: palette.runFileSearch()
    }

    Process {
        id: fileSearchProcess
        stdout: fileQueryOutput
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && palette.activeFileQuery === search.text.trim() && palette.searchScope === "unified" && !palette.parameterTarget) {
                try {
                    const parsed = JSON.parse(fileQueryOutput.text);
                    palette.localResults = Array.isArray(parsed) ? parsed : [];
                } catch (error) {
                    palette.localResults = [];
                }
            }
            if (palette.queuedFileQuery !== palette.activeFileQuery)
                Qt.callLater(() => palette.runFileSearch());
        }
    }

    function queueFileSearch(): void {
        localResults = [];
        queuedFileQuery = searchScope === "unified" && !parameterTarget && search.text.trim().length >= 2 ? search.text.trim() : "";
        if (queuedFileQuery)
            fileSearchDebounce.restart();
        else
            fileSearchDebounce.stop();
    }

    function runFileSearch(): void {
        if (fileSearchProcess.running || !queuedFileQuery || !runtime.paletteSearch)
            return;
        activeFileQuery = queuedFileQuery;
        fileSearchProcess.exec([runtime.paletteSearch, "search", activeFileQuery]);
    }

    FileView {
        id: unicodeData
        path: palette.runtime.emojiTest
        blockLoading: false
        onLoadedChanged: {
            if (loaded)
                palette.unicodeEntries = SymbolLibrary.parseUnicode(text());
        }
    }

    Process {
        id: calculationCopy
        onExited: (exitCode, exitStatus) => {
            palette.copyFeedback = exitCode === 0 ? "COPIED" : "COPY FAILED";
            if (exitCode === 0 && palette.copyOnSuccessClose)
                palette.hide();
        }
    }

    visible: open || closing

    anchors.fill: parent

    Shortcut {
        sequence: "Shift+Esc"
        context: Qt.ApplicationShortcut
        enabled: palette.open
        onActivated: palette.hide()
    }

    Shortcut {
        sequence: "?"
        context: Qt.ApplicationShortcut
        enabled: palette.open && !search.activeFocus
        onActivated: palette.helpOpen = !palette.helpOpen
    }

    Shortcut {
        sequence: "Alt+1"
        context: Qt.ApplicationShortcut
        enabled: palette.open
        onActivated: palette.chooseScope("unified")
    }
    Shortcut {
        sequence: "Alt+2"
        context: Qt.ApplicationShortcut
        enabled: palette.open
        onActivated: palette.chooseScope("apps")
    }
    Shortcut {
        sequence: "Alt+3"
        context: Qt.ApplicationShortcut
        enabled: palette.open
        onActivated: palette.chooseScope("actions")
    }
    Shortcut {
        sequence: "Alt+4"
        context: Qt.ApplicationShortcut
        enabled: palette.open
        onActivated: palette.chooseScope("emoji")
    }

    Timer {
        id: closeTimer
        // Keep the layer surface alive until the longer card scale finishes.
        interval: motion.normal + (motion.enabled ? 24 : 0)
        onTriggered: {
            palette.closing = false;
            // The layer remains until exit animation completion.
        }
    }

    ScriptModel {
        id: displayedModel
        values: palette.actionMode ? palette.actionEntries : resultModel.values
        onValuesChanged: {
            if (!palette.open)
                return;
            if (values.length === 0) {
                results.currentIndex = -1;
                return;
            }
            const retained = palette.selectionIdentity && !palette.actionMode ? values.findIndex(item => palette.identity(item) === palette.selectionIdentity) : -1;
            results.currentIndex = retained >= 0 ? retained : Math.max(0, Math.min(results.currentIndex, values.length - 1));
        }
    }

    ScriptModel {
        id: resultModel
        values: palette.filteredItems()
        // Partial expressions and rapidly changing search modes can have no
        // matches. Select a new valid result as soon as the model changes,
        // rather than leaving Enter targeted at the stale empty model.
        onValuesChanged: {
            if (!palette.open || palette.actionMode)
                return;
            if (values.length === 0)
                results.currentIndex = -1;
            else if (results.currentIndex < 0 || results.currentIndex >= values.length)
                results.currentIndex = 0;
        }
    }

    function subsequencePenalty(haystack: string, query: string): int {
        let offset = 0;
        let previous = -1;
        let penalty = 0;
        for (let i = 0; i < query.length; i++) {
            const position = haystack.indexOf(query[i], offset);
            if (position < 0)
                return 10000;
            if (previous < 0)
                penalty += position * 3;
            else
                penalty += (position - previous - 1) * 2;
            previous = position;
            offset = position + 1;
        }
        return penalty + Math.min(40, haystack.length - query.length);
    }

    function score(item, query): int {
        const name = item.searchName;
        const generic = item.searchGeneric;
        const keywords = item.searchKeywords;
        const binding = item.searchBinding;
        if (name === query)
            return 0;
        if (name.startsWith(query))
            return 10;
        if (item.searchWords.some(word => word.startsWith(query)))
            return 15;
        if (name.includes(query))
            return 20;
        if (keywords.some(keyword => keyword === query))
            return 25;
        if (keywords.some(keyword => keyword.startsWith(query)))
            return 30;
        if (generic.startsWith(query))
            return 35;
        if (generic.includes(query))
            return 40;
        if (keywords.some(keyword => keyword.includes(query)))
            return 45;
        if (binding.includes(query))
            return 50;
        if (query.length < 2)
            return 10000;
        return Math.min(100 + subsequencePenalty(name, query), 180 + subsequencePenalty(generic, query));
    }

    function filteredItems(): var {
        const rawQuery = search.text.trim();
        const query = rawQuery.toLowerCase();
        if (parameterTarget) {
            if (parameterTarget.parameterMode === "confirm")
                return [
                    {
                        kind: "argument",
                        name: "Confirm " + parameterTarget.name,
                        genericName: "Enter to confirm · Escape to cancel",
                        icon: "dialog-warning",
                        key: "↵ CONFIRM"
                    }
                ];
            if (!rawQuery)
                return [];
            if (parameterTarget.parameterMode === "search")
                return [PaletteUtilities.quicklinkResult(parameterTarget, parameterTarget.alias + " " + rawQuery)];
            if (parameterTarget.parameterMode === "move")
                return [
                    {
                        kind: "argument",
                        name: "Move to workspace " + rawQuery,
                        genericName: "Workspace 1–10",
                        icon: "view-grid",
                        key: "↵ MOVE"
                    }
                ];
            return [
                {
                    kind: "argument",
                    name: "Set " + parameterTarget.name + " to " + rawQuery + "%",
                    genericName: "Enter a percentage (0–100)",
                    icon: "preferences-system",
                    key: "↵ SET"
                }
            ];
        }

        if (searchScope === "emoji")
            return SymbolLibrary.search(query, unicodeEntries);

        if (searchScope === "unified") {
            const direct = rawQuery.match(/^(volume|brightness)\s+(\d{1,3})\s*%?$/i);
            if (direct && Number(direct[2]) <= 100)
                return [
                    {
                        kind: "commandArgument",
                        commandId: direct[1].toLowerCase() === "volume" ? "audio.setVolume" : "brightness.set",
                        argument: direct[2],
                        name: "Set " + direct[1] + " to " + direct[2] + "%",
                        genericName: "Set using the existing desktop service",
                        icon: "preferences-system",
                        key: "↵ SET"
                    }
                ];
        }

        const conversion = searchScope === "unified" ? PaletteUtilities.convert(rawQuery) : null;
        if (conversion)
            return [
                {
                    kind: "calculation",
                    name: "= " + conversion.result,
                    genericName: conversion.description + " · Enter to copy",
                    icon: "accessories-calculator",
                    key: "COPY",
                    result: conversion.result
                }
            ];

        const explicitCalculation = query.match(/^calc\s+(.+)$/);
        const expression = explicitCalculation ? explicitCalculation[1] : query;
        // Arithmetic works directly in search; other queries retain fuzzy app/action matching.
        const arithmeticQuery = /^[\d\s().+\-*/^]+$/.test(expression) && /\d/.test(expression) && /[+\-*/^]/.test(expression);
        if (searchScope === "unified" && (explicitCalculation || arithmeticQuery)) {
            const result = Calculator.calculate(expression);
            if (result !== null)
                return [
                    {
                        kind: "calculation",
                        name: "= " + result,
                        genericName: expression + " · Enter to copy",
                        icon: "accessories-calculator",
                        key: "COPY",
                        result: result
                    }
                ];
            if (explicitCalculation)
                return [];
        }

        const commandItems = indexedCommands;
        const applicationItems = indexedApplications;

        const items = searchScope === "apps" ? applicationItems : searchScope === "actions" ? commandItems.concat(indexedQuicklinks, indexedSnippets) : commandItems.concat(applicationItems, indexedQuicklinks, indexedSnippets, indexedWindows, indexedWorkspaces);
        // Keep the empty Unified surface short without truncating any search
        // result set. ListView virtualises rows as they enter the viewport.
        if (query.length === 0)
            return searchScope === "unified" ? commandItems.concat(applicationItems).sort((a, b) => Number(isFavourite(b)) - Number(isFavourite(a)) || (recentKeys.indexOf(identity(a)) < 0 ? 1000 : recentKeys.indexOf(identity(a))) - (recentKeys.indexOf(identity(b)) < 0 ? 1000 : recentKeys.indexOf(identity(b)))).slice(0, 9) : items;

        const matches = items.map(item => ({
                    entry: item,
                    relevance: (item.kind === "quicklink" && (query === item.alias || query.startsWith(item.alias + " ")) ? 0 : score(item, query)) - (isFavourite(item) ? 6 : 0) - (recentKeys.includes(identity(item)) ? 3 : 0)
                })).filter(result => result.relevance < 10000).sort((a, b) => {
            const rank = a.relevance - b.relevance;
            if (rank !== 0)
                return rank;
            if (a.entry.kind !== b.entry.kind)
                return a.entry.kind === "command" ? -1 : 1;
            return a.entry.name.localeCompare(b.entry.name);
        }).map(result => result.entry.kind === "quicklink" ? PaletteUtilities.quicklinkResult(result.entry, rawQuery) : result.entry);
        if (searchScope === "unified")
            matches.push(...localResults.filter(entry => entry && (entry.kind === "file" || entry.kind === "bookmark") && typeof entry.name === "string").map(entry => Object.assign({
                    key: "",
                    keywords: []
                }, entry)));

        if (searchScope !== "unified" || query.length < 2)
            return matches;
        // Emoji names are directly discoverable from unified searches while
        // clipboard history remains private to its dedicated panel.
        return matches.concat(SymbolLibrary.search(query, unicodeEntries));
    }

    function setLauncherSubmap(enabled: bool): void {
        Hyprland.dispatch(Hyprland.usingLua ? 'hl.dsp.submap("' + (enabled ? "launcher" : "reset") + '")' : "submap " + (enabled ? "launcher" : "reset"));
    }

    function show(): void {
        closeTimer.stop();
        // Preserve visibility when reopening during the exit animation.
        open = true;
        closing = false;
        setLauncherSubmap(true);
        copyFeedback = "";
        actionMode = false;
        parameterTarget = null;
        queueFileSearch();
        if (resultModel.values.length === 0)
            results.currentIndex = -1;
        else if (results.currentIndex < 0 || results.currentIndex >= resultModel.values.length)
            results.currentIndex = 0;
        search.forceActiveFocus();
    }

    function hide(): void {
        if (!open)
            return;

        // Do not momentarily unmap the Wayland surface on close. Its exit
        // animation must finish before visible changes to false.
        closing = motion.enabled;
        open = false;
        helpOpen = false;
        actionMode = false;
        parameterTarget = null;
        setLauncherSubmap(false);
        if (closing)
            closeTimer.restart();
    }

    function toggle(): void {
        if (open)
            hide();
        else
            show();
    }

    function identity(entry: var): string {
        if (!entry)
            return "";
        return entry.kind + ":" + (entry.commandId || entry.alias || entry.address || entry.workspaceId || (entry.desktopEntry && entry.desktopEntry.id) || entry.name);
    }

    function selectedEntry(): var {
        return !actionMode && results.currentIndex >= 0 && results.currentIndex < resultModel.values.length ? resultModel.values[results.currentIndex] : null;
    }

    function optionsFor(entry: var): var {
        if (!entry)
            return [];
        let options = [
            {
                kind: "paletteAction",
                action: "primary",
                name: entry.kind === "calculation" || entry.kind === "symbol" ? "Copy Result" : "Open / Run",
                genericName: entry.name,
                icon: "system-run",
                key: "↵ RUN"
            }
        ];
        if (entry.kind === "window")
            options[0].name = "Focus Window";
        if (entry.kind === "workspace")
            options[0].name = "Switch Workspace";
        if (entry.kind === "application") {
            const current = indexedWindows.find(win => win.toplevel && win.toplevel.lastIpcObject && String(win.toplevel.lastIpcObject.class || "").toLowerCase() === entry.name.toLowerCase());
            if (current)
                options.push({
                    kind: "paletteAction",
                    action: "focus",
                    name: "Switch to Existing Window",
                    genericName: current.name,
                    icon: "window",
                    key: "",
                    window: current.toplevel
                });
            options.push({
                kind: "paletteAction",
                action: "copyName",
                name: "Copy Application Name",
                genericName: entry.name,
                icon: "edit-copy",
                key: ""
            });
        }
        if (entry.kind === "quicklink" && entry.url)
            options.push({
                kind: "paletteAction",
                action: "copyUrl",
                name: "Copy Search URL",
                genericName: entry.url,
                icon: "edit-copy",
                key: ""
            });
        if (entry.kind === "quicklink")
            options.push({
                kind: "paletteAction",
                action: "search",
                name: "Enter Website Search",
                genericName: entry.alias + " <query>",
                icon: "edit-find",
                key: ""
            });
        if (entry.kind === "file") {
            options.push({
                kind: "paletteAction",
                action: "reveal",
                name: "Reveal in File Manager",
                genericName: entry.path,
                icon: "folder-open",
                key: ""
            });
            options.push({
                kind: "paletteAction",
                action: "copyPath",
                name: "Copy Path",
                genericName: entry.path,
                icon: "edit-copy",
                key: ""
            });
        }
        if (entry.kind === "bookmark" && entry.url)
            options.push({
                kind: "paletteAction",
                action: "copyUrl",
                name: "Copy Bookmark URL",
                genericName: entry.url,
                icon: "edit-copy",
                key: ""
            });
        if (entry.kind === "window")
            options.push({
                kind: "paletteAction",
                action: "move",
                name: "Move Window to Workspace…",
                genericName: entry.genericName,
                icon: "view-grid",
                key: ""
            });
        if (entry.kind === "workspace")
            options.push({
                kind: "paletteAction",
                action: "moveFocused",
                name: "Move Focused Window Here",
                genericName: entry.name,
                icon: "view-grid",
                key: ""
            });
        if (["command", "application", "quicklink"].includes(entry.kind))
            options.push({
                kind: "paletteAction",
                action: "favourite",
                name: isFavourite(entry) ? "Remove from Favourites" : "Add to Favourites",
                genericName: entry.name,
                icon: "starred",
                key: ""
            });
        if (entry.kind === "command")
            options.push({
                kind: "paletteAction",
                action: "copyName",
                name: "Copy Command Name",
                genericName: entry.name,
                icon: "edit-copy",
                key: ""
            });
        if (entry.kind === "calculation" || entry.kind === "symbol" || entry.kind === "snippet")
            options[0].name = "Copy to Clipboard";
        return options;
    }

    function openActions(): void {
        const entry = selectedEntry();
        if (!entry)
            return;
        actionTarget = entry;
        actionEntries = optionsFor(entry);
        actionMode = true;
        selectionIdentity = "";
        results.currentIndex = 0;
        results.forceActiveFocus();
    }

    function copyText(value: string, keepOpen: bool): void {
        if (calculationCopy.running) {
            copyFeedback = "COPY IN PROGRESS";
            return;
        }
        copyFeedback = "COPYING";
        copyOnSuccessClose = !keepOpen;
        calculationCopy.exec(["wl-copy", "--type", "text/plain", value]);
    }

    function beginParameter(entry: var, mode: string): void {
        priorQuery = search.text;
        parameterTarget = Object.assign({}, entry, {
            parameterMode: mode
        });
        actionMode = false;
        actionTarget = null;
        search.text = "";
        selectionIdentity = "";
        results.currentIndex = -1;
        search.forceActiveFocus();
    }

    function runEntry(entry: var, keepOpen: bool): void {
        if (!entry)
            return;
        if (entry.kind === "calculation" || entry.kind === "symbol" || entry.kind === "snippet") {
            copyText(entry.kind === "snippet" ? entry.snippetText : entry.result, keepOpen);
            return;
        }
        if (entry.kind === "quicklink" && !entry.url) {
            beginParameter(entry, "search");
            return;
        }
        if (entry.kind === "command" && entry.commandId === "notifications.clear") {
            beginParameter(entry, "confirm");
            return;
        }
        if (entry.kind === "command" && entry.parameterMode) {
            beginParameter(entry, entry.parameterMode);
            return;
        }
        if (entry.kind === "commandArgument") {
            if (!keepOpen)
                hide();
            argumentCommandTriggered(entry.commandId, entry.argument);
            return;
        }
        if (!keepOpen)
            hide();
        rememberEntry(entry);
        if (entry.kind === "command" && entry.commandId === "launcher.clearRecent")
            launcherPreferences.recent = "[]";
        else if (entry.kind === "command" && entry.commandId === "launcher.toggleHistory") {
            launcherPreferences.rememberRecent = !launcherPreferences.rememberRecent;
            if (!launcherPreferences.rememberRecent)
                launcherPreferences.recent = "[]";
        } else if (entry.kind === "command")
            commandTriggered(entry.commandId);
        else if (entry.kind === "application" && entry.desktopEntry)
            entry.desktopEntry.execute();
        else if (entry.kind === "quicklink" && entry.url)
            Quickshell.execDetached([runtime.urlOpen, entry.url]);
        else if (entry.kind === "file" && entry.path)
            Quickshell.execDetached([runtime.urlOpen, entry.path]);
        else if (entry.kind === "bookmark" && entry.url)
            Quickshell.execDetached([["firefox", "chromium", "google-chrome-stable", "brave-browser"].includes(entry.browser) ? entry.browser : runtime.urlOpen, entry.url]);
        else if (entry.kind === "window" && entry.toplevel && entry.toplevel.wayland)
            entry.toplevel.wayland.activate();
        else if (entry.kind === "workspace" && entry.workspaceId > 0 && entry.workspaceId <= 10)
            Hyprland.dispatch('hl.dsp.focus({ workspace = "' + entry.workspaceId + '" })');
        if (keepOpen)
            search.forceActiveFocus();
    }

    function executeAction(option: var, keepOpen: bool): void {
        const target = actionTarget;
        if (!target || !option)
            return;
        actionMode = false;
        actionTarget = null;
        if (option.action === "primary") {
            runEntry(target, keepOpen);
            return;
        }
        if (option.action === "search") {
            beginParameter(target, "search");
            return;
        }
        if (option.action === "favourite") {
            toggleFavourite(target);
            search.forceActiveFocus();
            return;
        }
        if (option.action === "copyName" || option.action === "copyUrl" || option.action === "copyPath") {
            copyText(option.action === "copyUrl" ? target.url : option.action === "copyPath" ? target.path : target.name, keepOpen);
            return;
        }
        if (option.action === "move") {
            beginParameter(target, "move");
            return;
        }
        if (option.action === "reveal") {
            if (!keepOpen)
                hide();
            Quickshell.execDetached([runtime.urlOpen, target.path.substring(0, target.path.lastIndexOf("/")) || "/"]);
            return;
        }
        if (!keepOpen)
            hide();
        if (option.action === "focus" && option.window && option.window.wayland)
            option.window.wayland.activate();
        else if (option.action === "moveFocused" && target.workspaceId > 0 && target.workspaceId <= 10)
            Hyprland.dispatch('hl.dsp.window.move({ workspace = "' + target.workspaceId + '", follow = false })');
        if (keepOpen)
            search.forceActiveFocus();
    }

    function launchIndex(index: int): void {
        if (!open || actionMode || index < 0 || index >= resultModel.values.length)
            return;
        results.currentIndex = index;
        launchCurrent(false);
    }

    function launchCurrent(keepOpen: bool): void {
        if (parameterTarget && parameterTarget.parameterMode === "confirm") {
            const commandId = parameterTarget.commandId;
            if (!keepOpen)
                hide();
            commandTriggered(commandId);
            return;
        }
        if (parameterTarget && parameterTarget.parameterMode === "percent") {
            const value = Number(search.text.trim());
            if (!/^\d{1,3}$/.test(search.text.trim()) || !Number.isInteger(value) || value < 0 || value > 100) {
                copyFeedback = "ENTER A PERCENTAGE 0–100";
                return;
            }
            const commandId = parameterTarget.commandId;
            if (!keepOpen)
                hide();
            argumentCommandTriggered(commandId, String(value));
            return;
        }
        if (parameterTarget && parameterTarget.parameterMode === "move") {
            const workspaceId = Number(search.text.trim());
            if (!Number.isInteger(workspaceId) || workspaceId < 1 || workspaceId > 10) {
                copyFeedback = "ENTER WORKSPACE 1–10";
                return;
            }
            const addr = parameterTarget.address;
            if (!/^0x[0-9a-f]+$/i.test(addr))
                return;
            if (!keepOpen)
                hide();
            Hyprland.dispatch('hl.dsp.window.move({ workspace = "' + workspaceId + '", follow = false, window = "address:' + addr + '" })');
            return;
        }
        if (results.currentIndex < 0 || results.currentIndex >= displayedModel.values.length)
            return;
        const entry = displayedModel.values[results.currentIndex];
        if (actionMode) {
            executeAction(entry, keepOpen);
            return;
        }
        runEntry(entry, keepOpen);
    }

    Rectangle {
        anchors.fill: parent
        color: theme.scrimStrong
        opacity: 0 // Background dimming is compositor-owned in this benchmark.

        Behavior on opacity {
            NumberAnimation {
                duration: motion.fast
                easing.type: palette.open ? motion.enterType : motion.exitType
                easing.bezierCurve: palette.open ? motion.enterCurve : motion.exitCurve
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: palette.hide()
        }
    }

    ShellSurface {
        id: card

        width: Math.min(palette.width - 80, 780)
        Behavior on width {
            Anim {
                motion: palette.motion
                type: Anim.FastSpatial
            }
        }
        height: Math.min(palette.height - 120, 675)
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: Math.max(86, palette.height * 0.13)
        }

        theme: palette.theme
        motion: palette.motion
        surfaceLayer: ShellSurface.Pane
        cornerRadius: theme.radiusPanel

        scale: palette.open ? 1 : theme.panelClosedScale
        opacity: palette.open ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: motion.normal
                easing.type: palette.open ? motion.enterType : motion.exitType
                easing.bezierCurve: palette.open ? motion.enterCurve : motion.exitCurve
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: motion.fast
                easing.type: motion.effectsType
                easing.bezierCurve: motion.effectsCurve
            }
        }

        Item {
            anchors.fill: parent
            anchors.margins: theme.spacing5

            Column {
                id: paletteIntro
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                spacing: theme.spacing1

                Text {
                    text: palette.actionMode ? "COMMAND PALETTE · ACTIONS" : palette.parameterTarget ? "COMMAND PALETTE · ARGUMENT" : "COMMAND PALETTE · SEARCH / CALCULATE"
                    color: theme.accent
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontPanelEyebrow
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.7
                }
                Row {
                    width: parent.width
                    spacing: theme.spacing2

                    Text {
                        width: parent.width - helpButton.width - parent.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        text: palette.actionMode ? "Actions for " + palette.actionTarget.name : palette.parameterTarget ? (palette.parameterTarget.parameterMode === "move" ? "Move to workspace" : palette.parameterTarget.name) : "What do you want to do?"
                        elide: Text.ElideRight
                        color: theme.textStrong
                        font.family: runtime.fontMono
                        font.pixelSize: theme.fontSize(24)
                        font.weight: Font.DemiBold
                    }

                    ShellAction {
                        id: helpButton
                        width: 36
                        height: 36
                        anchors.verticalCenter: parent.verticalCenter
                        runtime: palette.runtime
                        theme: palette.theme
                        motion: palette.motion
                        iconOnly: true
                        icon: "󰋗"
                        title: "Help (?)"
                        onActivated: palette.helpOpen = true
                    }
                }

                Row {
                    width: parent.width
                    spacing: theme.spacing2

                    Repeater {
                        model: [
                            {
                                title: "Unified",
                                scope: "unified",
                                shortcut: "ALT+1"
                            },
                            {
                                title: "Apps",
                                scope: "apps",
                                shortcut: "ALT+2"
                            },
                            {
                                title: "Actions",
                                scope: "actions",
                                shortcut: "ALT+3"
                            },
                            {
                                title: "Emoji",
                                scope: "emoji",
                                shortcut: "ALT+4"
                            }
                        ]
                        delegate: ShellAction {
                            required property var modelData
                            width: (paletteIntro.width - palette.theme.spacing2 * 3) / 4
                            height: 38
                            runtime: palette.runtime
                            theme: palette.theme
                            motion: palette.motion
                            compact: true
                            horizontalCompact: true
                            title: modelData.title
                            shortcut: modelData.shortcut
                            active: palette.searchScope === modelData.scope
                            onActivated: palette.chooseScope(modelData.scope)
                        }
                    }
                }
            }

            SquircleSurface {
                id: searchBox

                height: 60
                anchors {
                    top: paletteIntro.bottom
                    topMargin: theme.spacing3
                    left: parent.left
                    right: parent.right
                }

                exponent: theme.squircleExponent
                cornerRadius: theme.radiusMedium
                fillColor: theme.expressiveSurfaceStrong
                borderColor: search.activeFocus ? theme.accent : theme.outline
                borderWidth: search.activeFocus ? theme.borderFocus : theme.borderThin

                Behavior on borderColor {
                    ColorAnimation {
                        duration: motion.fast
                        easing.type: motion.effectsType
                        easing.bezierCurve: motion.effectsCurve
                    }
                }

                Text {
                    id: prompt

                    anchors {
                        left: parent.left
                        leftMargin: theme.spacing4
                        verticalCenter: parent.verticalCenter
                    }

                    text: ">"
                    color: theme.accent
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(20)
                    font.weight: Font.Bold
                }

                TextInput {
                    id: search

                    anchors {
                        left: prompt.right
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: theme.spacing3
                        rightMargin: theme.spacing3
                    }

                    color: theme.textStrong
                    selectionColor: theme.accent
                    selectedTextColor: theme.background
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(18)
                    clip: true

                    Text {
                        anchors.fill: parent
                        visible: search.text.length === 0
                        text: palette.parameterTarget ? (palette.parameterTarget.parameterMode === "confirm" ? "Press Enter again to confirm" : palette.parameterTarget.parameterMode === "move" ? "Workspace number (1–10)…" : palette.parameterTarget.parameterMode === "percent" ? "Percentage (0–100)…" : "Website search terms…") : palette.searchScope === "emoji" ? "Search emoji names…" : palette.searchScope === "apps" ? "Search applications…" : palette.searchScope === "actions" ? "Search desktop actions…" : "Apps, commands, windows, Quicklinks, 15 km to miles…"
                        color: theme.textMuted
                        font: search.font
                        verticalAlignment: Text.AlignVCenter
                    }

                    onTextChanged: {
                        palette.copyFeedback = "";
                        if (!palette.actionMode)
                            palette.selectionIdentity = "";
                        palette.queueFileSearch();
                        results.currentIndex = displayedModel.values.length > 0 ? 0 : -1;
                    }

                    Keys.onPressed: event => {
                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.AltModifier)) {
                            palette.openActions();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Tab) {
                            results.forceActiveFocus();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            palette.dismissOrReset();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            results.currentIndex = Math.min(displayedModel.values.length - 1, results.currentIndex + 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            results.currentIndex = Math.max(0, results.currentIndex - 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            const keepOpen = (event.modifiers & Qt.ShiftModifier) !== 0;
                            palette.launchCurrent(keepOpen);
                            event.accepted = true;
                        }
                    }
                }
            }

            ListView {
                id: results

                anchors {
                    top: searchBox.bottom
                    right: parent.right
                    bottom: footer.top
                    left: parent.left
                    rightMargin: 0
                    topMargin: theme.spacing3
                    bottomMargin: theme.spacing3
                }

                model: displayedModel
                spacing: theme.spacing1
                clip: true
                currentIndex: -1
                onCurrentIndexChanged: {
                    if (!palette.actionMode && currentIndex >= 0 && currentIndex < resultModel.values.length)
                        palette.selectionIdentity = palette.identity(resultModel.values[currentIndex]);
                }
                // The model update and keyboard handlers own the selection;
                // rebinding it to model length would override J/K navigation.
                // Autorepeated navigation must be immediate; the focused
                // surface itself still animates its tonal state.
                highlightMoveDuration: 0
                highlightResizeDuration: 0

                Keys.priority: Keys.BeforeItem
                Keys.onPressed: event => {
                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.AltModifier)) {
                        palette.openActions();
                    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_I || event.key === Qt.Key_Slash) {
                        search.forceActiveFocus();
                    } else if (event.key === Qt.Key_Escape) {
                        palette.dismissOrReset();
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                        results.currentIndex = Math.min(displayedModel.values.length - 1, results.currentIndex + 1);
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                        results.currentIndex = Math.max(0, results.currentIndex - 1);
                    } else if (event.key === Qt.Key_U || event.key === Qt.Key_D) {
                        const rows = Math.max(1, Math.floor(results.height / (57 + results.spacing) / 2));
                        results.currentIndex = Math.max(0, Math.min(displayedModel.values.length - 1, results.currentIndex + (event.key === Qt.Key_D ? rows : -rows)));
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        palette.launchCurrent((event.modifiers & Qt.ShiftModifier) !== 0);
                    } else {
                        return;
                    }
                    event.accepted = true;
                }

                highlight: SquircleSurface {
                    exponent: theme.squircleExponent
                    cornerRadius: theme.radiusMedium
                    fillColor: theme.blend(theme.layer2, theme.accent, theme.dark ? 0.07 : 0.045)
                    borderColor: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, theme.dark ? 0.53 : 0.62)
                    borderWidth: theme.borderThin
                }

                delegate: Item {
                    id: result

                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    height: 57

                    Row {
                        anchors {
                            fill: parent
                            leftMargin: theme.spacing3
                            rightMargin: theme.spacing3
                        }
                        spacing: theme.spacing3

                        SquircleSurface {
                            width: 36
                            height: 36
                            anchors.verticalCenter: parent.verticalCenter
                            exponent: theme.squircleExponent
                            cornerRadius: theme.radiusSmall
                            fillColor: result.ListView.isCurrentItem ? theme.blend(theme.controlBase, theme.accent, 0.18) : theme.controlBase
                            borderColor: result.ListView.isCurrentItem ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.55) : theme.subtleBorder
                            borderWidth: theme.borderThin

                            Text {
                                anchors.centerIn: parent
                                text: result.index + 1
                                color: result.ListView.isCurrentItem ? theme.accent : theme.textMuted
                                font.family: runtime.fontMono
                                font.pixelSize: theme.fontSize(11)
                                font.weight: Font.Bold
                            }
                        }

                        Item {
                            width: 36
                            height: parent.height

                            Image {
                                visible: !modelData.glyph
                                anchors.centerIn: parent
                                width: 29
                                height: 29
                                source: modelData.icon ? Quickshell.iconPath(modelData.icon, "application-x-executable") : Quickshell.iconPath("application-x-executable")
                                sourceSize.width: width
                                sourceSize.height: height
                                asynchronous: true
                                fillMode: Image.PreserveAspectFit
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: !!modelData.glyph
                                text: modelData.glyph || ""
                                color: theme.textStrong
                                font.pixelSize: theme.fontSize(24)
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(90, parent.width - 240)
                            spacing: 1

                            MarqueeText {
                                width: parent.width
                                text: modelData.name
                                textFormat: Text.PlainText
                                color: theme.textStrong
                                font.family: runtime.fontMono
                                font.pixelSize: theme.fontSize(14)
                                font.weight: result.ListView.isCurrentItem ? Font.DemiBold : Font.Normal
                            }

                            MarqueeText {
                                width: parent.width
                                visible: modelData.genericName && modelData.genericName.length > 0
                                text: modelData.genericName
                                textFormat: Text.PlainText
                                color: theme.textMuted
                                font.family: runtime.fontMono
                                font.pixelSize: theme.fontSize(11)
                            }
                        }

                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 122
                            height: parent.height

                            KeyChord {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.rightMargin: result.ListView.isCurrentItem && !palette.actionMode && !palette.parameterTarget ? 34 : 0
                                shortcut: result.modelData.key.length > 0 ? result.modelData.key : (result.ListView.isCurrentItem ? "↵ RUN" : "")
                                fontFamily: runtime.fontMono
                                fontSize: theme.fontSize(11)
                                textColor: result.ListView.isCurrentItem ? theme.accent : theme.textMuted
                            }
                        }
                    }

                    StateLayer {
                        theme: card.theme
                        motion: card.motion
                        cornerRadius: card.theme.radiusMedium
                        // Do not select a new row when search results move beneath a stationary pointer.
                        onPositionChanged: results.currentIndex = result.index
                        onActivated: {
                            results.currentIndex = result.index;
                            palette.launchCurrent(false);
                        }
                    }

                    ShellAction {
                        anchors.right: parent.right
                        anchors.rightMargin: theme.spacing2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 29
                        height: 29
                        visible: !palette.actionMode && result.ListView.isCurrentItem && !palette.parameterTarget
                        runtime: palette.runtime
                        theme: palette.theme
                        motion: palette.motion
                        compact: true
                        iconOnly: true
                        icon: "󰍉"
                        title: "More actions (Alt+Enter)"
                        onActivated: {
                            results.currentIndex = result.index;
                            palette.openActions();
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: displayedModel.values.length === 0
                    text: palette.parameterTarget ? "ENTER A VALUE" : "NO MATCHES"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(12)
                    font.letterSpacing: 1.5
                }
            }

            Row {
                id: footer

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }

                Text {
                    text: palette.copyFeedback || displayedModel.values.length + (palette.actionMode ? " ACTIONS" : " RESULTS")
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(10)
                    font.letterSpacing: 1.2
                }

                Item {
                    width: parent.width - parent.children[0].width - hints.width
                    height: 1
                }

                Text {
                    id: hints
                    text: palette.actionMode ? "J/K SELECT  ·  ↵ EXECUTE  ·  ESC BACK" : search.activeFocus ? "TYPE TO SEARCH  ·  TAB NAV  ·  ALT+↵ ACTIONS  ·  ⇧ESC CLOSE" : "J/K SELECT  ·  U/D PAGE  ·  ALT+↵ ACTIONS  ·  ESC BACK"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(10)
                    font.letterSpacing: 0.7
                }
            }
        }

        WidgetHelp {
            anchors.fill: parent
            runtime: palette.runtime
            theme: palette.theme
            motion: palette.motion
            open: palette.helpOpen
            title: "Command palette controls"
            bindings: [
                {
                    key: "Alt+1–4",
                    action: "Choose search mode"
                },
                {
                    key: "Tab",
                    action: "Switch search and results"
                },
                {
                    key: "J / K",
                    action: "Move through results"
                },
                {
                    key: "U / D",
                    action: "Half-page through results"
                },
                {
                    key: "Enter",
                    action: "Run selected result"
                },
                {
                    key: "Shift+Enter",
                    action: "Run without closing"
                },
                {
                    key: "Alt+Enter",
                    action: "Selected result actions"
                },
                {
                    key: "Esc",
                    action: "Close help or palette"
                }
            ]
            onDismissed: palette.dismissOrReset()
        }
    }
}

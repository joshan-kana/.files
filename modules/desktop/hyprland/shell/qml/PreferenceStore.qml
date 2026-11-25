import QtQuick
import QtCore
import Quickshell

// Persist only explicit overrides. Each feature supplies its own baseline
// and migrates its existing category without moving unrelated runtime state.
QtObject {
    id: store
    required property string category
    required property var defaults
    property var constraints: ({})
    property string location: "file://" + (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/desktop-shell/preferences.ini"
    property Settings backend: Settings {
        id: persisted
        location: store.location
        category: store.category
        property string overridesJson: ""
    }
    readonly property var overrides: objectFromJson(persisted.overridesJson)

    function objectFromJson(raw: string): var {
        try {
            const parsed = JSON.parse(raw);
            return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
        } catch (_) {
            return {};
        }
    }

    function has(key: string): bool {
        return Object.prototype.hasOwnProperty.call(overrides, key) && valid(key, overrides[key]);
    }

    function valid(key: string, value: var): bool {
        if (!Object.prototype.hasOwnProperty.call(defaults, key) || value === null || typeof value !== typeof defaults[key])
            return false;
        if (typeof value === "number" && !Number.isFinite(value) || typeof value === "object" && Array.isArray(value))
            return false;
        const rule = constraints[key];
        if (!rule)
            return true;
        if (rule.values && !rule.values.includes(value))
            return false;
        if (typeof value === "number" && (rule.integer && !Number.isInteger(value) || rule.min !== undefined && value < rule.min || rule.max !== undefined && value > rule.max))
            return false;
        return true;
    }

    function value(key: string): var {
        return has(key) ? overrides[key] : defaults[key];
    }

    function legacy(key: string, fallback: var): var {
        return coerceLegacy(backend.value(key, null), fallback);
    }

    function coerceLegacy(old: var, fallback: var): var {
        if (old === null || old === undefined)
            return undefined;
        if (typeof fallback === "boolean") {
            if (old === true || old === "true" || old === 1 || old === "1")
                return true;
            if (old === false || old === "false" || old === 0 || old === "0")
                return false;
            return undefined;
        }
        if (typeof fallback === "number") {
            const number = Number(old);
            return Number.isFinite(number) ? number : undefined;
        }
        return typeof old === "string" ? old : undefined;
    }

    function legacyMarked(key: string, marker: string): var {
        return backend.value(marker, "") === "default" ? undefined : legacy(key, defaults[key]);
    }

    function write(next: var): void {
        persisted.overridesJson = JSON.stringify(next);
        backend.setValue("overridesJson", persisted.overridesJson);
        backend.sync();
    }

    function initialize(old: var): void {
        if (persisted.overridesJson === "") {
            const next = {};
            for (const key of Object.keys(old))
                if (valid(key, old[key]))
                    next[key] = old[key];
            write(next);
        }
    }

    function setMany(values: var): void {
        const next = Object.assign({}, overrides);
        for (const key of Object.keys(values)) {
            if (valid(key, values[key]))
                next[key] = values[key];
        }
        write(next);
    }

    function set(key: string, value: var): void {
        setMany({
            [key]: value
        });
    }

    function reset(key: string): void {
        resetMany([key]);
    }

    function resetMany(keys: var): void {
        const next = Object.assign({}, overrides);
        for (const key of keys)
            delete next[key];
        write(next);
    }

    function resetAll(): void {
        write({});
    }
}

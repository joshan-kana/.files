// Pure search helpers for the native command palette. No commands or code evaluation.
const DEFAULT_QUICKLINKS = [
    { name: "Search GitHub", alias: "gh", url: "https://github.com/search?q={query}", keywords: ["code", "repositories"] },
    { name: "Search Nix Packages", alias: "np", url: "https://search.nixos.org/packages?query={query}", keywords: ["nixpkgs", "packages"] },
    { name: "Search Wikipedia", alias: "wiki", url: "https://en.wikipedia.org/w/index.php?search={query}", keywords: ["encyclopedia"] },
    { name: "Search YouTube", alias: "yt", url: "https://www.youtube.com/results?search_query={query}", keywords: ["videos"] }
];

function parseQuicklinks(text) {
    let entries = DEFAULT_QUICKLINKS;
    if (text && text.trim().length > 0) {
        try {
            const parsed = JSON.parse(text);
            if (!Array.isArray(parsed))
                return DEFAULT_QUICKLINKS;
            entries = parsed;
        } catch (error) {
            return DEFAULT_QUICKLINKS;
        }
    }
    const aliases = new Set();
    return entries.filter(item => {
        if (!item || typeof item.name !== "string" || typeof item.alias !== "string" || typeof item.url !== "string")
            return false;
        const alias = item.alias.trim().toLowerCase();
        if (!/^[a-z][a-z0-9_-]{0,23}$/.test(alias) || aliases.has(alias))
            return false;
        // No javascript:, file:, shell schemes, or untrusted URL replacement.
        if (!/^https:\/\/[^\s{}]+/i.test(item.url) && !/^http:\/\/[^\s{}]+/i.test(item.url))
            return false;
        if (item.url.length > 2048 || !/\{query\}/.test(item.url))
            return false;
        aliases.add(alias);
        return true;
    }).map(item => ({
        kind: "quicklink",
        name: item.name.slice(0, 100),
        alias: item.alias.trim().toLowerCase(),
        urlTemplate: item.url,
        keywords: Array.isArray(item.keywords) ? item.keywords.filter(word => typeof word === "string").slice(0, 12) : [],
        icon: "internet-web-browser",
        key: "↵ SEARCH",
        genericName: "Website search · " + item.alias.toLowerCase() + " <query>"
    }));
}

function linkUrl(template, input) {
    if (!input || !input.trim())
        return "";
    return template.replace(/\{query\}/g, encodeURIComponent(input.trim()));
}

const UNITS = {
    mm: ["length", 0.001, "mm"], millimeter: ["length", 0.001, "mm"], millimeters: ["length", 0.001, "mm"],
    cm: ["length", 0.01, "cm"], centimeter: ["length", 0.01, "cm"], centimeters: ["length", 0.01, "cm"],
    m: ["length", 1, "m"], meter: ["length", 1, "m"], meters: ["length", 1, "m"], metre: ["length", 1, "m"], metres: ["length", 1, "m"],
    km: ["length", 1000, "km"], kilometer: ["length", 1000, "km"], kilometers: ["length", 1000, "km"], kilometre: ["length", 1000, "km"], kilometres: ["length", 1000, "km"],
    in: ["length", 0.0254, "in"], inch: ["length", 0.0254, "in"], inches: ["length", 0.0254, "in"],
    ft: ["length", 0.3048, "ft"], foot: ["length", 0.3048, "ft"], feet: ["length", 0.3048, "ft"],
    yd: ["length", 0.9144, "yd"], yard: ["length", 0.9144, "yd"], yards: ["length", 0.9144, "yd"],
    mi: ["length", 1609.344, "mi"], mile: ["length", 1609.344, "mi"], miles: ["length", 1609.344, "mi"],
    g: ["mass", 0.001, "g"], gram: ["mass", 0.001, "g"], grams: ["mass", 0.001, "g"],
    kg: ["mass", 1, "kg"], kilogram: ["mass", 1, "kg"], kilograms: ["mass", 1, "kg"],
    lb: ["mass", 0.45359237, "lb"], lbs: ["mass", 0.45359237, "lb"], pound: ["mass", 0.45359237, "lb"], pounds: ["mass", 0.45359237, "lb"],
    oz: ["mass", 0.028349523125, "oz"], ounce: ["mass", 0.028349523125, "oz"], ounces: ["mass", 0.028349523125, "oz"],
    sec: ["time", 1, "s"], second: ["time", 1, "s"], seconds: ["time", 1, "s"], s: ["time", 1, "s"],
    min: ["time", 60, "min"], minute: ["time", 60, "min"], minutes: ["time", 60, "min"],
    h: ["time", 3600, "h"], hr: ["time", 3600, "h"], hour: ["time", 3600, "h"], hours: ["time", 3600, "h"],
    day: ["time", 86400, "days"], days: ["time", 86400, "days"],
    kb: ["data", 1000, "kB"], mb: ["data", 1000000, "MB"], gb: ["data", 1000000000, "GB"], tb: ["data", 1000000000000, "TB"],
    kib: ["data", 1024, "KiB"], mib: ["data", 1048576, "MiB"], gib: ["data", 1073741824, "GiB"],
    c: ["temperature", 1, "°C"], celsius: ["temperature", 1, "°C"],
    f: ["temperature", 1, "°F"], fahrenheit: ["temperature", 1, "°F"],
    k: ["temperature", 1, "K"], kelvin: ["temperature", 1, "K"]
};

function convert(query) {
    if (!query || query.length > 120)
        return null;
    const percent = query.trim().match(/^(-?(?:\d+(?:\.\d*)?|\.\d+))\s*%\s+(?:of)\s+(-?(?:\d+(?:\.\d*)?|\.\d+))$/i);
    if (percent) {
        const value = Number(percent[1]) * Number(percent[2]) / 100;
        if (!Number.isFinite(value))
            return null;
        return { result: String(Number(value.toPrecision(12))), description: query.trim() };
    }
    const matched = query.trim().match(/^(-?(?:\d+(?:\.\d*)?|\.\d+))\s*°?([a-zA-Z]+)\s+(?:to|in)\s+°?([a-zA-Z]+)$/);
    if (!matched)
        return null;
    const source = UNITS[matched[2].toLowerCase()];
    const destination = UNITS[matched[3].toLowerCase()];
    if (!source || !destination || source[0] !== destination[0])
        return null;
    const value = Number(matched[1]);
    let converted;
    if (source[0] === "temperature") {
        const celsius = source[2] === "°F" ? (value - 32) * 5 / 9 : source[2] === "K" ? value - 273.15 : value;
        converted = destination[2] === "°F" ? celsius * 9 / 5 + 32 : destination[2] === "K" ? celsius + 273.15 : celsius;
        if (celsius < -273.15)
            return null;
    } else
        converted = value * source[1] / destination[1];
    if (!Number.isFinite(converted))
        return null;
    const label = String(Number(converted.toPrecision(12))) + " " + destination[2];
    return { result: label, description: query.trim() };
}

function quicklinkResult(link, query) {
    const text = query.trim();
    const aliasMatch = text.match(/^([^\s]+)(?:\s+([\s\S]+))?$/);
    const parameter = aliasMatch && aliasMatch[1].toLowerCase() === link.alias ? (aliasMatch[2] || "") : "";
    return Object.assign({}, link, {
        name: parameter ? link.name + " · " + parameter : link.name,
        url: linkUrl(link.urlTemplate, parameter),
        parameter: parameter,
        promptOnActivation: !parameter
    });
}

function parseSnippets(text) {
    if (!text || !text.trim())
        return [];
    try {
        const source = JSON.parse(text);
        if (!Array.isArray(source))
            return [];
        const names = new Set();
        return source.filter(item => item && typeof item.name === "string" && typeof item.text === "string"
            && item.name.trim().length > 0 && item.name.length <= 100 && item.text.length <= 4000
            && !names.has(item.name.toLowerCase()) && (names.add(item.name.toLowerCase()), true))
            .map(item => ({
                kind: "snippet",
                name: item.name,
                genericName: "Saved text snippet · copy",
                icon: "edit-copy",
                key: "COPY",
                snippetText: item.text,
                keywords: Array.isArray(item.keywords) ? item.keywords.filter(word => typeof word === "string").slice(0, 12) : []
            }));
    } catch (error) {
        return [];
    }
}

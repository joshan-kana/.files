local hs = _G.hs

-- Central theme for all Hammerspoon UI (window switcher, cheatsheet, etc.)
-- Inspired by base16-framer — dark background, bright crisp text, no dimming.
--
-- Usage:
--   local theme = require("theme")
--   local colors = theme.colors
--   -- Or pick a named scheme:
--   theme.apply("framer")  -- default
--   theme.apply("tokyo-night")

local M = {}

-- Built‑in colour schemes
-- Each scheme must provide every key listed below.

local schemes = {}

-- Framer: deep dark background, bright foreground, rich accents.
-- Base palette adapted from base16‑framer by TSUYUSATO Kitsune.
schemes["framer"] = {
	bg = { hex = "111111" }, -- base00 — corrected by canvas gamma in hexToColor
	bgAlt = { hex = "1a1a1a" }, -- base01 – row background, slightly lighter
	bgSelected = { hex = "3a3a3a" }, -- brighter than base02 for selected rows
	stroke = { hex = "505050" }, -- subtle border
	fg = { hex = "d0d0d0" }, -- base05 – main text (bright, not dimmed)
	fgDim = { hex = "888888" }, -- base03 – secondary / dim text
	fgMuted = { hex = "666666" }, -- very muted (counter, footer)
	accent = { hex = "fc6a5c" }, -- red/coral  – primary accent
	green = { hex = "66cc66" },
	yellow = { hex = "ffcc00" },
	blue = { hex = "5588cc" },
	magenta = { hex = "cc55cc" },
	cyan = { hex = "55cccc" },
}

-- Tokyo Night: popular dark theme with blue-ish undertones.
schemes["tokyo-night"] = {
	bg = { hex = "1a1b26" },
	bgAlt = { hex = "24283b" },
	bgSelected = { hex = "3b4261" },
	stroke = { hex = "565f89" },
	fg = { hex = "c0caf5" },
	fgDim = { hex = "9aa5ce" },
	fgMuted = { hex = "565f89" },
	accent = { hex = "f7768e" },
	green = { hex = "9ece6a" },
	yellow = { hex = "e0af68" },
	blue = { hex = "7aa2f7" },
	magenta = { hex = "bb9af7" },
	cyan = { hex = "7dcfff" },
}

-- Active scheme (set by apply())

M._active = "framer"

-- Canvas color space correction
-- hs.canvas uses calibrated RGB (gamma ~1.8), not sRGB (gamma ~2.2).
-- Every hex color is raised to this exponent before the canvas sees it,
-- cancelling out the ~23% brightening.  Calibrated against Digital Color Meter.
local CANVAS_GAMMA = 1.058

-- Utility: hex → HS color table

local function hexToColor(hex)
	hex = hex:gsub("#", "")
	local g = CANVAS_GAMMA
	return {
		red = (tonumber(hex:sub(1, 2), 16) / 255) ^ g,
		green = (tonumber(hex:sub(3, 4), 16) / 255) ^ g,
		blue = (tonumber(hex:sub(5, 6), 16) / 255) ^ g,
		alpha = 1,
	}
end

-- Resolve a scheme value to an HS color table

local function resolve(val)
	if type(val) == "table" and val.red then
		return val -- already an HS color
	end
	if type(val) == "table" and val.hex then
		return hexToColor(val.hex)
	end
	if type(val) == "string" then
		return hexToColor(val)
	end
	error("theme: cannot resolve color value: " .. tostring(val))
end

-- Public API

--- Switch to a named colour scheme.
--- @param name string  e.g. "framer", "tokyo-night"
function M.apply(name)
	if not schemes[name] then
		hs.alert.show("Unknown theme: " .. name)
		return
	end
	M._active = name
end

--- Get the resolved HS color table for the active scheme.
--- This is the main accessor used by other modules.
--- @return table
function M.colors()
	local scheme = schemes[M._active]
	if not scheme then
		error("theme: no scheme named '" .. M._active .. "'")
	end

	local colors = {}
	for k, v in pairs(scheme) do
		colors[k] = resolve(v)
	end

	-- Pre‑compute common alpha‑variants used by the UI modules.
	colors.bgAlpha = resolve(scheme.bg)
	colors.bgAlpha.alpha = 0.90
	colors.bgAlphaStrong = resolve(scheme.bg)
	colors.bgAlphaStrong.alpha = 0.93
	colors.bgAltAlpha = resolve(scheme.bgAlt)
	colors.bgAltAlpha.alpha = 0.62
	colors.bgSelectedAlpha = resolve(scheme.bgSelected)
	colors.bgSelectedAlpha.alpha = 0.95
	colors.strokeFaint = resolve(scheme.stroke)
	colors.strokeFaint.alpha = 0.08
	colors.separator = resolve(scheme.fg)
	colors.separator.alpha = 0.06
	colors.footerMuted = resolve(scheme.fgMuted)
	colors.footerMuted.alpha = 0.80

	return colors
end

return M

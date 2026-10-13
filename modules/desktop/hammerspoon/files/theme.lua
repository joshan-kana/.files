-- Palette follows the active Stylix theme from the evaluated Mac configuration.
local M = {}
local scheme = require("nix_runtime").colors

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

-- Resolve the current shared theme for Hammerspoon drawing.
function M.colors()
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

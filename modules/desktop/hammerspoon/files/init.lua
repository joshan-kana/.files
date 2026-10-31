local hs = _G.hs
local ui = require("ui")

local yabai_utils = require("yabai_utils")
local bindings = require("keybinds")
local modifiers = require("modifiers")
local shortcut_passthrough = require("shortcut_passthrough")
local theme = require("theme")
local colors = theme.colors()
hs.alert.defaultStyle.fillColor = colors.bgAlphaStrong
hs.alert.defaultStyle.strokeColor = colors.stroke
hs.alert.defaultStyle.textColor = colors.fg
hs.alert.defaultStyle.textFont = theme.fonts.sansSerif
_G.eventtapBindings = {}

local function bindEventtap(mods, key, fn, rpt)
	local expected = {}
	for _, mod in ipairs(mods) do
		expected[mod] = true
	end

	local tap = hs.eventtap
		.new({ hs.eventtap.event.types.keyDown }, function(event)
			if event:getKeyCode() ~= hs.keycodes.map[key] then
				return false
			end
			local flags = event:getFlags()
			for _, mod in ipairs({ "cmd", "alt", "ctrl", "shift" }) do
				if (flags[mod] or false) ~= (expected[mod] or false) then
					return false
				end
			end

			if shortcut_passthrough.enabled() then
				return false
			end

			local repeated = event:getProperty(hs.eventtap.event.properties.keyboardEventAutorepeat) == 1
			local callback = fn
			if repeated then
				callback = rpt
			end
			if callback then
				callback()
			end
			return true
		end)
		:start()
	-- Retain event taps for the lifetime of this configuration.
	table.insert(_G.eventtapBindings, tap)
end

-- Sticky Hyper mode
-- hyper+tab toggles a modal in which bare keys act as hyper bindings.
local stickyHyper = hs.hotkey.modal.new()

function stickyHyper:entered()
	ui.mode("Hyper lock", true, "Shortcuts stay active")
	self._active = true
end
function stickyHyper:exited()
	ui.mode("Hyper lock", false, "Normal keyboard input restored")
	self._active = false
end

local function toggleStickyHyper()
	stickyHyper[stickyHyper._active and "exit" or "enter"](stickyHyper)
end

-- Bind everything from keybinds.lua.
for _, b in ipairs(bindings) do
	if b.stickyToggle then
		hs.hotkey.bind(modifiers.resolve(b.mods), b.key, toggleStickyHyper)
		stickyHyper:bind(modifiers.resolve(b.mods), b.key, toggleStickyHyper)
	else
		local fn = b.fn or function()
			yabai_utils.exec(b.cmd)
		end
		local rpt = b.rpt == true and fn or b.rpt

		if b.eventtap then
			bindEventtap(modifiers.resolve(b.mods), b.key, fn, rpt)
		elseif b.modal then
			b.modal:bind(modifiers.resolve(b.mods), b.key, fn, nil, rpt)
		else
			hs.hotkey.bind(modifiers.resolve(b.mods), b.key, fn, nil, rpt)

			local stickyMods = modifiers.resolve(b.mods, true)
			if stickyMods then
				stickyHyper:bind(stickyMods, b.key, fn)
			end
		end
	end
end

require("space_stash").start()

require("hs.ipc")

-- Set the built-in display brightness using Hammerspoon's per-screen API.
function _G.setDisplayBrightness(percent)
	local screen = hs.screen.mainScreen()
	if screen then
		screen:setBrightness(math.max(0, math.min(100, percent)) / 100)
	end
end

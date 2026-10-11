local hs = _G.hs

local yabai_utils = require("yabai_utils")
local bindings = require("keybinds")
local modifiers = require("modifiers")
require("theme").apply("framer") -- Set default theme (change to "tokyo-night" etc.)

-- Sticky Hyper mode
-- hyper+tab toggles a modal in which bare keys act as hyper bindings.
local stickyHyper = hs.hotkey.modal.new()

function stickyHyper:entered()
	hs.alert.show("Hyper-locked")
	self._active = true
end
function stickyHyper:exited()
	hs.alert.show("Hyper-unlocked")
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

		if b.modal then
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

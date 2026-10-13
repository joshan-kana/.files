local hs = _G.hs

-- Small stateless toggle functions used by keybinds.lua.

local y = require("yabai_utils")
local M = {}

local previousSpaceLayouts = hs.settings.get("hs_previous_space_layouts") or {}

--- Toggle floating layout for the current yabai space.
function M.spaceFloat()
	local space = y.json("query --spaces --space")

	if not space then
		hs.alert.show("Could not read yabai space")
		return
	end

	local spaceIndex = tostring(space.index)
	local currentLayout = space.type

	if currentLayout == "float" then
		y.exec("space --layout " .. (previousSpaceLayouts[spaceIndex] or "bsp"))
		previousSpaceLayouts[spaceIndex] = nil
	else
		previousSpaceLayouts[spaceIndex] = currentLayout
		y.exec("space --layout float")
	end
	hs.settings.set("hs_previous_space_layouts", previousSpaceLayouts)
end

--- Toggle menu bar visibility via AppleScript.
function M.menuBar()
	hs.osascript.applescript([[
tell application "System Events"
  tell dock preferences
    set autohide menu bar to not autohide menu bar
  end tell
end tell
]])
end

--- Toggle yabai mouse_follows_focus.
function M.mouseFollowsFocus()
	local output = y.exec("config mouse_follows_focus")
	-- yabai outputs just "on" or "off" (no key name, just the value)
	local current = (output or ""):match("^%s*on%s*$") and true or false
	local newState = not current
	local stateStr = newState and "on" or "off"

	y.exec("config mouse_follows_focus " .. stateStr)
	hs.alert.show("Mouse follows focus: " .. stateStr)
end

--- Power lock.
--- Keeps the Mac awake and blocks cooperative remote shutdowns.
--- Displays are still allowed to sleep.
local POWER_LOCK_SETTING = "hs_power_lock"
local POWER_LOCK_FILE = os.getenv("HOME") .. "/.local/state/power-lock"

local function setPowerLock(enabled, notify)
	hs.caffeinate.set("systemIdle", enabled)
	hs.caffeinate.set("system", enabled)

	hs.settings.set(POWER_LOCK_SETTING, enabled)

	if enabled then
		hs.execute('/bin/mkdir -p "$HOME/.local/state"')

		local file = io.open(POWER_LOCK_FILE, "w")
		if file then
			file:write("enabled\n")
			file:close()
		end
	else
		os.remove(POWER_LOCK_FILE)
	end

	if notify then
		hs.alert.show("Power Lock: " .. (enabled and "ON 🔒" or "OFF 🔓"))
	end
end

function M.powerLock()
	setPowerLock(hs.settings.get(POWER_LOCK_SETTING) ~= true, true)
end

-- Reapply the lock whenever Hammerspoon starts or reloads.
-- hs.caffeinate assertions themselves do not survive a reload.
setPowerLock(hs.settings.get(POWER_LOCK_SETTING) == true, false)

return M

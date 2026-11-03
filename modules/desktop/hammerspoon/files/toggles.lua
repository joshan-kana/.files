local hs = _G.hs
local ui = require("ui")

-- Small stateless toggle functions used by keybinds.lua.

local y = require("yabai_utils")
local M = {}

local previousSpaceLayouts = hs.settings.get("hs_previous_space_layouts") or {}

--- Toggle floating layout for the current yabai space.
function M.spaceFloat()
	local space = y.json("query --spaces --space")

	if not space then
		ui.error("Could not read yabai space")
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
local MOUSE_FOLLOWS_FOCUS_SETTING = "hs_mouse_follows_focus"

local function setMouseFollowsFocus(enabled)
	return y.ok("config mouse_follows_focus " .. (enabled and "on" or "off"))
end

function M.mouseFollowsFocus()
	local output, ok = y.exec("config mouse_follows_focus")
	local current = ok and (output or ""):match("^%s*(%a+)%s*$") or nil
	if current ~= "on" and current ~= "off" then
		ui.error("Could not read yabai mouse focus setting")
		return
	end

	local enabled = current ~= "on"
	if not setMouseFollowsFocus(enabled) then
		ui.error("Could not change yabai mouse focus setting")
		return
	end
	hs.settings.set(MOUSE_FOLLOWS_FOCUS_SETTING, enabled)
	ui.mode("Mouse follows focus", enabled)
end

-- Restore only an explicitly chosen override; otherwise keep the yabai default.
-- Retry briefly because Hammerspoon can start before yabai at login.
local savedMouseFollowsFocus = hs.settings.get(MOUSE_FOLLOWS_FOCUS_SETTING)
if type(savedMouseFollowsFocus) == "boolean" then
	local attempts = 0
	local function restore()
		if hs.settings.get(MOUSE_FOLLOWS_FOCUS_SETTING) ~= savedMouseFollowsFocus then
			return
		end
		attempts = attempts + 1
		if not setMouseFollowsFocus(savedMouseFollowsFocus) and attempts < 10 then
			hs.timer.doAfter(0.5, restore)
		end
	end
	hs.timer.doAfter(0.5, restore)
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
		ui.mode("Power Lock", enabled, enabled and "Mac stays awake" or "System sleep restored")
	end
end

function M.powerLock()
	setPowerLock(hs.settings.get(POWER_LOCK_SETTING) ~= true, true)
end

-- Reapply the lock whenever Hammerspoon starts or reloads.
-- hs.caffeinate assertions themselves do not survive a reload.
setPowerLock(hs.settings.get(POWER_LOCK_SETTING) == true, false)

return M

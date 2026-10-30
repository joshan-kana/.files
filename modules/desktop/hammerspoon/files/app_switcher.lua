local hs = _G.hs
local ui = require("ui")
local yabai = require("yabai_utils")

local M = {}
local newWindowMode = false
local newWindowMenus = { "New Window", "New Finder Window", "New OS Window" }

function M.toggleMode()
	newWindowMode = not newWindowMode
	ui.mode("New-window mode", newWindowMode, newWindowMode and "Create on current Space" or "Switch to existing apps")
end

local function focusNewWindow(pid, existing, space, attempts)
	for _, window in ipairs(yabai.json("query --windows") or {}) do
		if window.pid == pid and not existing[window.id] and window.subrole == "AXStandardWindow" then
			if window.space ~= space and not yabai.windowCmd(window.id, "--space " .. space) then
				ui.error("Could not move new window to this Space")
				return
			end
			local focusedSpace = yabai.json("query --spaces --space")
			if (not focusedSpace or focusedSpace.index ~= space) and not yabai.ok("space --focus " .. space) then
				ui.error("Could not return to original Space")
				return
			end
			if not window["has-focus"] and not yabai.windowCmd(window.id, "--focus") then
				ui.error("Could not focus new window")
			end
			return
		end
	end

	if attempts < 20 then
		hs.timer.doAfter(0.1, function()
			focusNewWindow(pid, existing, space, attempts + 1)
		end)
	else
		ui.error("New app window did not appear")
	end
end

function M.open(name)
	if not newWindowMode then
		hs.application.launchOrFocus(name)
		return
	end

	local app = hs.application.find(name, true) or hs.application.find(name)
	if not app then
		-- First launch already creates a window on the active Space.
		hs.application.launchOrFocus(name)
		return
	end

	local currentSpace = yabai.json("query --spaces --space")
	local windows = yabai.json("query --windows")
	if not currentSpace or not windows then
		ui.error("Could not identify current Space")
		return
	end

	local existing = {}
	for _, window in ipairs(windows) do
		existing[window.id] = true
	end

	for _, menu in ipairs(newWindowMenus) do
		if app:findMenuItem(menu) then
			if not app:selectMenuItem(menu) then
				ui.error("Could not open a new " .. name .. " window")
				return
			end
			hs.timer.doAfter(0.1, function()
				focusNewWindow(app:pid(), existing, currentSpace.index, 1)
			end)
			return
		end
	end

	ui.show(name .. " has no New Window command", { kind = "warning" })
end

return M

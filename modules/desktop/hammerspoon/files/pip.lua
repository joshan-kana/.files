-- Picture-in-picture style floating sticky top-layer window.
-- sticky makes it visible across Spaces.
-- sub-layer above replaces the old topmost toggle.
-- Tracks a single PiP window so hyper+p can restore it even when another
-- window is focused and covering it.

local y = require("yabai_utils")
local M = {}

local pipGrid = "6:6:4:0:2:2"
local pipWindowId = hs.settings.get("hs_pip_window_id")

-- Shared restore: resets sub-layer, sticky, and floating state for a PiP window.
local function pipRestore(id)
	y.windowCmd(id, "--sub-layer normal")

	local win = y.windowById(id)

	if win then
		if win["is-sticky"] then
			y.windowCmd(id, "--toggle sticky")
		end

		if win["is-floating"] then
			y.windowCmd(id, "--toggle float")
		end
	end

	pipWindowId = nil
	hs.settings.set("hs_pip_window_id", nil)
	hs.alert.show("PiP off")
end

function M.toggle()
	-- If we already have a tracked PiP, restore it even if another
	-- window is currently focused and covering it.
	if pipWindowId and y.windowById(pipWindowId) then
		pipRestore(pipWindowId)
		return
	end

	pipWindowId = nil

	local focused = y.json("query --windows --window")

	if not focused then
		hs.alert.show("Could not read yabai window")
		return
	end

	-- Hammerspoon reloaded and lost pipWindowId, but the focused window
	-- is already in the PiP state — just restore it.
	if focused["is-floating"] and focused["is-sticky"] and focused["sub-layer"] == "above" then
		pipRestore(focused.id)
		return
	end

	-- Enable PiP for the focused window.
	local id = focused.id

	if not focused["is-floating"] then
		y.windowCmd(id, "--toggle float")
	end

	-- Re-query after floating because sticky/floating can change the window state.
	focused = y.windowById(id) or focused

	if not focused["is-sticky"] then
		y.windowCmd(id, "--toggle sticky")
	end

	local subLayerOk = y.windowCmd(id, "--sub-layer above")

	hs.timer.doAfter(0.03, function()
		y.windowCmd(id, "--grid " .. pipGrid)

		local updated = y.windowById(id)
		pipWindowId = id
		hs.settings.set("hs_pip_window_id", id)

		if not subLayerOk or not updated or updated["sub-layer"] ~= "above" then
			hs.alert.show("PiP on, but sub-layer above failed")
		else
			hs.alert.show("PiP on")
		end
	end)
end

return M

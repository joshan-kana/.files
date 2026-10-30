local hs = _G.hs
local ui = require("ui")

-- Spotify "Expand Now Playing view" button.
--
-- Targets the circular diagonal-arrows button. Does NOT click the
-- bottom-right native fullscreen button.
--
-- Uses a synthetic click at the target coordinate, so yabai
-- mouse_follows_focus will not steal the cursor before the click.
--
-- To recalibrate the click coordinates:
-- 1. Open Spotify.
-- 2. Hover your mouse over the "Expand Now Playing view" button.
-- 3. Run this in the Hammerspoon console:
--      local app = hs.application.find("Spotify")
--      local win = app:mainWindow()
--      local f = win:frame(); local m = hs.mouse.absolutePosition()
--      print("xFromRight = " .. math.floor(f.x + f.w - m.x))
--      print("yFromTop = " .. math.floor(m.y - f.y))
-- 4. Update the values below.

local M = {}

local clickOffset = {
	xFromRight = 36,
	yFromTop = 93,
}

function M.open()
	local function click(win)
		local frame = win:frame()

		local point = {
			x = frame.x + frame.w - clickOffset.xFromRight,
			y = frame.y + clickOffset.yFromTop,
		}

		local event = hs.eventtap.event
		local types = event.types

		event.newMouseEvent(types.leftMouseDown, point):post()
		hs.timer.usleep(25000)
		event.newMouseEvent(types.leftMouseUp, point):post()
	end

	local function focusSpotifyThenClick(app, win)
		app:activate(true)
		win:focus()

		-- Brief delay so yabai mouse_follows_focus can settle.
		hs.timer.doAfter(0.04, function()
			click(win)
		end)
	end

	-- Fast path: Spotify is already running and has a window.
	local app = hs.application.find("Spotify")

	if app then
		local win = app:mainWindow()

		if win then
			focusSpotifyThenClick(app, win)
			return
		end
	end

	-- Slow path: Spotify is not ready — launch it and retry.
	hs.application.launchOrFocus("Spotify")

	local attempts = 0

	local function retry()
		attempts = attempts + 1

		local readyApp = hs.application.find("Spotify")

		if readyApp then
			local readyWin = readyApp:mainWindow()

			if readyWin then
				focusSpotifyThenClick(readyApp, readyWin)
				return
			end
		end

		if attempts >= 20 then
			ui.error("Spotify window not found")
			return
		end

		hs.timer.doAfter(0.08, retry)
	end

	hs.timer.doAfter(0.08, retry)
end

return M

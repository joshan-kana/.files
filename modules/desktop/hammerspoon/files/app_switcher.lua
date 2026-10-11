-- Launch-or-focus an app. All app names live in keybinds.lua.

local M = {}

--- Focus an app or launch it if not running.
--- @param app string  The app name or bundle ID.
function M.focus(app)
	hs.application.launchOrFocus(app)
end

return M

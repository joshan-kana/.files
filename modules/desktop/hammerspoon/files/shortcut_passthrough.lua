local hs = _G.hs
local ui = require("ui")

local M = {}
local settingsKey = "shortcut_passthrough.apps"
local apps = hs.settings.get(settingsKey) or {}

local function frontmostApp()
	local app = hs.application.frontmostApplication()
	local bundleID = app and app:bundleID()
	return app, bundleID
end

function M.enabled()
	local _, bundleID = frontmostApp()
	return bundleID ~= nil and apps[bundleID] == true
end

function M.toggle()
	local app, bundleID = frontmostApp()
	if not bundleID or bundleID == "" then
		ui.error("Cannot identify the focused application")
		return
	end

	local enabled = apps[bundleID] ~= true
	apps[bundleID] = enabled and true or nil
	hs.settings.set(settingsKey, apps)
	ui.mode(
		"Shortcut pass-through",
		enabled,
		(app:name() or bundleID) .. (enabled and ": Pass-through enabled" or ": Hammerspoon handles shortcuts")
	)
end

return M

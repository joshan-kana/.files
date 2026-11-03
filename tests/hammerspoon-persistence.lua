local sourceDir = assert(arg[1], "expected Hammerspoon source directory")
package.path = sourceDir .. "/?.lua;" .. package.path

local saved = {}
local delayed = {}
local notifications = {}
local errors = {}
local launchCount = 0
local menuCount = 0
local mouseState = "on"
local mouseAvailable = true

local function reload(name)
	package.loaded[name] = nil
	return require(name)
end

local function drainTimers()
	local pending = delayed
	delayed = {}
	for _, callback in ipairs(pending) do
		callback()
	end
end

_G.hs = {
	settings = {
		get = function(key)
			return saved[key]
		end,
		set = function(key, value)
			saved[key] = value
		end,
	},
	application = {
		launchOrFocus = function()
			launchCount = launchCount + 1
			return true
		end,
		find = function()
			return {
				findMenuItem = function()
					return true
				end,
				selectMenuItem = function()
					menuCount = menuCount + 1
					return true
				end,
				pid = function()
					return 123
				end,
			}
		end,
	},
	timer = {
		doAfter = function(_, callback)
			table.insert(delayed, callback)
		end,
	},
	caffeinate = { set = function() end },
	osascript = { applescript = function() end },
	alert = { defaultStyle = {} },
	hotkey = {
		modal = {
			new = function()
				local modal = {}
				modal.bind = function() end
				function modal:enter()
					self:entered()
				end
				function modal:exit()
					self:exited()
				end
				return modal
			end,
		},
	},
}

local ui = {
	mode = function(label, enabled)
		notifications[label] = enabled
	end,
	error = function(message)
		table.insert(errors, message)
	end,
}
local yabai = {
	exec = function(command)
		if command == "config mouse_follows_focus" then
			return mouseAvailable and mouseState or nil, mouseAvailable
		end
		error("Unexpected yabai command: " .. command)
	end,
	ok = function(command)
		if not mouseAvailable then
			return false
		end
		local requested = command:match("^config mouse_follows_focus (%a+)$")
		if requested then
			mouseState = requested
			return true
		end
		error("Unexpected yabai command: " .. command)
	end,
	json = function(command)
		if command == "query --spaces --space" then
			return { index = 1 }
		end
		if command == "query --windows" then
			return {}
		end
		error("Unexpected yabai query: " .. command)
	end,
}
package.loaded.ui = ui
package.loaded.yabai_utils = yabai

-- MEH mode is restored after requiring the module again.
local appSwitcher = reload("app_switcher")
appSwitcher.open("Zen")
assert(launchCount == 1 and menuCount == 0)
appSwitcher.toggleMode()
assert(saved.hs_app_switcher_new_window_mode == true)
assert(notifications["New-window mode"] == true)
appSwitcher = reload("app_switcher")
appSwitcher.open("Zen")
assert(menuCount == 1)
appSwitcher.toggleMode()
assert(saved.hs_app_switcher_new_window_mode == false)
appSwitcher = reload("app_switcher")
appSwitcher.open("Zen")
assert(launchCount == 2 and menuCount == 1)
delayed = {} -- Discard the mock new-window focus poll.

-- Mouse focus follows the declarative default until there is an explicit override.
local isolatedOS = setmetatable({ remove = function() end }, { __index = os })
local function reloadToggles()
	local environment = setmetatable({ os = isolatedOS }, { __index = _G })
	return assert(loadfile(sourceDir .. "/toggles.lua", "t", environment))()
end
local toggles = reloadToggles()
assert(#delayed == 0)
toggles.mouseFollowsFocus()
assert(mouseState == "off" and saved.hs_mouse_follows_focus == false)
mouseState = "on"
toggles = reloadToggles()
assert(#delayed == 1)
mouseAvailable = false
drainTimers()
assert(#delayed == 1, "Yabai startup race should be retried")
mouseAvailable = true
drainTimers()
assert(mouseState == "off")
mouseAvailable = false
toggles.mouseFollowsFocus()
assert(saved.hs_mouse_follows_focus == false, "Failed toggles must not overwrite preferences")
assert(#errors == 1)

-- An in-flight startup restore cannot revert a newer user choice.
mouseAvailable = true
mouseState = "off"
toggles = reloadToggles()
assert(#delayed == 1)
toggles.mouseFollowsFocus()
assert(saved.hs_mouse_follows_focus == true)
drainTimers()
assert(mouseState == "on")

-- Sticky Hyper restores its active modal, not just a saved indicator.
local toggleHyper
_G.hs.hotkey.bind = function(_, _, callback)
	toggleHyper = callback
end
package.loaded.keybinds = { { mods = "hyper", key = "tab", stickyToggle = true } }
package.loaded.modifiers = {
	resolve = function()
		return { "ctrl", "cmd", "alt" }
	end,
}
package.loaded.shortcut_passthrough = {
	enabled = function()
		return false
	end,
}
package.loaded.theme = {
	colors = function()
		return {}
	end,
	fonts = { sansSerif = "Sans" },
}
package.loaded.space_stash = { start = function() end }
package.loaded["hs.ipc"] = {}
saved.hs_sticky_hyper_enabled = true
reload("init")
assert(notifications["Hyper lock"] == true)
toggleHyper()
assert(saved.hs_sticky_hyper_enabled == false)
assert(notifications["Hyper lock"] == false)
reload("init")
assert(notifications["Hyper lock"] == false)
toggleHyper()
assert(saved.hs_sticky_hyper_enabled == true)
assert(notifications["Hyper lock"] == true)

print("Hammerspoon preference reload tests passed")

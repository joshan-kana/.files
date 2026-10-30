local hs = _G.hs

-- All keybindings in one place. Add, remove, or change shortcuts here.
-- Legend:
--   mods    - string alias (e.g. "hyper") or raw mod table
--   key     - the key pressed
--   cmd     - yabai command or command list
--   fn      - function reference (for module callbacks, gives autocomplete)
--   modal   - optional modal to bind this key inside
--   stickyToggle - marks the sticky Hyper toggle binding
--   rpt     - optional repeat function, or true to repeat the binding action
--   section - category label for the cheatsheet overlay
--   desc    - human description for the cheatsheet overlay

local yabai_utils = require("yabai_utils")
local window_switcher = require("window_switcher")
local switcherModifier = "alt"
window_switcher.setHoldModifier(switcherModifier)
local pip = require("pip")
local spotify = require("spotify")
local media = require("media")
local toggles = require("toggles")
local cheatsheet = require("cheatsheet")
local app_switcher = require("app_switcher")
local space_stash = require("space_stash")

local QUICK_ACCESS = "hs-quick-access"

local function quickSpace()
	local spaces = yabai_utils.json("query --spaces") or {}
	local before = {}
	for _, space in ipairs(spaces) do
		if space.label == QUICK_ACCESS then
			return space
		end
		before[space.uuid] = true
	end

	local current = yabai_utils.json("query --spaces --space")
	if not current or not yabai_utils.ok("space --create " .. current.display) then
		hs.alert.show("Cannot create quick workspace (check yabai scripting addition)")
		return nil
	end

	for _, space in ipairs(yabai_utils.json("query --spaces") or {}) do
		if not before[space.uuid] then
			if yabai_utils.ok("space " .. space.index .. " --label " .. QUICK_ACCESS) then
				return space
			end
			break
		end
	end
	hs.alert.show("Could not label quick workspace")
	return nil
end

local bindings = {
	-- Free AltTab-style canvas switcher
	{
		mods = { switcherModifier },
		key = "tab",
		fn = window_switcher.next,
		rpt = window_switcher.next,
		section = "WINDOWS",
		desc = "Window switcher (next)",
	},
	{
		mods = { switcherModifier, "shift" },
		key = "tab",
		fn = window_switcher.previous,
		rpt = window_switcher.previous,
		section = "WINDOWS",
		desc = "Window switcher (prev)",
	},

	-- App switching (meh = ctrl+alt+shift). Meh+Space toggles new-window mode.
	{
		mods = "meh",
		key = "space",
		fn = app_switcher.toggleMode,
		section = "APPS",
		desc = "Toggle app switch / new window on this Space",
	},
	{
		mods = "meh",
		key = "a",
		fn = function()
			app_switcher.open("Arc")
		end,
		section = "APPS",
		desc = "Arc",
	},
	{
		mods = "meh",
		key = "b",
		fn = function()
			app_switcher.open("Beeper Desktop")
		end,
		section = "APPS",
		desc = "Beeper",
	},
	{
		mods = "meh",
		key = "c",
		fn = function()
			app_switcher.open("ChatGPT")
		end,
		section = "APPS",
		desc = "ChatGPT",
	},
	{
		mods = "meh",
		key = "s",
		fn = function()
			app_switcher.open("Spotify")
		end,
		section = "APPS",
		desc = "Spotify",
	},
	{
		mods = "meh",
		key = "d",
		fn = function()
			app_switcher.open("Obsidian")
		end,
		section = "APPS",
		desc = "Obsidian",
	},
	{
		mods = "meh",
		key = "f",
		fn = function()
			app_switcher.open("iTerm")
		end,
		section = "APPS",
		desc = "iTerm",
	},
	{
		mods = "meh",
		key = "g",
		fn = function()
			app_switcher.open("Visual Studio Code")
		end,
		section = "APPS",
		desc = "Visual Studio Code",
	},
	{
		mods = "meh",
		key = "h",
		fn = function()
			app_switcher.open("Parallels Desktop")
		end,
		section = "APPS",
		desc = "Parallels Desktop",
	},
	{
		mods = "meh",
		key = "j",
		fn = function()
			app_switcher.open("Warp")
		end,
		section = "APPS",
		desc = "Warp",
	},
	{
		mods = "meh",
		key = "k",
		fn = function()
			app_switcher.open("Keymapp")
		end,
		section = "APPS",
		desc = "Keymapp",
	},
	{
		mods = "meh",
		key = "l",
		fn = function()
			app_switcher.open("Finder")
		end,
		section = "APPS",
		desc = "Finder",
	},
	{
		mods = "meh",
		key = "y",
		fn = function()
			app_switcher.open("Autodesk Fusion")
		end,
		section = "APPS",
		desc = "Autodesk Fusion",
	},
	{
		mods = "meh",
		key = "u",
		fn = function()
			app_switcher.open("BambuStudio")
		end,
		section = "APPS",
		desc = "BambuStudio",
	},
	{
		mods = "meh",
		key = "i",
		fn = function()
			app_switcher.open("Arduino IDE")
		end,
		section = "APPS",
		desc = "Arduino IDE",
	},
	{
		mods = "meh",
		key = ".",
		fn = function()
			app_switcher.open("Ableton Live 12 Suite")
		end,
		section = "APPS",
		desc = "Ableton Live 12 Suite",
	},
	{
		mods = "meh",
		key = "/",
		fn = function()
			app_switcher.open("XO")
		end,
		section = "APPS",
		desc = "XO",
	},

	-- Quick-access workspace (dedicated yabai Space).
	{
		mods = "hyper",
		key = "s",
		fn = function()
			local current = yabai_utils.json("query --spaces --space")
			if current then
				if current.label == QUICK_ACCESS then
					yabai_utils.ok("space --focus recent")
				else
					local target = quickSpace()
					if target then
						yabai_utils.ok("space --focus " .. target.index)
					end
				end
			end
		end,
		section = "DISPLAYS & SPACES",
		desc = "Open/return from quick workspace",
	},
	{
		mods = "hyper + shift",
		key = "s",
		fn = function()
			local win = yabai_utils.json("query --windows --window")
			if win then
				local target = quickSpace()
				if target and not yabai_utils.windowCmd(win.id, "--space " .. target.index) then
					hs.alert.show("Could not send window to quick workspace")
				end
			end
		end,
		section = "DISPLAYS & SPACES",
		desc = "Send window to quick workspace",
	},

	-- Managed, inset scratchpad Space associated with each regular Space.
	{
		mods = "hyper",
		key = "i",
		fn = space_stash.stashFocused,
		section = "WINDOWS",
		desc = "Send/return window to/from scratchpad",
	},
	{
		mods = "hyper + shift",
		key = "i",
		fn = space_stash.toggle,
		section = "WINDOWS",
		desc = "Open/leave this Space's scratchpad",
	},

	-- Window focus (vim-style hjkl)
	{
		mods = "hyper",
		key = "h",
		cmd = "window --focus west",
		section = "WINDOWS",
		desc = "Focus west",
	},
	{
		mods = "hyper",
		key = "j",
		cmd = "window --focus south",
		section = "WINDOWS",
		desc = "Focus south",
	},
	{
		mods = "hyper",
		key = "k",
		cmd = "window --focus north",
		section = "WINDOWS",
		desc = "Focus north",
	},
	{
		mods = "hyper",
		key = "l",
		cmd = "window --focus east",
		section = "WINDOWS",
		desc = "Focus east",
	},

	-- Window warp
	{
		mods = "hyper + shift",
		key = "h",
		cmd = "window --warp west",
		section = "WINDOWS",
		desc = "Warp window west",
	},
	{
		mods = "hyper + shift",
		key = "j",
		cmd = "window --warp south",
		section = "WINDOWS",
		desc = "Warp window south",
	},
	{
		mods = "hyper + shift",
		key = "k",
		cmd = "window --warp north",
		section = "WINDOWS",
		desc = "Warp window north",
	},
	{
		mods = "hyper + shift",
		key = "l",
		cmd = "window --warp east",
		section = "WINDOWS",
		desc = "Warp window east",
	},

	-- Display
	{
		mods = "hyper",
		key = "b",
		fn = yabai_utils.moveWindowToNextDisplay,
		section = "DISPLAYS & SPACES",
		desc = "Move window to next display",
	},
	{
		mods = "hyper",
		key = "v",
		fn = yabai_utils.focusNextDisplay,
		section = "DISPLAYS & SPACES",
		desc = "Focus next display",
	},

	-- Toggles
	{
		mods = "hyper + shift",
		key = "b",
		fn = toggles.menuBar,
		section = "TOGGLES",
		desc = "Toggle menu bar auto‑hide",
	},
	{
		mods = "hyper",
		key = "f",
		cmd = "window --toggle zoom-fullscreen",
		section = "WINDOWS",
		desc = "Toggle native fullscreen",
	},
	{
		mods = "hyper + shift",
		key = "f",
		fn = toggles.spaceFloat,
		section = "TOGGLES",
		desc = "Toggle space float layout",
	},
	{
		mods = "hyper",
		key = "m",
		fn = toggles.mouseFollowsFocus,
		section = "TOGGLES",
		desc = "Toggle mouse follows focus",
	},

	-- Modes
	{
		mods = "hyper",
		key = "r",
		fn = yabai_utils.toggleResizeMode,
		section = "WINDOWS",
		desc = "Enter resize mode",
	},
	{
		mods = "hyper",
		key = "p",
		fn = pip.toggle,
		section = "TOGGLES",
		desc = "Toggle PiP floating window",
	},

	-- Media
	{
		mods = "hyper",
		key = "[",
		fn = media.seekBackward,
		section = "MEDIA",
		desc = "Seek backward 10 s",
	},
	{
		mods = "hyper",
		key = "]",
		fn = media.seekForward,
		section = "MEDIA",
		desc = "Seek forward 10 s",
	},
	{
		mods = "hyper",
		key = "n",
		fn = spotify.open,
		section = "MEDIA",
		desc = "Spotify now playing view",
	},

	-- System
	{
		mods = "hyper + shift",
		key = "c",
		fn = toggles.powerLock,
		section = "TOGGLES",
		desc = "Toggle Power Lock",
	},
	{
		mods = "hyper",
		key = "/",
		fn = cheatsheet.show,
		section = "SYSTEM",
		desc = "Show this cheatsheet",
	},
	{
		mods = "hyper + shift",
		key = "r",
		fn = function()
			hs.execute("/bin/launchctl kickstart -k gui/$(/usr/bin/id -u)/org.nixos.yabai")
		end,
		section = "SYSTEM",
		desc = "Restart Yabai",
	},

	-- Space navigation: left and right
	{
		mods = "hyper",
		key = "left",
		cmd = "space --focus prev",
		section = "DISPLAYS & SPACES",
		desc = "Go to left space",
	},
	{
		mods = "hyper",
		key = "right",
		cmd = "space --focus next",
		section = "DISPLAYS & SPACES",
		desc = "Go to right space",
	},

	-- Sticky Hyper mode
	{
		mods = "hyper",
		key = "tab",
		stickyToggle = true,
		section = "SYSTEM",
		desc = "Toggle sticky Hyper mode",
	},

	-- Resize mode (modal)
	{
		mods = {},
		key = "h",
		modal = yabai_utils.resizeMode,
		cmd = { "window --resize left:-60:0", { raw = "||" }, "window --resize right:-60:0" },
		rpt = true,
		section = "RESIZE MODE",
		desc = "Shrink from left",
	},
	{
		mods = {},
		key = "j",
		modal = yabai_utils.resizeMode,
		cmd = { "window --resize bottom:0:60", { raw = "||" }, "window --resize top:0:60" },
		rpt = true,
		section = "RESIZE MODE",
		desc = "Shrink from bottom",
	},
	{
		mods = {},
		key = "k",
		modal = yabai_utils.resizeMode,
		cmd = { "window --resize top:0:-60", { raw = "||" }, "window --resize bottom:0:-60" },
		rpt = true,
		section = "RESIZE MODE",
		desc = "Shrink from top",
	},
	{
		mods = {},
		key = "l",
		modal = yabai_utils.resizeMode,
		cmd = { "window --resize right:60:0", { raw = "||" }, "window --resize left:60:0" },
		rpt = true,
		section = "RESIZE MODE",
		desc = "Shrink from right",
	},
	{
		mods = { "shift" },
		key = "h",
		modal = yabai_utils.resizeMode,
		cmd = { "window --resize left:60:0", { raw = "||" }, "window --resize right:-60:0" },
		rpt = true,
		section = "RESIZE MODE",
		desc = "Grow from left",
	},
	{
		mods = { "shift" },
		key = "j",
		modal = yabai_utils.resizeMode,
		cmd = { "window --resize bottom:0:-60", { raw = "||" }, "window --resize top:0:-60" },
		rpt = true,
		section = "RESIZE MODE",
		desc = "Grow from bottom",
	},
	{
		mods = { "shift" },
		key = "k",
		modal = yabai_utils.resizeMode,
		cmd = { "window --resize top:0:60", { raw = "||" }, "window --resize bottom:0:60" },
		rpt = true,
		section = "RESIZE MODE",
		desc = "Grow from top",
	},
	{
		mods = { "shift" },
		key = "l",
		modal = yabai_utils.resizeMode,
		cmd = { "window --resize right:-60:0", { raw = "||" }, "window --resize left:-60:0" },
		rpt = true,
		section = "RESIZE MODE",
		desc = "Grow from right",
	},
	{
		mods = {},
		key = "b",
		modal = yabai_utils.resizeMode,
		cmd = "space --balance",
		section = "RESIZE MODE",
		desc = "Balance space",
	},
	{
		mods = {},
		key = "escape",
		modal = yabai_utils.resizeMode,
		fn = function()
			yabai_utils.resizeMode:exit()
		end,
		section = "RESIZE MODE",
		desc = "Exit resize mode",
	},
	{
		mods = {},
		key = "return",
		modal = yabai_utils.resizeMode,
		fn = function()
			yabai_utils.resizeMode:exit()
		end,
		section = "RESIZE MODE",
		desc = "Exit resize mode",
	},
}

bindings[#bindings + 1] = {
	mods = "hyper",
	key = "0",
	fn = function()
		local display = yabai_utils.json("query --displays --display")
		if display and #display.spaces > 0 then
			yabai_utils.ok("space --focus " .. display.spaces[#display.spaces])
		end
	end,
	section = "DISPLAYS & SPACES",
	desc = "Focus last space on current display",
}

-- Space navigation: focus 1-9 and move window to space 1-9.
for i = 1, 9 do
	local key = tostring(i)

	bindings[#bindings + 1] = {
		mods = "hyper",
		key = key,
		cmd = "space --focus " .. i,
		section = "DISPLAYS & SPACES",
		desc = "Focus space " .. i,
	}
	bindings[#bindings + 1] = {
		mods = "hyper + shift",
		key = key,
		cmd = {
			"window --space " .. i,
			"window --focus first",
		},
		section = "DISPLAYS & SPACES",
		desc = "Move window to space " .. i,
	}
end

-- Feed bindings to the cheatsheet overlay so it stays in sync.
cheatsheet.setBindings(bindings)

return bindings

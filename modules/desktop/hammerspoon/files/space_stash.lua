local hs = _G.hs
local ui = require("ui")

-- A managed, inset BSP workspace for each ordinary Space.
-- Windows stay in yabai's normal tiling tree, so existing bindings still work.
local y = require("yabai_utils")
local M = {}

local PREFIX = "hs-stash-"
local SPACE_KEY = "hs-managed-stash-spaces"

-- Appearance: fractions of the screen reserved as margins around the layout.
local SIDE_INSET = 0.14
local VERTICAL_INSET = 0.13
local WINDOW_GAP = 18

local known = hs.settings.get(SPACE_KEY) or {}

local function spaces()
	return y.json("query --spaces") or {}
end

local function byUuid(uuid, all)
	for _, space in ipairs(all) do
		if space.uuid == uuid then
			return space
		end
	end
end

local function byIndex(index, all)
	for _, space in ipairs(all) do
		if space.index == index then
			return space
		end
	end
end

local function originFor(space, all)
	local uuid = space.label:match("^" .. PREFIX .. "(.+)$")
	if not uuid then
		for label, savedUuid in pairs(known) do
			if savedUuid == space.uuid then
				uuid = label:sub(#PREFIX + 1)
				break
			end
		end
	end
	return uuid and byUuid(uuid, all), uuid ~= nil
end

local function style(space, displayIndex)
	local display = y.json("query --displays --display " .. displayIndex)
	if not display then
		return
	end
	local h = math.floor(display.frame.w * SIDE_INSET)
	local v = math.floor(display.frame.h * VERTICAL_INSET)
	y.ok("space " .. space.index .. " --layout bsp")
	y.ok("space " .. space.index .. " --padding abs:" .. v .. ":" .. v .. ":" .. h .. ":" .. h)
	y.ok("space " .. space.index .. " --gap abs:" .. WINDOW_GAP)
end

local function findStash(origin, all)
	local label = PREFIX .. origin.uuid
	for _, space in ipairs(all) do
		if space.label == label then
			known[label] = space.uuid
			hs.settings.set(SPACE_KEY, known)
			return space
		end
	end
	local saved = byUuid(known[label], all)
	if saved and y.ok("space " .. saved.index .. " --label " .. label) then
		style(saved, origin.display)
		return saved
	end
end

local function ensureStash(origin)
	local before = spaces()
	local existing = findStash(origin, before)
	if existing then
		return existing
	end

	if not y.ok("space --create " .. origin.display) then
		ui.error("Cannot create scratchpad Space (load yabai scripting addition)")
		return
	end

	local seen = {}
	for _, space in ipairs(before) do
		seen[space.uuid] = true
	end
	for _, space in ipairs(spaces()) do
		if not seen[space.uuid] then
			local label = PREFIX .. origin.uuid
			if y.ok("space " .. space.index .. " --label " .. label) then
				known[label] = space.uuid
				hs.settings.set(SPACE_KEY, known)
				style(space, origin.display)
				return space
			end
			ui.error("Could not label scratchpad Space")
			return
		end
	end
	ui.error("Could not find created scratchpad Space")
end

function M.toggle()
	local active = y.json("query --spaces --space")
	if not active then
		return
	end
	local all = spaces()
	local origin, inStash = originFor(active, all)
	if inStash and not origin then
		ui.error("Original Space no longer exists")
		return
	end
	local target = origin or ensureStash(active)
	if target then
		y.ok("space --focus " .. target.index)
	end
end

function M.stashFocused()
	local win = y.json("query --windows --window")
	if not win or win["is-native-fullscreen"] or not win["can-move"] or win.subrole ~= "AXStandardWindow" then
		ui.error("This window cannot be stashed")
		return
	end
	if win["is-floating"] then
		ui.error("Only tiled windows support the full yabai keyboard workflow")
		return
	end

	local all = spaces()
	local active = byIndex(win.space, all)
	if not active then
		return
	end
	local original, inStash = originFor(active, all)
	if inStash and not original then
		ui.error("Original Space no longer exists")
		return
	end
	local target = original or ensureStash(active)
	if target and not y.windowCmd(win.id, "--space " .. target.index) then
		ui.error("Could not move window into or out of scratchpad")
	end
end

function M.start()
	local all = spaces()
	for label, uuid in pairs(known) do
		local stash = byUuid(uuid, all)
		if stash then
			if stash.label ~= label then
				y.ok("space " .. stash.index .. " --label " .. label)
			end
			local origin = byUuid(label:sub(#PREFIX + 1), all)
			if origin then
				style(stash, origin.display)
			end
		end
	end
end

return M

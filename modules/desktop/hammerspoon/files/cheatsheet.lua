local hs = _G.hs

-- Canvas-based hotkey cheatsheet — dark overlay matching window_switcher's aesthetic.
-- Reads bindings dynamically from keybinds.lua via setBindings().
-- Dismisses on any keypress.

local M = {}
local theme = require("theme")
local modifiers = require("modifiers")

-- helpers

local function rect(frame, fillColor, radius)
	return {
		type = "rectangle",
		action = "fill",
		frame = frame,
		roundedRectRadii = { xRadius = radius, yRadius = radius },
		fillColor = fillColor,
	}
end

local function label(frame, value, size, color, alignment, font)
	return {
		type = "text",
		action = "fill",
		frame = frame,
		text = value,
		textFont = font or theme.fonts.sansSerif,
		textSize = size,
		textColor = color,
		textAlignment = alignment or "left",
		textLineBreak = "truncateTail",
	}
end

-- visual constants

local L = {
	padding = 22,
	colGap = 28,
	colW = 340,
	headerH = 36,
	rowH = 27,
	sectionGap = 8,
	cornerRadius = 16,
	keyW = 105,
	descW = 215,
	descOffset = 105 + 20, -- description x offset (keyW + gap)
	sizes = {
		section = 14,
		key = 15,
		desc = 15,
		footer = 13,
	},
}

-- mod → symbol mapping

local MOD_SYMBOLS = {
	cmd = "⌘",
	command = "⌘",
	ctrl = "⌃",
	control = "⌃",
	alt = "⌥",
	option = "⌥",
	shift = "⇧",
}

local KEY_SYMBOLS = {
	left = "←",
	right = "→",
	up = "↑",
	down = "↓",
}

local function modsToSymbol(mods)
	if type(mods) == "string" then
		local symbol = modifiers.symbol(mods)
		if symbol then
			return symbol
		end
		-- Unrecognized string: pass through.
		return mods
	end

	if type(mods) ~= "table" then
		return tostring(mods)
	end

	-- Auto-detect hyper (ctrl+alt+cmd) and shifted-hyper in raw lists.
	local modsSet = {}
	for _, m in ipairs(mods) do
		modsSet[m:lower()] = true
	end

	if modsSet.ctrl and modsSet.alt and modsSet.cmd then
		return modsSet.shift and modifiers.symbols.hyper .. modifiers.symbols.shift or modifiers.symbols.hyper
	end

	-- Fallback: render canonical order.
	local parts = {}
	for _, m in ipairs(mods) do
		local sym = MOD_SYMBOLS[m:lower()]
		if sym then
			table.insert(parts, sym)
		end
	end
	table.sort(parts, function(a, b)
		local order = { ["⌃"] = 1, ["⌥"] = 2, ["⇧"] = 3, ["⌘"] = 4 }
		return (order[a] or 99) < (order[b] or 99)
	end)

	return table.concat(parts)
end

local function formatKey(mods, key)
	local sym = modsToSymbol(mods)
	local keyStr = KEY_SYMBOLS[key] or key:upper()
	if sym == "" then
		return keyStr
	end
	return sym .. " " .. keyStr
end

-- bindings → sections

local sections = {} -- { { title, items = { { mods, key, desc, range? } } } }

function M.setBindings(bindings)
	if not bindings then
		return
	end

	local map = {}
	local order = {}

	for _, b in ipairs(bindings) do
		local title = b.section or "OTHER"
		if not map[title] then
			map[title] = { title = title, items = {} }
			table.insert(order, title)
		end
		table.insert(map[title].items, {
			mods = b.mods,
			key = b.key,
			desc = b.desc or b.cmd or "",
		})
	end

	-- Collapse interleaved "<prefix> 1" .. "<prefix> 9" runs into "<prefix> 1–9".
	for _, title in ipairs(order) do
		local items = map[title].items
		local collapsed = {}
		local i = 1

		while i <= #items do
			local item = items[i]
			local prefix, startN = item.desc:match("^(%D+) (%d+)$")
			startN = startN and tonumber(startN)

			if prefix and startN == 1 and i + 1 <= #items then
				local endN = startN
				local j = i + 1
				while j <= #items do
					local p, n = items[j].desc:match("^(%D+) (%d+)$")
					n = n and tonumber(n)
					if p == prefix and n == endN + 1 then
						endN = n
						j = j + 1
					else
						break
					end
				end

				if endN > startN then
					table.insert(collapsed, {
						mods = item.mods,
						desc = prefix .. " 1–" .. endN,
						range = true,
					})
					i = j
				else
					table.insert(collapsed, item)
					i = i + 1
				end
			else
				table.insert(collapsed, item)
				i = i + 1
			end
		end

		map[title].items = collapsed
	end

	sections = {}
	for _, title in ipairs(order) do
		table.insert(sections, map[title])
	end
end

-- rendering

local canvas = nil
local dismissTap = nil
local dismissTimer = nil

local function cleanup()
	if dismissTap then
		dismissTap:stop()
		dismissTap = nil
	end
	if dismissTimer then
		dismissTimer:stop()
		dismissTimer = nil
	end
end

local function dismiss()
	cleanup()
	if canvas then
		canvas:hide(0.12)
		canvas = nil
	end
end

local function buildRow(elements, originX, y, item, palette)
	-- Always re-render the key from mods + key, so changes to mod prefixes
	-- propagate even if item.key carried a stale value.
	item.key = item.key or ""
	local keyLabel
	if item.range then
		local sym = modsToSymbol(item.mods)
		keyLabel = (sym == "" and "1–9") or (sym .. " 1–9")
	else
		keyLabel = formatKey(item.mods, item.key)
	end

	table.insert(
		elements,
		label(
			{ x = originX, y = y, w = L.keyW, h = L.rowH },
			keyLabel,
			L.sizes.key,
			palette.key,
			"right",
			theme.fonts.monospace
		)
	)
	table.insert(
		elements,
		label({ x = originX + L.descOffset, y = y, w = L.descW, h = L.rowH }, item.desc, L.sizes.desc, palette.desc)
	)
end

local function buildSection(elements, x, y, section, palette)
	table.insert(
		elements,
		label({ x = x, y = y, w = L.colW, h = L.headerH }, section.title, L.sizes.section, palette.section)
	)
	y = y + L.headerH

	table.insert(elements, rect({ x = x, y = y - 2, w = L.colW, h = 1 }, palette.separator, 0))

	for _, item in ipairs(section.items) do
		buildRow(elements, x, y, item, palette)
		y = y + L.rowH
	end

	return y
end

local function buildElements(colors, columnCount)
	local elements = {}
	local columns = {}
	local colHeights = {}

	for i = 1, columnCount do
		columns[i] = {}
		colHeights[i] = 0
	end

	for _, s in ipairs(sections) do
		local sectionH = L.headerH + (#s.items * L.rowH) + L.sectionGap
		local shortest = 1
		for i = 2, columnCount do
			if colHeights[i] < colHeights[shortest] then
				shortest = i
			end
		end
		table.insert(columns[shortest], s)
		colHeights[shortest] = colHeights[shortest] + sectionH
	end

	local contentH = math.max(table.unpack(colHeights))
	local width = (L.padding * 2) + (L.colW * columnCount) + (L.colGap * (columnCount - 1))
	local height = L.padding + contentH + L.padding + 18

	-- Cycle through theme accent colours so each section header pops.
	-- Falls through to fgDim if the theme has fewer accents than sections.
	local ACCENT_KEYS = { "accent", "green", "yellow", "blue", "magenta", "cyan" }
	local function sectionColor(index)
		return colors[ACCENT_KEYS[((index - 1) % #ACCENT_KEYS) + 1]] or colors.fgDim
	end

	local basePalette = {
		bg = colors.bgAlphaStrong,
		separator = colors.separator,
		section = colors.fgDim, -- overridden per section
		key = colors.fg,
		desc = colors.fgDim,
		footer = colors.footerMuted,
	}

	table.insert(elements, rect({ x = 0, y = 0, w = width, h = height }, basePalette.bg, L.cornerRadius))

	local sectionIndex = 0
	for col = 1, columnCount do
		local x = L.padding + ((col - 1) * (L.colW + L.colGap))
		local y = L.padding

		for i, s in ipairs(columns[col]) do
			sectionIndex = sectionIndex + 1
			basePalette.section = sectionColor(sectionIndex)
			y = buildSection(elements, x, y, s, basePalette)
			if i < #columns[col] then
				y = y + L.sectionGap
			end
		end
	end

	local footerY = height - L.padding - 4
	table.insert(
		elements,
		label(
			{ x = 0, y = footerY, w = width, h = L.rowH },
			"press any key to dismiss",
			L.sizes.footer,
			basePalette.footer,
			"center"
		)
	)

	return elements, width, height
end

local function render()
	if #sections == 0 then
		hs.alert.show("Cheatsheet: no bindings registered")
		return
	end

	local colors = theme.colors()
	local screenFrame = hs.screen.mainScreen():frame()
	local maxH = math.floor(screenFrame.h - 32)
	local maxW = math.floor(screenFrame.w - 32)

	local elements, width, height = buildElements(colors, 2)
	local threeColW = (L.padding * 2) + (L.colW * 3) + (L.colGap * 2)
	if height > maxH and threeColW <= maxW then
		elements, width, height = buildElements(colors, 3)
	end

	local frame = {
		x = screenFrame.x + math.floor((screenFrame.w - width) / 2),
		y = screenFrame.y + math.floor((screenFrame.h - height) / 2),
		w = width,
		h = height,
	}

	canvas = hs.canvas
		.new(frame)
		:level("modalPanel")
		:behavior({ "canJoinAllSpaces", "stationary" })
		:replaceElements(table.unpack(elements))
		:show(0.12)

	dismissTap = hs.eventtap
		.new({ hs.eventtap.event.types.keyDown }, function()
			dismiss()
			return false
		end)
		:start()

	-- timeout cheatsheet after a time period
	--   dismissTimer = hs.timer.doAfter(8, function()
	--     dismiss()
	--   end)
end

-- public api

function M.show()
	if canvas then
		dismiss()
	end
	render()
end

return M

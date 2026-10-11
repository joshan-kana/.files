-- Free AltTab-style canvas switcher.
-- App icon on the left, window title on the right.
-- Current Space only for yabai-friendly switching.

local M = {}
local imap = hs.fnutils.imap
local theme = require("theme")

local ui = {
	width = 680,
	maxRows = 9,
	padding = 14,
	rowHeight = 58,
	rowGap = 7,
	iconSize = 36,
	cornerRadius = 18,
	rowRadius = 13,
	font = "Helvetica Neue",
	titleSize = 15,
	appSize = 12,
	-- colours are resolved from theme.lua at render-time via getColors()
}

local windowFilter = hs.window.filter.new():setCurrentSpace(true):setDefaultFilter({})

local canvas = nil
local choices = {}
local selectedIndex = 1
local active = false
local releaseWatcher = nil

local function appIcon(app)
	if not app then
		return nil
	end

	local bundleID = app:bundleID()
	local path = app:path()

	return (bundleID and hs.image.imageFromAppBundle(bundleID)) or (path and hs.image.iconForFile(path))
end

local function rect(frame, fillColor, radius, strokeColor)
	return {
		type = "rectangle",
		action = strokeColor and "strokeAndFill" or "fill",
		frame = frame,
		roundedRectRadii = { xRadius = radius, yRadius = radius },
		fillColor = fillColor,
		strokeColor = strokeColor,
		strokeWidth = strokeColor and 1 or nil,
	}
end

local function text(frame, value, size, color, alignment)
	return {
		type = "text",
		action = "fill",
		frame = frame,
		text = value,
		textFont = ui.font,
		textSize = size,
		textColor = color,
		textLineBreak = "truncateTail",
		textAlignment = alignment or "left",
	}
end

local function image(frame, value)
	return {
		type = "image",
		action = "fill",
		frame = frame,
		image = value,
		imageScaling = "scaleProportionally",
	}
end

local function focusChoice(choice)
	local win = choice and choice.id and hs.window.get(choice.id)
	if not win then
		return
	end

	win:unminimize()
	win:focus()
end

local function close(commit)
	if not active then
		return
	end

	local choice = choices[selectedIndex]

	active = false

	if canvas then
		canvas:hide(0)
	end

	if commit then
		focusChoice(choice)
	end
end

local function ensureReleaseWatcher()
	if releaseWatcher then
		releaseWatcher:start()
		return
	end

	releaseWatcher = hs.eventtap
		.new({
			hs.eventtap.event.types.flagsChanged,
		}, function(event)
			if active and not event:getFlags().alt then
				local ok, err = xpcall(function()
					close(true)
				end, debug.traceback)

				if not ok then
					active = false
					if canvas then
						canvas:hide(0)
					end
					print("Canvas switcher release error:")
					print(err)
				end
			end

			return false
		end)
		:start()
end

local function buildChoices()
	return imap(windowFilter:getWindows(hs.window.sortByFocusedLast), function(win)
		if not win:isStandard() or not win:id() then
			return nil
		end

		local app = win:application()
		local appName = app and app:name() or "Unknown app"
		local title = win:title()

		return {
			id = win:id(),
			title = title ~= "" and title or appName,
			appName = appName,
			icon = appIcon(app),
		}
	end)
end

local function targetScreen()
	local win = hs.window.focusedWindow()
	return win and win:screen() or hs.screen.mainScreen()
end

local function initialSelection(direction)
	local focused = hs.window.focusedWindow()
	local focusedID = focused and focused:id()

	if focusedID then
		for index, choice in ipairs(choices) do
			if choice.id == focusedID then
				local nextIndex = index + direction
				if nextIndex < 1 then
					return #choices
				elseif nextIndex > #choices then
					return 1
				end
				return nextIndex
			end
		end
	end

	return direction < 0 and #choices or 1
end

local function switcherFrame(rowCount)
	local screenFrame = targetScreen():frame()
	local width = math.min(ui.width, screenFrame.w - 80)
	local height = ui.padding * 2 + rowCount * ui.rowHeight + math.max(rowCount - 1, 0) * ui.rowGap

	return {
		x = screenFrame.x + (screenFrame.w - width) / 2,
		y = screenFrame.y + (screenFrame.h - height) / 2,
		w = width,
		h = height,
	}
end

local function getColors()
	return theme.colors()
end

local function render()
	local rows = math.min(#choices, ui.maxRows)
	if rows == 0 then
		return
	end

	local colors = getColors()

	local startIndex = math.min(math.max(1, selectedIndex - rows + 1), #choices - rows + 1)

	local frame = switcherFrame(rows)
	local elements = {
		rect({ x = 0, y = 0, w = frame.w, h = frame.h }, colors.bgAlpha, ui.cornerRadius),
	}

	for row = 1, rows do
		local choiceIndex = startIndex + row - 1
		local choice = choices[choiceIndex]
		local selected = choiceIndex == selectedIndex

		local y = ui.padding + (row - 1) * (ui.rowHeight + ui.rowGap)
		local iconX = ui.padding + 14
		local iconY = y + (ui.rowHeight - ui.iconSize) / 2
		local textX = iconX + ui.iconSize + 14
		local textWidth = frame.w - textX - ui.padding - 18

		table.insert(
			elements,
			rect(
				{ x = ui.padding, y = y, w = frame.w - ui.padding * 2, h = ui.rowHeight },
				selected and colors.bgSelectedAlpha or colors.bgAltAlpha,
				ui.rowRadius,
				colors.strokeFaint
			)
		)

		if choice.icon then
			table.insert(elements, image({ x = iconX, y = iconY, w = ui.iconSize, h = ui.iconSize }, choice.icon))
		end

		table.insert(
			elements,
			text({ x = textX, y = y + 9, w = textWidth, h = 22 }, choice.title, ui.titleSize, colors.fg)
		)

		table.insert(
			elements,
			text({ x = textX, y = y + 31, w = textWidth, h = 18 }, choice.appName, ui.appSize, colors.fgDim)
		)
	end

	if #choices > rows then
		table.insert(
			elements,
			text(
				{ x = frame.w - 86, y = frame.h - 26, w = 64, h = 16 },
				tostring(selectedIndex) .. "/" .. tostring(#choices),
				11,
				colors.fgMuted,
				"right"
			)
		)
	end

	if not canvas then
		canvas = hs.canvas.new(frame)
		canvas:level("modalPanel")
		canvas:behavior({ "canJoinAllSpaces", "stationary" })
	else
		canvas:frame(frame)
	end

	canvas:replaceElements(table.unpack(elements)):show(0)
end

local function advance(direction)
	if not active then
		choices = buildChoices()

		if #choices == 0 then
			hs.alert.show("No windows")
			return
		end

		selectedIndex = initialSelection(direction)

		ensureReleaseWatcher()
		active = true
		render()

		-- The watcher is persistent, but this closes immediately if Option was
		-- released while the hotkey callback was still being handled.
		if not hs.eventtap.checkKeyboardModifiers().alt then
			close(true)
		end
		return
	end

	selectedIndex = selectedIndex + direction

	if selectedIndex < 1 then
		selectedIndex = #choices
	elseif selectedIndex > #choices then
		selectedIndex = 1
	end

	render()
end

local function run(direction)
	local ok, err = pcall(function()
		advance(direction)
	end)

	if ok then
		return
	end

	active = false

	if canvas then
		canvas:hide(0)
	end

	print("Canvas switcher error:")
	print(err)
	hs.alert.show("Canvas switcher error; check Hammerspoon Console")
end

function M.next()
	run(1)
end

function M.previous()
	run(-1)
end

return M

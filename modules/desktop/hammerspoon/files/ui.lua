local hs = _G.hs
local theme = require("theme")

local M = {}
local entries = {}
local maximum = 3
local width = 380
local gap = 10
local inset = 22
local iconSize = 34
local iconX = 23
local textX = 72
local textRight = 18
local titleSize = 15
local detailSize = 12
local lineGap = 4
local verticalPadding = 14
local accentHeight = 36

local styles = {
	info = { symbol = "i", color = "blue", duration = 2.5 },
	success = { symbol = "✓", color = "green", duration = 2.5 },
	warning = { symbol = "!", color = "yellow", duration = 4 },
	error = { symbol = "×", color = "accent", duration = 5.5 },
}

local function colorWithAlpha(color, alpha)
	return { red = color.red, green = color.green, blue = color.blue, alpha = alpha }
end

local function rect(frame, fill, radius, stroke)
	return {
		type = "rectangle",
		action = stroke and "strokeAndFill" or "fill",
		frame = frame,
		roundedRectRadii = { xRadius = radius, yRadius = radius },
		fillColor = fill,
		strokeColor = stroke,
		strokeWidth = stroke and 1 or nil,
	}
end

local function text(frame, value, size, color, alignment, lineBreak)
	local fonts = theme.fonts or {}
	return {
		type = "text",
		action = "fill",
		frame = frame,
		text = value,
		textFont = fonts.sansSerif or "Helvetica Neue",
		textSize = size,
		textColor = color,
		textAlignment = alignment or "left",
		textLineBreak = lineBreak or "truncateTail",
	}
end

-- Use the actual Stylix font metrics so wrapping and vertical centring do not
-- depend on the byte length of a message.
local function measure(value, font, size)
	return hs.drawing.getTextDrawingSize(hs.styledtext.new(value, {
		font = { name = font, size = size },
	}))
end

local function wrapTitle(title, maxWidth, font)
	local lines = {}

	local function addWord(word, current)
		local candidate = current == "" and word or (current .. " " .. word)
		if measure(candidate, font, titleSize).w <= maxWidth then
			return candidate
		end
		if current ~= "" then
			table.insert(lines, current)
		end
		if measure(word, font, titleSize).w <= maxWidth then
			return word
		end

		-- Extremely long paths and unbroken strings still wrap cleanly.
		local segment = ""
		for _, codepoint in utf8.codes(word) do
			local character = utf8.char(codepoint)
			if segment ~= "" and measure(segment .. character, font, titleSize).w > maxWidth then
				table.insert(lines, segment)
				segment = ""
			end
			segment = segment .. character
		end
		return segment
	end

	for paragraph in (title .. "\n"):gmatch("(.-)\n") do
		local current = ""
		for word in paragraph:gmatch("%S+") do
			current = addWord(word, current)
		end
		table.insert(lines, current)
	end

	return table.concat(lines, "\n"), #lines
end

local function textLayout(entry, canvasWidth)
	local font = (theme.fonts or {}).sansSerif or "Helvetica Neue"
	local bodyWidth = canvasWidth - textX - textRight
	local title, lines = wrapTitle(entry.title, bodyWidth, font)
	local titleHeight = measure("A", font, titleSize).h * lines
	local detailHeight = entry.detail and measure("A", font, detailSize).h or 0
	local contentHeight = titleHeight + (entry.detail and (lineGap + detailHeight) or 0)
	return {
		font = font,
		bodyWidth = bodyWidth,
		title = title,
		titleHeight = titleHeight,
		detailHeight = detailHeight,
		contentHeight = contentHeight,
		height = math.max(entry.detail and 80 or 68, contentHeight + verticalPadding * 2),
	}
end

local function activeScreen()
	local window = hs.window.focusedWindow()
	return (window and window:screen()) or hs.screen.mainScreen()
end

local function position(entry, index)
	local frame = entry.screen:frame()
	local w = math.min(width, frame.w - inset * 2)
	return {
		x = frame.x + (frame.w - w) / 2,
		y = frame.y + inset + (index - 1) * (entry.height + gap),
		w = w,
		h = entry.height,
	}
end

local function rearrange()
	local offsets = {}
	for _, entry in ipairs(entries) do
		local id = entry.screen:id()
		offsets[id] = offsets[id] or 0
		local frame = position(entry, 1)
		frame.y = frame.y + offsets[id]
		entry.canvas:frame(frame)
		offsets[id] = offsets[id] + entry.height + gap
	end
end

local function remove(entry)
	if entry.timer then
		entry.timer:stop()
		entry.timer = nil
	end
	for i, current in ipairs(entries) do
		if current == entry then
			table.remove(entries, i)
			break
		end
	end
	entry.canvas:delete(0.12)
	rearrange()
end

local function render(entry)
	local colors = theme.colors()
	local style = styles[entry.kind] or styles.info
	local accent = colors[style.color] or colors.fg
	local w, h = entry.canvas:frame().w, entry.height
	local layout = textLayout(entry, w)
	local iconY = (h - iconSize) / 2
	local symbolHeight = measure(style.symbol, layout.font, 18).h
	local contentY = (h - layout.contentHeight) / 2
	local elements = {
		rect({ x = 0.5, y = 0.5, w = w - 1, h = h - 1 }, colors.bgAlphaStrong, 16, colorWithAlpha(colors.stroke, 0.42)),
		-- Keep the accent entirely within the panel instead of crossing its curved edge.
		rect({ x = 9, y = (h - accentHeight) / 2, w = 4, h = accentHeight }, accent, 2),
		rect({ x = iconX, y = iconY, w = iconSize, h = iconSize }, colorWithAlpha(accent, 0.16), 10),
		text(
			{ x = iconX, y = (h - symbolHeight) / 2, w = iconSize, h = symbolHeight },
			style.symbol,
			18,
			accent,
			"center"
		),
		text(
			{ x = textX, y = contentY, w = layout.bodyWidth, h = layout.titleHeight },
			layout.title,
			titleSize,
			colors.fg
		),
	}
	if entry.detail then
		table.insert(
			elements,
			text({
				x = textX,
				y = contentY + layout.titleHeight + lineGap,
				w = layout.bodyWidth,
				h = layout.detailHeight,
			}, entry.detail, detailSize, colors.fgDim)
		)
	end
	entry.canvas:replaceElements(table.unpack(elements))
end

-- Repeated state changes update one notification instead of creating a stack.
function M.show(message, options)
	options = options or {}
	local title = tostring(message)
	local kind = styles[options.kind] and options.kind or "info"
	local detail = options.detail
	local screen = options.screen or activeScreen()
	local key = (options.key or title) .. ":" .. tostring(screen:id())

	local entry
	for _, existing in ipairs(entries) do
		if existing.key == key then
			entry = existing
			break
		end
	end

	if entry then
		entry.title = title
		entry.kind = kind
		entry.detail = detail
		entry.screen = screen
		entry.height = textLayout(entry, math.min(width, screen:frame().w - inset * 2)).height
		entry.canvas:frame(position(entry, 1))
	else
		if #entries >= maximum then
			remove(entries[1])
		end
		entry = {
			key = key,
			title = title,
			kind = kind,
			detail = detail,
			screen = screen,
		}
		entry.height = textLayout(entry, math.min(width, screen:frame().w - inset * 2)).height
		entry.canvas = hs.canvas.new(position(entry, 1))
		entry.canvas:level("status")
		entry.canvas:behavior({ "canJoinAllSpaces", "stationary" })
		table.insert(entries, entry)
	end

	render(entry)
	rearrange()
	entry.canvas:show(entry.shown and 0 or 0.12)
	entry.shown = true
	if entry.timer then
		entry.timer:stop()
	end
	entry.timer = hs.timer.doAfter(options.duration or (styles[kind] or styles.info).duration, function()
		remove(entry)
	end)
end

function M.toast(message)
	M.show(message)
end

function M.error(message)
	M.show(message, { kind = "error" })
end

function M.mode(label, enabled, detail)
	M.show(label, {
		kind = enabled and "success" or "info",
		detail = detail or (enabled and "Enabled" or "Disabled"),
		key = "mode:" .. label,
	})
end

return M

local hs = _G.hs
local theme = require("theme")

local M = {}
local entries = {}
local maximum = 3
local width = 380
local gap = 10
local inset = 22

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

local function toastHeight(title, detail)
	if detail then
		return 80
	end
	if #title > 70 then
		return 100
	end
	return #title > 34 and 82 or 66
end

local function activeScreen()
	local window = hs.window.focusedWindow()
	return (window and window:screen()) or hs.screen.mainScreen()
end

local function position(entry, index)
	local frame = entry.screen:frame()
	local w = math.min(width, frame.w - inset * 2)
	return {
		x = frame.x + frame.w - w - inset,
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
	local bodyWidth = w - 92
	local elements = {
		rect({ x = 0.5, y = 0.5, w = w - 1, h = h - 1 }, colors.bgAlphaStrong, 16, colorWithAlpha(colors.stroke, 0.42)),
		rect({ x = 0, y = 13, w = 3, h = h - 26 }, accent, 1.5),
		rect({ x = 17, y = (h - 32) / 2, w = 32, h = 32 }, colorWithAlpha(accent, 0.16), 10),
		text({ x = 17, y = (h - 32) / 2 + 5, w = 32, h = 24 }, style.symbol, 18, accent, "center"),
	}

	local multiline = not entry.detail and entry.height > 66
	local titleY = (entry.detail or multiline) and 16 or (h - 26) / 2
	local titleHeight = multiline and h - 28 or 25
	table.insert(
		elements,
		text(
			{ x = 64, y = titleY, w = bodyWidth, h = titleHeight },
			entry.title,
			15,
			colors.fg,
			nil,
			multiline and "wordWrap" or nil
		)
	)
	if entry.detail then
		table.insert(elements, text({ x = 64, y = 44, w = bodyWidth, h = 20 }, entry.detail, 12, colors.fgDim))
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
		entry.height = toastHeight(title, detail)
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
			height = toastHeight(title, detail),
		}
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

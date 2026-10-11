-- Shared yabai command wrappers used by init.lua and feature modules.

local YABAI = "/opt/homebrew/bin/yabai -m "
local M = {}

--- Run a yabai command, discarding output.
function M.exec(cmd)
	if type(cmd) == "table" then
		local parts = {}

		for i, part in ipairs(cmd) do
			if type(part) == "table" and part.raw then
				parts[#parts + 1] = part.raw
			else
				local previous = cmd[i - 1]
				if i > 1 and not (type(previous) == "table" and previous.raw) then
					parts[#parts + 1] = ";"
				end
				parts[#parts + 1] = YABAI .. part
			end
		end

		return hs.execute(table.concat(parts, " "))
	end

	return hs.execute(YABAI .. cmd)
end

--- Run a yabai command, returning whether it succeeded.
function M.ok(cmd)
	local _, ok = M.exec(cmd)
	return ok
end

--- Run a yabai command and parse the JSON output.
function M.json(cmd)
	local output = M.exec(cmd)
	local ok, decoded = pcall(hs.json.decode, output or "")

	if ok then
		return decoded
	end

	return nil
end

--- Run a command against a specific window by ID.
function M.windowCmd(id, cmd)
	if not id then
		return false
	end

	return M.ok("window " .. tostring(id) .. " " .. cmd)
end

--- Look up a window by its yabai ID. Returns nil if not found.
function M.windowById(id)
	if not id then
		return nil
	end

	local windows = M.json("query --windows")

	if not windows then
		return nil
	end

	for _, win in ipairs(windows) do
		if tostring(win.id) == tostring(id) then
			return win
		end
	end

	return nil
end

--- Focus the next display, preserving yabai's normal behavior.
--- If yabai lands on a non-focusable dialog and leaves no window focused,
--- fall back to the first visible standard window on the destination display.
function M.focusNextDisplay()
	local displays = M.json("query --displays")
	local focused = M.json("query --displays --display")
	if not displays or #displays < 2 or not focused then
		return
	end

	local target
	for i, display in ipairs(displays) do
		if display.index == focused.index then
			target = displays[(i % #displays) + 1]
			break
		end
	end
	if not target then
		return
	end

	hs.execute(
		"/opt/homebrew/bin/yabai -m display --focus next || " ..
			"/opt/homebrew/bin/yabai -m display --focus first"
	)

	hs.timer.doAfter(0.08, function()
		local windows = M.json("query --windows --display " .. target.index)
		if not windows then
			return
		end

		for _, win in ipairs(windows) do
			if win["has-focus"] then
				return
			end
		end

		for _, win in ipairs(windows) do
			if win.subrole == "AXStandardWindow"
				and win["is-visible"]
				and not win["is-minimized"] then
				M.exec("window " .. tostring(win.id) .. " --focus")
				return
			end
		end
	end)
end

--- Toggle the focused window to the next display (cycles through all displays).
function M.moveWindowToNextDisplay()
	local displays = M.json("query --displays")
	if not displays or #displays < 2 then
		return
	end
	local win = M.json("query --windows --window")
	if not win then
		return
	end
	local next_idx = (win.display % #displays) + 1
	M.exec("window --display " .. next_idx)
end

-- Resize mode

M.resizeMode = hs.hotkey.modal.new()

function M.resizeMode:entered()
	self._active = true
	hs.alert.show("Resize mode")
end

function M.resizeMode:exited()
	self._active = false
	hs.alert.show("Resize done")
end

function M.resizeMode:toggle()
	if self._active then
		self:exit()
	else
		self:enter()
	end
end

function M.toggleResizeMode()
	M.resizeMode:toggle()
end

return M

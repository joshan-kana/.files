-- Seek-only media controls.
-- No target picker, no polling, no Arc tab scanning.
--
-- Priority:
--   1. If Arc is frontmost, seek the active Arc tab's video.
--   2. Else if Spotify is running, seek Spotify.
--   3. Else try mpv IPC sockets.

local M = {}

local SEEK_AMOUNT = 10

local MPV_SOCKET_PATTERNS = {
	"/tmp/mpv*.sock",
	"/tmp/mpv/*.sock",
}

local function alert(msg)
	hs.alert.show(msg)
end

local function runAppleScript(script, quiet)
	local ok, result = hs.osascript.applescript(script)

	if not ok and not quiet then
		alert("AppleScript failed")
		print(result)
	end

	return ok, result
end

local function shellQuote(s)
	s = tostring(s or "")
	return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function appleScriptQuote(s)
	s = tostring(s or "")
	s = s:gsub("\\", "\\\\")
	s = s:gsub('"', '\\"')
	s = s:gsub("\n", "\\n")
	return '"' .. s .. '"'
end

local function frontmostBundleID()
	local app = hs.application.frontmostApplication()
	return app and app:bundleID()
end

-- Arc active tab video seek

local function arcSeek(seconds)
	local js = string.format(
		[[
(() => {
  const videos = [...document.querySelectorAll("video")]
    .filter(v => !isNaN(v.duration));

  const v = videos.find(v => !v.paused && !v.ended) || videos[0];

  if (!v) return "no video";

  v.currentTime = Math.max(
    0,
    Math.min(v.duration || Infinity, v.currentTime + %d)
  );

  return "ok";
})();
]],
		seconds
	)

	local script = [[
tell application "Arc"
  tell active tab of front window to execute javascript ]] .. appleScriptQuote(js) .. [[
end tell
]]

	local ok, result = runAppleScript(script, true)

	if not ok then
		alert("Arc seek failed")
		print(result)
		return false
	end

	return true
end

-- Spotify seek

local function spotifySeek(seconds)
	if not hs.application.get("com.spotify.client") then
		return false
	end

	local script = string.format(
		[[
tell application "Spotify"
  if player state is playing or player state is paused then
    set player position to ((player position) + %d)
    return "ok"
  end if
end tell
]],
		seconds
	)

	local ok, result = runAppleScript(script, true)

	if not ok then
		return false
	end

	return result == "ok"
end

-- mpv IPC seek

local function listMpvSockets()
	local sockets = {}

	for _, pattern in ipairs(MPV_SOCKET_PATTERNS) do
		local zshCode = "for f in " .. pattern .. '(N); do print -r -- "$f"; done'
		local cmd = "/bin/zsh -lc " .. shellQuote(zshCode)
		local output = hs.execute(cmd, true) or ""

		for line in output:gmatch("[^\r\n]+") do
			table.insert(sockets, line)
		end
	end

	table.sort(sockets)
	return sockets
end

local function mpvSeek(seconds)
	local sockets = listMpvSockets()

	if #sockets == 0 then
		return false
	end

	-- Seek the first live mpv socket.
	-- If you usually only have one mpv instance, this is perfect.
	for _, socketPath in ipairs(sockets) do
		local payload = hs.json.encode({
			command = { "seek", seconds, "relative+exact" },
		}) .. "\n"

		local cmd = table.concat({
			"printf",
			shellQuote(payload),
			"|",
			"/usr/bin/nc -U -w 1",
			shellQuote(socketPath),
			"2>/dev/null",
		}, " ")

		local output = hs.execute(cmd, true)

		if output and output:match('"error"%s*:%s*"success"') then
			return true
		end
	end

	return false
end

-- Public commands

local function seek(seconds)
	local bundleID = frontmostBundleID()

	-- Fast path: if you are watching Arc, control the active Arc tab.
	if bundleID == "company.thebrowser.Browser" then
		if arcSeek(seconds) then
			return
		end
	end

	-- If Spotify is the player, control Spotify directly.
	if spotifySeek(seconds) then
		return
	end

	-- Otherwise try mpv.
	if mpvSeek(seconds) then
		return
	end

	alert("No seekable media target")
end

function M.seekForward()
	seek(SEEK_AMOUNT)
end

function M.seekBackward()
	seek(-SEEK_AMOUNT)
end

return M

-- Shared modifier aliases and their cheatsheet symbols.

local M = {}

M.symbols = {
	hyper = "✦",
	meh = "✣",
	shift = "⇧",
}

M.hyper = { "cmd", "alt", "ctrl" }
M.meh = { "ctrl", "alt", "shift" }

local function withShift(mods)
	local out = {}
	for _, mod in ipairs(mods) do
		table.insert(out, mod)
	end
	table.insert(out, "shift")
	return out
end

local function alias(name, mods, sticky, symbol)
	return {
		name = name,
		mods = mods,
		sticky = sticky,
		symbol = symbol,
	}
end

M.aliases = {
	hyper = alias("hyper", M.hyper, {}, M.symbols.hyper),
	["hyper + shift"] = alias("hyper + shift", withShift(M.hyper), { "shift" }, M.symbols.hyper .. M.symbols.shift),
	meh = alias("meh", M.meh, nil, M.symbols.meh),
	["meh + shift"] = alias("meh + shift", withShift(M.meh), nil, M.symbols.meh .. M.symbols.shift),
}

function M.resolve(mods, sticky)
	if type(mods) ~= "string" then
		return mods
	end

	local entry = M.aliases[mods]
	if entry then
		if sticky and entry.sticky == nil then
			return nil
		end
		return sticky and entry.sticky or entry.mods
	end

	return mods
end

function M.symbol(mods)
	if type(mods) ~= "string" then
		return nil
	end
	local entry = M.aliases[mods]
	return entry and entry.symbol or nil
end

return M

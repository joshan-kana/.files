local vim = assert(_G.vim)
local source = "modules/cli/neovim/profiles.lua"
local state_file = vim.fn.stdpath("state") .. "/editor-profiles.json"

local function check(actual, expected)
	assert(actual == expected, "Expected " .. expected .. ", received " .. actual)
end

local function stored()
	return vim.json.decode(table.concat(vim.fn.readfile(state_file), "\n"))
end

local stage = vim.env.EDITOR_PROFILES_TEST_STAGE
if stage then
	local profiles = dofile(source)
	profiles.setup()
	if stage == "defaults" then
		check(profiles.status(), "positional")
		assert(vim.uv.fs_stat(state_file) == nil)
	elseif stage == "save" then
		vim.cmd("EditorKeymap native")
		vim.cmd("EditorSelection on")
		check(profiles.status(), "native · select")
		assert(stored().keymap == "native" and stored().selection == true)
	elseif stage == "restore" then
		check(profiles.status(), "native · select")
		check(vim.fn.maparg("x", "n"), "")
		check(vim.fn.maparg("w", "n"), "vaw")
		profiles.set_keymap("positional")
		assert(stored().keymap == "positional" and stored().selection == true)
	elseif stage == "independent" then
		check(profiles.status(), "positional · select")
		profiles.set_selection(false)
		assert(stored().keymap == "positional" and stored().selection == false)
	elseif stage == "restored-defaults" then
		check(profiles.status(), "positional")
		check(vim.fn.maparg("z", "n"), "u")
		check(vim.fn.maparg("w", "n"), "")
	elseif stage == "prepare-overlap" then
		profiles.set_keymap("native")
		profiles.set_selection(true)
	elseif stage == "overlap" then
		check(profiles.status(), "native · select")
		vim.fn.writefile({ vim.json.encode({ keymap = "native", selection = false }) }, state_file)
		profiles.set_keymap("positional")
		assert(stored().keymap == "positional" and stored().selection == false)
	elseif stage == "after-overlap" then
		check(profiles.status(), "positional")
	elseif stage == "invalid" then
		check(profiles.status(), "positional")
		profiles.set_keymap("native")
		assert(stored().keymap == "native" and stored().selection == false)
	elseif stage == "recovered" then
		check(profiles.status(), "native")
		check(vim.fn.maparg("x", "n"), "")
	else
		error("Unknown test stage " .. stage)
	end
	return
end

local base = vim.fn.tempname()
vim.fn.mkdir(base, "p")
local stages = {
	"defaults",
	"save",
	"restore",
	"independent",
	"restored-defaults",
	"prepare-overlap",
	"overlap",
	"after-overlap",
}
local function run(stage_name)
	local result = vim.system(
		{ vim.v.progpath, "--clean", "--headless", "-l", "tests/neovim/profiles-persistence.test.lua" },
		{
			env = { XDG_STATE_HOME = base, EDITOR_PROFILES_TEST_STAGE = stage_name },
			text = true,
		}
	)
		:wait()
	assert(result.code == 0, stage_name .. " failed: " .. (result.stderr or ""))
end
local success, reason = pcall(function()
	for _, stage_name in ipairs(stages) do
		run(stage_name)
	end
	vim.fn.writefile({ "{broken json" }, base .. "/nvim/editor-profiles.json")
	run("invalid")
	run("recovered")
end)
vim.fn.delete(base, "rf")
assert(success, reason)
print("Editing preferences persist across launches and recover from invalid state")

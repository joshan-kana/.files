local vim = assert(_G.vim)
local source = "modules/cli/neovim/profiles.lua"
local state_dir = vim.fn.stdpath("state")
local legacy_file = state_dir .. "/editor-profiles.json"
local keymap_file = state_dir .. "/editor-keymap"
local selection_file = state_dir .. "/editor-selection"

local function check(actual, expected)
	assert(actual == expected, "Expected " .. expected .. ", received " .. actual)
end

local function stored()
	return {
		keymap = vim.fn.readfile(keymap_file)[1],
		selection = vim.fn.readfile(selection_file)[1] == "true",
	}
end

local stage = vim.env.EDITOR_PROFILES_TEST_STAGE
if stage then
	local profiles = dofile(source)
	profiles.setup()
	if stage == "defaults" then
		check(profiles.status(), "positional")
		assert(vim.uv.fs_stat(keymap_file) == nil and vim.uv.fs_stat(selection_file) == nil)
	elseif stage == "save" then
		vim.cmd("EditorKeymap native")
		vim.cmd("EditorSelection on")
		check(profiles.status(), "native · select")
		assert(stored().keymap == "native" and stored().selection == true)
	elseif stage == "restore" then
		check(profiles.status(), "native · select")
		check(vim.fn.maparg("x", "n"), "")
		assert(type(vim.fn.maparg("w", "n", false, true).callback) == "function")
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
		vim.fn.writefile({ "false" }, selection_file)
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
	elseif stage == "legacy-restore" then
		check(profiles.status(), "native · select")
		profiles.set_keymap("positional")
		assert(vim.fn.readfile(keymap_file)[1] == "positional")
		assert(vim.uv.fs_stat(selection_file) == nil)
	elseif stage == "legacy-override" then
		check(profiles.status(), "positional · select")
		profiles.set_selection(false)
		assert(vim.fn.readfile(selection_file)[1] == "false")
	elseif stage == "legacy-final" then
		check(profiles.status(), "positional")
		assert(vim.json.decode(table.concat(vim.fn.readfile(legacy_file), "\n")).keymap == "native")
	elseif stage == "invalid-field" then
		check(profiles.status(), "native")
		profiles.set_keymap("positional")
		assert(vim.fn.readfile(keymap_file)[1] == "positional")
	elseif stage == "stress-keymap" then
		for i = 1, 60 do
			profiles.set_keymap(i % 2 == 0 and "native" or "positional")
		end
	elseif stage == "stress-selection" then
		for i = 1, 60 do
			profiles.set_selection(i % 2 == 0)
		end
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
	vim.fn.delete(base .. "/nvim/editor-keymap")
	vim.fn.delete(base .. "/nvim/editor-selection")
	vim.fn.writefile({ vim.json.encode({ keymap = "native", selection = true }) }, base .. "/nvim/editor-profiles.json")
	run("legacy-restore")
	run("legacy-override")
	run("legacy-final")
	vim.fn.writefile({ "unknown" }, base .. "/nvim/editor-keymap")
	run("invalid-field")
	for _ = 1, 6 do
		vim.fn.delete(base .. "/nvim/editor-keymap")
		vim.fn.delete(base .. "/nvim/editor-selection")
		local function launch(field)
			return vim.system(
				{ vim.v.progpath, "--clean", "--headless", "-l", "tests/neovim/profiles-persistence.test.lua" },
				{
					env = { XDG_STATE_HOME = base, EDITOR_PROFILES_TEST_STAGE = "stress-" .. field },
					text = true,
				}
			)
		end
		local keymap = launch("keymap")
		local selection = launch("selection")
		for _, process in ipairs({ keymap, selection }) do
			local result = process:wait()
			assert(result.code == 0, result.stderr or "Concurrent profile writer failed")
		end
		assert(vim.fn.readfile(base .. "/nvim/editor-keymap")[1] == "native", "Concurrent keymap overwritten")
		assert(vim.fn.readfile(base .. "/nvim/editor-selection")[1] == "true", "Concurrent selection overwritten")
	end
end)
vim.fn.delete(base, "rf")
assert(success, reason)
print("Editing preferences persist, migrate and survive concurrent writes")

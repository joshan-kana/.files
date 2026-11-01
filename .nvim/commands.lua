local vim = assert(_G.vim)
local M = {}

local function run(root, title, args)
	if vim.bo.modified then
		vim.notify("Save your changes before running " .. title, vim.log.levels.WARN)
		return
	end
	vim.system(
		args,
		{ cwd = root, text = true },
		vim.schedule_wrap(function(result)
			if result.code == 0 then
				vim.cmd.checktime()
				vim.notify(title .. " completed")
				return
			end
			vim.fn.setqflist({}, " ", {
				title = title,
				lines = vim.split((result.stdout or "") .. "\n" .. (result.stderr or ""), "\n", { trimempty = true }),
				efm = "%f:%l:%c: %m,%f:%l: %m,%m",
			})
			vim.cmd.copen()
			vim.notify(title .. " failed; see quickfix", vim.log.levels.ERROR)
		end)
	)
end

function M.setup(root)
	vim.api.nvim_create_user_command("ProjectFormat", function()
		run(root, "Project formatting and linting", { "nix", "fmt" })
	end, { desc = "Run the complete project treefmt formatting and linting suite" })

	vim.api.nvim_create_user_command("ProjectCheck", function()
		local system = vim.env.NVIM_PROJECT_SYSTEM
		if not system or system == "" then
			local uname = vim.uv.os_uname()
			system = (uname.machine == "arm64" and "aarch64" or uname.machine)
				.. (vim.fn.has("macunix") == 1 and "-darwin" or "-linux")
		end
		run(root, "Project quality check", { "nix", "build", "--no-link", ".#checks." .. system .. ".repo-quality" })
	end, { desc = "Check project formatting and linting without modifying source" })
end

return M

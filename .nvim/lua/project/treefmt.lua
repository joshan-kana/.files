local vim = assert(_G.vim)
local M = {}

local function report(title, result)
	local output = (result.stdout or "") .. "\n" .. (result.stderr or "")
	if result.code == 0 then
		vim.notify(title .. " completed", vim.log.levels.INFO)
		return true
	end
	vim.fn.setqflist({}, " ", {
		title = title,
		lines = vim.split(output, "\n", { trimempty = true }),
		efm = "%f:%l:%c: %m,%f:%l: %m,%m",
	})
	vim.cmd.copen()
	vim.notify(title .. " failed; see quickfix", vim.log.levels.ERROR)
	return false
end

function M.setup(root)
	local function run(title, command, buffer)
		vim.system(
			command,
			{ cwd = root, text = true },
			vim.schedule_wrap(function(result)
				if report(title, result) and buffer and vim.api.nvim_buf_is_valid(buffer) then
					vim.api.nvim_buf_call(buffer, function()
						vim.cmd.checktime()
					end)
				end
			end)
		)
	end

	vim.api.nvim_create_user_command("ProjectFormat", function()
		local buffer = vim.api.nvim_get_current_buf()
		local filename = vim.api.nvim_buf_get_name(buffer)
		if filename == "" or vim.bo[buffer].modified then
			vim.notify("Save the file before running treefmt", vim.log.levels.WARN)
			return
		end
		if not vim.startswith(filename, root .. "/") then
			vim.notify("The current file is outside this project", vim.log.levels.WARN)
			return
		end
		local formatter = vim.env.NVIM_PROJECT_TREEFMT
		local command = formatter and formatter ~= "" and { formatter, filename } or { "nix", "fmt", "--", filename }
		run("treefmt: " .. vim.fn.fnamemodify(filename, ":t"), command, buffer)
	end, { desc = "Format current file using project treefmt formatters and linters" })

	local function check()
		local system = vim.env.NVIM_PROJECT_SYSTEM
		if not system or system == "" then
			local uname = vim.uv.os_uname()
			system = (uname.machine == "arm64" and "aarch64" or uname.machine)
				.. (vim.fn.has("macunix") == 1 and "-darwin" or "-linux")
		end
		run(
			"Project lint and formatting check",
			{ "nix", "build", "--no-link", ".#checks." .. system .. ".repo-quality" }
		)
	end
	vim.api.nvim_create_user_command("ProjectLint", check, { desc = "Run the full project treefmt lint/format check" })
	vim.api.nvim_create_user_command("ProjectCheck", check, { desc = "Run the full project treefmt lint/format check" })
end

return M

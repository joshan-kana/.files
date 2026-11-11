local M = {}

function M.setup()
	require("nvim-autopairs").setup({
		check_ts = true,
		map_cr = true,
	})
end

return M

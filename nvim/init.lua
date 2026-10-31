-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- 用户自己的 vim 配置（选项、函数、按键）
-- 先 source 一次，让选项尽早生效
vim.cmd("source ~/.config/nvim/kemil.vim")

-- 注意：LazyVim 会在 `VeryLazy` 时加载它自己的 keymaps，
-- 会覆盖 kemil.vim 里的同名按键（如 <C-s>、<leader>E）。
-- 所以在 VeryLazy 之后再 source 一次，保证 kemil.vim 里的按键最终生效。
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    vim.cmd("source ~/.config/nvim/kemil.vim")
  end,
})

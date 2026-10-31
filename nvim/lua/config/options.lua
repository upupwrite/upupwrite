-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Use backslash as the leader key (LazyVim default is space)
vim.g.mapleader = "\\"

-- Make sure ~/.local/bin is in PATH for tools spawned by Neovim (mason, LSPs...).
-- e.g. a user-level `unzip` shim when the system package is missing.
local local_bin = vim.fn.expand("~/.local/bin")
if vim.fn.isdirectory(local_bin) == 1 and not (vim.env.PATH or ""):find(local_bin, 1, true) then
  vim.env.PATH = local_bin .. ":" .. (vim.env.PATH or "")
end

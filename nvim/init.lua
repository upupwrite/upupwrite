-- ~/.config/nvim/init.lua
-- Neovim 配置入口

-- ========== 基础设置 ==========
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.wrap=true

-- ========== 加载 Lazy.nvim ==========
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- ========== 加载插件配置 ==========
require('lazy').setup('plugins')

-- ========== 加载其他配置 ==========
vim.cmd("source ~/.config/nvim/kemil.vim")

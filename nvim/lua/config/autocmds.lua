-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local aug = vim.api.nvim_create_augroup("UserTroublePreview", { clear = true })

-- 在 Trouble 列表（错误 / 引用 / 符号…）里移动选择时，
-- 让「主编辑窗口」的光标跟着移动：
--   * 不打开预览窗口、不盖浮动层
--   * 焦点仍留在列表里，可以继续用 j/k、}、{ 浏览
local syncing = false

local function sync_main_window()
  if syncing then
    return
  end
  local ok, view = pcall(function()
    return require("trouble.api")._find_last()
  end)
  if not ok or not view or not view.win then
    return
  end
  -- 只在光标位于 Trouble 窗口时联动
  if not vim.api.nvim_buf_is_valid(view.win.buf) or vim.api.nvim_get_current_buf() ~= view.win.buf then
    return
  end

  local _, at = pcall(view.at, view)
  local item = at and at.item
  if not item or not item.filename then
    return
  end

  local _, main = pcall(view.main, view)
  local win = main and main.win
  if not win or not vim.api.nvim_win_is_valid(win) or win == vim.api.nvim_get_current_win() then
    return
  end

  item.buf = item.buf or vim.fn.bufadd(item.filename)
  if not vim.api.nvim_buf_is_loaded(item.buf) then
    vim.fn.bufload(item.buf)
  end

  syncing = true
  pcall(vim.api.nvim_win_set_buf, win, item.buf)
  vim.api.nvim_win_call(win, function()
    pcall(vim.api.nvim_win_set_cursor, win, item.pos)
    pcall(vim.cmd, "normal! zzzv")
  end)
  syncing = false
end

-- Trouble 列表不可编辑。鼠标点进列表时如果还处于插入模式，
-- 自动回到普通模式，避免后续按键继续被当作文本输入。
local function leave_insert_mode_in_trouble()
  if vim.bo.filetype ~= "trouble" then
    return
  end
  local mode = vim.api.nvim_get_mode().mode
  if mode:sub(1, 1) == "i" or mode:sub(1, 1) == "R" then
    vim.cmd("stopinsert")
  end
end

vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
  group = aug,
  callback = leave_insert_mode_in_trouble,
})

vim.api.nvim_create_autocmd("CursorMoved", {
  group = aug,
  callback = function()
    if vim.bo.filetype ~= "trouble" then
      return
    end
    -- 鼠标/滚轮在 Trouble 窗口里移动时也保证不留在插入模式
    leave_insert_mode_in_trouble()
    vim.schedule(sync_main_window)
  end,
})

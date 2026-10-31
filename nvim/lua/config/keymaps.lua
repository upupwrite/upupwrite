-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

-- Jump to the implementation of the symbol under the cursor,
-- falling back to its definition when no implementation is found.
local function goto_impl_or_def()
  local params = vim.lsp.util.make_position_params(0, "utf-16")
  vim.lsp.buf_request(0, "textDocument/implementation", params, function(err, result, ctx)
    if err or not result or vim.tbl_isempty(result) then
      vim.lsp.buf.definition()
      return
    end
    local client = vim.lsp.get_client_by_id(ctx and ctx.client_id)
    local offset_encoding = (client and client.offset_encoding) or "utf-16"
    vim.lsp.util.jump_to_location(result[1], offset_encoding)
  end)
end

-- Switch between the current file's header/source (clangd).
-- `:LspClangdSwitchSourceHeader` is created buffer-locally by clangd's
-- on_attach (nvim-lspconfig), so it only exists in C/C++ buffers.
local function switch_source_header()
  local cmds = vim.api.nvim_buf_get_commands(0, {})
  if cmds["LspClangdSwitchSourceHeader"] then
    vim.cmd("LspClangdSwitchSourceHeader")
  elseif vim.fn.exists(":ClangdSwitchSourceHeader") == 2 then
    vim.cmd("ClangdSwitchSourceHeader")
  else
    vim.notify("Switch source/header: clangd is not attached to this buffer", vim.log.levels.WARN)
  end
end

-- Toggle the file explorer (Snacks).
local function toggle_explorer()
  local explorer = Snacks.picker.get({ source = "explorer" })[1]
  if explorer then
    explorer:close()
  else
    Snacks.explorer({ cwd = LazyVim.root() })
  end
end

-- Close the current tab/buffer without disrupting the window layout.
local function close_current_tab()
  local ok, bufdelete = pcall(require, "snacks.bufdelete")
  if ok and bufdelete then
    bufdelete()
  else
    vim.cmd("bdelete")
  end
end

-- Error window (diagnostics)
-- 准确检测 diagnostics 列表是否已打开：
--   * 已打开 → 关闭（即使焦点不在列表里也不会重复聚焦）
--   * 未打开 → 打开并自动聚焦
-- NOTE: overrides LazyVim's default "<C-l> -> go to right window"
local function toggle_diagnostics()
  local trouble = require("trouble")
  if trouble.is_open("diagnostics") then
    trouble.close("diagnostics")
  else
    trouble.open({ mode = "diagnostics", focus = true })
  end
end

map("n", "<C-l>", toggle_diagnostics, { desc = "Toggle error window (diagnostics)" })

-- Close current tab/buffer
map("n", "<A-w>", close_current_tab, { desc = "Close current tab/buffer" })

-- Jump to implementation/definition under the cursor
map("n", "<F2>", goto_impl_or_def, { desc = "Go to implementation/definition" })

-- Toggle file explorer
map("n", "<F3>", toggle_explorer, { desc = "Toggle file explorer" })

-- Toggle file explorer from insert mode (leave insert mode first)
map("i", "<F3>", function()
  vim.cmd("stopinsert")
  toggle_explorer()
end, { desc = "Toggle file explorer" })

-- Switch between header/source file
map("n", "<F4>", switch_source_header, { desc = "Switch source/header" })

-- View the references of the symbol under the cursor as a *static* list.
-- (`Trouble lsp_references` re-queries on every CursorMoved, so the list would
-- change when the cursor moves onto other symbols. A quickfix snapshot won't.)
local function show_references()
  local params = vim.lsp.util.make_position_params(0, "utf-16")
  vim.lsp.buf_request(0, "textDocument/references", params, function(err, result, ctx)
    if err then
      vim.notify("LSP references failed: " .. tostring(err.message or err), vim.log.levels.WARN)
      return
    end
    if not result or #result == 0 then
      vim.notify("No references found", vim.log.levels.INFO)
      return
    end
    local client = vim.lsp.get_client_by_id(ctx and ctx.client_id)
    local offset_encoding = (client and client.offset_encoding) or "utf-16"
    local items = vim.lsp.util.locations_to_items(result, offset_encoding)
    vim.fn.setqflist({}, " ", { title = "References", items = items })
    vim.cmd("Trouble qflist toggle")
  end)
end

-- View symbol references under the cursor (static snapshot, <CR> to jump)
map("n", "<A-z>", show_references, { desc = "View references under cursor" })

-- Toggle symbol index (outline) for the current file
map("n", "<F8>", "<cmd>Outline<cr>", { desc = "Toggle symbol index (outline)" })

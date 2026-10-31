-- Use Neovim's built-in UI for cmdline / messages / notifications.
-- (Restores the native `:` cmdline, native `:messages` history and native
--  `vim.notify` output instead of floating popups and toasts.)
return {
  -- noice.nvim replaces the cmdline, the message/echo area and the popupmenu
  { "folke/noice.nvim", enabled = false },

  -- Toast notifications (pretty `vim.notify`)
  {
    "snacks.nvim",
    opts = {
      notifier = { enabled = false },
    },
  },
}

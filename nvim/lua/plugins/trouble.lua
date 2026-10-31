-- Trouble（错误列表 / 引用列表 / 符号索引 等）
return {
  {
    "folke/trouble.nvim",
    opts = {
      -- 关掉 Trouble 自带的预览（它是在主窗口上盖一个浮动窗口，
      -- 看起来像"另一个预览窗口"）。联动滚动改由
      -- lua/config/autocmds.lua 里的 autocmd 实现：
      -- 移动选择时，光标直接在主编辑窗口里移动。
      auto_preview = false,
      -- 高亮当前项
      follow = true,
    },
  },
}

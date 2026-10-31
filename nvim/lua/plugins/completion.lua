-- 补全键位：用 <Tab> 补全，禁用 <Enter> 补全（恢复原本换行）
--
-- Tab 行为（super-tab 预设 + LazyVim 的 snippet 处理）：
--   * 补全菜单可见时：接受当前选中项（select_and_accept）
--   * snippet 展开中：跳到下一个占位符（snippet_forward）
--   * 其它情况：回退到原生 Tab（插入缩进）
-- Shift-Tab：snippet 内回退占位符 / 否则原生反缩进
-- <C-y>：仍然可以接受补全
-- <C-n> / <C-p> / <Down> / <Up>：上下选择候选项
return {
  {
    "saghen/blink.cmp",
    opts = {
      keymap = {
        preset = "super-tab",
        -- 禁用 Enter 接受补全（false = 不交给 blink，使用 Neovim 原生行为）
        ["<CR>"] = false,
      },
    },
  },
}

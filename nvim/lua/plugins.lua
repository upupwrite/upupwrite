-- ~/.config/nvim/lua/plugins.lua
-- 所有插件的统一配置

-- ========== 主题列表（改这里切换深/浅色） ==========
local THEMES = {
  { 'tokyonight', 'night' },   -- 深色
  { 'tokyonight', 'day' },     -- 浅色
}

local current_theme = 1

local function apply_theme(idx)
  local t = THEMES[idx]
  if not t then return end
  local name, variant = t[1], t[2]

  pcall(function()
    require(name).setup({ style = variant })
  end)

  vim.cmd.colorscheme(name)
  pcall(function() require('lualine').refresh() end)
  vim.notify(('Theme: %s (%s)'):format(name, variant or 'default'))
end

local function cycle_theme()
  current_theme = current_theme % #THEMES + 1
  apply_theme(current_theme)
end

vim.keymap.set('n', '<F9>', cycle_theme, { desc = '切换主题（深/浅）' })

-- ========== 插件列表 ==========
return {
  -- ===== 主题 =====
  {
    'folke/tokyonight.nvim',
    priority = 1000,
    lazy = false,
    config = function()
      apply_theme(1)
    end,
  },

  -- ===== 状态栏 =====
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('lualine').setup({
        options = { theme = 'auto' }
      })
    end,
  },

  -- ===== 文件树 =====
  {
    'nvim-tree/nvim-tree.lua',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      local function nvim_tree_on_attach(bufnr)
        local api = require('nvim-tree.api')

        local function opts(desc)
          return {
            desc = 'nvim-tree: ' .. desc,
            buffer = bufnr,
            noremap = true,
            silent = true,
            nowait = true,
          }
        end

        api.config.mappings.default_on_attach(bufnr)

        vim.keymap.set('n', '<CR>', api.node.open.edit, opts('打开文件/目录'))
        vim.keymap.set('n', '<C-x>', api.tree.close, opts('关闭文件树'))
        vim.keymap.set('n', '<C-v>', api.node.open.vertical, opts('垂直分割打开'))
        vim.keymap.set('n', '<C-s>', api.node.open.horizontal, opts('水平分割打开'))
      end

      require('nvim-tree').setup({
        view = { width = 30 },
        filters = { dotfiles = true },
        on_attach = nvim_tree_on_attach,
      })

      vim.keymap.set('n', '<F3>', ':NvimTreeToggle<CR>', { silent = true, desc = 'Toggle file tree' })
    end,
  },

  -- ===== 代码片段 =====
  {
    'L3MON4D3/LuaSnip',
    version = 'v2.*',
    config = function()
      require('luasnip').setup({})
    end,
  },

  {
    'rafamadriz/friendly-snippets',
    dependencies = { 'L3MON4D3/LuaSnip' },
    config = function()
      require('luasnip.loaders.from_vscode').lazy_load()
    end,
  },

  -- ===== 括号自动闭合 =====
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    config = function()
      require('nvim-autopairs').setup({
        check_ts = true,
        enable_check_bracket_line = false,
        fast_wrap = {},
      })
    end,
  },

  -- ===== 补全引擎 coc.nvim（替代 blink.cmp） =====
  {
    'neoclide/coc.nvim',
    branch = 'release',
    lazy = false,
    config = function()
      -- 自动安装常用扩展
      vim.g.coc_global_extensions = {
        'coc-pyright',
        'coc-clangd',
        'coc-rust-analyzer',
        'coc-snippets',
        'coc-json',
      }

      local opts = { noremap = true, silent = true, nowait = true }

      -- Tab：补全菜单可见时接受当前项；否则插入 Tab
      vim.keymap.set('i', '<Tab>', function()
        if vim.fn['coc#pum#visible']() == 1 then
          return vim.fn['coc#pum#confirm']()
        end
        return '\t'
      end, { expr = true, silent = true, noremap = true, replace_keycodes = true })

      -- S-Tab：补全菜单可见时上一个候选；否则不做任何事
      vim.keymap.set('i', '<S-Tab>', function()
        if vim.fn['coc#pum#visible']() == 1 then
          return vim.fn['coc#pum#prev'](1)
        end
        return ''
      end, { expr = true, silent = true, noremap = true, replace_keycodes = true })

      -- Ctrl+Space：手动触发补全
      vim.keymap.set('i', '<C-space>', function()
        return vim.fn['coc#refresh']()
      end, { expr = true, silent = true, noremap = true, replace_keycodes = true })

      -- 不映射 <CR>：回车保持普通换行

      -- 代码导航与操作
      vim.keymap.set('n', 'gd', '<Plug>(coc-definition)', opts)
      vim.keymap.set('n', 'gy', '<Plug>(coc-type-definition)', opts)
      vim.keymap.set('n', 'gi', '<Plug>(coc-implementation)', opts)
      vim.keymap.set('n', 'gr', '<Plug>(coc-references)', opts)
      vim.keymap.set('n', 'K', ':call CocActionAsync("doHover")<CR>', opts)
      vim.keymap.set('n', '<leader>rn', '<Plug>(coc-rename)', opts)
      vim.keymap.set('n', '<leader>ca', '<Plug>(coc-codeaction-cursor)', opts)
      vim.keymap.set('n', '<leader>f', '<Plug>(coc-format)', opts)
    end,
  },

  -- ===== 代码大纲（后端改用 coc） =====
  {
    'stevearc/aerial.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {
      layout = {
        max_width = { 40, 0.3 },
        min_width = 25,
      },
      source = 'coc',
    },
    config = function(_, opts)
      require('aerial').setup(opts)
      vim.keymap.set('n', '<leader>a', '<cmd>AerialToggle!<CR>')
    end,
  },

  -- ===== 问题诊断 =====
  {
    'folke/trouble.nvim',
    opts = {},
    cmd = 'Trouble',
    keys = {
      { '<leader>xx', '<cmd>Trouble diagnostics toggle<CR>', desc = 'Diagnostics (Trouble)' },
      { '<leader>xX', '<cmd>Trouble diagnostics toggle filter.buf=0<CR>', desc = 'Buffer Diagnostics (Trouble)' },
      { '<F12>', '<cmd>Trouble diagnostics toggle<CR>', desc = 'Toggle diagnostics list' },
    },
  },

  -- ===== 文件标签栏 (Barbar) =====
  {
    'romgrk/barbar.nvim',
    version = '*',
    dependencies = {
      'nvim-tree/nvim-web-devicons',
    },
    init = function()
      vim.g.barbar_auto_setup = false
    end,
    config = function()
      require('barbar').setup({
        preset = 'tabs',
        position = 'top',
        theme = 'auto',
        icons = {
          filetype = {
            enabled = true,
          },
        },
        maximum_length = 30,
        maximum_prefix_length = 30,
        filename_display = 'smart',
        insert_at_end = false,
        insert_at_start = false,
        hide_inactive = false,
        animation = true,
      })

      vim.keymap.set('n', '<Tab>', '<Cmd>BufferNext<CR>', { desc = 'Next buffer' })
      vim.keymap.set('n', '<S-Tab>', '<Cmd>BufferPrevious<CR>', { desc = 'Previous buffer' })
      vim.keymap.set('n', '<leader>bd', '<Cmd>BufferClose<CR>', { desc = 'Close buffer' })
      vim.keymap.set('n', '<leader>bo', '<Cmd>BufferCloseAllButCurrent<CR>', { desc = 'Close other buffers' })
      vim.keymap.set('n', '<leader>bl', '<Cmd>BufferCloseBuffersLeft<CR>', { desc = 'Close left buffers' })
      vim.keymap.set('n', '<leader>br', '<Cmd>BufferCloseBuffersRight<CR>', { desc = 'Close right buffers' })
      vim.keymap.set('n', '<A-1>', '<Cmd>BufferGoto 1<CR>', { desc = 'Go to buffer 1' })
      vim.keymap.set('n', '<A-2>', '<Cmd>BufferGoto 2<CR>', { desc = 'Go to buffer 2' })
      vim.keymap.set('n', '<A-3>', '<Cmd>BufferGoto 3<CR>', { desc = 'Go to buffer 3' })
      vim.keymap.set('n', '<A-4>', '<Cmd>BufferGoto 4<CR>', { desc = 'Go to buffer 4' })
      vim.keymap.set('n', '<A-5>', '<Cmd>BufferGoto 5<CR>', { desc = 'Go to buffer 5' })
      vim.keymap.set('n', '<A-6>', '<Cmd>BufferGoto 6<CR>', { desc = 'Go to buffer 6' })
      vim.keymap.set('n', '<A-7>', '<Cmd>BufferGoto 7<CR>', { desc = 'Go to buffer 7' })
      vim.keymap.set('n', '<A-8>', '<Cmd>BufferGoto 8<CR>', { desc = 'Go to buffer 8' })
      vim.keymap.set('n', '<A-9>', '<Cmd>BufferGoto 9<CR>', { desc = 'Go to buffer 9' })
      vim.keymap.set('n', '<leader>bp', '<Cmd>BufferPin<CR>', { desc = 'Pin buffer' })
      vim.keymap.set('n', '<leader>bu', '<Cmd>BufferRestore<CR>', { desc = 'Restore closed buffer' })
      vim.keymap.set('n', '<leader>bb', '<Cmd>BufferPick<CR>', { desc = 'Pick buffer' })
    end,
  },

  -- ===== 终端配置 (Toggleterm) =====
  {
    'akinsho/toggleterm.nvim',
    version = '*',
    config = function()
      require('toggleterm').setup({
        size = 15,
        open_mapping = [[<leader>tt]],
        hide_numbers = true,
        shade_filetypes = {},
        shade_terminals = true,
        shading_factor = 2,
        start_in_insert = true,
        insert_mappings = true,
        persist_size = true,
        direction = 'tab',
        close_on_exit = true,
        shell = vim.o.shell,
        auto_scroll = true,
        highlights = {
          Normal = {
            guibg = '#1A1B26',
          },
        },
      })

      vim.keymap.set('n', '<leader>tt', '<cmd>ToggleTerm<CR>', { desc = 'Terminal in new tab' })
      vim.keymap.set('n', '<leader>tn', '<cmd>ToggleTerm<CR>', { desc = 'Terminal in new tab' })
      vim.keymap.set('n', '<leader>th', '<cmd>ToggleTerm direction=horizontal<CR>', { desc = 'Horizontal terminal' })
      vim.keymap.set('n', '<leader>tv', '<cmd>ToggleTerm direction=vertical<CR>', { desc = 'Vertical terminal' })
      vim.keymap.set('t', '<Esc>', [[<C-\><C-n>]], { desc = 'Exit terminal insert mode' })

      vim.api.nvim_create_autocmd('TermOpen', {
        callback = function()
          vim.cmd('startinsert')
        end,
      })

      vim.keymap.set('n', '<F10>', function()
        for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].buftype == 'terminal' then
              vim.api.nvim_set_current_tabpage(tab)
              vim.api.nvim_set_current_win(win)
              vim.cmd('startinsert')
              return
            end
          end
        end
        vim.cmd('ToggleTerm')
        vim.cmd('startinsert')
      end, { desc = 'Go to terminal tab, or open one' })
    end,
  },

  -- ===== 快速注释插件 =====
  {
    'numToStr/Comment.nvim',
    version = '*',
    config = function()
      require('Comment').setup({
        padding = true,
        sticky = true,
        ignore = nil,
        toggler = {
          line = 'gcc',
          block = 'gbc',
        },
        opleader = {
          line = 'gc',
          block = 'gb',
        },
        extra = {
          above = 'gcO',
          below = 'gco',
          eol = 'gcA',
        },
      })

      vim.keymap.set('n', '<C-_>', 'gcc', { desc = 'Toggle comment', remap = true })
      vim.keymap.set('v', '<C-_>', 'gc', { desc = 'Toggle comment', remap = true })
    end,
  },

  -- ===== AI 助手 llm.nvim（轻量，支持 DeepSeek） =====
  {
    "Kurama622/llm.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
    },
    cmd = { "LLM", "LLMSessionToggle", "LLMSelectedTextHandler", "LLMAppHandler" },
    config = function()
      require("llm").setup({
        url = "https://api.deepseek.com/chat/completions",
        model = "deepseek-chat",
        api_type = "openai",
        max_tokens = 4096,
        temperature = 0.3,
        top_p = 0.7,
        prompt = "You are a helpful assistant.",
      })
    end,
  },
}
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

-- ========== LSP 通用回调 ==========
local on_attach = function(client, bufnr)
  local opts = { buffer = bufnr, remap = false }
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
  vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
  vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
  vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
  vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
  vim.keymap.set('n', '<leader>f', function() vim.lsp.buf.format() end, opts)
end

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
      -- 文件树专属的 on_attach 回调
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

        -- 先加载默认键位（保留其他所有默认映射）
        api.config.mappings.default_on_attach(bufnr)

        -- 覆盖关键键位
        vim.keymap.set('n', '<CR>', api.node.open.edit, opts('打开文件/目录'))
        vim.keymap.set('n', '<C-x>', api.tree.close, opts('关闭文件树'))
        vim.keymap.set('n', '<C-v>', api.node.open.vertical, opts('垂直分割打开'))
        vim.keymap.set('n', '<C-s>', api.node.open.horizontal, opts('水平分割打开'))
      end

      require('nvim-tree').setup({
        view = { width = 30 },
        filters = { dotfiles = true },
        on_attach = nvim_tree_on_attach,   -- 新版本唯一的自定义入口
      })

      -- F3 打开/关闭文件树
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

  -- ===== 自动补全 + LSP =====
  {
    'saghen/blink.cmp',
    version = '*',
    build = 'cargo build --release',
    dependencies = {
      'L3MON4D3/LuaSnip',
      'rafamadriz/friendly-snippets',
    },
    opts = {
      completion = {
        accept = {
          auto_brackets = { enabled = false },
        },
      },
      sources = {
        default = { 'lsp', 'path', 'snippets', 'buffer' },
      },
      keymap = {
        preset = 'default',
        ['<C-space>'] = { 'show', 'fallback' },
        ['<CR>']      = { 'accept', 'fallback' },
        ['<Tab>']     = { 'accept', 'fallback' },
        ['<S-Tab>']   = { 'snippet_backward', 'fallback' },
      },
      fuzzy = {
        implementation = 'lua',
      },
    },
    config = function(_, opts)
      require('blink.cmp').setup(opts)

      local capabilities = require('blink.cmp').get_lsp_capabilities()

      vim.lsp.config('pyright', {
        cmd = { 'pyright-langserver', '--stdio' },
        filetypes = { 'python' },
        root_markers = { 'pyproject.toml', 'setup.py', 'requirements.txt', '.git' },
        capabilities = capabilities,
        on_attach = on_attach,
      })

      vim.lsp.config('clangd', {
        cmd = { 'clangd' },
        filetypes = { 'c', 'cpp', 'objc', 'objcpp' },
        root_markers = { 'compile_commands.json', 'compile_flags.txt', '.git' },
        capabilities = capabilities,
        on_attach = function(client, bufnr)
          on_attach(client, bufnr)
          vim.keymap.set('n', '<leader>ch', '<cmd>ClangdSwitchSourceHeader<CR>', { buffer = bufnr })
        end,
      })

      -- === Rust 语言服务器配置 ===
      vim.lsp.config('rust_analyzer', {
        cmd = { 'rust-analyzer' },
        filetypes = { 'rust' },
        root_markers = { 'Cargo.toml', '.git' },
        capabilities = capabilities,
        on_attach = on_attach,
        settings = {
          ['rust-analyzer'] = {
            cargo = {
              loadOutDirsFromCheck = true,
            },
            procMacro = {
              enable = true,
            },
            diagnostics = {
              disabled = { 'unresolved-proc-macro' },
            },
          },
        },
      })

      vim.lsp.enable('pyright')
      vim.lsp.enable('clangd')
      vim.lsp.enable('rust_analyzer')  -- 启用 rust-analyzer
    end,
  },

  -- ===== 代码大纲 =====
  {
    'stevearc/aerial.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {
      layout = {
        max_width = { 40, 0.3 },
        min_width = 25,
      },
      source = 'lsp',
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
      -- F12 打开/关闭整个项目的错误/诊断列表
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
        direction = 'tab',       -- 终端以标签页方式打开
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

      -- 任何终端缓冲区打开时，自动进入插入模式
      vim.api.nvim_create_autocmd('TermOpen', {
        callback = function()
          vim.cmd('startinsert')
        end,
      })

      -- F10：切到已有终端标签；没有则在新标签页打开终端，且进入插入模式
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
        -- 没有找到终端，则新建（direction = 'tab' 会在新标签页打开）
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

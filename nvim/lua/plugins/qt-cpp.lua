-- Qt / C++ development setup for LazyVim
--
-- Tool strategy: system packages (pacman/yay) are preferred when available,
-- mason only fills the gaps. This avoids slow/duplicate downloads.
--
-- Recommended system packages (fast, no mason download needed):
--   sudo pacman -S --needed unzip clang lldb cmake ninja
--   sudo pacman -S --needed qt6-base qt6-declarative qt6-tools   # qmlls6
--   yay -S --needed neocmakelsp cmake-format                    # LSP + cmake formatter
--   yay -S --needed codelldb-bin                                # debugger (or: pacman -S lldb)
--
-- clangd needs `compile_commands.json` to know Qt include paths/defines:
--   cmake -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
--   ln -s build/compile_commands.json .
local have = function(bin)
  return vim.fn.executable(bin) == 1
end

-- What is already provided by the system?
local sys = {
  clangd = have("clangd"),
  clang_format = have("clang-format"),
  qmlls = have("qmlls6") or have("qmlls"),
  neocmakelsp = have("neocmakelsp"),
  cmake_format = have("cmake-format"),
  cmakelint = have("cmakelint"),
  codelldb = have("codelldb"),
  lldb_dap = have("lldb-dap"),
}

-- Use the VSCode-style codelldb adapter when the binary exists, otherwise fall
-- back to lldb-dap (pacman `lldb`), otherwise let mason install codelldb.
local use_codelldb = sys.codelldb or not sys.lldb_dap
local use_lldb_dap = sys.lldb_dap and not sys.codelldb

-- Tools mason should install (only what the system does not provide).
-- LSP servers are NOT listed here: mason-lspconfig installs them (see `mason`
-- in opts.servers), and codelldb is installed by mason-nvim-dap.
local mason_tools = {}
local function need(tool, provided)
  if not provided then
    mason_tools[#mason_tools + 1] = tool
  end
end
need("clang-format", sys.clang_format) -- used by conform for C/C++
need("cmakelang", sys.cmake_format) -- provides cmake-format
need("cmakelint", sys.cmakelint)

return {
  -- Disable flash.nvim (the `s` quick-jump plugin)
  { "folke/flash.nvim", enabled = false },

  -- Treesitter parsers for C/C++/CMake/QML/GLSL
  -- ("c", "cpp" and "cmake" are already pulled in by the clangd/cmake extras)
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "cpp", "cmake", "qmljs", "glsl" },
    },
  },

  -- C/C++/QML/CMake language servers
  {
    "neovim/nvim-lspconfig",
    opts = {
      -- 关闭 C/C++ 的 LSP inlay hints。
      -- clangd 每次打开文件/修改后都会为整个文件请求一次 inlayHint；
      -- Qt 头文件很大时，这一步经常要几秒到十几秒，是打开文件后 CPU 飙高的
      -- 主要原因之一。需要时仍可用 LazyVim 的 <leader>uh 临时打开。
      inlay_hints = {
        enabled = true,
        exclude = { "vue", "c", "cpp", "objc", "objcpp", "cuda" },
      },
      servers = {
        -- use the system clangd when present (skip mason download)
        clangd = {
          mason = not sys.clangd,
          -- 低占用：打开项目文件时，clangd 的解析和索引是主要 CPU 来源。
          -- 下面这组参数只保留编辑当前文件所需的功能。
          cmd = {
            "clangd",
            -- 关闭后台索引。默认会索引整个项目和 C++ 标准库，打开一个 Qt
            -- 文件后可能持续占满一个核心 1~2 分钟。
            -- 需要跨文件索引时，把它改成 "--background-index"。
            "--background-index",
            "--j=1", -- 后台索引只用 1 个线程（默认 = CPU 核数）；关闭索引时无影响
            "--pch-storage=disk", -- preamble 放磁盘，省内存
            "--malloc-trim", -- 定期归还内存给系统
            "--header-insertion=iwyu",
            "--completion-style=detailed",
            -- clangd 23 要求这里必须给布尔值；不写值会直接报 invalid。
            "--function-arg-placeholders=1",
            "--fallback-style=llvm",
            -- 不要加 --clang-tidy：它会在每次解析后跑 clang-tidy，
            -- 在 Qt 头文件较多的项目里 CPU 开销非常明显。
          },
          init_options = {
            clangdFileStatus = true,
          },
        },
        -- Arch ships qmlls as `qmlls6` (qt6-declarative)
        qmlls = {
          mason = not sys.qmlls,
          cmd = { have("qmlls6") and "qmlls6" or "qmlls" },
        },
        neocmake = { mason = not sys.neocmakelsp },
      },
    },
  },

  -- Formatting: clang-format for C/C++, cmake-format for CMake
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        c = { "clang_format" },
        cpp = { "clang_format" },
        cmake = { "cmake_format" },
      },
    },
  },

  -- Debugger: prefer the system adapter, only use mason-nvim-dap as fallback
  {
    "jay-babu/mason-nvim-dap.nvim",
    optional = true,
    opts = {
      automatic_installation = use_codelldb and { exclude = {} } or { exclude = { "codelldb" } },
    },
  },
  {
    "mfussenegger/nvim-dap",
    optional = true,
    config = function()
      if use_lldb_dap then
        local dap = require("dap")
        dap.adapters.lldb = {
          type = "executable",
          command = "lldb-dap",
          name = "lldb",
        }
        for _, lang in ipairs({ "c", "cpp" }) do
          dap.configurations[lang] = {
            {
              name = "Launch (lldb-dap)",
              type = "lldb",
              request = "launch",
              program = function()
                return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/build/", "file")
              end,
              cwd = "${workspaceFolder}",
              stopOnEntry = false,
            },
          }
        end
      end
    end,
  },

  -- Extra binaries installed by mason.
  -- NOTE: mason's `ensure_installed` is concatenated from LazyVim, the extras
  -- and this file, so a package must never be listed twice nor listed when
  -- another installer already handles it, otherwise mason raises
  -- "Package is already installing". Hence: filter first, then add, then dedupe.
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      local removed = {
        codelldb = true, -- mason-nvim-dap (dap.core extra)
        clangd = true, -- mason-lspconfig (lspconfig opts.servers)
        qmlls = true, -- mason-lspconfig
        neocmakelsp = true, -- mason-lspconfig (neocmake)
        cmakelang = sys.cmake_format, -- formatter already on the system
        cmakelint = sys.cmakelint, -- linter already on the system
      }

      local seen, tools = {}, {}
      local function add(tool)
        if tool and not seen[tool] and not removed[tool] then
          seen[tool] = true
          tools[#tools + 1] = tool
        end
      end
      for _, tool in ipairs(opts.ensure_installed or {}) do
        add(tool)
      end
      for _, tool in ipairs(mason_tools) do
        add(tool)
      end
      opts.ensure_installed = tools
    end,
  },
}

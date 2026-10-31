# Qt / C++ 项目 clangd 报错排查指南

> 适用环境：Arch Linux + Neovim(LazyVim) + clangd + Qt6（方法同样适用于 Qt5、Ubuntu/Debian）
> 本文档解决的核心问题：编辑器报 `'QString' file not found`、`Unknown type name 'QString'` 之类的假错误。

---

## 0. 一句话结论

**99% 的这类报错不是代码问题，而是 clangd 没拿到编译参数（include 路径、宏定义）。**
给 clangd 一份 `compile_commands.json`，问题就消失了。

---

## 1. 典型症状

打开文件浏览器时看到：

```
└╴󰫵  default.h
  ├╴  'QString' file not found            clang (pp_file_not_found)  [2, 10]
  ├╴  Unknown type name 'QString'         clang (unknown_typename)   [6, 14]
  └╴  Unknown type name 'QString'         clang (unknown_typename)   [18, 14]
```

类似的还有：

| 报错 | 真正原因 |
|------|----------|
| `'QString' file not found` | 缺少 `-I/usr/include/qt6/QtCore` |
| `Unknown type name 'QString'` | 同上（头文件没找到导致类型未知） |
| `'ui_mainwindow.h' file not found` | AUTOUIC 生成文件在 `build/` 里，clangd 不知道 |
| `Use of undeclared identifier 'signals'` | 缺少 Qt 的宏定义 |
| `No such file or directory: 'QApplication'` | 没有 include 路径，或用了错误的 Qt 版本 |

但 `cmake --build build` 却能编译通过 —— 这就是判断依据：
**构建能过、编辑器报错 ⇒ 编辑器（clangd）缺参数，不是工程问题。**

---

## 2. 原理：clangd 从哪儿拿参数

clangd 的优先级：

1. `compile_commands.json`（编译数据库）里该文件的编译命令 → **最准确**
2. 找不到该文件时，借用**同目录或上层目录**某个 `.cpp` 的命令（header 推断）
3. 都没有 → 用兜底参数（几乎没有 include 路径）→ 于是 Qt 头文件全找不到
4. `.clangd` 配置文件里的 `CompileFlags` 可以对 1/2 的结果做**追加/删除**（对 3 也生效）

所以解决方案就是：**生成 1，或兜底 4**。

---

## 3. 方案 A：CMake 工程（推荐）

### 3.1 生成编译数据库

```bash
cd <项目根目录>
cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
```

- 必须在 **配置阶段** 加这个参数，它会被写进 `build/CMakeCache.txt`，以后重新 configure 都会保留。
- 生成结果：`build/compile_commands.json`

### 3.2 让 clangd 找得到它（关键一步）

clangd 只从**被打开文件的目录向上**找 `compile_commands.json`。
`src/ui/qss/default.h` 的上层目录里没有，所以要在项目根目录放一个：

```bash
ln -sfn build/compile_commands.json compile_commands.json
```

- 用软链而不是拷贝：CMake 重新生成时会覆盖目标文件，软链自动跟随，永不失效。
- 也可以写成相对路径 `ln -sfn build/compile_commands.json .` 效果一样。

### 3.3 一劳永逸：写进 CMakeLists.txt

在项目根 `CMakeLists.txt` 的 `project()` 之后加：

```cmake
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
```

这样即使别人用默认命令 `cmake -B build` 也会生成，不用记参数。

### 3.4 新建文件后

新增 `.cpp` / 新增 target 后，重新跑一次配置即可（不需要重新编译）：

```bash
cmake -S . -B build
```

> 只改代码、不改 `CMakeLists.txt` 的话，构建时也会自动重新生成。

---

## 4. 方案 B：qmake 工程（`.pro`）

qmake 不产出编译数据库，用第三方工具从编译过程**录制**一份：

```bash
# 方式 1：bear（最常用）
sudo pacman -S --needed bear
cd <项目根目录>
bear -- make -j$(nproc)

# 方式 2：compiledb（纯 Python）
pipx install compiledb      # 或 pip install --user compiledb
compiledb make -j$(nproc)
```

生成后在项目根目录得到 `compile_commands.json`，直接生效（不用软链）。

> 注意：must 是「编译」而不是「配置」，即需要真的跑一次 `make`。

---

## 5. 方案 C：Meson / Ninja / 其它

| 构建系统 | 做法 |
|----------|------|
| Meson | `meson setup build` 自动生成 `build/compile_commands.json` |
| CMake+Ninja | 同方案 A（`-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`） |
| 手写 Makefile | `bear -- make` |
| Bazel | `bazel run @hedron_compile_commands//:refresh_all` |

同样需要在项目根目录建软链（Meson 可 `ln -sfn build/compile_commands.json .`）。

---

## 6. 方案 D：手写 `.clangd`（没有构建系统 / 纯头文件库）

在项目根目录建 `.clangd`，直接给 clangd 灌参数。**Qt6 完整示例**：

```yaml
# .clangd
CompileFlags:
  Compiler: /usr/bin/clang++        # 可选，默认用 compile_commands.json 里的编译器
  Add:
    - -std=c++17
    - -fPIC
    # Qt 头文件（Qt6；Qt5 请换成 /usr/include/qt5）
    - -I/usr/include/qt6
    - -I/usr/include/qt6/QtCore
    - -I/usr/include/qt6/QtGui
    - -I/usr/include/qt6/QtWidgets
    - -I/usr/include/qt6/QtNetwork
    - -I/usr/include/qt6/QtSql
    # mkspecs（Qt 必须）
    - -I/usr/lib/qt6/mkspecs/linux-g++
    # Qt 常用宏
    - -DQT_CORE_LIB
    - -DQT_GUI_LIB
    - -DQT_WIDGETS_LIB
    - -DQT_NETWORK_LIB
    - -DQT_SQL_LIB
    # 自己的源码目录
    - -I.
    - -Isrc
```

**只想让 clangd 去别处读编译数据库**（例如 build 目录不叫 build）：

```yaml
CompileFlags:
  CompilationDatabase: /abs/path/to/build      # 或相对项目根的路径
```

**想删掉编译数据库里某些碍事的参数**（例如 gcc 专有的 `-mno-direct-extern-access`）：

```yaml
CompileFlags:
  Remove:
    - -mno-direct-extern-access
```

**诊断调速**（clangd 默认报错很多，可关掉不需要的）：

```yaml
Diagnostics:
  ClangTidy:
    Remove:
      - modernize-*
      - readability-*
```

> 提示：`$HOME/.config/clangd/config.yaml` 是**全局**配置，`<项目>/.clangd` 是**项目**配置，项目优先。

---

## 7. 在 Neovim 中验证与生效

### 7.1 先确认 clangd 真的附着上了

Neovim 0.11+ 没有 `:LspInfo` 了，用：

```vim
:checkhealth vim.lsp
```

或用本配置的快捷键 `<leader>cl`（LSP 信息选择器）。

正常应该看到：

```
- clangd (id: 1, root_dir: /home/you/project)
```

**root_dir 必须是项目根目录**（能包含 `compile_commands.json` 的那层）。如果是 `/home/you` 或 `/`，说明 root 判断错了，去检查项目里有没有 `.git`、`compile_commands.json`。

### 7.2 命令行直接验证（不依赖编辑器）

```bash
cd <项目根目录>
clangd --check=src/ui/qss/default.h --compile-commands-dir=build
```

末尾出现 `All checks completed, 0 errors` 就说明参数正确：

```
I[...] Loaded compilation database from .../build/compile_commands.json
I[...] internal (cc1) args are: ... -isystem /usr/include/qt6/QtCore ... -D QT_CORE_LIB ...
I[...] All checks completed, 0 errors
```

如果还能看到 `-isystem /usr/include/qt6/...`，说明 Qt 路径已经进来了。

### 7.3 让改动生效（重启 clangd）

Neovim 0.12 删除了 `:LspRestart`，用这段 lua：

```vim
:lua vim.lsp.stop_client(vim.lsp.get_clients({ name = "clangd" }))
```

然后在文件里 `:edit`（或移动光标触发重开）就会自动重新启动 clangd。
最省事的做法：`:qa` 重开 Neovim。

### 7.4 看 clangd 日志

```vim
:lua print(vim.lsp.log.get_filename())    " 日志路径，通常是 ~/.local/state/nvim/lsp.log
:lua vim.lsp.set_log_level("debug")       " 临时开调试
```

日志里搜 `Loaded compilation database`，能看到它到底读了哪个文件。

### 7.5 本配置提供的相关快捷键

| 按键 | 作用 |
|------|------|
| `<C-l>` | 打开并聚焦错误窗口（Trouble diagnostics）；已打开时直接关闭 |
| `<F2>` | 跳转到光标下符号的实现 / 定义（clangd） |
| `<F4>` | 头文件 ↔ 源文件切换 |
| `<A-z>` | 查看光标下符号的引用（静态快照，不受光标移动影响，`<CR>` 跳转） |
| `<F8>` | 打开/关闭当前文件的符号索引（Outline） |
| `<leader>cl` | LSP 信息（看 clangd 有没有附着、root 对不对） |
| `gd` / `gr` / `gI` | 定义 / 引用 / 实现 |

---

## 8. 常见问题速查表

### 8.1 生成的文件（`ui_*.h`、`moc_*`、`*_autogen`）找不到

它们是 CMake 的 AUTOUIC/AUTOMOC 在 `build/` 里生成的。只要 `compile_commands.json` 里有 `-I.../xxx_autogen/include`，clangd 就能找到。
**所以不要只给 `-I/usr/include/qt6`，一定要用方案 A 生成数据库。**
另外：**不要**把 `build/` 加进 `.gitignore` 之后就删除它——clangd 依赖它里面的生成头文件。

### 8.2 用的是 `build/` 里的生成文件，报错一堆

```vim
:set noreadonly
" 别编辑 build/ 里的文件，去编辑 src/ 里的源文件
```

### 8.3 `signals` / `slots` 报错

Qt 的宏来自 `-DQT_CORE_LIB` 等定义 + `QtCore/qobjectdefs.h`。通常 `compile_commands.json` 里有。
如果手动写 `.clangd`，确保加了对应的 `-DQT_*_LIB`。
若项目用 `QT_NO_KEYWORDS`（强制用 `Q_SIGNALS`），则要加 `-DQT_NO_KEYWORDS`。

### 8.4 Qt5 和 Qt6 混装，包含错了版本

Qt5 头文件在 `/usr/include/qt5`，Qt6 在 `/usr/include/qt6`，mkspecs 分别在 `/usr/lib/qt5|qt6/mkspecs/linux-g++`。
CMake 指定版本：

```bash
cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
      -DCMAKE_PREFIX_PATH=/usr/lib/cmake/Qt6      # 或 Qt5
```

或者 `find_package(QT NAMES Qt6 Qt5 ...)` 里调整顺序。
**改完 Qt 版本一定要重新生成 `compile_commands.json`。**

### 8.5 头文件 / 头文件-only 目录（`default.h` 这种）

目录里没有 `.cpp` 时，clangd 会借用上层目录某个 TU 的参数，通常没问题。
如果某个头文件解析异常，用方案 D 在项目根加 `.clangd`，或者给该目录加一个空的 `dummy.cpp`：

```bash
touch src/ui/qss/dummy.cpp     # 然后重新 cmake，让它进数据库
```

### 8.6 clangd 太吃内存 / 后台索引很卡

```yaml
# .clangd
Index:
  Background: Skip      # 或 Build
```

启动参数里也可以关闭后台索引（本配置 `lua/plugins/qt-cpp.lua` 已默认使用
`--background-index=0`，同时关闭了 `--clang-tidy` 和 C/C++ 的 inlay hints）。
如果更看重跨文件跳转，可以把 clangd 的 `--background-index=0` 改回
`--background-index`，但打开项目时会重新索引 C++ 标准库，CPU 会明显升高。
另外也可以给 clangd 限制线程：

```yaml
# .clangd
Diagnostics:
  ClangTidy:
    Remove: [ "*" ]
```

### 8.7 clangd 找错了编译数据库

多份 `compile_commands.json`（例如 `build/` 和 `build-debug/`）时，在项目根 `.clangd` 里明确指定：

```yaml
CompileFlags:
  CompilationDatabase: build-debug
```

### 8.8 打开的是 git worktree / 软链目录

clangd 解析的是**真实路径**，软链目录可能导致 root 判断异常。
`<leader>cl` 看 root_dir，必要时 `cd` 到真实路径再打开。

---

## 9. 附：某个真实项目的修复记录

项目：`~/gitee/copya`（Qt6 Widgets，CMake）

**修复前**

```
build/ 存在（CMakeCache.txt、Makefile 都有）
build/compile_commands.json  → 不存在
症状：src/ui/qss/default.h 报 'QString' file not found
```

**执行**

```bash
cd ~/gitee/copya
cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
ln -sfn build/compile_commands.json compile_commands.json
```

**修复后**

```
compile_commands.json: 14 个编译单元
  含 -isystem /usr/include/qt6/QtCore -isystem /usr/include/qt6/QtWidgets
     -D QT_CORE_LIB -D QT_GUI_LIB -D QT_WIDGETS_LIB

clangd --check=src/ui/qss/default.h --compile-commands-dir=build
  →  All checks completed, 0 errors

nvim src/ui/qss/default.h
  →  clangd root_dir: /home/kemil/gitee/copya
  →  diagnostics: 0
```

---

## 10. 三步走检查清单（遇到同类问题照做）

1. `ls build/compile_commands.json` —— 有没有？没有 → 方案 A/B/C 生成。
2. `ls compile_commands.json`（项目根）—— 有没有？没有 → `ln -sfn build/compile_commands.json .`
3. `clangd --check=<报错的文件> --compile-commands-dir=build` —— `0 errors`？
   - 是 → 回 Neovim 重启 clangd（7.3）。
   - 否 → 看日志里缺什么参数（通常是 Qt 路径或 `-DQT_*_LIB`），用 `.clangd` 补（方案 D）。

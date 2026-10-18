## niri - CopyQ 配置教程

---

## 📦 基础配置与界面设置

CopyQ 启动后会驻留在系统托盘，自动记录剪贴板历史。主窗口打开方式：默认快捷键 `Ctrl+Shift+V`，或命令行 `copyq toggle`。

**打开首选项**：在主窗口中按 `Ctrl+P`。

### 常用全局快捷键（可在“首选项 → 快捷键”中修改）

| 功能            | 默认快捷键                             |
| --------------- | -------------------------------------- |
| 显示/隐藏主窗口 | `Alt + .`（部分版本为 `Ctrl+Shift+V`） |
| 显示托盘菜单    | `Alt + ,`                              |

### 主窗口内的核心操作

| 操作                     | 快捷键       |
| ------------------------ | ------------ |
| 将选中项目粘贴到当前窗口 | `Enter`      |
| 编辑选中项目             | `F2`         |
| 删除项目                 | `Delete`     |
| 搜索/过滤                | 直接输入文字 |
| 新建标签页               | `Ctrl+T`     |

在首选项的 **“历史”** 或 **“条目”** 中，可以调整保存的历史条数上限。如果你的复制内容包含敏感信息，可以在 **“忽略窗口”** 中添加窗口标题，避免密码等内容被 CopyQ 记录。

---

## 🪟 niri 窗口规则：让 CopyQ 始终浮动

这是你在之前对话中尝试配置的部分。要让 CopyQ 窗口在 niri 中以浮动方式打开，需要使用 `window-rule`。

### 第一步：确认 CopyQ 的 `app-id`

不同安装方式（原生包 vs Flatpak）的 app-id 可能不同。先启动 CopyQ，然后在终端运行：

```bash
niri msg windows
```

在输出中找到 CopyQ 对应的条目，记录 **App ID** 的值。常见值可能是 `copyq`、`com.github.hluk.copyq` 等。

### 第二步：编写 window-rule

在 `~/.config/niri/config.kdl` 的**顶层**（`binds` 块之外）添加：

```kdl
window-rule {
    match app-id=r#"copyq"#
    open-floating true
}
```

这里使用了原始字符串 `r#"..."#` 包裹，`copyq` 会作为**正则表达式**进行**包含匹配**，因此即使实际 app-id 是 `com.github.hluk.copyq`，只要其中含有 `copyq` 也能匹配上，比精确匹配更不容易出错。

### 可选：固定浮窗位置

如果希望 CopyQ 每次出现在屏幕的同一位置，可以加上 `default-floating-position`：

```kdl
window-rule {
    match app-id=r#"copyq"#
    open-floating true
    default-floating-position x=100 y=200 relative-to="bottom-left"
}
```

`relative-to` 设为 `bottom-left` 表示坐标从屏幕左下角起算，比绝对坐标在不同分辨率下更灵活。

保存后运行 `niri validate` 检查语法，通过后 niri 通常会自动重载。

---

## 🚀 自启动与快捷键集成

### 自启动

在 `config.kdl` 顶层添加：

```kdl
spawn-at-startup "copyq"
```

`spawn-at-startup` 只在 niri **会话启动时**执行一次，`niri msg action reload-config` 不会重新触发它。修改自启动项后，需要**注销并重新登录 niri** 才会生效。

### 绑定 `Ctrl+`` 为 `copyq toggle

**注意**：niri 配置中**只能存在一个 `binds {}` 块**。找到文件中已有的那个 `binds` 块，在其中添加一行：

```kdl
binds {
    // ... 你已有的其他快捷键 ...

    Ctrl+Grave { spawn "copyq" "toggle"; }
}
```

反引号 `` ` `` 在 XKB 键名中对应 `Grave`。`copyq toggle` 的作用是“显示或隐藏主窗口”，与 `copyq -e "toggle()"` 等价。

---

## ⚙️ CopyQ 进阶功能

### 命令与脚本（F6）

在主窗口按 `F6` 打开**命令管理器**，可以添加自定义命令、绑定快捷键或设置自动触发条件。常用示例：

- **自动归类链接**：新建“自动执行”命令，内容填 `^(https?|ftp)://`，动作为“移动到指定标签并删除原项目”。
- **删除所有非固定项目**（`Ctrl+Del`）：`copyq: var items = Array.apply(0, Array(size())).map(function(_, i){ return i; }).filter(function(row){ return !plugins.itempinned.isPinned(row) }); if (items.length > 0) { remove.apply(this, items) }`

### 命令行常用子命令

除了 `toggle`，以下命令在脚本或 niri 快捷键中也很实用：

| 命令                  | 作用                       |
| --------------------- | -------------------------- |
| `copyq show [标签名]` | 显示主窗口并打开指定标签页 |
| `copyq hide`          | 隐藏主窗口                 |
| `copyq paste`         | 将剪贴板内容粘贴到当前窗口 |
| `copyq copy "文本"`   | 设置剪贴板文本             |
| `copyq count`         | 输出当前标签页的项目数量   |

---

## 🎨 主题与外观（可选）

在首选项的 **“外观”** 标签页中，可以加载或编辑主题。内置主题包括 One-Dark 等。如果想微调标签页宽度，可以在“编辑主题”的 CSS 区域修改以下两项：

```css
tab_bar_tab_selected_css=padding: 0.5em 1em
tab_bar_tab_unselected_css=padding: 0.5em 1em
```

如果需要**去掉标签之间的空隙**，将 `padding` 改为 `border: 0em solid` 即可。

---

## 📋 完整 niri 配置片段汇总

把以上内容整合后，`~/.config/niri/config.kdl` 中与 CopyQ 相关的部分应包含：

```kdl
// 自启动（仅在 niri 会话启动时执行一次，修改后需注销重登）
spawn-at-startup "copyq"
# Usage: Place this file /etc/keyd/default.conf

# Causes `capslock` to behave as `control` when pressed
# and escape when tapped. Note that `control` is what
# keyd regards as a 'modifier layer'.
# See the man page for more details.

[ids]

*

[main]

capslock = overload(control, esc)
// 快捷键——合并到已有的、唯一的 binds 块中
binds {
    // ... 其他已有绑定 ...
    Ctrl+Grave { spawn "copyq" "toggle"; }
}

// 窗口规则——让 CopyQ 以浮动方式打开
window-rule {
    match app-id=r#"copyq"#
    open-floating true
}
```

如果你之前单独建过一个 `binds {}` 块，记得把它删掉，只保留文件中原有的那一个，否则会再次触发 `duplicate node 'binds'` 报错。

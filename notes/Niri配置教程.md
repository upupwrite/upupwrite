# Niri配置教程

niri 的配置围绕一个核心文件 `~/.config/niri/config.kdl` 展开，使用 **KDL 语言**编写。它的设计哲学是“一切皆可热重载”，你保存文件后，键位、布局、窗口规则等几乎所有修改都会立即生效，无需重启。下面从基础结构到核心模块，为你详细拆解。

---

### 📂 配置文件基础

**文件位置与创建**
niri 按顺序查找配置：`$XDG_CONFIG_HOME/niri/config.kdl` → `~/.config/niri/config.kdl` → `/etc/niri/config.kdl`。如果前两者都不存在，niri 会自动在首选位置生成一份**默认配置**，强烈建议你以这份默认文件为起点进行修改。

**KDL 语法要点**
KDL 的语法直观且灵活，掌握以下几点即可顺畅编写。

- **注释**：`//` 用于单行注释。`/-` 可以注释掉紧随其后的**整个节点**（常用于临时禁用一个配置块）。
- **标志（Flags）**：niri 中大量开关型选项采用“标志”模式。**写出即启用**，省略或注释掉即禁用。例如 `input { focus-follows-mouse }` 启用了“焦点跟随鼠标”，删除这行则关闭。
- **不可重复的节**：大多数配置节（如 `input`、`layout`）**只能出现一次**。但用于配置不同设备的节可以重复，例如可以为不同的 `output "eDP-1"` 和 `output "HDMI-A-1"` 分别编写配置块。
- **`binds {}` 无默认值**：这是一个关键特性：如果你完全删除 `binds {}` 节，**不会**恢复任何默认快捷键。如果你不想要任何快捷键，可以留空；否则请确保保留这个节。

**验证与热重载**

- **验证**：在应用前，务必运行 `niri validate` 来检查语法错误。
- **自定义路径**：可以通过命令行参数 `niri --config /path/to/config.kdl` 或环境变量 `$NIRI_CONFIG` 来指定其他配置文件。

---

### ⚙️ 核心配置模块详解

#### ⌨️ 输入设备 (`input { ... }`)

输入配置按设备类型组织：`keyboard`、`touchpad`、`mouse`、`trackpoint`、`tablet` 等。

**键盘配置**
最核心的是 `xkb` 子节，用于设置布局和变体。

```kdl
input {
    keyboard {
        xkb {
            layout "us"       // 键盘布局，如 "fr", "de"
            variant "intl"    // 布局变体
            options "caps:escape" // 将 Caps Lock 映射为 Escape
        }
    }
}
```

**触控板与鼠标**
常见选项包括 `tap`（点击）、`natural-scroll`（自然滚动）、`accel-speed`（加速度）和 `dwt`（打字时禁用触控板）。

```kdl
input {
    touchpad {
        tap
        natural-scroll
        accel-speed 0.2
        dwt           // 打字时禁用触摸板
    }
    mouse {
        accel-speed -0.1
    }
}
```

#### 🖥️ 输出设备 (`output "NAME" { ... }`)

每个显示器对应一个 `output` 块，需要先通过 `niri msg outputs` 命令获取显示器的确切名称（如 `"eDP-1"`）。

```kdl
output "eDP-1" {
    mode "1920x1080@120.030"  // 分辨率@刷新率
    scale 2.0                  // 缩放比例，支持小数如 1.5
    transform "90"             // 旋转角度: "normal", "90", "180", "270"
    position x=0 y=0           // 在逻辑坐标系中的位置
    variable-refresh-rate      // 启用可变刷新率(VRR)
}
```

**定位要点**：`position` 使用的坐标是**逻辑坐标**。例如，一个 3840×2160 的显示器在 `scale 2.0` 下，逻辑尺寸是 1920×1080。若要在这个显示器右侧放置另一个，其 `position x` 应设为 `1920`。

#### 📐 布局 (`layout { ... }`)

此节控制窗口的间距、宽度和居中行为。

```kdl
layout {
    gaps 16                        // 窗口内外的统一间隙
    center-focused-column "on-overflow" // "never", "always", "on-overflow"
    always-center-single-column    // 单列时总是居中

    // 预设列宽，供快捷键切换 (默认 Mod+R)
    preset-column-widths {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
        fixed 1280                 // 也可以使用固定像素宽度
    }

    // 新窗口的默认宽度；留空 {} 则由窗口自身决定
    default-column-width { proportion 0.5; }
}
```

`center-focused-column` 的 `"on-overflow"` 是一个实用默认值：只有当聚焦的列无法与前一个列同时显示时，才会将其居中。

#### 🔗 快捷键绑定 (`binds { ... }`)

快捷键定义在 `binds` 节中，格式为 `[修饰键+]按键 { 动作; }`。

**基本语法**

```kdl
binds {
    // 启动终端
    Mod+T { spawn "alacritty"; }
    // 切换焦点
    Mod+Left  { focus-column-left; }
    Mod+Right { focus-column-right; }
    // 移动窗口
    Mod+Shift+Left  { move-column-left; }
    Mod+Shift+Right { move-column-right; }
}
```

**修饰键**：`Ctrl`/`Control`, `Shift`, `Alt`, `Super`/`Win`, `Mod`。`Mod` 是一个特殊键，在 TTY 上等价于 `Super`，在嵌套运行时等价于 `Alt`，便于测试。

**查找键名**：若不确定某个键的 XKB 名称，可以使用 `wev` 工具。运行 `wev` 后按下目标键，输出中的 `sym:` 字段即为键名。

**绑定属性**
可以为绑定添加属性来调整行为：

- `repeat=false`：禁止长按重复触发。
- `cooldown-ms=500`：设置冷却时间，防止过快触发。
- `allow-when-locked=true`：使快捷键在锁屏状态下依然有效（如音量控制）。

```kdl
binds {
    Mod+T repeat=false { spawn "alacritty"; }
    XF86AudioMute allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
}
```

#### 🪟 窗口规则 (`window-rule { ... }`)

窗口规则用于根据条件自动调整特定窗口的行为。规则**按配置顺序**应用，后定义的规则会覆盖先前的设置。

**匹配 (`match`) 与排除 (`exclude`)**

```kdl
window-rule {
    // 匹配所有 Telegram 窗口
    match app-id=r#"^org\.telegram\.desktop$"#
    // 但排除媒体查看器
    exclude title="^Media viewer$"

    // 应用的属性
    open-on-output "HDMI-A-1"
}
```

`app-id` 和 `title` 的值是**正则表达式**。使用 KDL 的原始字符串 `r#"..."#` 可以避免转义反斜杠的麻烦。

**常用匹配器**：`title`, `app-id`, `is-active`, `is-focused`, `is-floating`, `is-window-cast-target` 等。

**查找窗口信息**：运行 `niri msg pick-window`，然后点击目标窗口，即可获取其 `app-id` 和 `title`，用于编写精确的匹配规则。

**常用属性**：

- `open-maximized true`
- `open-floating true`
- `default-column-width { proportion 0.5; }`
- `focus-ring { active-color "#..."; }`
- `geometry-corner-radius 12` 与 `clip-to-geometry true` 结合，可实现窗口圆角。

#### 🖼️ 层规则 (`layer-rule { ... }`)

层规则针对 `layer-shell` 客户端（如状态栏 Waybar、启动器 Fuzzel、通知守护进程）进行配置，而窗口规则针对普通应用窗口。

```kdl
layer-rule {
    match namespace="^launcher$"   // 匹配 Fuzzel 的命名空间
    shadow { on }                  // 启用 niri 绘制的阴影
    geometry-corner-radius 10      // 设置圆角
}
```

一个典型用例是为通知设置 `block-out-from "screencast"`，防止通知出现在屏幕共享中。

#### ✨ 动画 (`animations { ... }`)

动画节控制所有内置过渡效果。可以全局调整速度，也可以精细控制单个动画。

```kdl
animations {
    // 全局速度倍率；低于 1.0 会加快，高于 1.0 会减慢
    // slow-down 1.5

    workspace-switch {
        spring damping-ratio=1.0 stiffness=1000 epsilon=0.0001
    }
    window-open {
        duration-ms 150
        curve "ease-out-expo"
    }
}
```

动画支持两种驱动方式：基于**时长**（`duration-ms` + `curve`）或基于**弹簧物理**（`spring` 加 `damping-ratio`, `stiffness` 等参数）。

---

### 🧩 高级配置技巧

#### 📦 使用 `include` 拆分配置

当配置变得庞大时，可以使用 `include` 在**顶层**引入其他 KDL 文件（需要 niri 25.11+）。

```kdl
// config.kdl
include "input.kdl"
include "keybinds.kdl"
include "rules.kdl"
include "theme.kdl"

// 可选 include：文件不存在时仅警告，不报错
include optional=true "local-overrides.kdl"
```

**合并逻辑**：`include` 的位置至关重要。被包含文件的设置会在**该位置**插入，并覆盖之前已有的同名设置。但合并是**部分**的，例如 `colors.kdl` 只设置颜色，不会重置你之前在主文件中设置的 `gaps`。

#### 🔄 动画与外观微调

除了上文的基础示例，你还可以探索更精细的控制，例如为 `horizontal-view-movement`（水平视口移动）或 `window-close` 设置不同的弹簧参数，以获得更贴合个人手感的滚动手感。

---

### 💎 总结与建议

niri 配置的核心逻辑可以概括为：**以默认配置为蓝本，用 KDL 语法按模块（输入/输出/布局/键位/规则）进行声明式修改，并依赖热重载即时验证效果**。

一个高效的配置流程是：

1. **备份默认配置**：`cp ~/.config/niri/config.kdl ~/.config/niri/config.kdl.bak`。
2. **小步修改**：每次集中调整一个模块（例如先搞定键盘布局和基础键位）。
3. **即时验证**：保存文件后，立即测试行为是否符合预期。若未生效，运行 `niri validate` 检查语法。
4. **善用工具**：用 `niri msg outputs` 获取显示器名，用 `niri msg pick-window` 获取窗口的 `app-id`/`title`，让规则编写更精确。
5. **适时拆分**：当配置文件超过几百行后，考虑使用 `include` 按功能拆分，保持可维护性。





# 精细配置

## Alt+F4

将 `Alt+F4` 配置为关闭窗口，只需要在 `binds {}` 节中添加一行即可。

### ⌨️ 配置代码

在 `~/.config/niri/config.kdl` 的 `binds` 块内，加入以下内容：

```kdl
binds {
    // 使用 Alt+F4 关闭窗口
    Alt+F4 { close-window; }
}
```

保存文件后，niri 会**自动热重载**，`Alt+F4` 即刻生效，无需重启。

### 💡 关键细节

**`repeat=false` 属性（推荐）**

默认情况下，按住快捷键会重复触发动作。对于关闭窗口这类操作，持续按住 `Alt+F4` 可能会导致误关多个窗口。参照默认配置中 `Mod+Q` 的做法，建议加上 `repeat=false` 来禁用长按重复：

```kdl
binds {
    Alt+F4 repeat=false { close-window; }
}
```

这样，按住 `Alt+F4` 时只会关闭当前窗口一次，需要再次关闭时必须重新按下快捷键。

### ⚠️ 关于 `Alt` 与 `Mod` 的区别

你明确指定了 `Alt+F4`，这里的 `Alt` 就是键盘上的 **Alt** 键本身，与 niri 中特殊的 `Mod` 修饰键无关。`Mod` 在 TTY 环境下映射为 `Super`，嵌套运行时映射为 `Alt`。如果你希望快捷键在两种环境下行为一致，才需要使用 `Mod`；而 `Alt+F4` 的写法在任何环境下都固定使用 Alt 键。



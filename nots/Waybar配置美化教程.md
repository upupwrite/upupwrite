# Waybar配置美化教程

Waybar 的配置遵循一条清晰的分工：**`config.jsonc` 决定“有什么、放在哪、怎么工作”，`style.css` 决定“长什么样”**。理解这条分界线后，美化就不会陷入“改了一个地方却不知道影响了什么”的困境。

---

## 📂 先理清两个文件

配置文件放在 `~/.config/waybar/` 下，核心只有两个文件：

- **`config.jsonc`** ：JSONC 格式（JSON + 注释），控制模块选择、位置、点击行为、自定义脚本等。
- **`style.css`** ：标准 CSS，控制颜色、圆角、间距、字体、动画、悬停效果。

如果目录不存在，创建它：

```bash
mkdir -p ~/.config/waybar
touch ~/.config/waybar/config.jsonc ~/.config/waybar/style.css
```

一个最小可用的 `config.jsonc` 长这样，可以先复制进去确认 Waybar 能正常显示：

```jsonc
{
  "layer": "top",
  "position": "top",
  "modules-left": ["clock"],
  "modules-center": ["hyprland/workspaces"],
  "modules-right": ["cpu", "memory", "battery"]
}
```

> Hyprland 用户注意：workspace 模块用 `hyprland/workspaces`；如果是 Sway，把前缀换成 `sway/`。

## 🧩 config.jsonc：模块与布局

### 📍 三个区域与基础参数

Waybar 把模块分成左、中、右三个区域，分别用 `modules-left`、`modules-center`、`modules-right` 定义。常用基础参数：

| 参数                                          | 作用                           | 示例                                        |
| --------------------------------------------- | ------------------------------ | ------------------------------------------- |
| `position`                                    | 栏的位置                       | `"top"` / `"bottom"` / `"left"` / `"right"` |
| `height`                                      | 栏的高度（像素）               | `32`                                        |
| `spacing`                                     | 模块之间的间距                 | `8`                                         |
| `margin-top` / `margin-left` / `margin-right` | 栏的外边距，常用于“浮动条”效果 | `4` / `8` / `8`                             |
| `layer`                                       | 层级，`top` 会盖在窗口上方     | `"top"`                                     |

### 🧱 模块的单独配置

每个模块可以在 config 中用同名键单独配置格式和行为。例如时钟和电池：

```jsonc
{
  "clock": {
    "format": "{:%H:%M}",
    "format-alt": "{:%a, %d %b %H:%M}",
    "tooltip-format": "{calendar}"
  },
  "battery": {
    "format": "{capacity}% {icon}",
    "format-icons": ["", "", "", "", ""],
    "warning": 30,
    "critical": 15
  }
}
```

### 🔁 同一模块的多个实例

如果需要在两个位置使用同一个模块（比如两块电池），用 `#` 后缀区分：

```jsonc
"modules-right": ["battery", "battery#bat2"],
"battery#bat2": {
  "bat": "BAT2",
  "format": "{capacity}%"
}
```

### 🧩 用 group 做“分岛”或 pill 组合

想把左、中、右各组做成独立的圆角区块，可以利用 `group` 把模块包起来，再在 CSS 中把整组作为一个容器来美化。常见的“三岛式”浮动栏就是这样实现的：三个组各自有背景和圆角，组与组之间留出空隙。

```jsonc
"group/left": {
  "orientation": "horizontal",
  "modules": ["hyprland/workspaces"]
},
"group/center": {
  "orientation": "horizontal",
  "modules": ["clock"]
},
"group/right": {
  "orientation": "horizontal",
  "modules": ["cpu", "memory", "battery"]
}
```

然后在 `modules-left/center/right` 中分别放置 `"group/left"` 等即可。CSS 中对 `#group-left`、`#group-center`、`#group-right` 设置 `background`、`border-radius`、`padding`，就能得到彼此独立的圆角区块。

## 🎨 style.css：从“能用”到“好看”

### 🧹 基础重置与字体

Waybar 的模块会继承 GTK 的一些默认样式，先用全局规则清掉不需要的边框和圆角，再统一字体。图标能否正常显示，取决于是否安装了 **Nerd Font** 并在 `font-family` 中正确指定。

```css
* {
  border: none;
  border-radius: 0;
  font-family: "JetBrainsMono Nerd Font", "Fira Code", monospace;
  font-weight: bold;
  font-size: 14px;
  min-height: 0;
}
```

### 🪟 窗口层：背景透明或半透明

`window#waybar` 是最外层容器。如果想让壁纸透出来，把背景设为完全透明；如果想要“整条有底色”，用半透明 `rgba`：

```css
/* 完全透明：模块自己提供底色 */
window#waybar {
  background: transparent;
  color: #cdd6f4;
}

/* 或者：整条半透明底色 */
window#waybar {
  background: rgba(30, 30, 46, 0.75);
  color: #cdd6f4;
}
```

> 毛玻璃的“模糊”本身通常不由 Waybar 的 CSS 直接完成。Waybar 基于 GTK，`backdrop-filter` 的支持并不稳定；更可靠的做法是用**半透明背景**，再配合 compositor（如 Hyprland）的模糊规则来获得磨砂效果。

### 📦 模块层：pill 形状与浮动感

pill 风格的核心就是四个属性：**背景、圆角、内边距、外边距**。把常用模块写在一起，逐项调整：

```css
#clock,
#battery,
#cpu,
#memory,
#network,
#pulseaudio,
#tray {
  background: #1e1e2e;
  color: #cdd6f4;
  padding: 4px 14px;
  margin: 4px 4px;
  border-radius: 12px;
}
```

- `padding` 控制“pill”的胖瘦，水平方向大一些会更有胶囊感。
- `margin` 控制模块之间的呼吸空间；设为 `4px 4px` 就足以让它们看起来像独立的小块。
- `border-radius` 设为高度的一半左右（比如高度 32、圆角 12～16）会比较自然。

### 🎯 分区域差异化圆角

如果想让左、中、右看起来像三块独立的“岛”，可以分别给 `#group-left`、`#group-center`、`#group-right` 设置背景和圆角，并调整它们的外边距：

```css
#group-left,
#group-center,
#group-right {
  background: #1e1e2e;
  border-radius: 14px;
  margin: 4px 6px;
  padding: 2px 6px;
}
```

### 🖱️ 悬停反馈

几乎所有模块都支持 `:hover` 伪类，用来给悬停增加颜色或背景变化：

```css
#clock:hover,
#battery:hover,
#cpu:hover {
  background: #cdd6f4;
  color: #11111b;
}
```

如果把过渡动画加在模块上，切换会更柔和：

```css
#clock,
#battery,
#cpu {
  transition: background-color 0.2s ease, color 0.2s ease;
}
```

## 🔋 动态状态：让颜色“会说话”

Waybar 的电池、CPU 等模块支持在 config 中定义 `warning` / `critical` 阈值，触发时会给对应模块加上 `.warning` / `.critical` 类，CSS 中可以直接针对状态写样式：

```jsonc
"battery": {
  "format": "{capacity}% {icon}",
  "warning": 30,
  "critical": 15
}
```

```css
#battery.warning {
  background: #f9e2af;
  color: #11111b;
}

#battery.critical {
  background: #f38ba8;
  color: #11111b;
}
```

Workspace 的常用状态类也值得单独处理：

```css
#workspaces button {
  color: #555869;
  padding: 4px 8px;
  border-radius: 8px;
}

#workspaces button.active {
  color: #1e1e2e;
  background: #a6adc8;
}

#workspaces button.urgent {
  color: #11111b;
  background: #a6e3a1;
}

#workspaces button:hover {
  background: #cdd6f4;
  color: #11111b;
}
```

> Hyprland 下活跃 workspace 的类名是 `.active`，不是旧版 Sway 的 `.focused`，如果颜色不生效先检查这里。

## 🧰 自定义模块：突破内置限制

内置模块不够用时，用 `custom/` 模块调用脚本。如果脚本输出 JSON，Waybar 可以根据内容动态改变 `text`、`tooltip`、`class` 等字段，配合 CSS 实现更细的状态反馈。

```jsonc
"custom/weather": {
  "exec": "~/.config/waybar/scripts/weather.sh",
  "return-type": "json",
  "interval": 1800,
  "format": "{}"
}
```

脚本输出示例：

```json
{"text": " 24°", "tooltip": "Clear sky", "class": "sunny"}
```

CSS 中就可以按 `#custom-weather.sunny` 等类名分别着色。如果不需要 JSON，省略 `return-type`，脚本直接输出纯文本即可。

## 🎨 主题与配色：站在现成方案上

从零配一套协调的颜色并不容易，直接用成熟的配色方案是更高效的起点。常见的 Waybar 主题包括 **Catppuccin**（Mocha / Macchiato / Frappe / Latte）、**Tokyo Night**、**Nord**、**Gruvbox**、**Rosé Pine**、**Everforest** 等。

在 `style.css` 顶部用 `@define-color` 定义变量，把“语义”和“色值”分开，换主题时只需要改这几行：

```css
@define-color bg       #1e1e2e;
@define-color fg       #cdd6f4;
@define-color accent   #89b4fa;
@define-color warning  #f9e2af;
@define-color critical #f38ba8;

window#waybar {
  background: transparent;
  color: @fg;
}

#clock,
#battery {
  background: @bg;
  color: @fg;
}

#battery.warning  { background: @warning;  color: @bg; }
#battery.critical { background: @critical; color: @bg; }
```

渐变也可以作为 accent 用于特定模块，例如时钟的 pill 背景：

```css
#clock {
  background: linear-gradient(135deg, #cba6f7, #89b4fa);
  color: #11111b;
}
```

## 🔄 调试与重载

改完配置后，不需要重启整个会话。最直接的方式：

```bash
killall waybar && waybar &
```

如果只想重新加载而不完全重启：

```bash
killall -SIGUSR2 waybar
```

如果 Waybar 没有按预期启动或样式没有生效，用调试模式查看报错：

```bash
waybar -l debug
```

常见问题排查方向：**Nerd Font 是否安装**、config 中模块名是否与 Waybar 版本匹配、CSS 选择器是否写错（比如 Hyprland 的 `.active` 误写为 `.focused`）、`rgba` 的 alpha 值是否设成了 `0` 导致背景完全透明。

## 💎 一个可以直接起步的美化骨架

把前面的要点合成一个最小可用的美化版本，可以先复制进去，再逐项调整成自己的风格。

**`config.jsonc`**

```jsonc
{
  "layer": "top",
  "position": "top",
  "height": 32,
  "spacing": 6,
  "modules-left": ["hyprland/workspaces"],
  "modules-center": ["clock"],
  "modules-right": ["cpu", "memory", "battery", "network", "pulseaudio"],
  "battery": {
    "format": "{capacity}% {icon}",
    "format-icons": ["", "", "", "", ""],
    "warning": 30,
    "critical": 15
  },
  "clock": {
    "format": "{:%H:%M}",
    "tooltip-format": "{calendar}"
  }
}
```

**`style.css`**

```css
@define-color bg       #1e1e2e;
@define-color fg       #cdd6f4;
@define-color subtext  #a6adc8;
@define-color accent   #89b4fa;
@define-color warning  #f9e2af;
@define-color critical #f38ba8;

* {
  border: none;
  border-radius: 0;
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-weight: bold;
  font-size: 13px;
  min-height: 0;
}

window#waybar {
  background: transparent;
  color: @fg;
}

#workspaces,
#clock,
#cpu,
#memory,
#battery,
#network,
#pulseaudio {
  background: @bg;
  padding: 4px 12px;
  margin: 3px 3px;
  border-radius: 10px;
  transition: background-color 0.2s ease, color 0.2s ease;
}

#workspaces button {
  color: #555869;
  padding: 2px 6px;
  border-radius: 6px;
}

#workspaces button.active {
  color: @bg;
  background: @subtext;
}

#workspaces button.urgent {
  color: @bg;
  background: @warning;
}

#workspaces button:hover,
#clock:hover,
#cpu:hover,
#battery:hover {
  background: @fg;
  color: @bg;
}

#battery.warning  { background: @warning;  color: @bg; }
#battery.critical { background: @critical; color: @bg; }

#clock {
  background: linear-gradient(135deg, #cba6f7, @accent);
  color: @bg;
}
```

这套骨架已经包含了透明底、pill 模块、悬停反馈、workspace 状态和电池状态样式。接下来可以按自己的桌面配色替换 `@define-color` 变量，或者从 Catppuccin / Tokyo Night 等主题中取色替换，逐步调出想要的效果。

# Waybar 用户操作手册

> 配置目录：`~/.config/waybar`（git 仓库）
> 本手册对应改动：右侧新增**音量调节**与**正在播放音乐**（单击打开悬浮菜单），日期改用**思源黑体**。

---

## 1. 布局总览

```
┌────────────────────────────────────────────────────────────────────────────────┐
│ 󱓻 1 2 3 4 5        █ Sunday 11:38 █    󰎆 歌名 · 歌手 █▂▄▆█▄▂ █ 󰕾 35% █ 󰍛 █ 󰁹  │
└────────────────────────────────────────────────────────────────────────────────┘
  工作区(左)      渐变色块时钟(中)             ─── 右侧模块（深浅交替色块）───
```

右侧从左到右：

| 顺序 | 模块 | 作用 |
|---|---|---|
| 1 | `group/tray-expander` | 系统托盘（点击展开） |
| 2 | `mpris` | **正在播放的音乐** |
| 3 | `custom/cava` | **音乐频谱**（cava） |
| 4 | `bluetooth` | 蓝牙 |
| 5 | `network` | 网络 |
| 6 | `wireplumber` | **音量** |
| 7 | `cpu` | CPU 占用（点击开 btop） |
| 8 | `battery` | 电量 |

### 1.1 分区与深浅配色（“一块一块”的视觉分隔）

每个模块现在都是一个**独立圆角色块**：块之间横留 5px 空隙、上下 2px，靠**底色深浅交替**区分相邻区块。

深浅用「主题前景色 + 透明度」定义，所以换主题（8 套）时深浅关系自动成立：

```css
@define-color shade1     alpha(@foreground, 0.05);   /* 最淡：蓝牙 / 音量 / 电量 */
@define-color shade2     alpha(@foreground, 0.12);   /* 中等：工作区 / 网络 / CPU */
@define-color shade3     alpha(@foreground, 0.22);   /* 备用（当前没有模块用） */
@define-color music-tint alpha(@accent,     0.14);   /* 音乐（强调色） */
@define-color cava-tint  alpha(@accent,     0.20);   /* 频谱（强调色更浓） */
```

| 模块 | 底色 |
|---|---|
| `#workspaces` | shade2 |
| `#clock` | **无色块**（直接坐在栏底色上，仅加粗） |
| `#mpris` | music-tint |
| `#custom-cava` | cava-tint（最浓的强调色） |
| `#bluetooth` / `#wireplumber` / `#battery` | shade1 |
| `#network` / `#cpu` | shade2 |

时钟保持“无块”状态；如果哪天想再给它加块，把 `#clock` 加回上面那组通用规则，并补
`#clock { background-color: @shade3; }`（`shade3` 这层就是为此预留的）。

调法：改 `style.css` 顶部那 5 个 `@define-color` 的数值即可（0.05→0.10 更明显，→0 完全隐藏）。
想要更强的“分隔感”，可以把通用规则 `margin: 2px 2.5px` 的左右加大到 `5px`。

---

## 2. 音量模块（`wireplumber`）

显示形如 `󰕾 35%`：图标表示音量档位（低 0–32% → 󰕿、中 33–65% → 󰖀、高 66–100% → 󰕾），后面是百分比。
静音时只显示 󰝟。

### 操作

| 操作 | 效果 |
|---|---|
| **左键单击** | 打开 fuzzel 悬浮调节菜单（见 §2.1） |
| **中键单击** | 静音 / 取消静音（同时弹 OSD） |
| **右键单击** | 直接打开 pavucontrol 混音器浮窗 |
| **滚轮向上 / 向下** | 音量 ±5%，**屏幕上弹 swayosd 的进度条 OSD** |
| **鼠标悬停** | 提示里显示设备名与当前音量 |

### 2.1 悬浮调节菜单（左键）

菜单由 `fuzzel` 渲染（已安装，无需额外插件），顶部信息行实时显示：**当前输出设备 / 是否静音 / 当前音量**。

| 菜单项 | 作用 |
|---|---|
| `󰝟 静音` / `󰕾 取消静音` | 切换静音（文字随状态变化） |
| `󰕾 音量 +5%` / `󰕿 音量 -5%` | 微调 |
| `设为 100/75/50/25/0%` | 一键跳档 |
| `󰓃 输出设备…` | 二级菜单：列出所有 Sink，`★` 标记当前默认，回车即切换默认输出 |
| `󰓃 打开混音器 (pavucontrol)` | 打开浮窗混音器 |
| `✕ 关闭` | 关闭菜单（`Esc` 同效） |

要点：

- **操作后菜单不关闭**，会带着新数值重新出现，可以连续点几下再按 `Esc` 退出。
- 支持键盘：直接敲「50」「静音」等关键字过滤，回车执行。
- 脚本：`scripts/audio-menu.sh`（用 `wpctl` 实现，改动即时生效，无需重启 waybar）。

### 混音器（右键 / 菜单里的「打开混音器」）

`pavucontrol` **已安装**，并且加了 niri 窗口规则，所以它现在以 **浮窗（640px 宽，居中）** 弹出，像弹窗而不是普通窗口：

```kdl
// ~/.config/niri/config.kdl
window-rule {
    match app-id=r#"org\.pulseaudio\.pavucontrol"#
    open-floating true
    default-window-height { proportion 0.65; }
    min-width 640
    max-width 640
    min-height 460
}
```

`scripts/audio-mixer.sh` 仍然保留降级链：`pavucontrol` → `pavucontrol-qt` → `pwvucontrol` → 终端 `pulsemixer` → 桌面通知。
（`pulsemixer` 也已安装，会走 alacritty 打开。）

### 颜色提示（`style.css` 中可改）

| 状态 | 表现 |
|---|---|
| 静音 | 半透明（`#wireplumber.muted`） |
| ≥ 85% | 黄色 `#f9e2af`（偏响提醒） |
| = 100% | 红色 `#f38ba8` |

### 右键混音器的行为

见上一节「混音器」。旧版降级链依然生效：`pavucontrol` → `pulsemixer`（终端）→ 桌面通知。

> 想要更现代的 PipeWire 混音器可以装 `pwvucontrol`（见 §6）。

### 常见问题

- **滚轮没反应**：确认 `pipewire-pulse` 在跑 → `systemctl --user status pipewire-pulse`
- **百分比不跟随变化**：手动验证 → `wpctl get-volume @DEFAULT_AUDIO_SINK@`
- **调的是不是当前输出设备**：本模块跟随默认 Sink，换耳机/HDMI 后会自动跟随
- 想改步长：`config.jsonc` → `"wireplumber"` → `"scroll-step": 5`
- 想允许超过 100%：把 `"max-volume"` 改成 `150`（部分设备可超推）

---

## 3. 音乐模块（`mpris`）

显示形如 `󰎆 歌名 · 歌手`：

- **播放中**：正常颜色
- **暂停**：斜体 + 半透明（`#mpris.paused`）
- **没有播放器 / 已停止**：整个模块隐藏，不占位

播放器图标按应用自动切换：默认 󰎆、Spotify 󰓇、Firefox 󰈹、Chromium 󰊯、mpv 󰐌、网易云 󰓇。

### 操作

| 操作 | 效果 |
|---|---|
| **左键单击** | 打开 fuzzel 播放器悬浮菜单（见 §3.1） |
| **中键单击** | 上一首 |
| **右键单击** | 下一首 |
| **鼠标悬停** | 播放器、状态、歌名、歌手、专辑 |

### 3.1 悬浮播放器菜单（左键）

顶部信息行显示：**歌名 / 歌手 — 专辑 / 播放状态 · 进度 · 播放器音量 · 播放器名**（进度实时刷新）。

| 菜单项 | 作用 |
|---|---|
| `⏸ 暂停` / `▶ 播放` | 播放/暂停（文字随状态变化） |
| `󰒭 下一首` / `󰒮 上一首` | 切歌 |
| `󰓛 停止` | 停止并关闭菜单 |
| `󰕾 播放器音量 +5%` / `󰕿 -5%` | 只改播放器自身音量（不动系统音量） |
| `󰒅 从头播放` | 进度归零（若已停止会顺便播放） |
| `󰆏 复制「歌名 - 歌手」` | 写入剪贴板（`wl-copy`） |
| `✕ 关闭` | 关闭菜单（`Esc` 同效） |

与音量菜单一样：**操作后菜单保持打开并刷新**，可以连点；脚本：`scripts/music-menu.sh`。

### 3.2 音乐频谱（cava）

bar 上 `#custom-cava` 是一个 12 列的实时频谱（方块字符 ▁▂▃▄▅▆▇█，强调色渲染）。
**单声道模式**：12 根柱子覆盖完整频段一遍，不是左右镜像对称的（`channels = mono`）。

- 数据源：`cava` → `scripts/cava.sh`（把 cava 的 `0-7` 数值流转成方块字符）→ waybar custom 模块。
- cava 专用配置：`~/.config/waybar/cava.conf`（不影响 `~/.config/cava` 里的全局配置）。
- 静音/无播放时显示一排 ▁（低平面），不会闪。
- 柱子数量：`cava.conf` 里的 `bars = 12`（源码注释里有说明，改完需 `pkill -USR2 -x waybar` 或等 `restart-interval` 生效）。
- 宽度：`style.css` 里 `#custom-cava { min-width: 96px; font-size: 11px; }`。

常用调参（`cava.conf`）：

| 项 | 作用 |
|---|---|
| `bars` | 柱子数量（越多越宽） |
| `framerate` | 帧率，60 流畅 / 30 省电 |
| `channels` | `mono` = 非对称整段频谱（当前）；`stereo` = 左右各半、镜像对称 |
| `[smoothing] noise_reduction` | 底噪抑制（0-100，越大越安静） |
| `autosens` | 自动增益，1 时小音量也能看出跳动 |

排障：

```bash
cava -p ~/.config/waybar/cava.conf | head -3   # 应看到 0-7 的数字流
pgrep -a cava                                  # 应由 waybar 拉起（父进程是 waybar）
```

### 显示与截断规则

`config.jsonc` → `"mpris"`：

- `title-len: 32` 歌名最多 32 字符，超出显示 `…`
- `artist-len: 18` 歌手最多 18 字符
- `dynamic-order: ["title", "artist"]` 只显示这两个字段
- 想显示进度：改成 `["title", "artist", "position", "length"]`
- 想更短：把 `title-len` 调到 20 左右
- 想让长标题自动占据剩余空间：加 `"expand": true`（不推荐，会挤压其他模块）

### 支持的播放器

依赖 `playerctl`（已安装）。一般规则：

| 播放器 | 是否需要额外操作 |
|---|---|
| Spotify / Chromium / Chrome / 网易云 | 直接可用 |
| Firefox | 直接可用（网站使用 Media Session API 时才有信息） |
| mpv | 已装 `mpv-mpris` 插件，直接可用 |
| VLC | 直接可用 |

### 排障

```bash
playerctl status            # Playing / Paused / No players found
playerctl metadata          # 看 title / artist 是否正确
playerctl --list-all        # 列出当前所有 MPRIS 播放器
```

- `No players found`：播放器没在放东西，或该播放器不支持 MPRIS
- 想固定跟随某个播放器：`"player": "spotify"`（默认 `playerctld`，会自动跟随活跃播放器）

---

## 4. 日期 / 时钟字体

时钟当前显示 `Sunday 11:38`，鼠标左键点击可在 **时间** 与 **完整日期**（`01 November W44 2026`）之间切换。

### 当前样式（= 最初的配置）

```css
/* style.css —— 与第一版一致，只是多了分区色块 */
#clock {
  font-weight: bold;
}
```

即**不覆盖字体**，跟随栏的基础字体 `JetBrainsMono Nerd Font`（等宽），仅加粗。

> 最初版本里还有一条 `margin-left: 8.75px;`（当年用来微调居中）。现在时钟是独立色块、
> 由 `.modules-center` 居中，加上这条会让色块整体右偏，所以没有恢复。想恢复就在
> `#clock` 里再加一行 `margin-left: 8.75px;`。

### 想换别的字体

机器上已装的可选字体（无需安装）：

| 字体 | 风格 |
|---|---|
| `JetBrainsMono Nerd Font` | 等宽，与其它模块统一（当前） |
| `Source Han Sans CN`（思源黑体） | 现代无衬线，中英文混排一致 |
| `Noto Serif` | 衬线，优雅、有纸质感 |
| `P052` / `C059` | 经典衬线（Palatino / Century 风格） |
| `URW Gothic` | 几何无衬线，圆润 |

改法：在 `#clock` 里加 `font-family: "字体名", monospace;`（可再配 `font-size` / `letter-spacing`），
保存后样式自动生效。

### 日期语言 / 格式

- 语言由 `LC_TIME` 决定。当前 `en_US.UTF-8` → 英文。想要中文星期：
  `LC_TIME=zh_CN.UTF-8`（需要 `locale-gen` 生成该 locale），或在 `config.jsonc` 里写死格式。
- 格式在 `config.jsonc` → `"clock"`：
  - `"format": "{:L%A %H:%M}"`（默认显示）
  - `"format-alt": "{:L%d %B W%V %Y}"`（点击后显示）
  - 例：`"{:L%m/%d %a %H:%M}"` → `11/01 Sun 11:38`

---

## 5. 改完配置怎么生效

| 目标 | 命令 |
|---|---|
| 只改了 `style.css` / 主题 | 自动生效（`reload_style_on_change: true`） |
| 改了 `config.jsonc` | `pkill -USR2 -x waybar`（重载配置） |
| 临时隐藏 / 显示整个 bar | `pkill -USR1 -x waybar` |
| 彻底重启 | `pkill -x waybar; waybar &` 或 `~/.local/bin/waybar-restart` |
| 换配色主题 | `~/.local/bin/waybar-theme gruvbox`（可选 8 套） |

---

## 6. 依赖与可选增强

### 当前已装（本配置依赖）

| 包 | 用途 |
|---|---|
| `waybar` | 主体 |
| `playerctl` | 音乐模块 + 播放器菜单 |
| `wireplumber` + `pipewire-pulse` | 音量模块 |
| `fuzzel` | **悬浮菜单渲染器**（左键单击弹的菜单） |
| `pavucontrol` | 混音器浮窗（右键） |
| `pulsemixer` | 终端混音器降级方案 |
| `mpv-mpris` | 让 mpv 出现在音乐模块 |
| `cava` | **音乐频谱**数据源（§3.2） |
| `swayosd` | 音量/亮度的屏幕 OSD 进度条（滚轮、中键静音时弹出） |
| `wl-copy`（`wl-clipboard`） | 菜单里的「复制歌名」 |
| 字体：思源黑体 / Noto CJK / JetBrainsMono Nerd Font | 日期 + 图标 |

### 已启用的联动（都写在配置里了，不用手动做）

**`swayosd`（OSD 进度条）**

- `~/.config/niri/config.kdl` 里加了开机自启：`spawn-at-startup "swayosd-server"`
- `config.jsonc` → `wireplumber` 接管了滚轮与中键：

```jsonc
"on-scroll-up":   "swayosd-client --output-volume +5 --max-volume 100",
"on-scroll-down": "swayosd-client --output-volume -5",
"on-click-middle": "swayosd-client --output-volume mute-toggle",
```

> 注意：一旦接管了滚轮，音量改由 `swayosd-client` 执行；**swayosd-server 必须运行**（已加开机自启，当前会话也已启动）。
> 若哪天 OSD 不显示但音量正常，重启它：`pkill -x swayosd-server; setsid swayosd-server >/dev/null 2>&1 &`
> 若完全无 GL 环境，用 `GSK_RENDERER=cairo swayosd-server` 启动（软件渲染）。

**`cava`（频谱）**

- `custom/cava` 模块 + `cava.conf` + `scripts/cava.sh`，详见 §3.2。

### 可选增强（未安装，按需）

**`pwvucontrol` — 更现代的 PipeWire 混音器**（AUR，需要 `yay`）

```bash
yay -S pwvucontrol
```

装完 `scripts/audio-mixer.sh` 会自动识别（顺序：`pavucontrol` → `pavucontrol-qt` → `pwvucontrol`）；想优先 pwvucontrol 就把它挪到第一个。
想让它也浮窗弹出，把 niri 规则里的 app-id 换成 `com.github.saivert.pwvucontrol`。

---

## 7. 已知事项

1. `modules-left` 目前是 `hyprland/workspaces`，但当前会话是 **niri**（`$XDG_CURRENT_DESKTOP=niri`），
   工作区数字很可能不显示。如需修复：把模块名改成 `niri/workspaces`（waybar 0.15 支持），
   并同步 `#workspaces` 相关 CSS 选择器（`#niri-workspaces`）。需要时告诉我。
2. 悬浮菜单依赖 `fuzzel`（已在用其它 fuzzel 配置的话，本脚本用命令行参数覆盖了字体/宽度，不影响你 `fuzzel.ini` 里的全局设置）。
3. `pavucontrol` 浮窗规则写在 `~/.config/niri/config.kdl`（本仓库之外），如果删除该规则就会退回普通窗口。
4. 屏幕是 **1280×800**，右侧模块空间有限：音乐模块已压缩为 `title-len 20 / artist-len 12 / max-length 34`（完整信息看 tooltip），频谱固定 12 列。
   如果实际显示挤到中间时钟，把 `config.jsonc` 里的 `max-length` 再调小到 `26`，或把 `cava.conf` 的 `bars` 改成 `8`。
2. 本目录的配置最初由 `~/github/waybar-setup/install-waybar.sh` 生成。重新运行该脚本会
   **覆盖** `config.jsonc` / `style.css`（旧文件会备份为 `*.backup.<时间戳>`）。
   本次改动已同步回该脚本模板，重跑即可得到同样的结果。

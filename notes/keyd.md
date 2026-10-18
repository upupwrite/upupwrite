## keyd

### 快速配置

```bash
sudo systemctl enable --now keyd

sudo mkdir -p /etc/keyd
sudo tee /etc/keyd/default.conf > /dev/null <<'EOF'
[ids]
*
[main]
capslock = esc
esc = capslock
EOF

sudo keyd reload
```

### 📦 安装与服务管理

不同发行版的安装方式略有差异：

- **Arch Linux / Manjaro**：`sudo pacman -S keyd`
- **Ubuntu 26.04 及以上**：已进入官方仓库，可直接 `sudo apt install keyd`
- **Fedora**：可通过 Copr 仓库安装（`sudo dnf copr enable fmonteghetti/keyd` 后安装）
- **从源码构建**：克隆官方仓库后，执行 `make && sudo make install`

服务管理使用 systemd。启动并设置开机自启：`sudo systemctl enable --now keyd`。查看运行状态：`sudo systemctl status keyd`。**每次修改配置文件后**，都需要重载配置：

```bash
sudo keyd reload
```

如果重载不生效，可以尝试完全重启服务：`sudo systemctl restart keyd`。

### ⌨️ 将 Caps Lock 映射为 Esc

这是最直接的需求。你只需要创建一个配置文件，写入一行映射即可。

**第一步：创建配置文件**

配置文件必须放在 `/etc/keyd/` 目录下，且必须以 `[ids]` 节开头。最通用的做法是创建 `default.conf`，让它对所有键盘生效：

```bash
sudo mkdir -p /etc/keyd
sudo tee /etc/keyd/default.conf > /dev/null <<'EOF'
[ids]

[main]
capslock = esc
esc = capslock
EOF
```

**第二步：启用并启动 keyd 服务**

```bash
sudo systemctl enable --now keyd
```

执行后，Caps Lock 键就会**完全变成 Esc 键**，原有的 Caps Lock 功能（大小写锁定）将被覆盖。

---

### 🔍 调试与键名发现

在编写复杂配置前，你很可能需要确认某个物理按键在 keyd 中的**标准名称**。

**查看按键名称**：运行 `sudo keyd monitor`，然后按下你想查询的键。终端会输出类似 `capslock down` / `capslock up` 的事件，其中的 `capslock` 就是该键在配置中应使用的名称。`keyd monitor` 也可用于确认键盘的设备 ID（`vid:pid`），方便你为特定键盘单独编写配置。

**查看有效键名列表**：`keyd list-keys` 会列出 keyd 支持的所有合法键名。

---

### 🗂️ 配置文件的核心结构

一个有效的 keyd 配置文件遵循类似 INI 的结构，核心组成如下：

**`[ids]` 节（必需，且必须为首节）**

用于指定这条配置作用于哪些设备。`[ids]` 下的空行（或仅写 `*` 通配）表示匹配所有被识别为键盘的设备。如果要**排除**某个被误识别为键盘的鼠标（这在 keyd 中可能导致指针异常），可以在 `[ids]` 下写入 `-设备ID`，例如 `-1234:5678`。

**层（Layers）**

层是 keyd 最核心的抽象，可以理解为“一套按键映射的集合”。`[main]` 是默认层，所有未特别指定的映射都应放在这里。通过 `layer(<层名>)` 动作，你可以临时激活另一个层。例如，实现按住 Caps Lock 时 `HJKL` 变为方向键：

```kdl
[main]
capslock = layer(nav)

[nav]
h = left
j = down
k = up
l = right
```

当你**按住** Caps Lock 时，`nav` 层被激活并覆盖 `main` 层，此时 `H/J/K/L` 输出方向键；松开 Caps Lock 后恢复正常。

**层与修饰键的结合**

层名后可以附加修饰符（`C` 代表 Control，`S` 代表 Shift，`A` 代表 Alt 等）。`[capslock:C]` 表示“当 Caps Lock 作为修饰键被按住时”的映射，同时 Caps Lock 本身在单独按下时仍可输出 `Esc`（如果配置了 `overload`）。

---

### ⚙️ 常用动作与宏

在 `=` 右侧，除了直接写另一个键名，还可以使用各种动作：

| 动作                           | 作用                                                                            |
| ------------------------------ | ------------------------------------------------------------------------------- |
| `layer(<name>)`                | 按住期间激活指定层                                                              |
| `oneshot(<name>)`              | 轻按后，下一键生效一次层功能（类似“粘滞键”）                                    |
| `overload(<修饰键>, <轻按键>)` | 按住作修饰键，轻按输出另一键（即 Caps→Ctrl/Esc 的方案）                         |
| `macro(...)`                   | 发送一段按键序列，如 `macro(C-t 100ms google.com enter)` 可打开新标签并输入网址 |
| `setlayout(<layout>)`          | 切换到 keyd 内部定义的字母布局（如 Colemak）                                    |
| `toggle(<layer>)`              | 按一次开启层，再按一次关闭                                                      |

宏中的 `100ms` 是按键间的延迟，可用于应对某些响应较慢的应用。

---

### 🔗 和弦（Chording）与组合层（Composite Layers）

**和弦**允许你将多个键的**同时按下**视为一个独立按键。例如：

```kdl
j+k = esc
```

设置后，几乎同时按下 `J` 和 `K`，就会输出 `Esc`，而不是先输出 J 再输出 K。默认的和弦判定窗口是 50 毫秒，可以在 `[global]` 中通过 `chord_timeout` 调整。

**组合层**用 `+` 连接已有层名来定义，只有当这些层**同时处于激活状态**时才生效。例如：

```kdl
[control+alt]
h = left
```

当 `Control` 层和 `Alt` 层（即按住 Ctrl 和 Alt 时）同时激活，`H` 会输出 `Left`；单独的 `Ctrl+H` 或 `Alt+H` 不受影响。

---

### 🛡️ 安全网：紧急终止序列

因为 keyd 在系统底层修改键盘输入，**一个错误的配置可能导致你完全无法使用键盘**。keyd 内置了紧急终止机制：**同时按住 `退格键` + `Esc` + `回车键`**，keyd 进程会立即被强制终止，键盘恢复正常。请在修改配置前牢记这个组合，尤其是在尝试复杂映射时。

---

### 🖥️ 与 niri / Wayland 的兼容性

keyd 在 niri 下可以正常工作，因为它的操作层级在合成器之下，不感知 Wayland 或 X11 的存在。无论是 `spawn` 启动的终端，还是在 niri 的 `binds` 中定义的快捷键，接收到的都是 keyd 重映射**之后**的按键事件。这意味着：

- 你在 `config.kdl` 中绑定的 `Ctrl+Grave`（CopyQ 切换）会使用 keyd 处理后的 `Ctrl` 和 `` ` `` 键。
- 如果使用了 `capslock = overload(control, esc)`，那么 Caps Lock 在按住时产生的 `Ctrl` **同样可以**与 niri 的快捷键配合使用（例如 `Caps + 某个 niri 绑定键`）。



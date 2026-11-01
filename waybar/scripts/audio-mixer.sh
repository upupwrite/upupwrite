#!/usr/bin/env bash
# waybar 音量模块「右键」调用：打开系统音量混合器
# 优先级：图形混音器 -> 终端混音器 -> 桌面通知
set -u

# 1) 图形界面混音器
for gui in pavucontrol pavucontrol-qt pwvucontrol; do
    if command -v "$gui" >/dev/null 2>&1; then
        setsid "$gui" >/dev/null 2>&1 &
        exit 0
    fi
done

# 2) 终端混音器（需要 pulsemixer + 任一终端）
if command -v pulsemixer >/dev/null 2>&1; then
    for term in ${TERMINAL:-} kitty alacritty foot wezterm ghostty xterm; do
        if command -v "$term" >/dev/null 2>&1; then
            setsid "$term" -e pulsemixer >/dev/null 2>&1 &
            exit 0
        fi
    done
fi

# 3) 兜底：用通知显示当前音量并提示安装
vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null |
    awk '{ printf "%d", $2 * 100 }')
muted=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -c MUTED)

if [ "$muted" = "1" ]; then
    msg="当前音量 ${vol}%（已静音）"
else
    msg="当前音量 ${vol}%"
fi

if command -v notify-send >/dev/null 2>&1; then
    notify-send -a waybar -i audio-volume-high \
        "未找到图形音量混合器" \
        "$msg"$'\n'"安装后可右键打开混音器：sudo pacman -S pavucontrol"
else
    echo "$msg"
fi

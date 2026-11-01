#!/usr/bin/env bash
# waybar custom/cava 模块的数据源
# 把 cava 的 raw ascii 输出（0-7 的数值，';' 分隔）转成方块字符流，
# 每一行就是 waybar 的一帧，实现音乐频谱。
set -u

CONF="${HOME}/.config/waybar/cava.conf"

# 未安装 cava 时不刷屏、也不让 waybar 反复重启脚本
if ! command -v cava >/dev/null 2>&1; then
    printf '%s\n' ""
    sleep 600
    exit 0
fi

exec cava -p "$CONF" 2>/dev/null |
    sed -u 's/;//g; s/0/▁/g; s/1/▂/g; s/2/▃/g; s/3/▄/g; s/4/▅/g; s/5/▆/g; s/6/▇/g; s/7/█/g'

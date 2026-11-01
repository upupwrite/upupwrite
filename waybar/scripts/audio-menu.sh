#!/usr/bin/env bash
# waybar 音量模块「左键」：fuzzel 悬浮调节菜单
# 操作后菜单保持打开并实时刷新数值，适合连续调节；Esc / 关闭 退出。
set -u

SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FUZZEL_COMMON=(--dmenu --lines=10 --width=38 --font="JetBrainsMono Nerd Font:size=11")
SINK="@DEFAULT_AUDIO_SINK@"

sink_line() {
    wpctl status | awk '/Sinks:/{f=1;next} /Sources:/{f=0} f && /[0-9]+\./'
}

sink_name() {
    sink_line | sed -n '/\*/p' |
        sed -E 's/^.*\* *[0-9]+\. //; s/ *\[vol:.*$//; s/ +$//'
}

volume_info() {
    local raw
    raw=$(wpctl get-volume "$SINK" 2>/dev/null)
    VOL_PCT=$(awk '{ printf "%d", $2 * 100 }' <<<"$raw")
    if grep -q 'MUTED' <<<"$raw"; then
        VOL_MUTED=1
    else
        VOL_MUTED=0
    fi
}

pick_sink() {
    local cur sel id
    cur=$(sink_name)
    sel=$(printf '%s\n' "$(sink_line |
        sed -E 's/^.*\* *([0-9]+)\. (.*) *\[vol:.*$/★ \1. \2/; t; s/^.*  *([0-9]+)\. (.*) *\[vol:.*$/  \1. \2/' |
        sed -E 's/ +$//')" |
        fuzzel "${FUZZEL_COMMON[@]}" --prompt="输出设备 ▸ " --mesg="当前：${cur}") || return 0
    [ -z "$sel" ] && return 0
    id=$(sed -E 's/^[^0-9]*([0-9]+)\..*/\1/' <<<"$sel")
    [ -n "$id" ] && wpctl set-default "$id" >/dev/null
}

while :; do
    volume_info
    if [ "$VOL_MUTED" = "1" ]; then
        state=" · 已静音"
        mute_label="󰕾 取消静音"
    else
        state=""
        mute_label="󰝟 静音"
    fi

    choice=$(printf '%s\n' \
        "$mute_label" \
        "󰕾 音量 +5%" \
        "󰕿 音量 -5%" \
        "  设为 100%" \
        "  设为 75%" \
        "  设为 50%" \
        "  设为 25%" \
        "  设为 0%" \
        "󰓃 输出设备…" \
        "󰓃 打开混音器 (pavucontrol)" \
        "✕ 关闭" |
        fuzzel "${FUZZEL_COMMON[@]}" \
            --prompt="音量 ${VOL_PCT}% ▸ " \
            --placeholder="选择操作" \
            --mesg="$(sink_name)${state}
当前音量 ${VOL_PCT}%") || exit 0

    case "$choice" in
    "") exit 0 ;;
    *"静音" | *"取消静音") wpctl set-mute "$SINK" toggle ;;
    *"+5%") wpctl set-volume -l 1.0 "$SINK" 5%+ ;;
    *"-5%") wpctl set-volume "$SINK" 5%- ;;
    *"设为 100%") wpctl set-volume "$SINK" 1.0 ;;
    *"设为 75%") wpctl set-volume "$SINK" 0.75 ;;
    *"设为 50%") wpctl set-volume "$SINK" 0.5 ;;
    *"设为 25%") wpctl set-volume "$SINK" 0.25 ;;
    *"设为 0%") wpctl set-volume "$SINK" 0.0 ;;
    *"输出设备…") pick_sink ;;
    *"打开混音器"*)
        "$SELF_DIR/audio-mixer.sh"
        exit 0
        ;;
    *"关闭") exit 0 ;;
    esac
done

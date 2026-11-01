#!/usr/bin/env bash
# waybar 音乐模块「左键」：fuzzel 悬浮播放器菜单
# 操作后菜单保持打开并实时刷新曲目/进度，适合连续控制；Esc / 关闭 退出。
set -u

FUZZEL_COMMON=(--dmenu --lines=10 --width=46 --font="JetBrainsMono Nerd Font:size=11")
SEP=$'\x1f'

fmt_time() { # 微秒 -> m:ss / h:mm:ss
    local us="${1:-0}"
    [ "$us" = "0" ] && {
        echo "0:00"
        return
    }
    awk -v us="$us" 'BEGIN{
        s=int(us/1000000); h=int(s/3600); m=int((s%3600)/60); s=s%60;
        if (h>0) printf "%d:%02d:%02d", h, m, s; else printf "%d:%02d", m, s
    }'
}

if ! playerctl status >/dev/null 2>&1; then
    fuzzel "${FUZZEL_COMMON[@]}" --prompt="音乐 ▸ " \
        --mesg="没有正在播放的播放器" <<<"✕ 关闭" >/dev/null 2>&1
    exit 0
fi

read_meta() {
    local raw
    raw=$(playerctl metadata --format \
        "{{title}}${SEP}{{artist}}${SEP}{{album}}${SEP}{{playerName}}${SEP}{{mpris:length}}${SEP}{{position}}" 2>/dev/null)
    IFS="$SEP" read -r M_TITLE M_ARTIST M_ALBUM M_PLAYER M_LEN M_POS <<<"$raw"
    M_STATUS=$(playerctl status 2>/dev/null || echo "Stopped")
    M_VOL=$(playerctl volume 2>/dev/null || echo "")
}

while :; do
    read_meta
    [ -n "${M_TITLE:-}" ] || M_TITLE="(无标题)"
    [ -n "${M_ARTIST:-}" ] || M_ARTIST="(未知艺术家)"

    progress=""
    case "$M_STATUS" in
    Playing | Paused)
        progress=" · $(fmt_time "${M_POS:-0}")/$(fmt_time "${M_LEN:-0}")"
        ;;
    Stopped) progress=" · 已停止" ;;
    esac

    case "$M_STATUS" in
    Playing) status_label="⏸ 暂停" ;;
    *) status_label="▶ 播放" ;;
    esac

    vol_txt=""
    [ -n "${M_VOL:-}" ] && vol_txt=$(awk -v v="$M_VOL" 'BEGIN{printf " · 播放器音量 %d%%", v*100}')

    choice=$(printf '%s\n' \
        "$status_label" \
        "󰒭 下一首" \
        "󰒮 上一首" \
        "󰓛 停止" \
        "󰕾 播放器音量 +5%" \
        "󰕿 播放器音量 -5%" \
        "󰒅 从头播放" \
        "󰆏 复制「歌名 - 歌手」" \
        "✕ 关闭" |
        fuzzel "${FUZZEL_COMMON[@]}" \
            --prompt="音乐 ▸ " \
            --placeholder="选择操作" \
            --mesg="${M_TITLE}
${M_ARTIST} — ${M_ALBUM:-未知专辑}
${M_STATUS}${progress}${vol_txt} · ${M_PLAYER}") || exit 0

    case "$choice" in
    "") exit 0 ;;
    *"+5%") playerctl volume 0.05+ ;;
    *"-5%") playerctl volume 0.05- ;;
    *"暂停" | *"播放") playerctl play-pause ;;
    *"下一首") playerctl next ;;
    *"上一首") playerctl previous ;;
    *"停止") playerctl stop && exit 0 ;;
    *"从头播放")
        playerctl position 0
        [ "$M_STATUS" != "Playing" ] && playerctl play
        ;;
    *"复制"*)
        printf '%s - %s\n' "$M_TITLE" "$M_ARTIST" | wl-copy
        ;;
    *"关闭") exit 0 ;;
    esac
done

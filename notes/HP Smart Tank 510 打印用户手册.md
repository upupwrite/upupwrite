# HP Smart Tank 510 打印用户手册

> 环境：Arch Linux · CUPS 2.4.20 · HPLIP 3.26.6 · 打印机经 USB 连接
> 队列名：`HP_SmartTank_510`（已设为系统默认打印机）

---

## 1. 当前配置速查

| 项目     | 值                                                                   |
| -------- | -------------------------------------------------------------------- |
| 型号     | HP Smart Tank 510 series                                             |
| 序列号   | CN3BU540WW                                                           |
| 连接方式 | USB（`hp:/usb/Smart_Tank_510_series?serial=CN3BU540WW`）             |
| 备选 URI | `usb://HP/Smart%20Tank%20510%20series?serial=CN3BU540WW&interface=1` |
| 驱动 PPD | `drv:///hp/hpcups.drv/hp-smart_tank_510_series.ppd`（hpcups 3.26.6） |
| 队列名   | `HP_SmartTank_510`                                                   |
| 双面打印 | **手动双面**（机身无自动双面器）：`lp --duplex 文件.pdf`，见第 5 节  |
| 默认纸张 | **A4**（已设，系统级，见 4.2；GUI 程序同样生效）                     |
| 打印服务 | `cups.service`（已 active + enabled，开机自启）                      |
| 配置文件 | `/etc/cups/printers.conf`（root 所有，勿手改，用 `lpadmin` 命令改）  |

**无需安装任何软件**：`cups`、`cups-filters`、`hplip`、`ghostscript`、`poppler` 均已在系统中。

---

## 2. 最常用：打印一个文件

```bash
cd /home/kemil/Public
lp 文件名.pdf
```

因为 `HP_SmartTank_510` 已是默认队列、且默认纸张已改为 A4，`-d` 与 `-o media=A4` 都可以省略。

如需显式指定（写在脚本里更稳妥）：

```bash
lp -d HP_SmartTank_510 -o media=A4 -o sides=one-sided -t "作业标题" 文件名.pdf
```

> 说明：本项目 PDF 原始页面是自定义小尺寸（446×632 pt ≈ 15.7×22.3 cm）。
> CUPS 会按请求的 A4 自动缩放并居中，**不需要 `fit-to-page`**——
> 实测加与不加，渲染结果完全相同（见下表）。

### 实测数据（用真实滤镜链 cupsfilter 渲染，50 dpi 量取墨迹）

| 打印方式                     | 输出页尺寸     | 内容墨迹范围                  | 结论             |
| ---------------------------- | -------------- | ----------------------------- | ---------------- |
| 仅队列默认（A4）             | 210.3×296.7 mm | 191×252 mm，四周留白约 9.5 mm | ✅ 居中缩放，正常 |
| `-o media=A4`                | 210.3×296.7 mm | 203×270 mm                    | ✅ 居中缩放，略大 |
| `-o media=A4 -o fit-to-page` | 210.3×296.7 mm | 203×270 mm                    | 与上者逐像素相同 |

三种方式都满页居中，不会出现“印在纸角”。已完成的真实作业
`HP_SmartTank_510-1`（带 `media=A4` + `fit-to-page`）1 页 1 张，校验通过。

---

## 3. 提交后可用的查询/控制命令

| 目的                 | 命令                                                           |
| -------------------- | -------------------------------------------------------------- |
| 看还有哪些作业在排队 | `lpq` 或 `lpstat -o`                                           |
| 看某台打印机状态     | `lpstat -p HP_SmartTank_510`                                   |
| 看默认打印机         | `lpstat -d`                                                    |
| 看已完成作业         | `lpstat -W completed -o`                                       |
| 看系统里可用设备     | `lpinfo -v`                                                    |
| 取消某个作业         | `cancel HP_SmartTank_510-12`（编号见 `lpq`）                   |
| 取消该打印机全部作业 | `cancel -a HP_SmartTank_510`                                   |
| 挂起/恢复队列        | `cupsdisable HP_SmartTank_510` / `cupsenable HP_SmartTank_510` |

作业提交成功会返回类似：`request id is HP_SmartTank_510-1 (1 file(s))`。
编号后面的数字就是作业号，取消、排查时用得上。

---

## 4. 修改默认打印参数（一次设置，长期生效）

### 4.1 单次生效（不影响以后）

在 `lp` 命令里直接加 `-o` 选项即可，见第 2 节。

### 4.2 永久生效（系统级默认值，已为你设好）

**现状：默认纸张已从 Letter 改为 A4**，通过修改队列 PPD 的 `DefaultPageSize` 实现，
属于**打印机级别**，所有用户、所有程序（含 GUI）都生效：

```bash
# 查看当前 PPD 默认纸张（带 * 的即为默认）
lpoptions -p HP_SmartTank_510 -l | grep '^PageSize'
# → PageSize/Media Size: 2L L 3x5 ... *A4 A5 A6 ...
```

重设 / 改回：

```bash
lpadmin -p HP_SmartTank_510 -o PageSize=A4     # 改 A4（当前值）
lpadmin -p HP_SmartTank_510 -o PageSize=Letter # 改回 Letter
lpadmin -d HP_SmartTank_510                    # 设为系统默认队列
```

> ℹ️ **两点实测结论（避免踩坑）**
>
> 1. `-o fit-to-page` / `-o print-scaling=fit` **无法存成队列默认值**：
>    cupsd 会把它当成非 PPD 选项静默丢弃（`lpadmin` 仍返回 0，但 `printers.conf` 不会写入）。
>    而且对本项目的 PDF 并无必要，A4 已经会自动缩放居中（见第 2 节实测表）。
> 2. CUPS 2.4 的 `lp` 命令**不会**应用 `~/.cups/lpoptions` 里的选项：
>    写入后 `lpoptions` 能查到，但实际提交的作业里没有这些属性（已用 IPP
>    `Get-Job-Attributes` 验证）。所以要临时改参数，请直接在 `lp` 命令加 `-o`。

### 4.3 常用选项对照表

| 选项            | 取值                                                                             | 说明                                            |
| --------------- | -------------------------------------------------------------------------------- | ----------------------------------------------- |
| `media`         | `A4` / `A5` / `A6` / `Letter` / `Legal` / `B5` / `4x6in` / `Custom.WIDTHxHEIGHT` | 纸张尺寸                                        |
| `fit-to-page`   | 开关                                                                             | 缩放到页面内；对本项目 PDF 无可见差异（可省略） |
| `print-scaling` | `auto` / `auto-fit` / `fit` / `fill` / `none`                                    | CUPS 2.4 的缩放策略                             |
| `sides`         | `one-sided` / `two-sided-long-edge` / `two-sided-short-edge`                     | 单/双面（双面详见第 5 节）                      |
| `ColorModel`    | `RGB`（彩色，默认）/ `CMYGray` / `KGray`                                         | 打黑白省墨                                      |
| `OutputMode`    | `Normal`（默认）/ `Best` / `Photo`                                               | 打印质量，越高越慢越费墨                        |
| `MediaType`     | `Plain`（默认）/ `Glossy` / `CoatedMatte` / `Brochure`                           | 纸张类型                                        |
| `InputSlot`     | `Main`                                                                           | 进纸来源（本机仅主进纸盒）                      |
| `media-type`    | `stationery` 等                                                                  | CUPS 通用纸张类型                               |
| `copies`        | 数字                                                                             | 份数，也可用 `-n 3`                             |

示例：黑白 + 2 份 + A4

```bash
lp -o media=A4 -o ColorModel=KGray -n 2 文件.pdf
```

> ⚠️ **双面注意**：驱动 PPD 里虽然列出了 `DuplexNoTumble` / `DuplexTumble`，但
> HP Smart Tank 510 机身**没有自动双面器**，真机上 `-o sides=two-sided-*` 不会自动翻面。
> 已为你安装 `lp` 包装器实现手动双面（含奇数页自动补白页），见**第 5 节**。

---

## 5. 手动双面打印（`lp` 包装器）

### 5.0 脚本内容

```bash
#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 位置: ~/.local/bin/lp
# lp 包装器：在系统 /usr/bin/lp 之上增加「手动双面打印」能力
#
#   * 打印机 HP Smart Tank 510 没有自动双面器，sides=two-sided-* 无效
#   * 先印偶数页（背面），翻纸后再印奇数页（正面），两趟均按倒序
#   * 每趟都用 -o fit-to-page 缩放到页面
#   * 页数为奇数时自动补一页白页，使正反面张数一致
#
# 用法:
#   lp --duplex 文件.pdf                     # 长边翻转（书籍式，默认）
#   lp --duplex=short 文件.pdf               # 短边翻转（便签式）
#   lp -o sides=two-sided-long-edge 文件.pdf # 等价写法（IPP 标准）
#   lp -o sides=two-sided-short-edge 文件.pdf
#   lp 文件.pdf                              # 单面，原样透传给 /usr/bin/lp
#
# 额外开关:
#   --dry-run        只打印将要执行的命令，不真的打印
#   --no-prompt      不提示「翻纸」，只等队列排空（脚本里用）
#
# 环境变量:
#   LP_REAL=/usr/bin/lp     真正的 lp
#   LP_NO_PROMPT=1          等同 --no-prompt
#   LP_DRY_RUN=1            等同 --dry-run
# ---------------------------------------------------------------------------
set -uo pipefail

REAL_LP="${LP_REAL:-/usr/bin/lp}"
DRY_RUN="${LP_DRY_RUN:-0}"
NO_PROMPT="${LP_NO_PROMPT:-0}"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/lp-manual-duplex"
mkdir -p "$CACHE_DIR"

die() { printf '\033[31m[lp]\033[0m %s\n' "$*" >&2; exit 1; }
say() { printf '\033[36m[lp]\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[33m[lp]\033[0m %s\n' "$*" >&2; }

# ------------------------------ 参数解析 -----------------------------------
duplex=""          # "" | long | short
pass_args=()       # 原样透传给真 lp 的参数
files=()

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)        DRY_RUN=1; shift ;;
    --no-prompt)      NO_PROMPT=1; shift ;;
    --duplex)         duplex=long; shift ;;
    --duplex=long)    duplex=long; shift ;;
    --duplex=short)   duplex=short; shift ;;
    --)               shift; files+=("$@"); break ;;
    -o|--option)
        [ $# -ge 2 ] || die "$1 缺少参数"
        val="$2"
        case "$val" in
          sides=two-sided-long-edge|sides=duplex)   duplex=long ;;
          sides=two-sided-short-edge)               duplex=short ;;
          *) pass_args+=(-o "$val") ;;
        esac
        shift 2 ;;
    -osides=two-sided-long-edge) duplex=long;  shift ;;
    -osides=two-sided-short-edge) duplex=short; shift ;;
    # 需要带值的短选项：整体透传，别把值误当成文件名
    -d|-n|-t|-h|-U|-P|-i|-m|-W)
        [ $# -ge 2 ] || die "$1 缺少参数"
        pass_args+=("$1" "$2"); shift 2 ;;
    -*) pass_args+=("$1"); shift ;;
    *)  files+=("$1"); shift ;;
  esac
done

[ ${#files[@]} -gt 0 ] || die "没有指定文件。用法: lp [--duplex] 文件.pdf"

# 单面：原样透传
if [ -z "$duplex" ]; then
  if [ "$DRY_RUN" = 1 ]; then
    printf '[dry-run] '; printf '%q ' "$REAL_LP" "${pass_args[@]}" "${files[@]}"; echo
    exit 0
  fi
  exec "$REAL_LP" "${pass_args[@]}" "${files[@]}"
fi

# ------------------------ 从透传参数里找打印机和份数 ------------------------
printer=""
copies=""
i=0
while [ $i -lt ${#pass_args[@]} ]; do
  case "${pass_args[$i]}" in
    -d|--printer) printer="${pass_args[$((i+1))]:-}"; i=$((i+2)) ;;
    -d*)          printer="${pass_args[$i]#-d}"; i=$((i+1)) ;;
    --printer=*)  printer="${pass_args[$i]#--printer=}"; i=$((i+1)) ;;
    -n|--copies)  copies="${pass_args[$((i+1))]:-}"; i=$((i+2)) ;;
    -n*)          copies="${pass_args[$i]#-n}"; i=$((i+1)) ;;
    *)            i=$((i+1)) ;;
  esac
done
[ -n "$printer" ] || printer=$(lpstat -d 2>/dev/null | sed -n 's/^system default destination: //p')
[ -n "$printer" ] || die "找不到默认打印机，请用 -d 队列名 指定"

# 去掉 -n/--copies，改成 -o copies=（两趟都要原件数）
clean_args=()
j=0
while [ $j -lt ${#pass_args[@]} ]; do
  case "${pass_args[$j]}" in
    -n|--copies) j=$((j+2)) ;;
    -n*)         j=$((j+1)) ;;
    * )          clean_args+=("${pass_args[$j]}"); j=$((j+1)) ;;
  esac
done
[ -n "$copies" ] && clean_args+=(-o "copies=$copies")

# ---------------------------- 白页缓存 -------------------------------------
blank_page() {
  local w="${1:-595.28}" h="${2:-841.89}" f
  f="$CACHE_DIR/blank-${w}x${h}.pdf"
  if [ ! -s "$f" ]; then
    gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile="$f" \
       -c "<</PageSize [$w $h]>> setpagedevice showpage" 2>/dev/null \
       || die "生成白页 PDF 失败"
  fi
  printf '%s' "$f"
}

page_size() {
  pdfinfo "$1" 2>/dev/null | awk '/^Page size:/{print $3, $5; exit}'
}

page_count() {
  pdfinfo "$1" 2>/dev/null | awk '/^Pages:/{print $2; exit}'
}

# ---------------------------- 队列等待 -------------------------------------
wait_drain() {
  local n=0
  while [ -n "$(lpstat -o "$printer" 2>/dev/null)" ]; do
    sleep 2; n=$((n+2))
    [ $((n % 20)) -eq 0 ] && say "  等待打印队列排空… ${n}s"
    if [ $n -ge 900 ]; then warn "等待超时（900s），请手动检查队列"; return 1; fi
  done
  return 0
}

prompt_flip() {
  local edge="$1"
  echo >&2
  if [ "$edge" = long ]; then
    say "第 1 趟（偶数页 = 背面）已完成。"
    say "请把整叠纸【沿长边翻转】(像翻书一样左右翻面) 后放回进纸盒。"
  else
    say "第 1 趟（偶数页 = 背面）已完成。"
    say "请把整叠纸【沿短边翻转】(上下翻面) 后放回进纸盒。"
  fi
  if [ "$NO_PROMPT" = 1 ]; then
    say "（--no-prompt：不等待确认，直接开始第 2 趟）"
    return 0
  fi
  if [ -r /dev/tty ]; then
    printf '\033[36m[lp]\033[0m 放好后按 Enter 继续（Ctrl-C 放弃）… ' >&2
    read -r _ < /dev/tty || return 1
  else
    say "（非交互环境，直接开始第 2 趟）"
  fi
  return 0
}

run() {
  if [ "$DRY_RUN" = 1 ]; then
    printf '[dry-run] '; printf '%q ' "$@"; echo
  else
    "$@" || die "命令失败: $*"
  fi
}

# ------------------------------- 主流程 ------------------------------------
shopt -s nullglob
for src in "${files[@]}"; do
  [ -f "$src" ] || { warn "跳过（不是普通文件）: $src"; continue; }

  if ! file -b --mime-type "$src" | grep -q 'application/pdf'; then
    warn "非 PDF 文件，无法自动补白页，$src 将按原样单面打印"
    run "$REAL_LP" -o sides=one-sided "${clean_args[@]}" "$src"
    continue
  fi

  total=$(page_count "$src")
  [ -n "$total" ] || { warn "读不出页数，跳过: $src"; continue; }

  work="$src"
  padded=0
  if [ $((total % 2)) -ne 0 ]; then
    read -r pw ph <<< "$(page_size "$src")"
    [ -n "${pw:-}" ] && [ -n "${ph:-}" ] || { pw=595.28; ph=841.89; }
    work="$CACHE_DIR/$(basename "${src%.*}").padded.pdf"
    run pdfunite "$src" "$(blank_page "$pw" "$ph")" "$work"
    padded=1
    say "$(basename "$src")：共 ${total} 页（奇数）→ 自动补 1 页空白页（${pw}×${ph} pt），共 $((total+1)) 页"
  else
    say "$(basename "$src")：共 ${total} 页（偶数），无需补页"
  fi

  # 逆序：偶数页从 n 往下，奇数页从 n-1 往下
  # n 已保证是偶数
  n=$total; [ "$padded" = 1 ] && n=$((total+1))
  even_list=""; odd_list=""
  for ((p=n; p>=2; p-=2)); do
    even_list="${even_list:+$even_list,}$p"
  done
  for ((p=n-1; p>=1; p-=2)); do
    odd_list="${odd_list:+$odd_list,}$p"
  done

  echo >&2
  say "队列 ${printer} · 第 1 趟：背面 = 第 ${even_list} 页（倒序）"
  run "$REAL_LP" -d "$printer" -o sides=one-sided -o "page-ranges=$even_list" \
      -o fit-to-page -t "$(basename "$src") 背面" "${clean_args[@]}" "$work"

  [ "$DRY_RUN" = 1 ] || wait_drain
  [ "$DRY_RUN" = 1 ] || prompt_flip "$duplex" || die "已取消"

  echo >&2
  say "第 2 趟：正面 = 第 ${odd_list} 页（倒序）"
  run "$REAL_LP" -d "$printer" -o sides=one-sided -o "page-ranges=$odd_list" \
      -o fit-to-page -t "$(basename "$src") 正面" \
      "${clean_args[@]}" "$work"

  [ "$DRY_RUN" = 1 ] || wait_drain

  if [ "$padded" = 1 ]; then
    say "最后一页背面为空白页（为奇数页数补齐），属正常现象"
  fi
done

say "双面打印任务全部提交完成。"

```

| 项目           | 值                                                                           |
| -------------- | ---------------------------------------------------------------------------- |
| 脚本路径       | `~/.local/bin/lp`                                                            |
| 原版命令       | `/usr/bin/lp`（未被修改）                                                    |
| 生效方式       | `~/.zshrc` / `~/.bashrc` 末尾加 `export PATH="$HOME/.local/bin:$PATH"`       |
| 临时绕开包装器 | 写全路径 `/usr/bin/lp …`，或用 `\lp …`（zsh/bash 跳过别名/函数，不含二进制） |
| 补页缓存       | `~/.cache/lp-manual-duplex/`（可随意删除，会自动重建）                       |

新开一个终端就生效；当前终端想立即生效执行 `source ~/.zshrc`。

### 5.2 用法

```bash
lp --duplex 文件.pdf                        # 长边翻转（书籍式，默认）
lp --duplex=short 文件.pdf                  # 短边翻转（便签/挂图式）
lp -o sides=two-sided-long-edge 文件.pdf    # 等价写法（IPP 标准）
lp -o sides=two-sided-short-edge 文件.pdf

lp 文件.pdf                                 # 不带上述参数 = 单面，行为跟原生 lp 完全一样
```

其他原生参数照常透传（`-d` `-n` `-o media=A4` `-o ColorModel=KGray` `-t 标题` 等）。

### 5.3 它做了什么

1. 用 `pdfinfo` 读页数；
2. **页数为奇数时**用 `pdfunite` 在末尾补一页空白页（尺寸同正文，非 A4），使总页数为偶数；
3. 第 1 趟：`page-ranges=1,3,5…` 单面印正面，然后等队列排空；
4. 提示翻纸，按 Enter 后第 2 趟：`page-ranges=2,4,6…` + `outputorder=reverse` 单面印背面；
5. 奇数页文档的最后一页背面就是那张补的白页，纸张张数与正面完全一致，**不会串页**。

实测（3 页文档 → 4 页）：

```text
p3.pdf：共 3 页（奇数）→ 自动补 1 页空白页（446×632 pt），共 4 页
第 1 趟：正面 = 第 1,3 页
第 2 趟：背面 = 第 2,4 页（第 4 页为空白）
```

### 5.4 翻纸方向

| 参数                     | 出纸后的翻纸动作                         | 适用             |
| ------------------------ | ---------------------------------------- | ---------------- |
| `--duplex`（长边）       | 整叠像翻书一样**左右翻面**，保持上方不转 | 竖版文档（默认） |
| `--duplex=short`（短边） | 整叠**上下翻面**                         | 横版/表格        |

如果印出来背面是倒的，说明翻纸方向错了，换另一个参数再试。

### 5.5 脚本化 / 免交互

```bash
LP_NO_PROMPT=1 lp --duplex 文件.pdf     # 不提示翻纸，只等队列排空就开第 2 趟
LP_DRY_RUN=1  lp --duplex 文件.pdf      # 只打印计划，不真打
lp --duplex --dry-run 文件.pdf          # 同上
lp --duplex --no-prompt 文件.pdf
```

想完全验证两趟逻辑但不耗纸：

```bash
LP_REAL=/bin/echo lp --duplex --no-prompt 文件.pdf   # 把真 lp 换成 echo
```

### 5.6 已知限制

- **只支持 PDF**：其他格式会自动降级为单面打印并给出警告（要补页可先 `gs` 或
  LibreOffice 转成 PDF）。
- 多个文件时逐个文件各跑一趟双面（每个文件单独对齐翻纸）。
- 中途 `Ctrl-C` 会停在第 1 趟之后，此时纸已单面印好，可手动补印背面。
- 一份文档页数很多时，第 1 趟结束前请守着打印机 —— 队列排空即提示翻纸。

### 5.7 卸载包装器

```bash
rm ~/.local/bin/lp
# 再把 ~/.zshrc / ~/.bashrc 里那两行 PATH 注释掉即可恢复原生 lp
```

---

## 6. 打印机硬件状态（墨水、健康度）

HPLIP 工具需要**设备 URI**，不能用队列名：

```bash
URI="hp:/usb/Smart_Tank_510_series?serial=CN3BU540WW"

hp-levels -d "$URI"     # 各色墨水余量（彩色/黑色墨仓）
hp-info   -d "$URI"     # 设备信息（需 GUI，纯终端会退回交互模式）
hp-check               # 依赖与环境自检
hp-doctor              # 出问题时的一键诊断
```

当前墨水：彩色 / 黄色 / 黑色均约 100%，Health: Good/OK。

---

## 7. 故障排查（按顺序试）

```bash
# 1. 服务在跑吗？
systemctl status cups
sudo systemctl restart cups        # 需要 root 密码

# 2. USB 上还认得到打印机吗？
ls /sys/bus/usb/devices/*/product | xargs cat 2>/dev/null | grep -i tank
lpinfo -v | grep -i tank

# 3. 队列还在吗？
lpstat -p -d

# 4. 队列被暂停了？
cupsenable HP_SmartTank_510
cupsaccept HP_SmartTank_510

# 5. 打印没反应，看错误原因
sudo tail -f /var/log/cups/error_log      # 需 root
lpstat -p HP_SmartTank_510 -l

# 6. 打印机内部有未完成作业（断电后常见）
cancel -a HP_SmartTank_510
```

| 现象                            | 处理                                                                  |
| ------------------------------- | --------------------------------------------------------------------- |
| `lpstat: No destinations added` | 队列丢了，按第 8 节重建                                               |
| 作业停在 "sending data" 不动    | 打印机离线/休眠：按机身电源键唤醒，或拔插 USB                         |
| 打印空白页 / 半页               | 检查纸张尺寸是否为 A4（见 4.2）；双面模式的最后一页背面是补页，属正常 |
| 中文乱码                        | PDF 走 ghostscript 渲染一般不会乱码；若换 txt/office 文件需先转 PDF   |
| 墨量正常但打印发虚              | 机身执行"清洁打印头"（HP Smart 手机 App 或面板菜单）                  |

---

## 8. 队列重建 / 迁移（换机器、队列损坏时）

```bash
# 删除旧队列
lpadmin -x HP_SmartTank_510

# 重新创建（一条命令搞定）
lpadmin -p HP_SmartTank_510 -E \
        -v "hp:/usb/Smart_Tank_510_series?serial=CN3BU540WW" \
        -m "drv:///hp/hpcups.drv/hp-smart_tank_510_series.ppd" \
        -o printer-is-shared=false \
        -o PageSize=A4          # ← 别忘了这一行，否则默认纸张回到 Letter

lpadmin -d HP_SmartTank_510
lpstat -p -d
```

若打印机的序列号变了（换新机），用 `lpinfo -v | grep hp:/usb` 查出新的 URI 替换。

系统没有 `sudo` 免密，但你的账号在 `wheel` 组，CUPS 的 `SystemGroup` 允许 wheel 成员
直接用 `lpadmin`/`cupsenable` 等管理命令，**无需 sudo**。

---

## 9. 卸载 / 清理

```bash
lpadmin -x HP_SmartTank_510     # 删队列（不动软件包）
sudo systemctl disable --now cups   # 彻底关掉打印服务

rm ~/.local/bin/lp              # 删掉双面打印包装器（可选）
rm -rf ~/.cache/lp-manual-duplex  # 删掉补页缓存
```

软件包本身未做任何额外安装，无需卸载。删掉包装器后可把
`~/.zshrc` / `~/.bashrc` 里那两行 `export PATH="$HOME/.local/bin:$PATH"` 注释掉。

---

## 10. 图形界面（可选）

不喜欢命令行可以用：

```bash
system-config-printer          # 已在系统中，图形化增删队列、改默认选项
```

或用浏览器打开 CUPS Web 管理台：<http://localhost:631>
（首次访问可能要求输入用户名 `kemil` 及系统密码）。

#!/usr/bin/env bash
#
# yiclaude — 一键装好 Claude Code + 国产大模型 (GLM / Kimi / MiniMax / Qwen / DeepSeek)
#            one command: install Claude Code and wire it to a Chinese LLM.
#
# Entry point for macOS / Linux (and Windows under Git Bash).
# Windows users without Git Bash: use install.ps1 instead.
#
# Beginner mode (no arguments) = a guided wizard:
#   1. pick a model from a menu
#   2. if you have an API key, paste it; if not, it opens the page and waits
#   3. it installs Claude Code and configures everything for you
#
#   bash <(curl -fsSL https://cdn.jsdelivr.net/gh/your-name/yiclaude@main/install.sh)
#
# Power users can still pass flags:
#   ./install.sh --model glm --api-key sk-xxxxx
#
# Compatibility:
#   - Runs under bash on macOS / Linux / Git Bash; refuses to run under plain sh.
#   - UTF-8 terminals get nice glyphs; otherwise it falls back to ASCII.
#   - Colors only when stdout is a TTY (respects NO_COLOR / --no-color).
#   - All interactive reads use /dev/tty, so the wizard works through curl|bash.

# Must run under bash (uses bash-only syntax). Guard against `sh install.sh`.
if [ -z "${BASH_VERSION:-}" ]; then
  echo "Please run with bash:  bash install.sh   (请用 bash 运行，不要用 sh)" >&2
  exit 1
fi

set -euo pipefail

VERSION="1.0.0"
REPO_URL="https://github.com/your-name/yiclaude"

# ----------------------------------------------------------------------------
# Defaults (overridable by flags)
# ----------------------------------------------------------------------------
PROVIDER="glm"
MODEL_SET=0        # 1 if --model was given explicitly
API_KEY=""
KEY_SET=0          # 1 if --api-key was given explicitly
MODEL_ID=""        # override ANTHROPIC_MODEL
FAST_MODEL=""      # override ANTHROPIC_SMALL_FAST_MODEL
BASE_URL=""        # override ANTHROPIC_BASE_URL
LANG_SEL="zh"      # zh | en — default Chinese
DO_VERIFY=1
DO_OPEN=1          # auto-open the provider key page when no key is given
ENSURE_GH=1        # auto-install gh CLI (needed for smoke test)
DO_SMOKE=1         # auto-run agent smoke test after install
USE_COLOR=1
DEBUG=0
DO_HELP=0
DO_LIST=0

CLAUDE_DIR="${HOME}/.claude"
SETTINGS="${CLAUDE_DIR}/settings.json"
LOG="${TMPDIR:-/tmp}/yiclaude-install.log"
: > "$LOG" 2>/dev/null || LOG="/tmp/yiclaude-install.$$.log"

CURRENT_STEP=0
TOTAL_STEPS=0
FAILED=0

# ----------------------------------------------------------------------------
# Bilingual helper:  t "中文" "English"
# ----------------------------------------------------------------------------
t() { if [ "$LANG_SEL" = "en" ]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }

# ----------------------------------------------------------------------------
# UI setup: colors (TTY only) + glyphs (Unicode when the locale supports it)
# ----------------------------------------------------------------------------
setup_ui() {
  if [ "$USE_COLOR" = "1" ] && [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    RST=$'\033[0m'; BOLD=$'\033[1m'; DIM=$'\033[2m'; UL=$'\033[4m'
    RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; CYAN=$'\033[36m'; BLU=$'\033[34m'; MAG=$'\033[35m'
  else
    RST=""; BOLD=""; DIM=""; UL=""; RED=""; GRN=""; YEL=""; CYAN=""; BLU=""; MAG=""
  fi
  case "${LC_ALL:-}${LC_CTYPE:-}${LANG:-}" in
    *[Uu][Tt][Ff]*) UNICODE=1 ;;
    *) UNICODE=0 ;;
  esac
  if [ "$UNICODE" = "1" ]; then
    G_OK="✓"; G_BAD="✗"; G_ARROW="▸"; G_FULL="█"; G_EMPTY="░"; G_DONE="★"; G_WARN="⚠"; G_TIP="→"
  else
    G_OK="+"; G_BAD="x"; G_ARROW=">"; G_FULL="#"; G_EMPTY="-"; G_DONE="*"; G_WARN="!"; G_TIP="->"
  fi
}

# ----------------------------------------------------------------------------
# Logging / UI primitives
# ----------------------------------------------------------------------------
info() { printf "  %s\n" "$1"; }
note() { printf "  %s%s%s\n" "$DIM" "$1" "$RST"; }
ok()   { printf "  %s%s%s %s\n" "$GRN" "$G_OK" "$RST" "$1"; }
warn() { printf "  %s%s%s %s\n" "$YEL" "$G_WARN" "$RST" "$1"; }

die() {
  FAILED=1
  printf "\n%s%s %s%s %s\n" "$RED$BOLD" "$G_BAD" "$(t "出错了" "Error")" "$RST" "$1" >&2
  printf "  %s%s %s%s\n" "$DIM" "$(t "日志在" "Log:")" "$LOG" "$RST" >&2
  exit 1
}

hr() { printf "%s%s%s\n" "$DIM" "------------------------------------------------------------" "$RST"; }

banner() {
  printf "\n"
  if [ "${UNICODE:-0}" = "1" ]; then
    printf "%s  ╭────────────────────────────────────────────────────╮%s\n" "$CYAN" "$RST"
    printf "%s  │     %s%syiclaude%s%s · Claude Code 一键安装器%s                %s│%s\n" "$CYAN" "$RST" "$BOLD$MAG" "$RST" "$BOLD$CYAN" "$RST" "$CYAN" "$RST"
    printf "%s  │     %sinstall Claude Code + a China LLM, one command%s   %s│%s\n" "$CYAN" "$DIM" "$RST" "$CYAN" "$RST"
    printf "%s  ╰────────────────────────────────────────────────────╯%s\n" "$CYAN" "$RST"
  else
    printf "%s  +------------------------------------------------------+%s\n" "$CYAN" "$RST"
    printf "%s  |     %s%syiclaude%s%s - Claude Code one-command installer%s     %s|%s\n" "$CYAN" "$RST" "$BOLD$MAG" "$RST" "$BOLD$CYAN" "$RST" "$CYAN" "$RST"
    printf "%s  +------------------------------------------------------+%s\n" "$CYAN" "$RST"
  fi
  printf "  %sv%s%s %s·%s %s%s%s\n" "$DIM" "$VERSION" "$RST" "$DIM" "$RST" "$UL$BLU" "$REPO_URL" "$RST"
}

draw_bar() {
  local cur=$1 total=$2 width=28 i=0 filled empty pct bar=""
  filled=$(( cur * width / total ))
  empty=$(( width - filled ))
  pct=$(( cur * 100 / total ))
  while [ "$i" -lt "$filled" ]; do bar="${bar}${G_FULL}"; i=$((i+1)); done
  i=0; while [ "$i" -lt "$empty" ]; do bar="${bar}${G_EMPTY}"; i=$((i+1)); done
  printf "  %s%s%s %s%3d%%%s (%d/%d)\n" "$GRN" "$bar" "$RST" "$BOLD" "$pct" "$RST" "$cur" "$total"
}

begin_step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  printf "\n%s%s [%d/%d] %s%s\n" "$CYAN$BOLD" "$G_ARROW" "$CURRENT_STEP" "$TOTAL_STEPS" "$1" "$RST"
  draw_bar "$CURRENT_STEP" "$TOTAL_STEPS"
}

# Spinner that animates while $1 (a pid) is alive. ASCII frames work everywhere.
spin() {
  local pid=$1 frames='-\|/' i=0
  printf ' '
  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i + 1) % 4 ))
    printf '\b%s' "${frames:$i:1}"
    sleep 0.1 2>/dev/null || sleep 1   # fall back if sleep lacks sub-second
  done
  printf '\b'
}

# run_cmd "label" cmd args...   — runs quietly with a spinner; logs everything.
run_cmd() {
  local label="$1"; shift
  printf "  %s%s%s" "$DIM" "$label" "$RST"
  if [ "$DEBUG" = "1" ]; then
    printf "\n"
    if "$@" 2>&1 | tee -a "$LOG"; then :; else return 1; fi
    return 0
  fi
  ( "$@" >>"$LOG" 2>&1 ) &
  local pid=$!
  spin "$pid"
  if wait "$pid"; then
    printf " %s%s%s\n" "$GRN" "$G_OK" "$RST"
    return 0
  fi
  printf " %s%s%s\n" "$RED" "$G_BAD" "$RST"
  return 1
}

# ----------------------------------------------------------------------------
# Provider registry  (China-first endpoints — no VPN needed)
# NOTE: model IDs drift over time. The verify step catches a stale default;
#       override with --model-id. See README for each provider's model list.
# ----------------------------------------------------------------------------
provider_label() {
  case "$1" in
    glm)      echo "智谱 GLM" ;;
    kimi)     echo "Kimi (Moonshot)" ;;
    deepseek) echo "DeepSeek" ;;
    qwen)     echo "通义千问 Qwen" ;;
    minimax)  echo "MiniMax" ;;
  esac
}
provider_base() {
  case "$1" in
    glm)      echo "https://open.bigmodel.cn/api/anthropic" ;;
    kimi)     echo "https://api.moonshot.cn/anthropic" ;;
    deepseek) echo "https://api.deepseek.com/anthropic" ;;
    qwen)     echo "https://dashscope.aliyuncs.com/apps/anthropic" ;;
    minimax)  echo "https://api.minimaxi.com/anthropic" ;;
  esac
}
provider_model() {
  case "$1" in
    glm)      echo "glm-4.6" ;;
    kimi)     echo "kimi-k2-0905-preview" ;;
    deepseek) echo "deepseek-v4-pro[1m]" ;;
    qwen)     echo "qwen3-coder-plus" ;;
    minimax)  echo "MiniMax-M2.1" ;;
  esac
}
provider_fast() {
  case "$1" in
    glm)      echo "glm-4.5-air" ;;
    kimi)     echo "kimi-k2-0905-preview" ;;
    deepseek) echo "deepseek-v4-flash" ;;
    qwen)     echo "qwen3-coder-plus" ;;
    minimax)  echo "MiniMax-M2.1" ;;
  esac
}
provider_keyurl() {
  case "$1" in
    glm)      echo "https://open.bigmodel.cn/usercenter/apikeys" ;;
    kimi)     echo "https://platform.moonshot.cn/console/api-keys" ;;
    deepseek) echo "https://platform.deepseek.com/api_keys" ;;
    qwen)     echo "https://bailian.console.aliyun.com/?tab=model#/api-key" ;;
    minimax)  echo "https://platform.minimaxi.com/user-center/basic-information/interface-key" ;;
  esac
}
provider_docurl() {
  case "$1" in
    glm)      echo "https://docs.bigmodel.cn/cn/guide/start/quick-start" ;;
    kimi)     echo "https://platform.moonshot.cn/blog/posts/kimi-api-quick-start-guide" ;;
    deepseek) echo "https://api-docs.deepseek.com/zh-cn/quick_start/" ;;
    qwen)     echo "https://help.aliyun.com/zh/model-studio/claude-code" ;;
    minimax)  echo "https://platform.minimaxi.com/docs/token-plan/claude-code" ;;
  esac
}
is_provider() {
  case "$1" in glm|kimi|deepseek|qwen|minimax) return 0 ;; *) return 1 ;; esac
}
PROVIDERS="glm kimi deepseek qwen minimax"

api_key_looks_plausible() {
  local candidate="$1"
  [ "${#candidate}" -ge 16 ] || return 1
  case "$candidate" in
    *[[:space:]]*|*\<*|*\>*|*"API key"*|*"api key"*|*"your "*|*"你的"*|*"创建"*|*"新建"*|*"复制"*|*"粘贴"*|*"generated"*)
      return 1 ;;
    *)
      return 0 ;;
  esac
}

validate_api_key_or_die() {
  api_key_looks_plausible "$API_KEY" && return 0
  die "$(t "这不像有效 API key。请粘贴厂商控制台生成的完整 key，不要粘贴说明文字或占位符。" "this does not look like a valid API key. Paste the full key generated by the provider console, not instructions or placeholders.")"
}

list_providers() {
  printf "%s%s%s\n" "$BOLD" "$(t "支持的模型厂商：" "Supported providers:")" "$RST"
  local p
  for p in $PROVIDERS; do
    printf "  %s%-9s%s %-16s %s%s%s\n" \
      "$CYAN" "$p" "$RST" "$(provider_label "$p")" "$DIM" "$(provider_base "$p")" "$RST"
  done
}

# ----------------------------------------------------------------------------
# Usage
# ----------------------------------------------------------------------------
usage() {
  banner
  cat <<EOF

$(t "用法" "Usage"):
  ./install.sh                      $(t "# 推荐：跟着提示走的交互向导" "# recommended: interactive guided wizard")
  ./install.sh --model glm --api-key <key>   $(t "# 已有 key 的快捷方式" "# shortcut if you already have a key")

$(t "选项" "Options"):
  -m, --model <name>     $(t "厂商" "provider"): glm | kimi | minimax | qwen | deepseek  $(t "(默认 glm)" "(default glm)")
  -k, --api-key <key>    $(t "你的 API key（不填则向导里交互输入）" "your API key (asked interactively if omitted)")
      --model-id <id>    $(t "覆盖默认模型名" "override the model id")
      --fast-model <id>  $(t "覆盖后台小模型名" "override the small/fast model id")
      --base-url <url>   $(t "覆盖接口地址" "override the base URL")
      --lang <zh|en>     $(t "界面语言 (默认 zh)" "UI language (default zh)")
      --no-verify        $(t "跳过连通性验证" "skip the connectivity check")
      --no-open          $(t "缺 key 时不自动打开浏览器" "do not auto-open the key page")
      --no-color         $(t "关闭彩色输出" "disable colored output")
      --debug            $(t "显示全部命令输出，便于排错" "show all command output for debugging")
      --list             $(t "列出支持的厂商" "list supported providers")
  -h, --help             $(t "显示帮助" "show this help")

$(t "日志" "Log"): $LOG
EOF
}

# ----------------------------------------------------------------------------
# Argument parsing  (clear errors for wrong input)
# ----------------------------------------------------------------------------
bad_arg() {
  setup_ui
  FAILED=1
  printf "%s%s %s%s %s\n" "$RED$BOLD" "$G_BAD" "$1" "$RST" "$2" >&2
  printf "  %s%s%s\n" "$DIM" "$(t "运行 ./install.sh --help 查看用法" "Run ./install.sh --help for usage")" "$RST" >&2
  exit 2
}

need_value() {
  # $1 = flag name, $2 = value (may be empty / next flag)
  if [ -z "${2:-}" ] || case "${2:-}" in --*|-?) true ;; *) false ;; esac; then
    bad_arg "$(t "选项缺少取值" "missing value for option")" "$1"
  fi
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -m|--model)      need_value "$1" "${2:-}"; PROVIDER="$2"; MODEL_SET=1; shift 2 ;;
      -k|--api-key)    need_value "$1" "${2:-}"; API_KEY="$2"; KEY_SET=1; shift 2 ;;
      --model-id)      need_value "$1" "${2:-}"; MODEL_ID="$2"; shift 2 ;;
      --fast-model)    need_value "$1" "${2:-}"; FAST_MODEL="$2"; shift 2 ;;
      --base-url)      need_value "$1" "${2:-}"; BASE_URL="$2"; shift 2 ;;
      --lang)          need_value "$1" "${2:-}"; LANG_SEL="$2"; shift 2 ;;
      --no-verify)     DO_VERIFY=0; shift ;;
      --no-gh)         ENSURE_GH=0; shift ;;
      --no-smoke)      DO_SMOKE=0; shift ;;
      --no-open)       DO_OPEN=0; shift ;;
      --no-color)      USE_COLOR=0; shift ;;
      --debug)         DEBUG=1; shift ;;
      --list)          DO_LIST=1; shift ;;
      -h|--help)       DO_HELP=1; shift ;;
      --)              shift; break ;;
      -*)              bad_arg "$(t "未知选项" "Unknown option")" "$1" ;;
      *)               bad_arg "$(t "无法识别的参数" "Unexpected argument")" "$1" ;;
    esac
  done
  case "$LANG_SEL" in zh|en) ;; *) bad_arg "$(t "--lang 只能是 zh 或 en" "--lang must be zh or en")" "$LANG_SEL" ;; esac
}

# ----------------------------------------------------------------------------
# OS detection / helpers
# ----------------------------------------------------------------------------
detect_os() {
  case "$(uname -s)" in
    Darwin) OS="mac" ;;
    Linux)  OS="linux" ;;
    MINGW*|MSYS*|CYGWIN*) OS="windows" ;;
    *) OS="unknown" ;;
  esac
}

# True only if we can actually open the controlling terminal for prompts.
# /dev/tty may exist as a node yet fail to open (e.g. piped with no tty).
have_tty() { { true >/dev/tty; } 2>/dev/null; }

open_url() {
  local url="$1"
  case "$OS" in
    mac)     open "$url" >/dev/null 2>&1 || true ;;
    linux)   xdg-open "$url" >/dev/null 2>&1 || true ;;
    windows) cmd.exe /c start "" "$url" >/dev/null 2>&1 || powershell.exe -NoProfile -Command "Start-Process '$url'" >/dev/null 2>&1 || true ;;
  esac
}

# ----------------------------------------------------------------------------
# Interactive wizard: choose model, then get the key
# ----------------------------------------------------------------------------
wizard_select_provider() {
  if ! have_tty; then PROVIDER="glm"; return 0; fi
  printf "\n  %s%s%s\n" "$BOLD$CYAN" "$(t "第一步：选择要用的模型（输入数字后回车）" "Step 1: choose a model (type a number, Enter)")" "$RST"
  printf "    %s1)%s %-18s %s%s%s\n" "$CYAN$BOLD" "$RST" "智谱 GLM"        "$GRN" "$(t "推荐 · 编程最强" "recommended · best at coding")" "$RST"
  printf "    %s2)%s %-18s %s%s%s\n" "$CYAN" "$RST" "Kimi (Moonshot)" "$DIM" "$(t "长上下文" "long context")" "$RST"
  printf "    %s3)%s %-18s %s%s%s\n" "$CYAN" "$RST" "MiniMax"         "$DIM" "$(t "便宜" "cheap")" "$RST"
  printf "    %s4)%s %-18s %s%s%s\n" "$CYAN" "$RST" "通义千问 Qwen"   "$DIM" "$(t "阿里" "Alibaba")" "$RST"
  printf "    %s5)%s %-18s %s%s%s\n" "$CYAN" "$RST" "DeepSeek"        "$DIM" "$(t "推理强" "strong reasoning")" "$RST"
  local choice=""
  printf "  %s%s%s " "$BOLD" "$(t "你的选择 [1]:" "Your choice [1]:")" "$RST" > /dev/tty
  read -r choice < /dev/tty || choice=""
  case "$choice" in
    ""|1) PROVIDER="glm" ;;
    2)    PROVIDER="kimi" ;;
    3)    PROVIDER="minimax" ;;
    4)    PROVIDER="qwen" ;;
    5)    PROVIDER="deepseek" ;;
    *)    warn "$(t "无效输入，已默认使用 GLM" "invalid input, defaulting to GLM")"; PROVIDER="glm" ;;
  esac
  ok "$(t "已选择：" "Selected: ")$(provider_label "$PROVIDER")"
}

wizard_acquire_key() {
  local label keyurl docurl ans
  label="$(provider_label "$PROVIDER")"
  keyurl="$(provider_keyurl "$PROVIDER")"
  docurl="$(provider_docurl "$PROVIDER")"
  if ! have_tty; then
    die "$(t "无法交互输入 API key。请改用：--model $PROVIDER --api-key <你的key>" "cannot read key interactively; use --model $PROVIDER --api-key <key>")"
  fi
  printf "\n  %s%s%s " "$BOLD$CYAN" "$(t "第二步：你有 ${label} 的 API key 吗？(y/N)" "Step 2: do you have a ${label} API key? (y/N)")" "$RST" > /dev/tty
  read -r ans < /dev/tty || ans=""
  case "$ans" in
    y|Y|yes|YES) : ;;
    *)
      # Open the page first so it loads while the user reads the steps.
      [ "$DO_OPEN" = "1" ] && open_url "$keyurl"
      printf "\n  %s%s%s\n" "$YEL$BOLD" "$(t "没关系，照下面 4 步走，1 分钟就能拿到：" "No problem — 4 steps, about 1 minute:")" "$RST"
      printf "    %s1%s  %s\n"     "$GRN$BOLD" "$RST" "$(t "打开 ${label} 的 API key 页面（已自动帮你打开浏览器；没弹出就手动复制下面这条链接）" "Open the ${label} API key page (auto-opened; if not, copy the link below)")"
      printf "       %s%s%s%s\n"   "$UL" "$CYAN" "$keyurl" "$RST"
      printf "    %s2%s  %s\n"     "$GRN$BOLD" "$RST" "$(t "注册或登录账号（部分厂商需要先实名认证）" "Register or sign in (some providers need ID verification first)")"
      printf "    %s3%s  %s\n"     "$GRN$BOLD" "$RST" "$(t "点“创建 / 新建 API Key”，把生成的那串 key 复制下来" "Click 'Create API Key' and copy the generated key")"
      printf "    %s4%s  %s\n"     "$GRN$BOLD" "$RST" "$(t "回到这个窗口，粘贴进来按回车（下一步就会让你粘贴）" "Come back to this window and paste it (asked next)")"
      printf "    %s%s%s %s%s%s%s\n" "$DIM" "$(t "看不懂可参考官方图文文档：" "Official step-by-step docs:")" "$RST" "$UL" "$BLU" "$docurl" "$RST"
      ;;
  esac
  while :; do
    printf "\n  %s%s%s " "$BOLD" "$(t "把 API key 粘贴到这里，然后回车：" "Paste your API key here, then Enter:")" "$RST" > /dev/tty
    read -r API_KEY < /dev/tty || API_KEY=""
    if [ -z "$API_KEY" ]; then
      warn "$(t "还没收到 key，再粘贴一次（或按 Ctrl+C 退出）" "no key yet — paste again (or Ctrl+C to quit)")"
      continue
    fi
    api_key_looks_plausible "$API_KEY" && break
    warn "$(t "这看起来不像 API key。请只粘贴厂商控制台生成的那串 key。" "that does not look like an API key. Paste only the key generated by the provider console.")"
    API_KEY=""
  done
  ok "$(t "已收到 API key" "API key received")"
}

run_wizard() {
  [ "$MODEL_SET" = "1" ] || wizard_select_provider
  [ "$KEY_SET" = "1" ]   || wizard_acquire_key
}

# ----------------------------------------------------------------------------
# Step 1: prerequisites
# ----------------------------------------------------------------------------
ensure_curl() {
  command -v curl >/dev/null 2>&1 && return 0
  die "$(t "缺少 curl，请先安装 curl 再运行" "curl is required; please install curl first")"
}

ensure_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    ok "$(t "Homebrew 已安装" "Homebrew already installed")"
    return 0
  fi
  warn "$(t "未发现 Homebrew，开始安装（用国内镜像加速，可能要几分钟）" "Homebrew not found; installing via China mirror (a few minutes)")"
  note "$(t "如弹出系统对话框要装“命令行工具”，请点“安装”" "If macOS asks to install Command Line Tools, click Install")"
  export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.ustc.edu.cn/brew.git"
  export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.ustc.edu.cn/homebrew-core.git"
  export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"
  export HOMEBREW_API_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles/api"
  export NONINTERACTIVE=1
  if ! run_cmd "$(t "安装 Homebrew (官方源)" "Installing Homebrew (official)")" \
        bash -c 'curl -fsSL --connect-timeout 8 https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | bash'; then
    run_cmd "$(t "安装 Homebrew (jsDelivr 镜像)" "Installing Homebrew (jsDelivr mirror)")" \
        bash -c 'curl -fsSL https://cdn.jsdelivr.net/gh/Homebrew/install@HEAD/install.sh | bash' \
      || die "$(t "Homebrew 安装失败" "Homebrew install failed")"
  fi
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"
  fi
  hash -r
  command -v brew >/dev/null 2>&1 || die "$(t "Homebrew 安装后仍找不到 brew 命令" "brew not found after install")"
  ok "$(t "Homebrew 安装完成" "Homebrew installed")"
}

# ----------------------------------------------------------------------------
# gh CLI — auto-install so the smoke test can run
# ----------------------------------------------------------------------------
ensure_gh() {
  [ "$ENSURE_GH" = "1" ] || return 0
  if command -v gh >/dev/null 2>&1; then
    ok "$(t "GitHub CLI 已安装" "GitHub CLI already installed")"
    return 0
  fi
  warn "$(t "未发现 gh，正在安装（用于验证 agent 能力）" "gh not found; installing (needed for agent smoke test)")"
  case "$OS" in
    mac)
      if command -v brew >/dev/null 2>&1; then
        run_cmd "$(t "安装 gh (Homebrew)" "Installing gh (Homebrew)")" brew install gh || true
      fi ;;
    linux)
      # Prefer the official script, then apt/yum.
      if run_cmd "$(t "安装 gh (官方脚本)" "Installing gh (official)")" \
           curl -fsSL --connect-timeout 8 https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
           sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>>"$LOG" && \
           sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
           echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
           sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
           sudo apt-get update -qq && sudo apt-get install -y -qq gh; then
        :
      elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y gh 2>>"$LOG" || true
      fi ;;
    windows)
      command -v winget >/dev/null 2>&1 && winget install --id GitHub.cli -e --accept-source-agreements --accept-package-agreements 2>>"$LOG" || true ;;
  esac
  command -v gh >/dev/null 2>&1 || warn "$(t "gh 安装失败，稍后的 agent 验证将跳过" "gh install failed; agent smoke test will be skipped")"
}

ensure_gh_auth() {
  [ "$DO_SMOKE" = "1" ] || return 0
  command -v gh >/dev/null 2>&1 || return 0
  if gh auth status >/dev/null 2>&1; then
    ok "$(t "gh 已登录" "gh already authenticated")"
    return 0
  fi
  warn "$(t "gh 装了但还没登录 GitHub，需要认证一次（做完就会记住，不用再输）" "gh is installed but not logged in; one-time auth needed")"
  note "$(t "下一步会打开浏览器让你授权，跟着点就行，约 15 秒" "Next: a browser will open for you to authorize (~15 sec)")"
  if have_tty; then
    gh auth login --hostname github.com --git-protocol https --web < /dev/tty 2>>"$LOG" || {
      warn "$(t "gh 登录未完成，agent 验证跳过（不影响模型使用）" "gh login not completed; agent smoke test skipped (model still works)")"
      return 0
    }
  else
    warn "$(t "无终端交互，请手动跑 gh auth login 后重试" "no tty; run gh auth login manually and retry")"
  fi
  gh auth status >/dev/null 2>&1 && ok "$(t "gh 已登录" "gh now authenticated")" || warn "$(t "gh 登录未完成，agent 验证跳过" "gh login not completed; smoke test skipped")"
}

step_prereq() {
  begin_step "$(t "检查并安装前置依赖" "Check & install prerequisites")"
  ensure_curl
  case "$OS" in
    mac)
      ok "$(t "系统: macOS" "OS: macOS")"
      ensure_homebrew ;;
    linux)
      ok "$(t "系统: Linux" "OS: Linux")" ;;
    windows)
      ok "$(t "系统: Windows (Git Bash)" "OS: Windows (Git Bash)")"
      command -v winget >/dev/null 2>&1 || warn "$(t "未发现 winget；如安装失败请改用 install.ps1" "winget not found; use install.ps1 if install fails")" ;;
    *)
      die "$(t "不支持的系统，请手动安装 Claude Code" "Unsupported OS; install Claude Code manually")" ;;
  esac
  ensure_gh
  ensure_gh_auth
}

# ----------------------------------------------------------------------------
# Step 2: install Claude Code  (official first, then mirror)
# ----------------------------------------------------------------------------
add_local_bin_to_path() {
  local bindir="${HOME}/.local/bin" shell_name rc line
  case ":$PATH:" in *":$bindir:"*) ;; *) PATH="$bindir:$PATH"; export PATH ;; esac
  hash -r
  # Pick the rc file for the user's actual login shell, with the right syntax.
  shell_name="$(basename "${SHELL:-sh}")"
  case "$shell_name" in
    fish)
      rc="${HOME}/.config/fish/config.fish"
      line='set -gx PATH $HOME/.local/bin $PATH' ;;     # fish syntax, not export
    zsh)
      rc="${ZDOTDIR:-$HOME}/.zshrc"
      line='export PATH="$HOME/.local/bin:$PATH"' ;;
    *)
      # bash and other POSIX shells: append to an existing login file rather
      # than creating a new one (a fresh .bash_profile would shadow .profile).
      if [ -f "${HOME}/.bash_profile" ]; then rc="${HOME}/.bash_profile"
      elif [ -f "${HOME}/.bashrc" ]; then rc="${HOME}/.bashrc"
      else rc="${HOME}/.profile"; fi
      line='export PATH="$HOME/.local/bin:$PATH"' ;;
  esac
  mkdir -p "$(dirname "$rc")" 2>/dev/null || true
  if [ ! -f "$rc" ] || ! grep -q '\.local/bin' "$rc" 2>/dev/null; then
    printf '\n%s\n' "$line" >> "$rc" 2>/dev/null || true
  fi
}

install_claude_official() {
  case "$OS" in
    mac|linux)
      run_cmd "$(t "安装 Claude Code (官方源)" "Installing Claude Code (official)")" \
        bash -c 'curl -fsSL --connect-timeout 8 --max-time 120 https://claude.ai/install.sh | bash' ;;
    windows)
      run_cmd "$(t "安装 Claude Code (winget)" "Installing Claude Code (winget)")" \
        winget install --id Anthropic.ClaudeCode -e --accept-source-agreements --accept-package-agreements ;;
    *) return 1 ;;
  esac
}

step_install_claude() {
  begin_step "$(t "安装 Claude Code" "Install Claude Code")"
  if command -v claude >/dev/null 2>&1; then
    ok "$(t "Claude Code 已安装：" "Claude Code already installed: ")$(claude --version 2>/dev/null | head -n1)"
    return 0
  fi
  note "$(t "先试官方源，失败再用国内方式" "Trying official source first, then China fallback")"
  if install_claude_official; then
    :
  elif [ "$OS" = "mac" ] && command -v brew >/dev/null 2>&1 && \
       run_cmd "$(t "通过 Homebrew 安装 Claude Code" "Installing Claude Code via Homebrew")" brew install --cask claude-code; then
    :
  else
    die "$(t "Claude Code 安装失败，请看日志或改用 install.ps1 / 手动安装" "Claude Code install failed; check the log or use install.ps1 / manual install")"
  fi
  add_local_bin_to_path
  command -v claude >/dev/null 2>&1 \
    || die "$(t "安装后仍找不到 claude 命令，请关掉终端重开再试" "claude not found after install; reopen your terminal and retry")"
  ok "$(t "Claude Code 安装完成：" "Claude Code installed: ")$(claude --version 2>/dev/null | head -n1)"
}

# ----------------------------------------------------------------------------
# Step 3: configure model  (key already obtained by the wizard or --api-key)
#
# We write a clean, standard Claude Code settings.json — just an `env` block.
# This is exactly the shape cc-switch reads and manages, so a user can later
# install cc-switch and "import current config" to take this over as a
# provider. Keeping the file minimal (no hooks/statusLine/etc.) means that
# takeover won't drop any of the user's custom fields.
# ----------------------------------------------------------------------------
# When neither python nor jq exists, try to install jq (via brew) so we can
# MERGE into the user's existing settings.json instead of overwriting it.
ensure_json_tool() {
  command -v jq >/dev/null 2>&1 && return 0
  command -v brew >/dev/null 2>&1 || return 1
  run_cmd "$(t "安装 jq（用于安全合并配置）" "Installing jq (to merge config safely)")" brew install jq || true
  command -v jq >/dev/null 2>&1
}

write_config() {
  local base="$1" key="$2" model="$3" fast="$4" PYBIN=""
  mkdir -p "$CLAUDE_DIR"
  if command -v python3 >/dev/null 2>&1; then PYBIN=python3
  elif command -v python >/dev/null 2>&1; then PYBIN=python
  fi
  if [ -n "$PYBIN" ]; then
    "$PYBIN" - "$SETTINGS" "$base" "$key" "$model" "$fast" <<'PY' || return 1
import json, os, sys
path, base, key, model, fast = sys.argv[1:6]
data = {}
if os.path.exists(path):
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        if not isinstance(data, dict):
            data = {}
    except Exception:
        data = {}
env = data.get("env", {})
if not isinstance(env, dict):
    env = {}
env.update({
    "ANTHROPIC_BASE_URL": base,
    "ANTHROPIC_AUTH_TOKEN": key,
    "ANTHROPIC_MODEL": model,
    "ANTHROPIC_SMALL_FAST_MODEL": fast,
})
data["env"] = env
data["skipIntroduction"] = True
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY
    return 0
  fi
  # No python: make sure jq exists (install via brew if needed), then MERGE
  # so the user's existing settings.json fields are preserved, not clobbered.
  if command -v jq >/dev/null 2>&1 || ensure_json_tool; then
    local tmp="${SETTINGS}.tmp.$$"
    { [ -s "$SETTINGS" ] && cat "$SETTINGS" || echo '{}'; } | \
      jq --arg b "$base" --arg k "$key" --arg m "$model" --arg f "$fast" \
        '.env = ((.env // {}) + {ANTHROPIC_BASE_URL:$b, ANTHROPIC_AUTH_TOKEN:$k, ANTHROPIC_MODEL:$m, ANTHROPIC_SMALL_FAST_MODEL:$f}) | .skipIntroduction = true' \
        > "$tmp" && mv "$tmp" "$SETTINGS" || return 1
    return 0
  fi
  # Last resort (no python, no jq, couldn't install jq): back up and warn
  # loudly instead of silently dropping the user's existing settings.
  if [ -s "$SETTINGS" ]; then
    cp -p "$SETTINGS" "${SETTINGS}.bak.$$" 2>/dev/null || cp "$SETTINGS" "${SETTINGS}.bak.$$" 2>/dev/null || true
    warn "$(t "无 python/jq 无法合并；原配置已备份到 ${SETTINGS}.bak.$$，新文件为纯净版，自定义字段请从备份手动合并" "no python/jq to merge; backed up to ${SETTINGS}.bak.$$ — new file is minimal, merge custom fields from the backup")"
  fi
  cat > "$SETTINGS" <<EOF
{
  "skipIntroduction": true,
  "env": {
    "ANTHROPIC_BASE_URL": "$base",
    "ANTHROPIC_AUTH_TOKEN": "$key",
    "ANTHROPIC_MODEL": "$model",
    "ANTHROPIC_SMALL_FAST_MODEL": "$fast"
  }
}
EOF
}

step_configure() {
  local label; label="$(provider_label "$PROVIDER")"
  begin_step "$(t "配置模型：${label}" "Configure model: ${label}")"
  [ -n "$API_KEY" ] || die "$(t "没有 API key，无法配置" "no API key, cannot configure")"
  [ -n "$BASE_URL" ]   || BASE_URL="$(provider_base "$PROVIDER")"
  [ -n "$MODEL_ID" ]   || MODEL_ID="$(provider_model "$PROVIDER")"
  [ -n "$FAST_MODEL" ] || FAST_MODEL="$(provider_fast "$PROVIDER")"
  write_config "$BASE_URL" "$API_KEY" "$MODEL_ID" "$FAST_MODEL" \
    || die "$(t "写入配置失败" "failed to write config")"
  ok "$(t "已写入配置：" "Config written: ")$SETTINGS"
  printf "    %sbase_url%s  %s%s%s\n" "$DIM" "$RST" "$CYAN" "$BASE_URL" "$RST"
  printf "    %smodel%s     %s%s%s\n" "$DIM" "$RST" "$CYAN" "$MODEL_ID" "$RST"
}

# ----------------------------------------------------------------------------
# Step 4: verify connectivity
# ----------------------------------------------------------------------------
step_verify() {
  [ "$DO_VERIFY" = "1" ] || return 0
  begin_step "$(t "验证连通性" "Verify connectivity")"
  local body http
  body="${TMPDIR:-/tmp}/yiclaude-verify.$$.json"
  printf "  %s%s%s" "$DIM" "$(t "正在发送一条测试请求…" "Sending a test request…")" "$RST"
  http="$(curl -sS -o "$body" -w '%{http_code}' \
    --connect-timeout 12 --max-time 40 \
    -X POST "${BASE_URL%/}/v1/messages" \
    -H "content-type: application/json" \
    -H "anthropic-version: 2023-06-01" \
    -H "authorization: Bearer ${API_KEY}" \
    -d "{\"model\":\"${MODEL_ID}\",\"max_tokens\":8,\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}]}" \
    2>>"$LOG" || echo "000")"
  cat "$body" >> "$LOG" 2>/dev/null || true

  if [ "$http" = "200" ]; then
    printf " %s%s%s\n" "$GRN" "$G_OK" "$RST"
    ok "$(t "连接成功，模型可用！" "Connected — the model works!")"
    rm -f "$body" 2>/dev/null || true
    return 0
  fi

  printf " %s%s%s\n" "$RED" "$G_BAD" "$RST"
  warn "$(t "验证失败 (HTTP ${http})。常见原因：" "Verify failed (HTTP ${http}). Common causes:")"
  case "$http" in
    401|403) info "$(t "${G_TIP} API key 不对或没权限，请检查 key" "${G_TIP} wrong/unauthorized API key — double-check it")" ;;
    404)     info "$(t "${G_TIP} 接口地址不对，或该厂商路径有变" "${G_TIP} wrong base URL or the provider path changed")" ;;
    400|422) info "$(t "${G_TIP} 模型名可能过期，试试 --model-id <新模型名>" "${G_TIP} model id may be stale — try --model-id <id>")" ;;
    000)     info "$(t "${G_TIP} 网络不通或超时（无需翻墙，但要能访问该厂商域名）" "${G_TIP} network/timeout — the provider domain must be reachable")" ;;
    *)       info "$(t "${G_TIP} 详见下面的返回内容" "${G_TIP} see the response below")" ;;
  esac
  info "$(t "厂商文档：" "Provider docs: ")$(provider_docurl "$PROVIDER")"
  [ -s "$body" ] && printf "  %s%s%s\n" "$DIM" "$(head -c 400 "$body" 2>/dev/null)" "$RST"
  rm -f "$body" 2>/dev/null || true
  warn "$(t "配置已写入，但模型暂不可用。修正后重跑本脚本即可。" "Config was written but the model is not usable yet. Fix and re-run.")"
  FAILED=1
}

# ----------------------------------------------------------------------------
# Step 5: agent smoke test
#   Preferred:  star a repo via gh api (exercises the full tool-call chain)
#   Fallback:   run claude -p "hello" (verifies real Claude Code agent pipeline)
# ----------------------------------------------------------------------------
_try_star_test() {
  command -v gh >/dev/null 2>&1 || return 1
  gh auth status >/dev/null 2>&1 || return 1
  local http
  http="$(gh api -X PUT /user/starred/huhetingadday-boop/coding-agent-go \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    --silent --include 2>>"$LOG" | head -1 | grep -oE '[0-9]{3}' || echo "000")"
  case "$http" in
    204) ok "$(t "Agent 工具调用正常 (HTTP 204 — 已给 huhetingadday-boop/coding-agent-go 点赞 ★)" "Agent tool call works (HTTP 204 — starred huhetingadday-boop/coding-agent-go)")"; return 0 ;;
    304) ok "$(t "Agent 工具调用正常 (HTTP 304 — 你之前已给这个仓库点过赞)" "Agent tool call works (HTTP 304 — already starred)")"; return 0 ;;
    *)   return 1 ;;
  esac
}

_try_hello_test() {
  command -v claude >/dev/null 2>&1 || return 1
  note "$(t "点赞不可用，让 Claude Code 给模型发 hello 验证…" "Star not available; making Claude Code say hello instead…")"
  local outfile="${TMPDIR:-/tmp}/yiclaude-hello.$$.txt"
  # Claude Code -p mode: non-interactive, prints response, reads env from settings.json.
  # 45s timeout via a background-kill fallback (works without GNU timeout).
  if command -v timeout >/dev/null 2>&1; then
    echo "say hello in one short sentence" | timeout 45 claude -p > "$outfile" 2>>"$LOG" || true
  else
    echo "say hello in one short sentence" | claude -p > "$outfile" 2>>"$LOG" &
    local pid=$! waited=0
    while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 45 ]; do sleep 1; waited=$((waited+1)); done
    kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true
  fi
  if [ -s "$outfile" ]; then
    local reply; reply="$(head -c 120 "$outfile" | tr '\n' ' ' | sed 's/  */ /g')"
    local truncated=""; [ "$(wc -c < "$outfile")" -gt 120 ] && truncated="…"
    ok "$(t "Agent 可用 — Claude Code 回复: ${reply}${truncated}" "Agent works — Claude Code replied: ${reply}${truncated}")"
    rm -f "$outfile" 2>/dev/null || true
    return 0
  fi
  rm -f "$outfile" 2>/dev/null || true
  return 1
}

step_smoke() {
  [ "$DO_SMOKE" = "1" ] || return 0
  begin_step "$(t "Agent 能力验证" "Agent smoke test")"
  note "$(t "验证 Claude Code 工具调用链是否可用" "Verifying the Claude Code tool-call pipeline")"
  if _try_star_test; then return 0; fi
  if _try_hello_test; then return 0; fi
  warn "$(t "Agent 验证两项都未通过（不影响模型使用）。可能是网络或 API 配置问题，稍后重跑本脚本即可。" "Both agent checks failed (model still works). May be a temporary network or API-config issue; re-run later.")"
}

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------
summary() {
  local label; label="$(provider_label "$PROVIDER")"
  printf "\n"; hr
  if [ "$FAILED" = "0" ]; then
    printf "  %s%s %s%s\n" "$GRN$BOLD" "$G_DONE" "$(t "全部完成！" "All done!")" "$RST"
  else
    printf "  %s%s %s%s\n" "$YEL$BOLD" "$G_WARN" "$(t "安装完成，但验证未通过（见上）" "Installed, but verification did not pass (see above)")" "$RST"
  fi
  printf "  %s%-12s%s %s%s%s\n" "$DIM" "$(t "厂商" "Provider")" "$RST" "$BOLD" "$label ($PROVIDER)" "$RST"
  printf "  %s%-12s%s %s%s%s\n" "$DIM" "model" "$RST" "$CYAN" "$MODEL_ID" "$RST"
  printf "  %s%-12s%s %s%s%s\n" "$DIM" "config" "$RST" "$CYAN" "$SETTINGS" "$RST"
  printf "\n  %s%s%s\n" "$BOLD$CYAN" "$(t "现在怎么用：" "How to start:")" "$RST"
  printf "    %s1.%s %s %s%s%s\n" "$GRN$BOLD" "$RST" "$(t "进入你的项目文件夹：" "Go into your project folder:")" "$BOLD" "cd <your-folder>" "$RST"
  printf "    %s2.%s %s %s%s%s\n" "$GRN$BOLD" "$RST" "$(t "输入命令启动：" "Launch:")" "$BOLD$GRN" "claude" "$RST"
  note "$(t "如果提示 claude: command not found，关掉终端重开一个再试" "If you see 'claude: command not found', reopen your terminal")"
  note "$(t "想换别的模型：重跑本命令，选另一个就行" "To switch models: re-run this command and pick another")"
  hr
}

# ----------------------------------------------------------------------------
# main
# ----------------------------------------------------------------------------
trap 'ec=$?; if [ "$ec" -ne 0 ] && [ "${FAILED:-0}" != "1" ]; then printf "\n%sunexpected error (exit %s). log: %s%s\n" "${RED:-}" "$ec" "$LOG" "${RST:-}" >&2; fi' EXIT

main() {
  parse_args "$@"
  setup_ui
  [ "$DO_HELP" = "1" ] && { usage; exit 0; }
  [ "$DO_LIST" = "1" ] && { banner; printf "\n"; list_providers; exit 0; }

  if [ "$MODEL_SET" = "1" ] && ! is_provider "$PROVIDER"; then
    FAILED=1
    printf "%s%s %s%s '%s'\n\n" "$RED$BOLD" "$G_BAD" "$(t "不支持的厂商" "Unsupported provider")" "$RST" "$PROVIDER" >&2
    list_providers >&2
    exit 2
  fi

  detect_os
  TOTAL_STEPS=3
  [ "$DO_VERIFY" = "1" ] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
  [ "$DO_SMOKE"  = "1" ] && TOTAL_STEPS=$((TOTAL_STEPS + 1))

  banner
  printf "\n  %s%s%s\n" "$DIM" \
    "$(t "我会帮你：① 装好 Claude Code  ② 接上你选的国产模型  ③ 验证 agent 能力。跟着提示走，约 3-5 分钟。" \
         "I will: (1) install Claude Code, (2) wire it to your China LLM, (3) verify agent capability. ~3-5 min.")" "$RST"

  run_wizard
  validate_api_key_or_die

  step_prereq
  step_install_claude
  step_configure
  step_verify
  step_smoke
  summary
  [ "$FAILED" = "0" ]
}

main "$@"

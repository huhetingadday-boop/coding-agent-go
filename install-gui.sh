#!/usr/bin/env bash
#
# coding-agent-go GUI — browser-based installer for Claude Code / Codex + Chinese LLMs.
# Launches the Python server and opens the browser.
#
# Usage:
#   bash install-gui.sh              # default port 17860
#   bash install-gui.sh --port 9999  # custom port

set -euo pipefail

# Git Bash / Cygwin / MSYS are the wrong entry point on Windows: they have no
# apt/brew and the install steps assume a real Unix. Point them at the .bat.
# (WSL is a real Linux and is handled below — it just works.)
case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*)
    echo "检测到 Git Bash / Cygwin (Windows)。请在 cmd 或 PowerShell 里运行 install-gui.bat。" >&2
    echo "Detected Git Bash / Cygwin on Windows. Please run install-gui.bat from cmd or PowerShell instead." >&2
    exit 1 ;;
esac
# WSL is a real Linux, so the installer works here. It installs into the WSL
# side, so use the tools from a WSL terminal. If you want them in a Windows
# shell instead, run install-gui.bat from cmd/PowerShell. Informational only —
# no prompt, so the one-liner runs unattended.
if grep -qiE 'microsoft|wsl' /proc/sys/kernel/osrelease 2>/dev/null; then
  echo "检测到 WSL：将安装到 WSL 的 Linux 环境，请在 WSL 终端里使用。" >&2
  echo "（想在 Windows 终端里用，请改用 PowerShell 跑 install-gui.bat。）" >&2
  echo "Detected WSL: installing into the WSL Linux side; use the tools from a WSL terminal." >&2
fi

PORT=17860
while [ $# -gt 0 ]; do
  case "$1" in
    --port) PORT="$2"; shift 2 ;;
    -h|--help) echo "Usage: bash install-gui.sh [--port <port>]"; exit 0 ;;
    *) echo "Unknown: $1"; exit 2 ;;
  esac
done

PY=""
for c in python3 python; do
  command -v "$c" >/dev/null 2>&1 && { PY="$c"; break; }
done

if [ -z "$PY" ]; then
  echo "需要 Python 3，正在安装…"
  # Probe sudo non-interactively first so a passwordless config gap
  # fails fast with a clear message instead of hanging.
  if ! sudo -n true 2>/dev/null; then
    sudo_ok=0
  else
    sudo_ok=1
  fi
  if command -v brew >/dev/null 2>&1; then
    brew install python3
  elif command -v apt-get >/dev/null 2>&1; then
    if [ "$sudo_ok" = 0 ]; then
      echo "需要 sudo 权限 — 请在终端手动运行: sudo apt-get install -y python3" >&2
      exit 1
    fi
    sudo apt-get update -qq && sudo apt-get install -y python3
  elif command -v dnf >/dev/null 2>&1; then
    if [ "$sudo_ok" = 0 ]; then
      echo "需要 sudo 权限 — 请在终端手动运行: sudo dnf install -y python3" >&2
      exit 1
    fi
    sudo dnf install -y python3
  elif command -v pacman >/dev/null 2>&1; then
    if [ "$sudo_ok" = 0 ]; then
      echo "需要 sudo 权限 — 请在终端手动运行: sudo pacman -Sy --noconfirm python" >&2
      exit 1
    fi
    sudo pacman -Sy --noconfirm python
  else
    echo "请先安装 Python 3: https://python.org/downloads/" >&2; exit 1
  fi
fi

# Find server.py next to this script (cloned repo). When this script is piped
# straight from curl (`bash <(curl …)`), $0 is a /dev/fd path and server.py is
# not on disk, so fetch the app into a temp dir from the China-friendly CDN.
SCRIPTPATH="$(cd "$(dirname "$0")" 2>/dev/null && pwd)" || SCRIPTPATH=""
if [ -n "$SCRIPTPATH" ] && [ -f "$SCRIPTPATH/server.py" ]; then
  SERVER="$SCRIPTPATH/server.py"
else
  CDN="https://cdn.jsdelivr.net/gh/huhetingadday-boop/coding-agent-go@latest"
  DEST="$(mktemp -d 2>/dev/null || echo "/tmp/coding-agent-go.$$")"
  mkdir -p "$DEST"
  echo "下载 server.py / providers.json …"
  curl -fsSL "$CDN/server.py"      -o "$DEST/server.py"
  curl -fsSL "$CDN/providers.json" -o "$DEST/providers.json"
  SERVER="$DEST/server.py"
fi
exec "$PY" "$SERVER" --port "$PORT"

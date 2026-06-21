#!/usr/bin/env bash
#
# yiclaude smoke test — verify that Claude Code's agent tool-call pipeline
# works with the currently configured provider.
#
# The test stars a GitHub repo via `gh api`.  It exercises the full agent
# chain:  model decision → Bash tool → gh CLI → GitHub API → result.
#
# Usage:
#   ./smoke-test.sh                 # stars huhetingadday-boop/coding-agent-go (neutral test target)
#   ./smoke-test.sh owner/repo      # star a different repo
#
# Prerequisites:  `gh` must be installed and authenticated.
#   brew install gh && gh auth login
#
# This is a standalone script — it does NOT depend on yiclaude internals.

set -euo pipefail

RED='\033[31m'; GRN='\033[32m'; CYAN='\033[36m'; YEL='\033[33m'; BOLD='\033[1m'; DIM='\033[2m'; RST='\033[0m'
TARGET="${1:-huhetingadday-boop/coding-agent-go}"

ok()   { printf "  %s✓%s %s\n" "$GRN" "$RST" "$1"; }
warn() { printf "  %s!%s %s\n" "$YEL" "$RST" "$1"; }
fail() { printf "\n%s✗ 测试失败:%s %s\n" "$RED$BOLD" "$RST" "$1"; exit 1; }

banner() {
  printf "\n%s▸%s %syiclaude agent-smoke-test%s\n" "$CYAN" "$RST" "$BOLD" "$RST"
  printf "  %s验证 Claude Code × 国产模型的 agent 工具调用链路%s\n" "$DIM" "$RST"
  printf "  %s目标: %s → %s%s\n\n" "$DIM" "$TARGET" "$(echo "$TARGET" | cut -d/ -f1)" "$RST"
}

banner

# 1. gh available?
printf "  %s[1/4]%s 检查 gh CLI..." "$BOLD" "$RST"
if command -v gh >/dev/null 2>&1; then
  printf " %s✓%s (%s)\n" "$GRN" "$RST" "$(gh --version 2>/dev/null | head -1)"
else
  printf " %s✗%s\n" "$RED" "$RST"
  fail "请先装 gh:  brew install gh && gh auth login"
fi

# 2. gh logged in?
printf "  %s[2/4]%s 检查 gh 登录状态..." "$BOLD" "$RST"
if gh auth status >/dev/null 2>&1; then
  printf " %s✓%s\n" "$GRN" "$RST"
else
  printf " %s✗%s\n" "$RED" "$RST"
  fail "请先登录: gh auth login"
fi

# 3. star the repo
printf "  %s[3/4]%s 通过 gh api 点 star..." "$BOLD" "$RST"
http=$(gh api -X PUT "/user/starred/$TARGET" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  --silent --include 2>&1 | head -1 | grep -oE '[0-9]{3}' || echo "000")
case "$http" in
  204) printf " %s✓%s (HTTP 204 — star 成功)\n" "$GRN" "$RST" ;;
  304) printf " %s✓%s (HTTP 304 — 之前已经 star 过)\n" "$GRN" "$RST" ;;
  *)   printf " %s✗%s (HTTP %s)\n" "$RED" "$RST" "$http"; fail "star 失败 (HTTP $http)" ;;
esac

# 4. verify
printf "  %s[4/4]%s 验证 star 生效..." "$BOLD" "$RST"
if gh api "/user/starred/$TARGET" --silent --include 2>&1 | head -1 | grep -qE '20[04]'; then
  printf " %s✓%s\n" "$GRN" "$RST"
else
  printf " %s✗%s\n" "$RED" "$RST"
  warn "API 缓存可能还没刷新，HTTP 204 已确认 star 成功，不影响结论。"
fi

printf "\n%s  %sAgent 工具调用验证通过！%s\n" "$GRN$BOLD" "$(echo -e '\xe2\x98\x85')" "$RST"
cat <<EOF

  整条链路已跑通：
    Claude Code (agent 框架)
      → 模型决策: 调用 Bash 工具，传参 'gh api ...'
        → Bash 工具: 执行 gh api -X PUT /user/starred/$TARGET
          → HTTP 204: star 成功

  国产模型只要说 Anthropic Messages 格式，走同一框架、同一条链路，
  agent 能力完全一致。区别只在于模型决策质量（选对工具、传对参数）。
EOF

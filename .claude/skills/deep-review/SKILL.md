---
name: deep-review
description: Deep, project-specific review for coding-agent-go changes. Use when reviewing a diff, PR, or branch in this repo, or when asked to audit the installer. The MANDATORY gate is mirror-first: every install/download target must try the China (domestic) source first and fall back to the official/overseas source only if the mirror fails — the product's no-VPN promise. Also covers install-command consistency, cross-platform parity, network timeouts/fallbacks, self-test safety, and the keys-stay-local privacy guarantee.
---

# Deep Review — coding-agent-go

This project is a one-click installer for Claude Code / Codex / Gemini aimed at users in mainland China who often have **no VPN**. The whole value is: it installs reliably without a VPN. So a review here is not generic — it checks the invariants that keep that promise true.

Review the diff against `main` (`git diff main...HEAD` or the working tree). For a large diff, fan out the dimensions below to parallel subagents, then merge findings. Report each finding as `file:line` + severity (**blocker** / should-fix / nit).

## Gate 0 — Mirror-first (MANDATORY, never skip)
Every place that installs software or downloads a file MUST try the China source first and use the official/overseas source only as a fallback. This is a hard gate: if any install target is official-first, the review FAILS until it's fixed.

**How to audit.** Find every network install/download site, then confirm the ordering for each:
```bash
grep -nE "subprocess\.run|_run\(|_download\(|_npm_global|curl |Invoke-WebRequest|iwr |npm install|brew install|pip install" server.py install-gui.sh install-gui.ps1 install-gui.bat
grep -nE "github\.com|api\.github|raw\.githubusercontent|registry\.npmjs\.org|nodejs\.org|python\.org|claude\.ai|chatgpt\.com|brew\.sh" server.py install-gui.* install.sh
```
For each hit, the **China source must appear first** and the overseas host must be reachable only after the mirror fails. Known-good sources (a domestic host on the left of each pair):
- **npm packages** → `_npm_global` uses `NPM_MIRROR` (`registry.npmmirror.com`) then `NPM_OFFICIAL` (`registry.npmjs.org`). Every CLI (`@anthropic-ai/claude-code`, `@openai/codex`, `@vybestack/llxprt-code`, `mimo2codex`) installs through this.
- **Node.js** → `cdn.npmmirror.com` / `mirrors.ustc.edu.cn` then `nodejs.org` (`_install_node`, `_install_node_tarball_mac`).
- **GitHub release assets / raw files** → `GH_PROXIES` (`ghfast.top`, `gh-proxy.com`, `ghproxy.net`) or jsDelivr, then direct `github.com` / `raw.githubusercontent.com` last (`_install_gh`, `_seed_better_sqlite3_prebuild`, `_install_brew`).
- **Homebrew** → USTC env remotes (`HOMEBREW_BREW_GIT_REMOTE`, `HOMEBREW_CORE_GIT_REMOTE`, `HOMEBREW_BOTTLE_DOMAIN`, `HOMEBREW_API_DOMAIN`) + install.sh via jsDelivr/proxies (`_install_brew`).
- **Python (Windows)** → `cdn.npmmirror.com` / `mirrors.huaweicloud.com` then `python.org` (`install-gui.ps1`, `install-gui.bat`).
- **The bootstrap script + `server.py` / `providers.json`** → ghproxy (`ghfast.top`) or jsDelivr mirrors, official GitHub last (`install-gui.sh` mirror list; README/homepage commands).

**Violation patterns to flag as blocker:**
- A `curl`/`_download`/`Invoke-WebRequest` whose FIRST URL is an overseas host (`github.com`, `nodejs.org`, `claude.ai`, `chatgpt.com`, `python.org`, `registry.npmjs.org`, `raw.githubusercontent.com`).
- `npm install` without `--registry <mirror>` on the first attempt (a user whose default registry is already the mirror is fine, but the code must pass the mirror explicitly — see the note on `NPM_OFFICIAL`).
- A new dependency added with only an official source and no China fallback.
- An official-first "probe then fall back to mirror" shape (the old bug): the mirror must be the primary path, the official source the fallback. Reference the fixed shape in `_install_claude` / `_install_codex` (mac/Linux): npm-mirror first inside a `try`, official `claude.ai` / `chatgpt.com` installer only in the `except`.

Output for this gate: an explicit **PASS/FAIL** plus the full list of install targets and which source each tries first.

## Gate 1 — Install-command consistency
The public install command appears in several files; they must all agree.
- `README.md`, `README.en.md`, `docs/index.html` (the download page `BASE`), and `install-gui.{sh,ps1,bat}` must point at the same primary source and the same fallback.
- If the primary uses ghproxy → `raw.githubusercontent.com/.../main/`, confirm `RELEASE.md` still describes the channel split truthfully (primary tracks `main`; jsDelivr `@latest` fallback + app files are tag-gated).
- Verify any URL you cite actually serves the file (don't ship a dead proxy domain): `curl -sI <url>`.

## Gate 2 — Cross-platform parity
Each install path must handle macOS, Linux, and Windows, or explicitly and cleanly skip. When a fix touches one platform's install, check the sibling branches (`IS_WIN` / `IS_MAC` / `IS_LINUX`) for the same issue. Node prerequisites: confirm the npm path has Node ensured (either an earlier `_plan` step or inside the function's mirror `try`).

## Gate 3 — Timeouts, fallbacks, and "not frozen"
- Every network call is timeout-bounded (`subprocess.run(..., timeout=)`, `_run(..., timeout=)`, `_download(..., timeout=)`). No unbounded call.
- Long steps stream a heartbeat so the UI never looks frozen (large downloads like the ~115 MB codex binary should tell the user to wait).
- A fallback chain must not dead-end on a raw Python error — the final failure should raise a friendly bilingual message, not a leaked `TimeoutExpired`/`cmd fail` string.
- Timeout values fit the payload: a big native binary needs a generous mirror timeout; a fail-fast probe should be short.

## Gate 4 — Self-test safety
Tests must stay fully offline. Any new install/network side effect must be guarded by `_skip_for_test(...)` / `TEST_MODE` (`CAG_SELFTEST=1`) so `tests/test_e2e.py` never touches the network or the user's real `~/.claude` / `~/.codex` / `~/.llxprt-code`. New behavior gets a regression test. Run before approving:
```bash
CAG_SELFTEST=1 python3 tests/test_e2e.py && CAG_SELFTEST=1 python3 tests/test_install_reuse.py
```

## Gate 5 — Privacy and SSE contract
- The API key flows only between the user's machine and the LLM vendor. It must never be logged, sent to the author, or leaked into the served HTML. Config writes land only in local files.
- Each install run streams `log` events and exactly one terminal `done`/`error` over SSE; the `_installing` lock is always released.

## Output
1. **Mirror-first gate: PASS / FAIL** with the target-by-target source table.
2. Findings by gate, each `file:line` + severity, most severe first.
3. One-line verdict: safe to merge, or the blockers to fix first.

# coding-agent-go
[![tests](https://github.com/huhetingadday-boop/coding-agent-go/actions/workflows/test.yml/badge.svg)](https://github.com/huhetingadday-boop/coding-agent-go/actions/workflows/test.yml)
[中文](README.md) · **English**

One command to install Claude Code / OpenAI Codex / Gemini CLI inside mainland China and wire them to China LLMs (GLM / Kimi / MiniMax / Qwen / DeepSeek). No VPN, a GUI flow, and a non-technical user just follows the prompts.

## One command to install and open the setup UI
One command does it all: it downloads the installer (`server.py` + `providers.json`), starts a local web setup UI on your machine (default http://localhost:17860), and opens your browser. No need to clone the repo first. Follow the GUI: ① pick Claude Code / Codex / Gemini → ② pick a model → ③ paste your API key → ④ it installs and verifies automatically.
### WSL / macOS / Linux (bash)
Open a terminal (in WSL use the same command), paste this one line, press Enter:
```bash
bash <(curl -fsSL https://cdn.jsdelivr.net/gh/huhetingadday-boop/coding-agent-go@main/install-gui.sh)
```
### Windows PowerShell
Open "PowerShell", paste this one line, press Enter (`irm | iex` is the PowerShell version of `curl | sh`):
```powershell
irm https://cdn.jsdelivr.net/gh/huhetingadday-boop/coding-agent-go@main/install-gui.ps1 | iex
```
Both commands download `server.py` and `providers.json`, start the local UI server, and open the browser — no clone needed. WSL installs into the WSL Linux environment, so run it in a WSL terminal; to use the native Windows terminal, take the PowerShell path.
> No Python? No problem: the script installs it automatically (per-user, no UAC prompt). If you prefer cmd/batch on the command line, you can also use: `$f="$env:TEMP\acgg.bat"; iwr https://cdn.jsdelivr.net/gh/huhetingadday-boop/coding-agent-go@main/install-gui.bat -OutFile $f; cmd /c $f`

## Supported agents

| Agent | How it connects | Complexity |
|-------|-----------------|------------|
| **Claude Code** | Native Anthropic protocol, direct | Low |
| **OpenAI Codex** | Via a local mimo2codex proxy (`wire_api = "responses"`); the proxy is zero-auth, so no key is written to your shell | Medium |
| **Gemini CLI** | Via the llxprt-code community CLI, native Anthropic protocol, direct | Low |

## Supported models

| Option | Vendor | Default model |
|--------|--------|---------------|
| `glm` | Zhipu GLM (recommended) | glm-4.6 |
| `kimi` | Kimi (Moonshot) | kimi-k2.7-code |
| `minimax` | MiniMax | MiniMax-M3 |
| `qwen` | Qwen | qwen3-coder-plus |
| `deepseek` | DeepSeek | deepseek-v4-pro |

## No API key yet

The GUI shows each vendor's API key page and the steps to get one. Sign up, create a key, copy it, and paste it in.
- Zhipu GLM: https://www.bigmodel.cn/usercenter/proj-mgmt/apikeys
- Kimi: https://platform.kimi.com/console/api-keys
- MiniMax: https://platform.minimaxi.com/user-center/basic-information/interface-key
- Qwen: https://bailian.console.aliyun.com/?tab=model#/api-key
- DeepSeek: https://platform.deepseek.com/api_keys

## What it does for you

- Installs prerequisites automatically: on macOS, Homebrew + gh CLI; the Codex / Gemini paths also install Node.js
- Official sources first, automatic fallback to China mirrors (USTC / jsDelivr) on failure
- Writes the config files (Claude Code: `settings.json` / Codex: `config.toml` / Gemini: llxprt `config.json`)
- Codex path starts a local mimo2codex proxy to reach China models (`wire_api = "responses"`). The proxy is zero-auth, so no key goes into your shell config, and it is set to start on boot
- Sends a test request to confirm the model really works
- Agent smoke test: stars huhetingadday-boop/coding-agent-go through `gh api` to verify the full tool-call path

## Uninstall

### Claude Code
- Remove config: delete the `env` block in `~/.claude/settings.json`
- Uninstall: macOS `brew uninstall --cask claude-code`

### Codex
- Remove config: delete the coding-agent-go provider in `~/.codex/config.toml`
- Remove proxy config: delete `~/.mimo2codex/`
- Uninstall Codex: `npm uninstall -g @openai/codex`
- Uninstall the proxy: `npm uninstall -g mimo2codex`

### Gemini CLI
- Remove config: delete `~/.llxprt-code/config.json`
- Uninstall: `npm uninstall -g @vybestack/llxprt-code`

## Debugging

If something goes wrong during install, check the debug log:
- macOS/Linux: `/tmp/coding-agent-go-debug.log`
- Windows: `%TEMP%\coding-agent-go-debug.log`

## License

[MIT](LICENSE)

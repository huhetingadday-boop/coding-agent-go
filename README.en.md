# coding-agent-go
[![tests](https://github.com/huhetingadday-boop/coding-agent-go/actions/workflows/test.yml/badge.svg)](https://github.com/huhetingadday-boop/coding-agent-go/actions/workflows/test.yml)
[中文](README.md) · **English**

One command installs Claude Code / OpenAI Codex / Gemini CLI and wires them to China LLMs (DeepSeek / GLM / Kimi / Qwen / MiniMax). Open a terminal, paste, press Enter — no VPN, just follow the prompts.

<p align="center">
  <img src="docs/demo.gif" alt="coding-agent-go install demo" width="600">
</p>

> 🚧 A double-click desktop app (native window) is a work in progress, not released yet — for now, use the one-line command below.

## One-line install (open a terminal, paste, Enter)
One command does it all: it downloads the installer (`server.py` + `providers.json`), starts a local web setup UI on your machine (default http://localhost:17860), and opens your browser. No need to clone the repo first. Follow the GUI: ① pick Claude Code / Codex / Gemini → ② pick a model → ③ paste your API key → ④ it installs and verifies automatically.
### macOS / Linux / WSL (bash)
Open a terminal (in WSL use the same command), paste this one line, press Enter:
```bash
bash <(curl -fsSL --connect-timeout 8 https://ghfast.top/https://raw.githubusercontent.com/huhetingadday-boop/coding-agent-go/main/install-gui.sh)
```
If that can't connect, use the jsDelivr fallback (pinned to the latest release):
```bash
bash <(curl -fsSL https://cdn.jsdelivr.net/gh/huhetingadday-boop/coding-agent-go@latest/install-gui.sh)
```
### Windows PowerShell
Open "PowerShell", paste this one line, press Enter (`irm | iex` is the PowerShell version of `curl | sh`):
```powershell
irm https://cdn.jsdelivr.net/gh/huhetingadday-boop/coding-agent-go@latest/install-gui.ps1 | iex
```
Both commands download `server.py` and `providers.json`, start the local UI server, and open the browser — no clone needed. WSL installs into the WSL Linux environment, so run it in a WSL terminal; to use the native Windows terminal, take the PowerShell path.
> No Python? No problem: the script installs it automatically (per-user, no UAC prompt). If you prefer cmd/batch on the command line, you can also use: `$f="$env:TEMP\acgg.bat"; iwr https://cdn.jsdelivr.net/gh/huhetingadday-boop/coding-agent-go@latest/install-gui.bat -OutFile $f; cmd /c $f`

## After it installs — how to use it
The installer tells you the next step when it finishes. In short:
- Open a terminal and type `claude` (Codex is `codex`, Gemini is `llxprt`) to start chatting
- Try a prompt: "write me a small Python script that runs"
- Cost: pay-as-you-go — a few yuan lasts a long time; check usage on the vendor's dashboard
- On Windows, open a new terminal window after installing so the new command is on PATH

## Supported agents

| Agent | How it connects | Complexity |
|-------|-----------------|------------|
| **Claude Code** | Native Anthropic protocol, direct | Low |
| **OpenAI Codex** | Via a local mimo2codex proxy (`wire_api = "responses"`); the proxy is zero-auth, so no key is written to your shell | Medium |
| **Gemini CLI** | Via the llxprt-code community CLI, native Anthropic protocol, direct | Low |

## Supported models

| Option | Vendor | Default model |
|--------|--------|---------------|
| `deepseek` | DeepSeek (recommended) | deepseek-v4-pro |
| `glm` | Zhipu GLM | glm-4.6 |
| `kimi` | Kimi (Moonshot) | kimi-k2.7-code |
| `minimax` | MiniMax | MiniMax-M3 |
| `qwen` | Qwen | qwen3-coder-plus |

## No API key yet
The GUI shows each vendor's API key page and the steps to get one. Sign up, create a key, copy it, and paste it in.
- Zhipu GLM: https://www.bigmodel.cn/usercenter/proj-mgmt/apikeys
- Kimi: https://platform.kimi.com/console/api-keys
- MiniMax: https://platform.minimaxi.com/user-center/basic-information/interface-key
- Qwen: https://bailian.console.aliyun.com/?tab=model#/api-key
- DeepSeek: https://platform.deepseek.com/api_keys

## Security & privacy
- **Your API key only flows between your computer and the LLM vendor** — never to the author or any third party. All config is written only to local files on your machine.
- **The install scripts are public — read them before you run them.** If `irm | iex` / `curl | sh` makes you uneasy, open the script in your browser first and decide: [install-gui.ps1](https://github.com/huhetingadday-boop/coding-agent-go/blob/main/install-gui.ps1) (Windows) · [install-gui.sh](https://github.com/huhetingadday-boop/coding-agent-go/blob/main/install-gui.sh) (macOS/Linux/WSL).
- **The main command is tuned for China networks; the fallback is pinned to a release.** The macOS/Linux main command goes through ghproxy straight to GitHub, avoiding the SSL errors and throttling jsdelivr occasionally hits in China; it tracks the `main` branch. To run only tagged releases, use the jsDelivr fallback above (the Windows command is also jsDelivr `@latest`).

## Trouble?
- **Where's the terminal?** Windows: search "PowerShell" in Start. Mac: search "Terminal" in Launchpad. Open it, paste the command, Enter.
- **Windows asks "Do you want to allow this app to make changes to your device?"** That's normal — it pops a few times while installing Node and Codex components (e.g. `codex-windows-sandbox-setup.exe`). Click **Yes**; clicking No stops the install.
- **No Python?** Don't worry — the script installs it for you (per-user, no UAC).
- **Blocked by 360 / PC Manager / antivirus?** Choose "Allow" / "Trust" in the popup, not "Block"; if it blocks `node` or the background proxy, add it to the trusted list and re-run. If that's too fiddly, turn the antivirus off, install, then turn it back on.
- **"claude" not found?** Close the terminal and open a new one — new commands need a fresh window to be on PATH.
- **Windows still stuck?** Open PowerShell as Administrator and run the install command again.

## Community
Questions, feedback, or tutorial updates — join the group, or follow the author "产品经理胡笛笛" ([Douyin](https://www.douyin.com/user/MS4wLjABAAAAAaiQmXTnVitWO9_2loyITZvKbS3rZYVocuQa-UgLd5E) · [Xiaohongshu](https://www.xiaohongshu.com/user/profile/6210ebbd0000000010004897)).
<!-- Export your WeChat/QQ group QR code to docs/qrcode.png, then uncomment the line below -->
<!-- ![group QR](docs/qrcode.png) -->
> Group QR pending — drop the QR image at `docs/qrcode.png`, then uncomment to show it.

## Buy the author a coffee ☕
If this saved you time, you can tip the author via WeChat Pay:
<img src="docs/wechat-pay.png" alt="WeChat Pay · tip the author 胡笛笛" width="260">

## What it does for you
- Installs prerequisites automatically: when Node.js is needed (Codex / Gemini, and Claude's npm fallback) it uses the official prebuilt — **no Homebrew, no Xcode Command Line Tools, no admin** (an existing brew is used if present)
- Official sources first, automatic fallback to China mirrors (USTC / jsDelivr / npmmirror) — installs Claude Code / Codex / Gemini even without a VPN
- Writes the config files (Claude Code: `settings.json` / Codex: `config.toml` / Gemini: llxprt `config.json`)
- Codex path starts a local mimo2codex proxy to reach China models (`wire_api = "responses"`). The proxy is zero-auth, so no key goes into your shell config, and it is set to start on boot
- Sends a test request to confirm the model really works
- Agent smoke test: stars huhetingadday-boop/coding-agent-go through `gh api` to verify the full tool-call path

## Debugging
If something goes wrong during install, check the debug log:
- macOS/Linux: `/tmp/coding-agent-go-debug.log`
- Windows: `%TEMP%\coding-agent-go-debug.log`

## License
[Apache 2.0](LICENSE)

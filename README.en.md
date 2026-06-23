# coding-agent-go
[![tests](https://github.com/huhetingadday-boop/coding-agent-go/actions/workflows/test.yml/badge.svg)](https://github.com/huhetingadday-boop/coding-agent-go/actions/workflows/test.yml)
[中文](README.md) · **English**

One command to install Claude Code / OpenAI Codex / Gemini CLI inside mainland China and wire them to China LLMs (GLM / Kimi / MiniMax / Qwen / DeepSeek). No VPN, a GUI flow, and a non-technical user just follows the prompts.

## Download an installer (double-click, no terminal)
Best for non-technical users: download, double-click, done — no terminal, no VPN.
- 📥 **Download page (auto-detects your OS)**: <https://huhetingadday-boop.github.io/coding-agent-go/>
- 🍎 **macOS (Apple Silicon M1/M2/M3/M4)**: [China mirror .dmg](https://gh-proxy.com/https://github.com/huhetingadday-boop/coding-agent-go/releases/latest/download/coding-agent-go-macos.dmg) · [GitHub direct](https://github.com/huhetingadday-boop/coding-agent-go/releases/latest/download/coding-agent-go-macos.dmg)
- 🪟 **Windows 10 / 11 (64-bit)**: [China mirror .exe](https://gh-proxy.com/https://github.com/huhetingadday-boop/coding-agent-go/releases/latest/download/coding-agent-go-windows.exe) · [GitHub direct](https://github.com/huhetingadday-boop/coding-agent-go/releases/latest/download/coding-agent-go-windows.exe)

Double-click after downloading; the install UI opens in your browser. If the first open is blocked ("unidentified developer" on macOS, or a SmartScreen box on Windows), see [Installer won't open](#installer-wont-open). On an Intel Mac, use the one-line command below instead. Binaries come from [Releases](https://github.com/huhetingadday-boop/coding-agent-go/releases/latest), each with a SHA-256; the download page and binaries appear after the first version tag is built.

## Demo
<!--
  Recording guide: capture a 30-second run — open PowerShell → paste the install command → the GUI installs everything → type claude in a terminal and it works.
  Record with ScreenToGif (Windows) or Kap (macOS), export a GIF named demo.gif into docs/, then uncomment the line below.
-->
<!-- ![demo](docs/demo.gif) -->
> Demo GIF pending — record one per the guide above, drop it at `docs/demo.gif`, then uncomment to show it.

## One command to install and open the setup UI
One command does it all: it downloads the installer (`server.py` + `providers.json`), starts a local web setup UI on your machine (default http://localhost:17860), and opens your browser. No need to clone the repo first. Follow the GUI: ① pick Claude Code / Codex / Gemini → ② pick a model → ③ paste your API key → ④ it installs and verifies automatically.
### WSL / macOS / Linux (bash)
Open a terminal (in WSL use the same command), paste this one line, press Enter:
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
- **The install command is pinned to the latest release.** jsdelivr's `@latest` resolves only to a tagged release, never an unreleased dev branch — so the command is stable and reproducible.
- **Packaged builds are verifiable.** Each `.exe` / `.dmg` on the [Releases](https://github.com/huhetingadday-boop/coding-agent-go/releases) page ships a SHA-256 checksum, so you can verify it before running.

## Installer won't open
The binaries aren't paid-signed by Apple/Microsoft, so the OS may block the first open. Allow it once and it's fine after that.
### macOS: "can't be opened — unidentified developer"
- Drag **AI Coding Go** from the .dmg into Applications.
- In Applications, **right-click it → "Open"**, then click "Open" in the dialog.
- Still blocked? System Settings → "Privacy & Security" → "Open Anyway".
### Windows: SmartScreen blue box / antivirus block
360 / 电脑管家 / Windows SmartScreen sometimes block the `.exe`, the PowerShell script, or the background proxy. If that happens:
- SmartScreen blue box: click "More info" → "Run anyway".
- 360 / 电脑管家 popup: choose "Allow" / "Trust", not "Block".
- Antivirus blocked the proxy or `node`: whitelist the `%TEMP%\coding-agent-go` folder and Node.js, then re-run the install command.
- Still stuck: open PowerShell as Administrator and run the install command again.

## Community
Questions, feedback, or tutorial updates — join the group, or follow the author "产品经理胡笛笛" ([Douyin](https://www.douyin.com/user/MS4wLjABAAAAAaiQmXTnVitWO9_2loyITZvKbS3rZYVocuQa-UgLd5E) · [Xiaohongshu](https://www.xiaohongshu.com/user/profile/6210ebbd0000000010004897)).
<!-- Export your WeChat/QQ group QR code to docs/qrcode.png, then uncomment the line below -->
<!-- ![group QR](docs/qrcode.png) -->
> Group QR pending — drop the QR image at `docs/qrcode.png`, then uncomment to show it.

## What it does for you
- Installs prerequisites automatically: when Node.js is needed (Codex / Gemini, and Claude's npm fallback) it uses the official prebuilt — **no Homebrew, no Xcode Command Line Tools, no admin** (an existing brew is used if present)
- Official sources first, automatic fallback to China mirrors (USTC / jsDelivr / npmmirror) — installs Claude Code / Codex / Gemini even without a VPN
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

### Node.js (the portable build this tool installs on macOS when brew is absent)
- Delete the `~/.coding-agent-go/node` folder
- Remove the PATH line tagged `# coding-agent-go` from your shell profile (`~/.zprofile` / `~/.zshrc`, etc.)

## Debugging
If something goes wrong during install, check the debug log:
- macOS/Linux: `/tmp/coding-agent-go-debug.log`
- Windows: `%TEMP%\coding-agent-go-debug.log`

## License
[MIT](LICENSE)

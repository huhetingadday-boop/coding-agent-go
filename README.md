# coding-agent-go
[![tests](https://github.com/huhetingadday-boop/coding-agent-go/actions/workflows/test.yml/badge.svg)](https://github.com/huhetingadday-boop/coding-agent-go/actions/workflows/test.yml)
**中文** · [English](README.en.md)

下载安装包，双击就能装好 Claude Code / OpenAI Codex / Gemini CLI 并接上国产大模型（DeepSeek / GLM / Kimi / Qwen / MiniMax）。不用翻墙、不用敲命令，电脑小白跟着提示走就行。会用终端的也可以一行命令装（见 [下面](#其次会用命令行一行直接装)）。

## 下载安装包（双击运行，最适合电脑小白）
不会敲命令也没关系：下载下来双击就跑，不用开终端、不用翻墙。它是一个一键安装器（应用内置网页，不依赖浏览器），跑一次装好就行。
- 📥 **下载页（自动识别系统）**：<https://huhetingadday-boop.github.io/coding-agent-go/>
- 🍎 **macOS（Intel 与 Apple 芯片通用）**：[国内镜像 .dmg](https://gh-proxy.com/https://github.com/huhetingadday-boop/coding-agent-go/releases/latest/download/coding-agent-go-macos.dmg) · [GitHub 直连](https://github.com/huhetingadday-boop/coding-agent-go/releases/latest/download/coding-agent-go-macos.dmg)
- 🪟 **Windows 10 / 11（64 位）**：[国内镜像 .exe](https://gh-proxy.com/https://github.com/huhetingadday-boop/coding-agent-go/releases/latest/download/coding-agent-go-windows.exe) · [GitHub 直连](https://github.com/huhetingadday-boop/coding-agent-go/releases/latest/download/coding-agent-go-windows.exe)

下载后双击运行，会弹出一个安装窗口，跟着走、装完关掉窗口就行。首次打开如果提示「身份不明的开发者」(macOS) 或 SmartScreen 蓝框 (Windows)，见 [安装包打不开怎么办](#安装包打不开怎么办)。macOS 是通用版，Intel 和 Apple 芯片都能用，不用挑。安装包来自 [Releases](https://github.com/huhetingadday-boop/coding-agent-go/releases/latest)，每个都附 SHA-256 校验值。

## 演示
<!--
  录制指引：录一段 30 秒的完整过程 —— 下载安装包 → 双击打开（弹出安装窗口）→ 选模型 / 填 Key → 装好后终端输入 claude 能用。
  用 ScreenToGif（Windows）或 Kap（macOS）录屏，导出成 GIF，命名为 demo.gif 放到 docs/ 目录，再取消下面一行的注释。
-->
<!-- ![演示](docs/demo.gif) -->
> 演示动图待补 —— 按上面注释里的指引录一段放到 `docs/demo.gif`，再取消注释即可显示。

## 其次：会用命令行？一行直接装
（不想下载安装包、习惯终端的话走这条。）一行命令搞定：下载安装器（`server.py` + `providers.json`），在本机起一个网页版安装界面（默认 http://localhost:17860），浏览器自动打开。不用先 clone 仓库。跟着 GUI 走：① 选 Claude Code / Codex / Gemini → ② 选模型 → ③ 填 API Key → ④ 自动安装并验证。
### WSL / macOS / Linux（bash）
打开终端（WSL 里直接用同一条命令），粘贴这一行，回车：
```bash
bash <(curl -fsSL https://cdn.jsdelivr.net/gh/huhetingadday-boop/coding-agent-go@latest/install-gui.sh)
```
### Windows PowerShell
打开「PowerShell」，粘贴这一行，回车（`irm | iex` 就是 PowerShell 版的 `curl | sh`）：
```powershell
irm https://cdn.jsdelivr.net/gh/huhetingadday-boop/coding-agent-go@latest/install-gui.ps1 | iex
```
两条命令都会自动下载 `server.py` 和 `providers.json`，起本机 UI 服务并打开浏览器，不用先 clone。WSL 会装到 WSL 的 Linux 环境，请在 WSL 终端里用；想在 Windows 原生终端里用，就走 PowerShell 这条。
> 没装 Python 也没关系：脚本会自动装（per-user，不弹 UAC）。如果命令行里偏好 cmd/批处理，也可以用：`$f="$env:TEMP\acgg.bat"; iwr https://cdn.jsdelivr.net/gh/huhetingadday-boop/coding-agent-go@latest/install-gui.bat -OutFile $f; cmd /c $f`

## 装好之后怎么用
安装器跑完会直接告诉你下一步。简单说：
- 打开终端，输入 `claude`（Codex 是 `codex`，Gemini 是 `llxprt`）就能开聊
- 试一句：「帮我写一个能跑的 Python 小脚本」
- 费用：按量计费，先充几块钱能用很久；用量在所选厂商的官网后台可查
- Windows 装完后请打开一个新的终端窗口，新装的命令才在 PATH 里

## 支持的 Agent

| Agent | 接入方式 | 复杂度 |
|-------|---------|--------|
| **Claude Code** | 原生 Anthropic 协议直连 | 低 |
| **OpenAI Codex** | 本地 mimo2codex 代理转接（`wire_api = "responses"`），代理零鉴权，不写 Key 到 shell | 中 |
| **Gemini CLI** | 通过 llxprt-code 社区版原生支持 Anthropic 协议直连 | 低 |

## 支持的模型

| 选项 | 厂商 | 默认模型 |
|------|------|----------|
| `deepseek` | DeepSeek（推荐） | deepseek-v4-pro |
| `glm` | 智谱 GLM | glm-4.6 |
| `kimi` | Kimi (Moonshot) | kimi-k2.7-code |
| `minimax` | MiniMax | MiniMax-M3 |
| `qwen` | 通义千问 Qwen | qwen3-coder-plus |

## 没有 API Key 怎么办
GUI 里会给出每个厂商的 API Key 申请页链接和步骤指引。注册、新建 key、复制、粘贴即可。
- 智谱 GLM：https://www.bigmodel.cn/usercenter/proj-mgmt/apikeys
- Kimi：https://platform.kimi.com/console/api-keys
- MiniMax：https://platform.minimaxi.com/user-center/basic-information/interface-key
- 通义千问 Qwen：https://bailian.console.aliyun.com/?tab=model#/api-key
- DeepSeek：https://platform.deepseek.com/api_keys

## 安全与隐私
- **你的 API Key 只在本机和大模型厂商之间走**，绝不会发给作者或任何第三方。所有配置只写到你电脑上的本地文件。
- **安装脚本是公开的，可以先看再跑**。不放心 `irm | iex` / `curl | sh` 的话，先在浏览器打开脚本看一眼内容，再决定运行：[install-gui.ps1](https://github.com/huhetingadday-boop/coding-agent-go/blob/main/install-gui.ps1)（Windows）· [install-gui.sh](https://github.com/huhetingadday-boop/coding-agent-go/blob/main/install-gui.sh)（macOS/Linux/WSL）。
- **安装命令钉在最新发布版**：jsdelivr 的 `@latest` 只指向打过 tag 的正式发布版，绝不会跑未发布的开发分支，所以命令稳定、可复现。
- **打包版可校验**：[Releases](https://github.com/huhetingadday-boop/coding-agent-go/releases) 里的 `.exe` / `.dmg` 每个都附 SHA-256 校验值，校验通过再运行更放心。

## 安装包打不开怎么办
安装包没有花钱买苹果/微软的签名，所以首次打开系统可能拦一下。放行一次就好，之后正常。
### macOS：提示「无法打开」「来自身份不明的开发者」
新版 macOS（Sequoia/15）去掉了「右键→打开」这个老办法，会直接弹「无法打开…」只给「完成 / 移到废纸篓」两个按钮。别慌，走下面这条，所有版本都管用（只需一次）：
1. 双击安装包，弹出「无法打开…」时点 **「完成」**（**千万不要点「移到废纸篓」**）。
2. 打开「系统设置 →「隐私与安全性」」，往下拉到「安全性」那一段。
3. 看到「已阻止使用 Coding Agent Installer」，点旁边的 **「仍要打开」**，按提示用密码 / Touch ID 确认一次即可（不用拖进「应用程序」，跑一次就行）。

> 想彻底不弹这个框？那需要花钱买苹果签名并做公证（notarization）。目前是免费的临时安装器，所以保留这一步手动放行。
### Windows：SmartScreen 蓝框 / 杀软拦截
360 / 电脑管家 / Windows SmartScreen 有时会拦下 `.exe`、PowerShell 脚本或后台代理进程。遇到拦截：
- SmartScreen 蓝框：点「更多信息」→「仍要运行」。
- 360 / 电脑管家弹窗：选「允许」或「信任」，不要选「阻止」。
- 杀软拦了代理进程或 `node`：把 `%TEMP%\coding-agent-go` 目录和 Node.js 加入白名单，再重跑安装命令。
- 还不行：用管理员身份打开 PowerShell 再跑一次安装命令。

## 加群交流
有问题、想反馈、想看教程更新，欢迎进群，或关注作者「产品经理胡笛笛」（[抖音](https://www.douyin.com/user/MS4wLjABAAAAAaiQmXTnVitWO9_2loyITZvKbS3rZYVocuQa-UgLd5E) · [小红书](https://www.xiaohongshu.com/user/profile/6210ebbd0000000010004897)）。
<!-- 把微信/QQ 群二维码导出为 docs/qrcode.png，再取消下面一行的注释 -->
<!-- ![进群二维码](docs/qrcode.png) -->
> 群二维码待补 —— 把二维码图片放到 `docs/qrcode.png`，再取消注释即可显示。

## 它帮你做了什么
- 自动装好前置依赖：需要 Node.js 时(Codex / Gemini，以及 Claude 走 npm 兜底时)，用官方预编译包装好 —— **不用 Homebrew、不用 Xcode 命令行工具、不用管理员**(已有 brew 就直接用)
- 官方源优先，失败自动切国内镜像（USTC / jsDelivr / npmmirror），不用翻墙也能装上 Claude Code / Codex / Gemini
- 写入配置文件（Claude Code: `settings.json` / Codex: `config.toml` / Gemini: llxprt `config.json`）
- Codex 路径起一个本地 mimo2codex 代理转接国产模型（`wire_api = "responses"`）。代理零鉴权，所以不用把 Key 写进 shell 配置，配好开机自启
- 发送测试请求，确认模型真的能用
- Agent smoke test：通过 `gh api` 给 huhetingadday-boop/coding-agent-go 点 star，验证完整工具调用链路

## 卸载

### Claude Code
- 取消配置：删除 `~/.claude/settings.json` 里的 `env` 块
- 卸载：macOS `brew uninstall --cask claude-code`

### Codex
- 取消配置：删除 `~/.codex/config.toml` 里 coding-agent-go 相关的 provider
- 删除代理配置：删掉 `~/.mimo2codex/` 目录
- 卸载 Codex：`npm uninstall -g @openai/codex`
- 卸载代理：`npm uninstall -g mimo2codex`

### Gemini CLI
- 取消配置：删除 `~/.llxprt-code/config.json`
- 卸载：`npm uninstall -g @vybestack/llxprt-code`

### Node.js（macOS 上由本工具装的便携版，没有 brew 时才会装）
- 删除 `~/.coding-agent-go/node` 目录
- 删掉 shell 配置（`~/.zprofile` / `~/.zshrc` 等）里带 `# coding-agent-go` 标记的那行 PATH

## 调试
安装过程中遇到问题，查看调试日志：
- macOS/Linux: `/tmp/coding-agent-go-debug.log`
- Windows: `%TEMP%\coding-agent-go-debug.log`

## 许可证
[MIT](LICENSE)

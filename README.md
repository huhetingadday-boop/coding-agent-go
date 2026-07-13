# coding-agent-go
[![tests](https://github.com/huhetingadday-boop/coding-agent-go/actions/workflows/test.yml/badge.svg)](https://github.com/huhetingadday-boop/coding-agent-go/actions/workflows/test.yml)
**中文** · [English](README.en.md)

一行命令，在国内装好 Claude Code / OpenAI Codex / Gemini CLI 并接上国产大模型（DeepSeek / GLM / Kimi / Qwen / MiniMax）。打开终端，粘贴，回车——不用翻墙，电脑小白跟着提示走就行。

<p align="center">
  <img src="docs/demo.gif" alt="coding-agent-go 安装演示" width="600">
</p>

> 🚧 双击即用的桌面 App（原生窗口）正在开发中（WIP），暂未发布；现在请用下面的一行命令安装。

## 一键安装（打开终端，粘贴，回车）
一行命令搞定：下载安装器（`server.py` + `providers.json`），在本机起一个网页版安装界面（默认 http://localhost:17860），浏览器自动打开。不用先 clone 仓库。跟着 GUI 走：① 选 Claude Code / Codex / Gemini → ② 选模型 → ③ 填 API Key → ④ 自动安装并验证。
### macOS / Linux / WSL（bash）
打开终端（WSL 里直接用同一条命令），粘贴这一行，回车：
```bash
bash <(curl -fsSL --connect-timeout 8 https://ghfast.top/https://raw.githubusercontent.com/huhetingadday-boop/coding-agent-go/main/install-gui.sh)
```
连不上就用 jsDelivr 备用（钉最新发布版）：
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
- **主命令为国内网络优化，备用命令钉正式发布版**。macOS/Linux 主命令走 ghproxy 直连 GitHub，绕开 jsdelivr 在国内偶发的 SSL 报错和限速；它跟 `main` 分支走。想只跑打过 tag 的正式发布版，用上面的 jsdelivr 备用命令（Windows 命令也是 jsdelivr `@latest`）。

## 遇到问题
- **不知道终端在哪？** Windows 在开始菜单搜「PowerShell」；Mac 在「启动台」搜「终端 / Terminal」。打开后把命令粘进去回车。
- **Windows 弹「是否允许此应用对你的设备进行更改?」？** 正常的——装 Node、Codex 组件（如 `codex-windows-sandbox-setup.exe`）时会弹几次，点 **「是」** 就行；点「否」会装不上。
- **没装 Python？** 不用管，脚本会自动帮你装（per-user，不弹 UAC）。
- **被 360 / 电脑管家 / 杀软拦了？** 弹窗里选「允许」或「信任」，别选「阻止」；如果它拦了 `node` 或后台代理进程，把它加进信任区再重跑命令。实在不会弄，就先临时关掉杀软，装完再打开。
- **提示找不到 `claude`？** 关掉终端、重新开一个再试 —— 新装的命令需要新窗口才在 PATH 里。
- **Windows 还不行？** 用管理员身份打开 PowerShell 再跑一次安装命令。

## 加群交流
有问题、想反馈、想看教程更新，欢迎进群，或关注作者「产品经理胡笛笛」（[抖音](https://www.douyin.com/user/MS4wLjABAAAAAaiQmXTnVitWO9_2loyITZvKbS3rZYVocuQa-UgLd5E) · [小红书](https://www.xiaohongshu.com/user/profile/6210ebbd0000000010004897)）。
<!-- 把微信/QQ 群二维码导出为 docs/qrcode.png，再取消下面一行的注释 -->
<!-- ![进群二维码](docs/qrcode.png) -->
> 群二维码待补 —— 把二维码图片放到 `docs/qrcode.png`，再取消注释即可显示。

## 打赏作者 ☕
觉得有用，可以请作者喝杯咖啡（微信支付）：
<img src="docs/wechat-pay.png" alt="微信支付 · 打赏作者胡笛笛" width="260">

## 它帮你做了什么
- 自动装好前置依赖：需要 Node.js 时(Codex / Gemini，以及 Claude 走 npm 兜底时)，用官方预编译包装好 —— **不用 Homebrew、不用 Xcode 命令行工具、不用管理员**(已有 brew 就直接用)
- 官方源优先，失败自动切国内镜像（USTC / jsDelivr / npmmirror），不用翻墙也能装上 Claude Code / Codex / Gemini
- 写入配置文件（Claude Code: `settings.json` / Codex: `config.toml` / Gemini: llxprt `config.json`）
- Codex 路径起一个本地 mimo2codex 代理转接国产模型（`wire_api = "responses"`）。代理零鉴权，所以不用把 Key 写进 shell 配置，配好开机自启
- 发送测试请求，确认模型真的能用
- Agent smoke test：通过 `gh api` 给 huhetingadday-boop/coding-agent-go 点 star，验证完整工具调用链路

## 调试
安装过程中遇到问题，查看调试日志：
- macOS/Linux: `/tmp/coding-agent-go-debug.log`
- Windows: `%TEMP%\coding-agent-go-debug.log`

## 许可证
[Apache 2.0](LICENSE)

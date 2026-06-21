# coding-agent-go
[![tests](https://github.com/huhetingadday-boop/coding-agent-go/actions/workflows/test.yml/badge.svg)](https://github.com/huhetingadday-boop/coding-agent-go/actions/workflows/test.yml)

一行命令，在国内装好 Claude Code / OpenAI Codex / Gemini CLI 并接上国产大模型（GLM / Kimi / MiniMax / Qwen / DeepSeek）。不用翻墙，GUI 操作，电脑小白跟着提示走就行。

## 一键安装并启动安装 UI
一行命令搞定：下载安装器（`server.py` + `providers.json`），在本机起一个网页版安装界面（默认 http://localhost:17860），浏览器自动打开。不用先 clone 仓库。跟着 GUI 走：① 选 Claude Code / Codex / Gemini → ② 选模型 → ③ 填 API Key → ④ 自动安装并验证。
### WSL / macOS / Linux（bash）
打开终端（WSL 里直接用同一条命令），粘贴这一行，回车：
```bash
bash <(curl -fsSL https://cdn.jsdelivr.net/gh/huhetingadday-boop/coding-agent-go@main/install-gui.sh)
```
### Windows PowerShell
打开「PowerShell」，粘贴这一行，回车（`irm | iex` 就是 PowerShell 版的 `curl | sh`）：
```powershell
irm https://cdn.jsdelivr.net/gh/huhetingadday-boop/coding-agent-go@main/install-gui.ps1 | iex
```
两条命令都会自动下载 `server.py` 和 `providers.json`，起本机 UI 服务并打开浏览器，不用先 clone。WSL 会装到 WSL 的 Linux 环境，请在 WSL 终端里用；想在 Windows 原生终端里用，就走 PowerShell 这条。
> 没装 Python 也没关系：脚本会自动装（per-user，不弹 UAC）。如果命令行里偏好 cmd/批处理，也可以用：`$f="$env:TEMP\acgg.bat"; iwr https://cdn.jsdelivr.net/gh/huhetingadday-boop/coding-agent-go@main/install-gui.bat -OutFile $f; cmd /c $f`

## 支持的 Agent

| Agent | 接入方式 | 复杂度 |
|-------|---------|--------|
| **Claude Code** | 原生 Anthropic 协议直连 | 低 |
| **OpenAI Codex** | 原生 Chat Completions 直连（`wire_api = "chat"`），无需代理 | 低 |
| **Gemini CLI** | 通过 llxprt-code 社区版原生支持 Anthropic 协议直连 | 低 |

## 支持的模型

| 选项 | 厂商 | 默认模型 |
|------|------|----------|
| `glm` | 智谱 GLM（推荐） | glm-4.6 |
| `kimi` | Kimi (Moonshot) | kimi-k2.7-code |
| `minimax` | MiniMax | MiniMax-M3 |
| `qwen` | 通义千问 Qwen | qwen3-coder-plus |
| `deepseek` | DeepSeek | deepseek-v4-pro |

## 没有 API Key 怎么办

GUI 里会给出每个厂商的 API Key 申请页链接和步骤指引。注册、新建 key、复制、粘贴即可。
- 智谱 GLM：https://www.bigmodel.cn/usercenter/proj-mgmt/apikeys
- Kimi：https://platform.moonshot.cn/console/api-keys
- MiniMax：https://platform.minimaxi.com/user-center/basic-information/interface-key
- 通义千问 Qwen：https://bailian.console.aliyun.com/?tab=model#/api-key
- DeepSeek：https://platform.deepseek.com/api_keys

## 它帮你做了什么

- 自动装好前置依赖：macOS 装 Homebrew + gh CLI，Codex / Gemini 路径额外装 Node.js
- 官方源优先，失败自动切国内镜像（USTC / jsDelivr）
- 写入配置文件（Claude Code: `settings.json` / Codex: `config.toml` / Gemini: llxprt `config.json`）
- Codex 路径直连国产模型（`wire_api = "chat"`），把 API Key 写入 shell 配置，无需代理
- 发送测试请求，确认模型真的能用
- Agent smoke test：通过 `gh api` 给 huhetingadday-boop/coding-agent-go 点 star，验证完整工具调用链路

## 卸载

### Claude Code
- 取消配置：删除 `~/.claude/settings.json` 里的 `env` 块
- 卸载：macOS `brew uninstall --cask claude-code`

### Codex
- 取消配置：删除 `~/.codex/config.toml` 里 coding-agent-go 相关的 provider
- 删除 API Key：删掉 shell 配置（如 `~/.zshrc`）里 `coding-agent-go codex key` 标记的那一段
- 卸载 Codex：`npm uninstall -g @openai/codex`

### Gemini CLI
- 取消配置：删除 `~/.llxprt-code/config.json`
- 卸载：`npm uninstall -g @vybestack/llxprt-code`

## 调试

安装过程中遇到问题，查看调试日志：
- macOS/Linux: `/tmp/coding-agent-go-debug.log`
- Windows: `%TEMP%\coding-agent-go-debug.log`

## 许可证

[MIT](LICENSE)

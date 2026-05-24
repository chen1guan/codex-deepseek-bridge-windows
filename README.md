# codex-deepseek-bridge-windows

在 Windows 平台上，通过 Moon Bridge 将 DeepSeek 模型接入 OpenAI Codex（VSCode 插件版），实现本地化部署。

```
Codex (VSCode) → Moon Bridge (Transform) → DeepSeek API (Anthropic 协议)
```

> 原始 Skill 只支持 Linux/macOS，本项目基于 Windows 实机部署经验整理，覆盖了官方未提到的 5 个关键兼容性问题。

## 特性

- **无需管理员权限**：Go 通过 zip 解压安装，choco/winget 一概不要
- **中国大陆友好**：内置 GOPROXY 镜像配置，不再卡在 `dial tcp` 超时
- **线程级配置防还原**：修复 Codex 恢复旧会话时覆盖 config.toml 的问题
- **VSCode 环境变量兼容**：处理 `claudeCode.environmentVariables` 与 config.toml 的优先级冲突
- **开机自启**：通过 Windows 启动文件夹快捷方式实现自动启动，无 systemd

## 前置条件

| 组件 | 要求 |
|------|------|
| Windows | 10 / 11 |
| PowerShell | 5.1+（系统自带） |
| Git | 已安装 |
| DeepSeek API Key | 从 [platform.deepseek.com/api_keys](https://platform.deepseek.com/api_keys) 获取 |

## 快速开始

完整步骤请查看 [SKILL.md](./SKILL.md)，这里是一个概览：

```powershell
# 1. 安装 Go（无需管理员）
# → 下载 zip 解压到 %USERPROFILE%\go，详见 SKILL.md

# 2. 设置环境变量
$env:GOROOT = "$env:USERPROFILE\go"
$env:GOPATH = "$env:USERPROFILE\go\gopath"
$env:GOPROXY = "https://goproxy.cn,direct"
$env:PATH = "$env:GOROOT\bin;$env:PATH"

# 3. 克隆 Moon Bridge
git clone https://github.com/ZhiYi-R/moon-bridge.git $env:USERPROFILE\.moonbridge

# 4. 配置 API Key + 编写 config.yml（详见 SKILL.md）

# 5. 编译
cd $env:USERPROFILE\.moonbridge
go build ./cmd/moonbridge

# 6. 启动
go run .\cmd\moonbridge --config config.yml

# 7. 生成 Codex 配置文件（详见 SKILL.md）

# 8. VSCode 中 Ctrl+Shift+P → Reload Window
```

## 与原版 Skill 的差异

原版 Skill（[nezhafan/skills](https://github.com/nezhafan/skills)）仅适配 Linux/macOS，本项目在此基础上做了以下 Windows 适配：

| 问题 | 原版做法 | Windows 适配 |
|------|----------|-------------|
| 安装 Go | `brew install go` / `apt install` | zip 解压到用户目录，无需管理员 |
| Go 模块代理 | 默认 `proxy.golang.org` | 改用 `goproxy.cn`（中国大陆必备） |
| 日志混入输出 | 不涉及 | `cmd /c "2>nul"` 分离 stderr |
| config.toml 被还原 | 不涉及 | 修改 `state_5.sqlite` 中旧线程的 provider |
| VSCode 环境变量 | 不涉及 | 同步修改 `settings.json` 中的 `ANTHROPIC_BASE_URL` |
| 开机自启 | systemd / nohup | 启动文件夹快捷方式 |

## 常见问题

**Codex 反复 Reconnecting，发消息无反应**

可能原因：
1. Moon Bridge 没启动 → 运行 `Invoke-WebRequest http://127.0.0.1:38440/v1/models` 检查
2. `config.toml` 被旧线程还原 → 运行 `sqlite3 $env:USERPROFILE\.codex\state_5.sqlite "UPDATE threads SET model_provider='moonbridge', model='moonbridge' WHERE model_provider!='moonbridge';"`
3. VSCode 环境变量覆盖了 config → 检查 `settings.json` 中的 `claudeCode.environmentVariables`

**编译报错 `dial tcp ... connectex`**

Go 模块代理被墙，执行 `$env:GOPROXY = "https://goproxy.cn,direct"`

**config.toml 第一行不是 `model = "moonbridge"`**

Go 日志混入 stdout，用 `cmd /c "2>nul"` 分离 stderr 重新生成

**401 / 402 错误**

- 401 → API Key 无效，检查 `config.yml`
- 402 → DeepSeek 欠费，去 [platform.deepseek.com](https://platform.deepseek.com) 充值

## 相关项目

- [Moon Bridge](https://github.com/ZhiYi-R/moon-bridge) — Anthropic 协议转发层
- [DeepSeek API](https://platform.deepseek.com) — DeepSeek 模型 API
- [nezhafan/skills](https://github.com/nezhafan/skills) — 原版 Linux/macOS Skill

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=chen1guan/codex-deepseek-bridge-windows&type=Date)](https://star-history.com/#chen1guan/codex-deepseek-bridge-windows&Date)

## 许可证

[MIT](./LICENSE)

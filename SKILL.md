---
name: codex-deepseek-bridge-windows
description: Windows 上将 DeepSeek 模型接入 Codex 的自动配置脚本。触发：用户询问如何在 Windows 上配置 Codex+DeepSeek、Codex 显示 Reconnecting、连接 Moon Bridge 等。
---

# codex-deepseek-bridge-windows

在 Windows 上将 DeepSeek 模型通过 Moon Bridge 接入 Codex。

## 执行步骤

### 1. 检查环境

确认以下条件满足：
- Windows 10 / 11
- Git 已安装（运行 `git --version`）
- `$env:USERPROFILE\.codex` 目录存在（Codex 已安装）

### 2. 提示用户输入 API Key

> 请输入你的 DeepSeek API Key（从 platform.deepseek.com/api_keys 获取）

不提供选项，直接让用户输入。API Key 不保存到参数，每次安装重新询问。

### 3. 运行安装脚本

执行本仓库中的 `setup.ps1` 脚本：

```powershell
cd <本仓库目录>
.\setup.ps1
```

脚本会自动完成以下操作：
1. 安装 Go（下载 zip 解压到用户目录，无需管理员）
2. 克隆 Moon Bridge 仓库
3. 写入 config.yml（使用用户输入的 API Key）
4. 编译 Moon Bridge
5. 生成 Codex 配置文件（config.toml + models_catalog.json）
6. 修复线程级配置还原问题（更新 state_5.sqlite）
7. 更新 VSCode 环境变量
8. 创建开机自启快捷方式
9. 启动 Moon Bridge

### 4. 验证连通性

```powershell
Invoke-WebRequest -Uri "http://127.0.0.1:38440/v1/models" -TimeoutSec 5
```

返回 Moon Bridge 模型列表即成功。`401` = key 有问题，`402` = 余额不足。

### 5. 重启 Codex

告诉用户：
- VSCode：`Ctrl+Shift+P` → `Reload Window`
- CLI：重新启动 `codex`

## 常见问题

| 现象 | 原因 | 解决 |
|------|------|------|
| Codex Reconnecting | Moon Bridge 没启动 | 运行 `go run .\cmd\moonbridge --config config.yml` |
| config.toml 被还原 | 旧线程覆盖配置 | 运行脚本修复或手动更新 state_5.sqlite |
| `dial tcp ... connectex` | Go 代理被墙 | 设置 `$env:GOPROXY = "https://goproxy.cn,direct"` |
| 401 | API Key 无效 | 检查 config.yml 中的 api_key |
| 402 | DeepSeek 欠费 | platform.deepseek.com 充值 |

## 配置文件路径

| 文件 | 路径 |
|------|------|
| Moon Bridge | `%USERPROFILE%\.moonbridge\` |
| config.yml | `%USERPROFILE%\.moonbridge\config.yml` |
| config.toml | `%USERPROFILE%\.codex\config.toml` |
| VSCode 设置 | `%APPDATA%\Code\User\settings.json` |
| 启动脚本 | `%USERPROFILE%\.moonbridge\start_moonbridge.ps1` |

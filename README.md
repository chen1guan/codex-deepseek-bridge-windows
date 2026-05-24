# codex-deepseek-bridge-windows

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Stars](https://img.shields.io/github/stars/chen1guan/codex-deepseek-bridge-windows)](https://github.com/chen1guan/codex-deepseek-bridge-windows)
[![Last Commit](https://img.shields.io/github/last-commit/chen1guan/codex-deepseek-bridge-windows)](https://github.com/chen1guan/codex-deepseek-bridge-windows)

在 Windows 上将 DeepSeek 模型通过 Moon Bridge 接入 Codex（VSCode 插件版）。

```
Codex (VSCode) → Moon Bridge (Transform) → DeepSeek API (Anthropic 协议)
```

## 快速开始

```powershell
# 1. 克隆本仓库
git clone https://github.com/chen1guan/codex-deepseek-bridge-windows.git
cd codex-deepseek-bridge-windows

# 2. 运行配置脚本（自动安装 Go、克隆 Moon Bridge、生成配置）
.\setup.ps1
```

脚本会提示你输入 DeepSeek API Key（从 [platform.deepseek.com/api_keys](https://platform.deepseek.com/api_keys) 获取），然后自动完成所有配置。

配置完成后，在 VSCode 中 `Ctrl+Shift+P` → `Reload Window` 即可使用。

## 前置条件

| 组件 | 要求 |
|------|------|
| Windows | 10 / 11 |
| PowerShell | 5.1+（系统自带） |
| Git | 已安装 |
| DeepSeek API Key | 从 [platform.deepseek.com/api_keys](https://platform.deepseek.com/api_keys) 获取 |

不需要管理员权限，不需要安装其他工具。

## 手动配置

如果不想用脚本，可以按照 [SETUP.md](./SETUP.md) 中的步骤手动配置。

## 特性

- **无需管理员权限**：Go 通过 zip 解压安装
- **中国大陆友好**：内置 GOPROXY 镜像配置
- **线程级配置防还原**：修复 Codex 恢复旧会话时覆盖 config.toml 的问题
- **VSCode 环境变量兼容**：处理环境变量与 config.toml 的优先级冲突
- **开机自启**：通过启动文件夹快捷方式自动启动

## 常见问题

**Codex 反复 Reconnecting，发消息无反应**

1. 检查 Moon Bridge 是否启动：`Invoke-WebRequest http://127.0.0.1:38440/v1/models`
2. 检查 `config.toml` 是否被旧线程还原（详见 [SETUP.md](./SETUP.md#configtoml-被覆盖回旧配置)）
3. 检查 VSCode 设置中的 `claudeCode.environmentVariables` 是否指向 Moon Bridge

**编译报错 `dial tcp ... connectex`**

Go 模块代理被墙，执行 `$env:GOPROXY = "https://goproxy.cn,direct"`

**401 / 402 错误**

- 401 → API Key 无效，检查 `config.yml`
- 402 → DeepSeek 欠费，去 [platform.deepseek.com](https://platform.deepseek.com) 充值

详细排查步骤见 [SETUP.md](./SETUP.md#常见问题)

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=chen1guan/codex-deepseek-bridge-windows&type=Date)](https://star-history.com/#chen1guan/codex-deepseek-bridge-windows&Date)

## 许可证

[MIT](./LICENSE)

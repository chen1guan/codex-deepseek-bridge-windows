---
name: codex-deepseek-bridge-windows
description: Windows 平台将 DeepSeek 模型通过 Moon Bridge 转发层接入 Codex/VSCode，实现本地部署配置。触发：用户询问如何在 Windows 上配置 Codex+DeepSeek、Codex 显示 Reconnecting、连接 Moon Bridge 等。
---

# Skill: codex-deepseek-bridge-windows

**平台：Windows**（PowerShell 5.1+，无需管理员权限）

将 DeepSeek 模型通过 Moon Bridge 转发层接入 OpenAI Codex（VSCode 插件版）。

```
Codex (VSCode) → Moon Bridge (Transform) → DeepSeek API (Anthropic 协议)
```

> **Input Parameters:**
> - `model_name` (string, optional, default: `"deepseek-v4-pro"`): 模型选择。可选值：`deepseek-v4-pro`（旗舰）或 `deepseek-v4-flash`（快速）
> - **API Key** 不通过参数传入，执行 Step 2 时直接让用户输入，不提供选项。

---

## 环境变量说明

| 变量 | 值 | 说明 |
|------|------|------|
| `MB_DIR` | `$env:USERPROFILE\.moonbridge` | Moon Bridge 安装目录 |
| `CODEX_HOME` | `$env:USERPROFILE\.codex` | Codex 配置目录 |
| `GOROOT` | `$env:USERPROFILE\go` | Go 安装目录 |
| `GOPATH` | `$env:USERPROFILE\go\gopath` | Go 工作目录 |
| `GOPROXY` | `https://goproxy.cn,direct` | 中国 Go 模块代理（必须） |
| 后台启动 | `Start-Process -WindowStyle Hidden` | 后台进程（非 nohup） |
| 查看日志 | `Get-Content $env:TEMP\moonbridge.log` | Windows 日志路径 |

**后续所有步骤都需要先设置 Go 环境变量。建议加到 PowerShell Profile（`$PROFILE`）中：**

```powershell
$env:GOROOT = "$env:USERPROFILE\go"
$env:GOPATH = "$env:USERPROFILE\go\gopath"
$env:GOPROXY = "https://goproxy.cn,direct"
$env:PATH = "$env:GOROOT\bin;$env:PATH"
```

---

## 部署步骤

### Step 1: 安装 Go + 检查前置条件

**Go 安装**（无需管理员权限，直接下载 zip 解压到用户目录）：

```powershell
$goVersion = "1.26.3"
$arch = "amd64"
$url = "https://go.dev/dl/go$goVersion.windows-$arch.zip"
$dlPath = "$env:TEMP\go.zip"
$installPath = "$env:USERPROFILE\go"
Invoke-WebRequest -Uri $url -OutFile $dlPath -TimeoutSec 120
Expand-Archive -Path $dlPath -DestinationPath $env:USERPROFILE -Force
```

**设置环境变量并检查：**

```powershell
$env:GOROOT = "$env:USERPROFILE\go"
$env:GOPATH = "$env:USERPROFILE\go\gopath"
$env:GOPROXY = "https://goproxy.cn,direct"
$env:PATH = "$env:GOROOT\bin;$env:PATH"
New-Item -ItemType Directory -Force -Path $env:GOPATH

go version        # 需要 1.25+
git --version     # 需要 git
```

**检查 Codex 配置目录是否存在：**

```powershell
if (Test-Path "$env:USERPROFILE\.codex") {
    Write-Output "Codex dir exists"
} else {
    Write-Output "Codex dir NOT found"
}
```

### Step 2: 获取 API Key + 克隆仓库 + 写入 config.yml

**首先，直接让用户输入 DeepSeek API Key：**

> 请输入你的 DeepSeek API Key（从 platform.deepseek.com/api_keys 获取）

**克隆 Moon Bridge：**

```powershell
$mbDir = "$env:USERPROFILE\.moonbridge"
if (Test-Path $mbDir) {
    Write-Output "Moon Bridge directory already exists"
} else {
    git clone https://github.com/ZhiYi-R/moon-bridge.git $mbDir
}
```

**创建 data 目录：**

```powershell
New-Item -ItemType Directory -Force -Path "$mbDir\data"
```

**写入 `$mbDir\config.yml`：**（将 `$API_KEY` 和 `$MODEL_NAME` 替换为实际值）

```yaml
mode: "Transform"
server:
  addr: "127.0.0.1:38440"

persistence:
  active_provider: db_sqlite

extensions:
  deepseek_v4:
    config:
      reinforce_instructions: true
  db_sqlite:
    enabled: true
    config:
      path: ./data/moonbridge.db
      wal: true
      busy_timeout_ms: 5000
      max_open_conns: 1

cache:
  mode: "explicit"
  ttl: "5m"
  prompt_caching: true

defaults:
  model: "moonbridge"
  max_tokens: 65536

models:
  $MODEL_NAME:
    context_window: 1000000
    max_output_tokens: 384000
    default_reasoning_level: "high"
    supported_reasoning_levels:
      - effort: "high"
        description: "High reasoning effort"
      - effort: "xhigh"
        description: "Extra high reasoning effort"
    supports_reasoning_summaries: true
    default_reasoning_summary: "auto"
    extensions:
      deepseek_v4:
        enabled: true

providers:
  deepseek:
    base_url: "https://api.deepseek.com/anthropic"
    api_key: "$API_KEY"
    version: "2023-06-01"
    offers:
      - model: $MODEL_NAME
        pricing:
          input_price: 2
          output_price: 8
          cache_write_price: 1
          cache_read_price: 0.2

routes:
  moonbridge:
    model: $MODEL_NAME
    provider: deepseek
```

### Step 3: 编译验证

```powershell
Set-Location $mbDir
go build ./cmd/moonbridge 2>&1
```

编译通过后，告诉用户在新终端中启动：

```powershell
cd $mbDir
go run .\cmd\moonbridge --config config.yml
```

或后台运行：

```powershell
cd $mbDir
Start-Process -WindowStyle Hidden -FilePath "$env:GOROOT\bin\go.exe" -ArgumentList "run", ".\cmd\moonbridge", "--config", "config.yml" -RedirectStandardOutput "$env:TEMP\moonbridge.log" -RedirectStandardError "$env:TEMP\moonbridge_err.log"
```

成功标志：`Moon Bridge 监听于 127.0.0.1:38440`

### Step 4: 验证连通性（用户启动 Moon Bridge 后执行）

```powershell
Invoke-WebRequest -Uri "http://127.0.0.1:38440/v1/models" -TimeoutSec 5
Invoke-WebRequest -Uri "http://127.0.0.1:38440/v1/responses" -Method Post -ContentType "application/json" -Body '{"model":"moonbridge","input":"用一句话打招呼","max_output_tokens":50}' -TimeoutSec 30
```

应返回 DeepSeek 回复。`401` = key 有问题，`402` = 余额不足。

### Step 5: 生成 Codex 配置文件

**⚠️ 关键：Go 的日志会混入 stdout，需要用 `cmd /c "2>nul"` 分离 stderr，否则生成的 config.toml 第一行是日志而不是 `model = "moonbridge"`。**

```powershell
$mbDir = "$env:USERPROFILE\.moonbridge"
$codexHome = "$env:USERPROFILE\.codex"
Set-Location $mbDir

# 备份现有配置
Copy-Item "$codexHome\config.toml" "$codexHome\config.toml.bak" -Force
Copy-Item "$codexHome\models_catalog.json" "$codexHome\models_catalog.json.bak" -Force -ErrorAction SilentlyContinue

# 获取模型名称（用 cmd 分离 stderr）
$model = cmd /c "go run .\cmd\moonbridge --config config.yml --print-codex-model 2>nul"

# 生成 config.toml（用 cmd 分离 stderr，Output 用 utf8 编码）
cmd /c "go run .\cmd\moonbridge --config config.yml --print-codex-config $model --codex-base-url http://127.0.0.1:38440/v1 --codex-home $codexHome 2>nul" | Out-File -FilePath "$env:TEMP\codex_config_new.toml" -Encoding utf8

# 验证第一行
Get-Content "$env:TEMP\codex_config_new.toml" -TotalCount 1
# 应该输出: model = "moonbridge"
```

**部署 config.toml：**

```powershell
Copy-Item "$env:TEMP\codex_config_new.toml" "$codexHome\config.toml" -Force
```

**检查 models_catalog.json 是否自动生成：**

```powershell
if (Test-Path "$codexHome\models_catalog.json") {
    Get-Content "$codexHome\models_catalog.json" -TotalCount 5
} else {
    Write-Output "models_catalog.json NOT found, re-run Step 5"
}
```

### Step 6: 后续操作

**重启 Codex：**
- VSCode：`Ctrl+Shift+P` → `Reload Window`
- CLI：重新启动 `codex` 命令

**下次启动 Moon Bridge：**
```powershell
cd $env:USERPROFILE\.moonbridge
go run .\cmd\moonbridge --config config.yml
```

**查日志：**
```powershell
Get-Content $env:TEMP\moonbridge.log
```

---

## 开机自启

创建 PowerShell 启动脚本：

```powershell
# 文件: $env:USERPROFILE\.moonbridge\start_moonbridge.ps1
$env:GOROOT = "$env:USERPROFILE\go"
$env:GOPATH = "$env:USERPROFILE\go\gopath"
$env:GOPROXY = "https://goproxy.cn,direct"
$env:PATH = "$env:GOROOT\bin;$env:PATH"
Set-Location $env:USERPROFILE\.moonbridge
Start-Process -WindowStyle Hidden -FilePath "$env:GOROOT\bin\go.exe" -ArgumentList "run", ".\cmd\moonbridge", "--config", "config.yml" -RedirectStandardOutput "$env:TEMP\moonbridge.log" -RedirectStandardError "$env:TEMP\moonbridge_err.log"
Write-Output "Moon Bridge started"
```

创建 Windows 启动文件夹快捷方式（无需管理员权限）：

```powershell
$startupDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$scriptPath = "$env:USERPROFILE\.moonbridge\start_moonbridge.ps1"
$shortcutPath = "$startupDir\MoonBridge.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath = "powershell.exe"
$Shortcut.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
$Shortcut.WorkingDirectory = "$env:USERPROFILE\.moonbridge"
$Shortcut.WindowStyle = 7
$Shortcut.Save()
```

---

## 常见问题

### ⚠️ Codex 反复 Reconnecting / 发消息无反应

**原因 1：Moon Bridge 没启动**

```powershell
Invoke-WebRequest -Uri "http://127.0.0.1:38440/v1/models" -TimeoutSec 3
```

如果报错，启动 Moon Bridge。

**原因 2：config.toml 被覆盖回旧配置**

这是最常见的问题。**根因**：Codex 的 `state_5.sqlite` 数据库会为每个对话线程保存 `model_provider`。恢复旧线程时，Codex 会把该线程的 provider 覆盖回 `config.toml`。

修复方法——批量更新数据库中的旧线程：

```powershell
$db = "$env:USERPROFILE\.codex\state_5.sqlite"

# 查看所有线程的 provider 分布
sqlite3 $db "SELECT model_provider, COUNT(*) FROM threads GROUP BY model_provider;"

# 全部改为你当前的 provider
sqlite3 $db "UPDATE threads SET model_provider = 'moonbridge', model = 'moonbridge' WHERE model_provider != 'moonbridge';"
```

**原因 3：VSCode 环境变量覆盖了 config.toml**

检查 `settings.json`（路径：`$env:APPDATA\Code\User\settings.json`）中的 `claudeCode.environmentVariables`，确保指向 Moon Bridge：

```json
"claudeCode.environmentVariables": [
    { "name": "ANTHROPIC_BASE_URL", "value": "http://127.0.0.1:38440/v1" },
    { "name": "ANTHROPIC_AUTH_TOKEN", "value": "sk-noauth" }
]
```

> ⚠️ `ANTHROPIC_BASE_URL` 的优先级可能高于 config.toml 中的 `base_url`。如果 config.toml 被恢复，env var 也会被 Codex 写回为旧值。建议 **同步检查** config.toml 和 VSCode settings.json。

### ⚠️ 编译报错 `dial tcp ... connectex: A connection attempt failed`

Go 模块代理被墙（中国大陆）。必须设置：
```powershell
$env:GOPROXY = "https://goproxy.cn,direct"
```

### ⚠️ config.toml 第一行不是 `model = "moonbridge"` 而是日志

Go 命令的 INFO 日志混入了 stdout。用 `cmd /c "2>nul"` 分离 stderr：
```powershell
# 错误写法（日志混入）：
$model = go run .\cmd\moonbridge --config config.yml --print-codex-model

# 正确写法（用 cmd 分离）：
$model = cmd /c "go run .\cmd\moonbridge --config config.yml --print-codex-model 2>nul"
```

### ⚠️ `bind: Only one usage of each socket address` 端口被占用

说明 Moon Bridge 已经在运行了。验证：
```powershell
Invoke-WebRequest -Uri "http://127.0.0.1:38440/v1/models" -TimeoutSec 3
```

### ⚠️ `401` / `402`

- `401`：API Key 无效，检查 `config.yml` 中的 `api_key`
- `402`：DeepSeek 欠费，去 platform.deepseek.com 充值

### ⚠️ 还原旧配置

```powershell
Copy-Item "$env:USERPROFILE\.codex\config.toml.bak" "$env:USERPROFILE\.codex\config.toml" -Force
```

---

## 配置文件路径速查

| 文件 | 路径 |
|------|------|
| Moon Bridge 源码 | `%USERPROFILE%\.moonbridge\` |
| config.yml | `%USERPROFILE%\.moonbridge\config.yml` |
| config.toml | `%USERPROFILE%\.codex\config.toml` |
| config.toml 备份 | `%USERPROFILE%\.codex\config.toml.bak` |
| models_catalog.json | `%USERPROFILE%\.codex\models_catalog.json` |
| 线程数据库 | `%USERPROFILE%\.codex\state_5.sqlite` |
| VSCode 设置 | `%APPDATA%\Code\User\settings.json` |
| Moon Bridge 日志 | `%TEMP%\moonbridge.log` |
| 启动脚本 | `%USERPROFILE%\.moonbridge\start_moonbridge.ps1` |
| 开机自启快捷方式 | `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\MoonBridge.lnk` |
| Go 安装目录 | `%USERPROFILE%\go\` |

---

## 更新日志

### v1.0.0 (2026-05-24)
- 初始版本，基于 Linux 原版 skill 适配 Windows 平台
- 解决 Go 无管理员安装、GOPROXY 代理、stderr/stdout 混入、线程级配置还原、VSCode 环境变量覆盖等 5 个 Windows 特有兼容性问题
- 补充开机自启方案（启动文件夹快捷方式）

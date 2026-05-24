# 手动配置指南

本文档描述了 `setup.ps1` 脚本中每个步骤的手动操作方法。如果你已经运行了 `setup.ps1`，不需要再看这里。

---

## 环境变量

后续所有命令都需要先设置 Go 环境变量（建议加到 `$PROFILE` 中）：

```powershell
$env:GOROOT = "$env:USERPROFILE\go"
$env:GOPATH = "$env:USERPROFILE\go\gopath"
$env:GOPROXY = "https://goproxy.cn,direct"
$env:PATH = "$env:GOROOT\bin;$env:PATH"
```

---

## Step 1: 安装 Go

下载 Go zip 包解压到用户目录（无需管理员权限）：

```powershell
$goVersion = "1.26.3"
$url = "https://go.dev/dl/go$goVersion.windows-amd64.zip"
Invoke-WebRequest -Uri $url -OutFile "$env:TEMP\go.zip" -TimeoutSec 120
Expand-Archive -Path "$env:TEMP\go.zip" -DestinationPath $env:USERPROFILE -Force
```

验证：`go version`，需要 1.25+。

## Step 2: 克隆 Moon Bridge

```powershell
git clone https://github.com/ZhiYi-R/moon-bridge.git $env:USERPROFILE\.moonbridge
```

## Step 3: 获取 API Key + 写入 config.yml

先去 [platform.deepseek.com/api_keys](https://platform.deepseek.com/api_keys) 获取 DeepSeek API Key。

创建 data 目录：

```powershell
mkdir -p $env:USERPROFILE\.moonbridge\data
```

写入 `config.yml`，将 `$API_KEY` 替换为你的 Key，`$MODEL_NAME` 替换为 `deepseek-v4-pro` 或 `deepseek-v4-flash`：

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

## Step 4: 编译

```powershell
cd $env:USERPROFILE\.moonbridge
go build ./cmd/moonbridge
```

如果报错 `dial tcp ... connectex`，设置代理后重试：
```powershell
$env:GOPROXY = "https://goproxy.cn,direct"
```

## Step 5: 启动 Moon Bridge

前台运行（用于调试）：

```powershell
cd $env:USERPROFILE\.moonbridge
go run .\cmd\moonbridge --config config.yml
```

看到 `Moon Bridge 监听于 127.0.0.1:38440` 即启动成功。

后台运行：

```powershell
Start-Process -WindowStyle Hidden -FilePath "$env:GOROOT\bin\go.exe" -ArgumentList "run", ".\cmd\moonbridge", "--config", "config.yml" -RedirectStandardOutput "$env:TEMP\moonbridge.log" -RedirectStandardError "$env:TEMP\moonbridge_err.log"
```

验证：

```powershell
Invoke-WebRequest -Uri "http://127.0.0.1:38440/v1/models" -TimeoutSec 5
```

## Step 6: 生成 Codex 配置文件

备份旧配置：

```powershell
Copy-Item "$env:USERPROFILE\.codex\config.toml" "$env:USERPROFILE\.codex\config.toml.bak" -Force
```

生成新配置（**用 `cmd /c "2>nul"` 分离 stderr，否则 Go 日志会混入 config.toml**）：

```powershell
cd $env:USERPROFILE\.moonbridge
$codexHome = "$env:USERPROFILE\.codex"
$model = cmd /c "go run .\cmd\moonbridge --config config.yml --print-codex-model 2>nul"
cmd /c "go run .\cmd\moonbridge --config config.yml --print-codex-config $model --codex-base-url http://127.0.0.1:38440/v1 --codex-home $codexHome 2>nul" | Out-File -FilePath "$env:TEMP\codex_config_new.toml" -Encoding utf8
```

验证第一行是 `model = "moonbridge"`：

```powershell
Get-Content "$env:TEMP\codex_config_new.toml" -TotalCount 1
```

部署：

```powershell
Copy-Item "$env:TEMP\codex_config_new.toml" "$codexHome\config.toml" -Force
```

## Step 7: 修复线程级配置还原问题

Codex 会为每个对话线程保存 provider 到 `state_5.sqlite`。恢复旧线程时会覆盖 `config.toml`。

```powershell
$db = "$env:USERPROFILE\.codex\state_5.sqlite"
sqlite3 $db "UPDATE threads SET model_provider = 'moonbridge', model = 'moonbridge' WHERE model_provider != 'moonbridge';"
```

## Step 8: 更新 VSCode 环境变量

编辑 `%APPDATA%\Code\User\settings.json`，确保 `claudeCode.environmentVariables` 指向 Moon Bridge：

```json
"claudeCode.environmentVariables": [
    { "name": "ANTHROPIC_BASE_URL", "value": "http://127.0.0.1:38440/v1" },
    { "name": "ANTHROPIC_AUTH_TOKEN", "value": "sk-noauth" }
]
```

> `ANTHROPIC_BASE_URL` 的优先级高于 config.toml，必须同步修改。

## Step 9: 重启 Codex

- VSCode：`Ctrl+Shift+P` → `Reload Window`
- CLI：重新启动 `codex` 命令

---

## 常见问题

### Codex 反复 Reconnecting

**原因 1：Moon Bridge 没启动**

```powershell
Invoke-WebRequest -Uri "http://127.0.0.1:38440/v1/models" -TimeoutSec 3
```

**原因 2：config.toml 被旧线程覆盖**

```powershell
# 查看当前配置
Get-Content "$env:USERPROFILE\.codex\config.toml" -TotalCount 3
# 如果 model_provider 不是 moonbridge，需要重新部署 + 修复数据库（见 Step 6-7）
```

**原因 3：VSCode 环境变量指向旧地址**

检查 `%APPDATA%\Code\User\settings.json` 中的 `ANTHROPIC_BASE_URL`，改为 `http://127.0.0.1:38440/v1`。

### config.toml 第一行是日志

Go 的 INFO 日志混入了 stdout。用 `cmd /c "2>nul"` 分离 stderr 重新生成：

```powershell
cmd /c "go run .\cmd\moonbridge --config config.yml --print-codex-config $model --codex-base-url http://127.0.0.1:38440/v1 --codex-home $codexHome 2>nul" | Out-File -FilePath "$env:TEMP\codex_config_new.toml" -Encoding utf8
```

### 端口被占用

```powershell
Invoke-WebRequest -Uri "http://127.0.0.1:38440/v1/models" -TimeoutSec 3
```

如果能通，说明 Moon Bridge 已经在运行了，不需要再启动。

### 401 / 402

- 401 → API Key 无效，检查 `config.yml` 中的 `api_key`
- 402 → DeepSeek 欠费，去 [platform.deepseek.com](https://platform.deepseek.com) 充值

### 还原旧配置

```powershell
Copy-Item "$env:USERPROFILE\.codex\config.toml.bak" "$env:USERPROFILE\.codex\config.toml" -Force
```

---

## 文件路径速查

| 文件 | 路径 |
|------|------|
| Moon Bridge 源码 | `%USERPROFILE%\.moonbridge\` |
| config.yml | `%USERPROFILE%\.moonbridge\config.yml` |
| config.toml | `%USERPROFILE%\.codex\config.toml` |
| config.toml 备份 | `%USERPROFILE%\.codex\config.toml.bak` |
| 线程数据库 | `%USERPROFILE%\.codex\state_5.sqlite` |
| VSCode 设置 | `%APPDATA%\Code\User\settings.json` |
| Moon Bridge 日志 | `%TEMP%\moonbridge.log` |
| 启动脚本 | `%USERPROFILE%\.moonbridge\start_moonbridge.ps1` |
| 开机自启快捷方式 | `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\MoonBridge.lnk` |
| Go 安装目录 | `%USERPROFILE%\go\` |

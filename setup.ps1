Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Codex + DeepSeek (Moon Bridge) Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ===== Step 1: Check prerequisites =====
Write-Host "[1/8] Checking prerequisites..." -ForegroundColor Yellow

# Check Git
try {
    $gitVer = git --version 2>&1
    Write-Host "  Git: $gitVer" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Git not found. Please install Git first." -ForegroundColor Red
    Write-Host "  Download: https://git-scm.com/download/win"
    exit 1
}

# Check .codex directory
if (Test-Path "$env:USERPROFILE\.codex") {
    Write-Host "  Codex dir: OK" -ForegroundColor Green
} else {
    Write-Host "  WARNING: .codex directory not found. Codex may not be installed yet." -ForegroundColor Yellow
}

# ===== Step 2: Install Go =====
Write-Host "[2/8] Installing Go..." -ForegroundColor Yellow

$goDir = "$env:USERPROFILE\go"
$goBin = "$goDir\bin\go.exe"

if (Test-Path $goBin) {
    $ver = & $goBin version 2>&1
    Write-Host "  Go already installed: $ver" -ForegroundColor Green
} else {
    Write-Host "  Downloading Go..." -ForegroundColor Cyan
    $goVersion = "1.26.3"
    $arch = "amd64"
    $url = "https://go.dev/dl/go$goVersion.windows-$arch.zip"
    $dlPath = "$env:TEMP\go.zip"
    Invoke-WebRequest -Uri $url -OutFile $dlPath -TimeoutSec 120
    Expand-Archive -Path $dlPath -DestinationPath $env:USERPROFILE -Force
    Write-Host "  Go installed to $goDir" -ForegroundColor Green
}

# Set environment variables
$env:GOROOT = $goDir
$env:GOPATH = "$goDir\gopath"
$env:GOPROXY = "https://goproxy.cn,direct"
$env:PATH = "$goDir\bin;$env:PATH"
New-Item -ItemType Directory -Force -Path $env:GOPATH | Out-Null

$ver = go version 2>&1
Write-Host "  Go version: $ver" -ForegroundColor Green

# ===== Step 3: Clone Moon Bridge =====
Write-Host "[3/8] Cloning Moon Bridge..." -ForegroundColor Yellow

$mbDir = "$env:USERPROFILE\.moonbridge"

if (Test-Path $mbDir) {
    Write-Host "  Moon Bridge already exists at $mbDir" -ForegroundColor Green
} else {
    git clone https://github.com/ZhiYi-R/moon-bridge.git $mbDir 2>&1 | Out-Null
    Write-Host "  Cloned to $mbDir" -ForegroundColor Green
}

# ===== Step 4: Get API Key + Write config.yml =====
Write-Host "[4/8] Configuring DeepSeek API Key..." -ForegroundColor Yellow

$apiKey = Read-Host "  Enter your DeepSeek API Key (from https://platform.deepseek.com/api_keys)"

if ([string]::IsNullOrWhiteSpace($apiKey)) {
    Write-Host "  ERROR: API Key is required." -ForegroundColor Red
    exit 1
}

$deepseekModel = "deepseek-v4-pro"

# Create data directory
New-Item -ItemType Directory -Force -Path "$mbDir\data" | Out-Null

# Write config.yml
$configYml = @"
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
  $deepseekModel:
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
    api_key: "$apiKey"
    version: "2023-06-01"
    offers:
      - model: $deepseekModel
        pricing:
          input_price: 2
          output_price: 8
          cache_write_price: 1
          cache_read_price: 0.2

routes:
  moonbridge:
    model: $deepseekModel
    provider: deepseek
"@

$configYml | Out-File -FilePath "$mbDir\config.yml" -Encoding utf8
Write-Host "  config.yml written" -ForegroundColor Green

# ===== Step 5: Build Moon Bridge =====
Write-Host "[5/8] Building Moon Bridge..." -ForegroundColor Yellow

Set-Location $mbDir
$buildResult = go build ./cmd/moonbridge 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  Build successful" -ForegroundColor Green
} else {
    Write-Host "  ERROR: Build failed" -ForegroundColor Red
    Write-Host "  $buildResult"
    exit 1
}

# ===== Step 6: Generate Codex config =====
Write-Host "[6/8] Generating Codex configuration..." -ForegroundColor Yellow

$codexHome = "$env:USERPROFILE\.codex"

# Backup existing config
if (Test-Path "$codexHome\config.toml") {
    Copy-Item "$codexHome\config.toml" "$codexHome\config.toml.bak" -Force
    Write-Host "  config.toml backed up" -ForegroundColor Green
}

# Generate config using cmd to separate stderr from stdout
Set-Location $mbDir
$model = cmd /c "go run .\cmd\moonbridge --config config.yml --print-codex-model 2>nul"
cmd /c "go run .\cmd\moonbridge --config config.yml --print-codex-config $model --codex-base-url http://127.0.0.1:38440/v1 --codex-home $codexHome 2>nul" | Out-File -FilePath "$env:TEMP\codex_config_new.toml" -Encoding utf8

# Verify first line is correct
$firstLine = (Get-Content "$env:TEMP\codex_config_new.toml" -TotalCount 1).Trim()
if ($firstLine -eq 'model = "moonbridge"') {
    Write-Host "  Config file generated correctly" -ForegroundColor Green
} else {
    Write-Host "  ERROR: Config file has invalid first line: $firstLine" -ForegroundColor Red
    Write-Host "  Please check the generated file at $env:TEMP\codex_config_new.toml"
    exit 1
}

# Deploy config.toml
Copy-Item "$env:TEMP\codex_config_new.toml" "$codexHome\config.toml" -Force
Write-Host "  config.toml deployed" -ForegroundColor Green

# ===== Step 7: Fix thread-level config revert =====
Write-Host "[7/8] Fixing thread-level config persistence..." -ForegroundColor Yellow

$stateDb = "$codexHome\state_5.sqlite"
if (Test-Path $stateDb) {
    try {
        $oldCount = (sqlite3 $stateDb "SELECT COUNT(*) FROM threads WHERE model_provider != 'moonbridge';" 2>&1).Trim()
        if ($oldCount -ne "0" -and $oldCount -ne $null) {
            sqlite3 $stateDb "UPDATE threads SET model_provider = 'moonbridge', model = 'moonbridge' WHERE model_provider != 'moonbridge';" 2>&1 | Out-Null
            Write-Host "  Fixed $oldCount threads" -ForegroundColor Green
        } else {
            Write-Host "  No threads to fix" -ForegroundColor Green
        }
    } catch {
        Write-Host "  Could not update thread database (sqlite3 not found or file locked)" -ForegroundColor Yellow
        Write-Host "  You can fix this manually later: sqlite3 $stateDb `"UPDATE threads SET model_provider='moonbridge', model='moonbridge' WHERE model_provider!='moonbridge';`""
    }
} else {
    Write-Host "  No existing state database found (OK for new installs)" -ForegroundColor Green
}

# ===== Step 8: Update VSCode settings =====
Write-Host "[8/8] Updating VSCode settings..." -ForegroundColor Yellow

$vscodeSettings = "$env:APPDATA\Code\User\settings.json"
if (Test-Path $vscodeSettings) {
    $settings = Get-Content $vscodeSettings -Raw

    # Check if claudeCode.environmentVariables exists
    if ($settings -match '"claudeCode.environmentVariables"') {
        # Update existing ANTHROPIC_BASE_URL and ANTHROPIC_AUTH_TOKEN
        $settings = $settings -replace '"ANTHROPIC_BASE_URL"\s*,\s*"value"\s*:\s*"[^"]*"', '"ANTHROPIC_BASE_URL", "value": "http://127.0.0.1:38440/v1"'
        $settings = $settings -replace '"ANTHROPIC_AUTH_TOKEN"\s*,\s*"value"\s*:\s*"[^"]*"', '"ANTHROPIC_AUTH_TOKEN", "value": "sk-noauth"'
        $settings | Out-File -FilePath $vscodeSettings -Encoding utf8 -NoNewline
        Write-Host "  VSCode settings updated" -ForegroundColor Green
    } else {
        Write-Host "  No claudeCode.environmentVariables in settings.json (skipping)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  VSCode settings.json not found (skipping)" -ForegroundColor Yellow
}

# ===== Start Moon Bridge =====
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Starting Moon Bridge..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Set-Location $mbDir
Start-Process -WindowStyle Hidden -FilePath $goBin -ArgumentList "run", ".\cmd\moonbridge", "--config", "config.yml" -RedirectStandardOutput "$env:TEMP\moonbridge.log" -RedirectStandardError "$env:TEMP\moonbridge_err.log"
Start-Sleep -Seconds 5

try {
    Invoke-WebRequest -Uri "http://127.0.0.1:38440/v1/models" -TimeoutSec 5 -ErrorAction Stop | Out-Null
    Write-Host "  Moon Bridge is running on http://127.0.0.1:38440" -ForegroundColor Green
} catch {
    Write-Host "  Moon Bridge did not start. Check log: Get-Content $env:TEMP\moonbridge.log" -ForegroundColor Red
}

# ===== Create startup shortcut =====
Write-Host "Creating startup shortcut..." -ForegroundColor Yellow
$startupDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"

$scriptContent = @'
$env:GOROOT = "$env:USERPROFILE\go"
$env:GOPATH = "$env:USERPROFILE\go\gopath"
$env:GOPROXY = "https://goproxy.cn,direct"
$env:PATH = "$env:GOROOT\bin;$env:PATH"
Set-Location $env:USERPROFILE\.moonbridge
Start-Process -WindowStyle Hidden -FilePath "$env:GOROOT\bin\go.exe" -ArgumentList "run", ".\cmd\moonbridge", "--config", "config.yml" -RedirectStandardOutput "$env:TEMP\moonbridge.log" -RedirectStandardError "$env:TEMP\moonbridge_err.log"
'@
$scriptContent | Out-File -FilePath "$mbDir\start_moonbridge.ps1" -Encoding utf8

$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut("$startupDir\MoonBridge.lnk")
$Shortcut.TargetPath = "powershell.exe"
$Shortcut.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$mbDir\start_moonbridge.ps1`""
$Shortcut.WorkingDirectory = $mbDir
$Shortcut.WindowStyle = 7
$Shortcut.Save()
Write-Host "  Startup shortcut created" -ForegroundColor Green

# ===== Done =====
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " Setup complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Moon Bridge:  http://127.0.0.1:38440" -ForegroundColor White
Write-Host "  Config file:  $codexHome\config.toml" -ForegroundColor White
Write-Host "  Moon Bridge dir: $mbDir" -ForegroundColor White
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Yellow
Write-Host "  1. Restart VSCode: Ctrl+Shift+P -> Reload Window" -ForegroundColor White
Write-Host "  2. Open Codex and start chatting with DeepSeek!" -ForegroundColor White
Write-Host ""

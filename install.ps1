param(
  [string]$AegisVersion = $(if ($env:AEGIS_VERSION) { $env:AEGIS_VERSION } else { "v0.1.2" }),
  [string]$AegisProfile = $(if ($env:AEGIS_PROFILE) { $env:AEGIS_PROFILE } else { "release" }),
  [string]$AegisHome = $(if ($env:AEGIS_HOME) { $env:AEGIS_HOME } else { Join-Path $HOME ".aegis\profiles\$AegisProfile" }),
  [string]$BinDir = $(if ($env:AEGIS_BIN_DIR) { $env:AEGIS_BIN_DIR } else { Join-Path $HOME ".aegis\bin" }),
  [switch]$WorkerOnly,
  [switch]$NoStartLocalGateway
)

$ErrorActionPreference = "Stop"

$StateDir = if ($env:AEGIS_RUNTIME_DIR) { $env:AEGIS_RUNTIME_DIR } else { Join-Path $AegisHome ".aegis" }
$RunDir = if ($env:AEGIS_RUN_DIR) { $env:AEGIS_RUN_DIR } else { Join-Path $StateDir "run" }
$LogDir = if ($env:AEGIS_LOG_DIR) { $env:AEGIS_LOG_DIR } else { Join-Path $StateDir "logs" }
$EvidenceDir = if ($env:AEGIS_EVIDENCE_DIR) { $env:AEGIS_EVIDENCE_DIR } else { Join-Path $StateDir "evidence" }
$DbDir = Join-Path $StateDir "db"
$TokenFile = Join-Path $StateDir "access-token.txt"
$RootFile = if ($env:AEGIS_ROOT_FILE) { $env:AEGIS_ROOT_FILE } else { Join-Path $HOME ".aegis\root.txt" }
$ProfileRootFile = if ($env:AEGIS_PROFILE_ROOT_FILE) { $env:AEGIS_PROFILE_ROOT_FILE } else { Join-Path $HOME ".aegis\roots\$AegisProfile.txt" }

function New-RandomHex {
  param([int]$Bytes)
  $buffer = New-Object byte[] $Bytes
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try { $rng.GetBytes($buffer) } finally { $rng.Dispose() }
  return -join ($buffer | ForEach-Object { $_.ToString("x2") })
}

function Quote-Env {
  param([string]$Value)
  $escaped = $Value.Replace('\', '\\').Replace('"', '\"').Replace('$', '\$').Replace('`', '\`')
  return '"' + $escaped + '"'
}

function ConvertTo-Base64Url {
  param([byte[]]$Bytes)
  return [Convert]::ToBase64String($Bytes).TrimEnd("=").Replace("+", "-").Replace("/", "_")
}

function ConvertStringTo-Base64Url {
  param([string]$Text)
  return ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes($Text))
}

function Mint-Token {
  New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
  $secret = $env:AEGIS_AUTH_SECRET
  if ([string]::IsNullOrWhiteSpace($secret)) {
    $secret = New-RandomHex 32
    $env:AEGIS_AUTH_SECRET = $secret
  }
  $ownerId = if ($env:AEGIS_OWNER_ID) { $env:AEGIS_OWNER_ID } else { "owner" }
  $headerJson = '{"alg":"HS256","typ":"JWT"}'
  $payload = [ordered]@{
    sub = "bootstrap-owner"
    tid = $ownerId
    role = "owner"
    typ = "access"
    exp = [int64]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + 30 * 24 * 3600)
  }
  $payloadJson = $payload | ConvertTo-Json -Compress
  $signingInput = "$(ConvertStringTo-Base64Url $headerJson).$(ConvertStringTo-Base64Url $payloadJson)"
  $hmac = [System.Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($secret))
  try { $sig = $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($signingInput)) } finally { $hmac.Dispose() }
  Set-Content -Path $TokenFile -Value "$signingInput.$(ConvertTo-Base64Url $sig)" -NoNewline -Encoding ASCII
}

function Download-Bundle {
  $target = "x86_64-pc-windows-msvc"
  $asset = "aegis-native-$AegisVersion-$target.zip"
  $url = "https://github.com/HaloForgeAI/aegis-release/releases/download/$AegisVersion/$asset"
  $tmp = Join-Path ([IO.Path]::GetTempPath()) "aegis-$([Guid]::NewGuid())"
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  $zip = Join-Path $tmp $asset
  Write-Host "Downloading $asset ..."
  Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
  Expand-Archive -Path $zip -DestinationPath $tmp -Force
  $bundle = Join-Path $tmp "aegis-native-$AegisVersion-$target"
  New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $AegisHome "scripts") | Out-Null
  Copy-Item (Join-Path $bundle "aegis.exe") (Join-Path $BinDir "aegis.exe") -Force
  Copy-Item (Join-Path $bundle "aegis-server.exe") (Join-Path $BinDir "aegis-server.exe") -Force
  Copy-Item (Join-Path $bundle "aegis-install.ps1") (Join-Path $AegisHome "scripts\aegis-install.ps1") -Force -ErrorAction SilentlyContinue
  Copy-Item (Join-Path $bundle "aegis-stop.ps1") (Join-Path $AegisHome "scripts\aegis-stop.ps1") -Force -ErrorAction SilentlyContinue
}

function Write-Env {
  New-Item -ItemType Directory -Force -Path $AegisHome, $StateDir, $RunDir, $LogDir, $EvidenceDir, $DbDir | Out-Null
  if ($WorkerOnly) {
    if ([string]::IsNullOrWhiteSpace($env:AEGIS_SERVER_URL) -or [string]::IsNullOrWhiteSpace($env:AEGIS_ACCESS_TOKEN)) {
      throw "AEGIS_SERVER_URL and AEGIS_ACCESS_TOKEN are required for -WorkerOnly."
    }
    Set-Content -Path (Join-Path $AegisHome ".env") -Value @(
      "AEGIS_PROFILE=$(Quote-Env $AegisProfile)",
      "AEGIS_API_URL=$(Quote-Env $env:AEGIS_SERVER_URL)",
      "AEGIS_PUBLIC_URL=$(Quote-Env $env:AEGIS_SERVER_URL)",
      "AEGIS_RUNTIME_DIR=$(Quote-Env $StateDir)",
      "AEGIS_RUN_DIR=$(Quote-Env $RunDir)",
      "AEGIS_LOG_DIR=$(Quote-Env $LogDir)",
      "AEGIS_EVIDENCE_DIR=$(Quote-Env $EvidenceDir)"
    ) -Encoding ASCII
    Set-Content -Path $TokenFile -Value $env:AEGIS_ACCESS_TOKEN -NoNewline -Encoding ASCII
    return
  }

  if ([string]::IsNullOrWhiteSpace($env:AEGIS_AUTH_SECRET)) { $env:AEGIS_AUTH_SECRET = New-RandomHex 32 }
  $ownerId = if ($env:AEGIS_OWNER_ID) { $env:AEGIS_OWNER_ID } else { "owner" }
  Set-Content -Path (Join-Path $AegisHome ".env") -Value @(
    "AEGIS_AUTH_SECRET=$(Quote-Env $env:AEGIS_AUTH_SECRET)",
    "AEGIS_OWNER_ID=$(Quote-Env $ownerId)",
    "AEGIS_PROFILE=$(Quote-Env $AegisProfile)",
    "AEGIS_API_URL=`"http://localhost:8787`"",
    "AEGIS_PUBLIC_URL=$(Quote-Env $(if ($env:AEGIS_PUBLIC_URL) { $env:AEGIS_PUBLIC_URL } else { "http://localhost:8788" }))",
    "AEGIS_WEB_PORT=$(Quote-Env $(if ($env:AEGIS_WEB_PORT) { $env:AEGIS_WEB_PORT } else { "8788" }))",
    "AEGIS_RUNTIME_DIR=$(Quote-Env $StateDir)",
    "AEGIS_RUN_DIR=$(Quote-Env $RunDir)",
    "AEGIS_LOG_DIR=$(Quote-Env $LogDir)",
    "AEGIS_EVIDENCE_DIR=$(Quote-Env $EvidenceDir)",
    "AEGIS_SQLITE_PATH=$(Quote-Env (Join-Path $DbDir "aegis.sqlite"))",
    "AEGIS_ATTACHMENTS_DIR=$(Quote-Env (Join-Path $StateDir "attachments"))",
    "",
    "AEGIS_LLM_BASE_URL=$(Quote-Env $env:AEGIS_LLM_BASE_URL)",
    "AEGIS_LLM_MODEL=$(Quote-Env $env:AEGIS_LLM_MODEL)",
    "AEGIS_LLM_API_KEY=$(Quote-Env $env:AEGIS_LLM_API_KEY)",
    "",
    "AEGIS_CONTEXT_MAINTENANCE_ENABLED=true",
    "AEGIS_CONTEXT_MAINTENANCE_USE_LLM=false",
    "AEGIS_GATEWAY_DISPATCH_ENABLED=true",
    "AEGIS_GATEWAY_HEALTH_ENABLED=true",
    "AEGIS_AUTOMATION_SCHEDULER_ENABLED=true",
    "",
    "AEGIS_TELEGRAM_BOT_TOKEN=$(Quote-Env $env:AEGIS_TELEGRAM_BOT_TOKEN)",
    "AEGIS_TELEGRAM_OWNER_ID=$(Quote-Env $ownerId)",
    "AEGIS_TELEGRAM_MODE=$(Quote-Env $(if ($env:AEGIS_TELEGRAM_MODE) { $env:AEGIS_TELEGRAM_MODE } else { "polling" }))",
    "AEGIS_TELEGRAM_SECRET_TOKEN=$(Quote-Env $(if ($env:AEGIS_TELEGRAM_SECRET_TOKEN) { $env:AEGIS_TELEGRAM_SECRET_TOKEN } else { New-RandomHex 16 }))"
  ) -Encoding ASCII
  Mint-Token
}

Download-Bundle
Write-Env
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $RootFile), (Split-Path -Parent $ProfileRootFile) | Out-Null
Set-Content -Path $RootFile -Value $AegisHome -Encoding ASCII
Set-Content -Path $ProfileRootFile -Value $AegisHome -Encoding ASCII
$env:Path = "$BinDir;$env:Path"

if ($WorkerOnly) {
  Write-Host "Worker-only install is ready."
  Write-Host "Start Local Gateway with: $BinDir\aegis.exe --root `"$AegisHome`" local-gateway --workspace-root <path>"
} elseif ($NoStartLocalGateway) {
  & (Join-Path $BinDir "aegis.exe") --root $AegisHome start --no-local-gateway
} else {
  & (Join-Path $BinDir "aegis.exe") --root $AegisHome start
}

Write-Host "Aegis installed at $AegisHome"
Write-Host "CLI: $(Join-Path $BinDir "aegis.exe")"

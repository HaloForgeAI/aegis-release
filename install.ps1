param(
  [string]$AegisVersion = $(if ($env:AEGIS_VERSION) { $env:AEGIS_VERSION } else { "v0.1.1" }),
  [string]$AegisHome = $(if ($env:AEGIS_HOME) { $env:AEGIS_HOME } else { Join-Path $HOME ".aegis\self-host" }),
  [string]$AegisBinDir = $(if ($env:AEGIS_BIN_DIR) { $env:AEGIS_BIN_DIR } else { Join-Path $HOME ".aegis\bin" }),
  [string]$ReleaseRepo = $(if ($env:AEGIS_RELEASE_REPO) { $env:AEGIS_RELEASE_REPO } else { "HaloForgeAI/aegis-release" }),
  [string]$ReleaseBranch = $(if ($env:AEGIS_RELEASE_BRANCH) { $env:AEGIS_RELEASE_BRANCH } else { "main" }),
  [switch]$NoDocker,
  [switch]$NoCli
)

$ErrorActionPreference = "Stop"

$RawBase = "https://raw.githubusercontent.com/$ReleaseRepo/$ReleaseBranch"
$ReleaseBase = "https://github.com/$ReleaseRepo/releases/download/$AegisVersion"

function Require-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Missing required command: $Name"
  }
}

function Download-File {
  param([string]$Url, [string]$OutFile)
  Invoke-WebRequest -Uri $Url -OutFile $OutFile
}

function Install-AegisCli {
  Require-Command "Expand-Archive"
  $asset = "aegis-cli-$AegisVersion-x86_64-pc-windows-msvc.zip"
  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("aegis-install-" + [System.Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  try {
    $archive = Join-Path $tmp $asset
    Write-Host "Downloading $asset..."
    Download-File "$ReleaseBase/$asset" $archive
    Expand-Archive -Path $archive -DestinationPath $tmp -Force
    New-Item -ItemType Directory -Force -Path $AegisBinDir | Out-Null
    Copy-Item (Join-Path $tmp "aegis.exe") (Join-Path $AegisBinDir "aegis.exe") -Force
    Write-Host "Installed aegis CLI to $AegisBinDir\aegis.exe"
  }
  finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Install-AegisCompose {
  Require-Command "docker"
  New-Item -ItemType Directory -Force -Path $AegisHome | Out-Null
  Push-Location $AegisHome
  try {
    Download-File "$RawBase/compose/aegis.compose.yml" "aegis.compose.yml"
    if (-not (Test-Path ".env")) {
      Download-File "$RawBase/.env.example" ".env"
      $secret = [System.Guid]::NewGuid().ToString("N") + [System.Guid]::NewGuid().ToString("N")
      (Get-Content ".env") -replace '^AEGIS_AUTH_SECRET=.*', "AEGIS_AUTH_SECRET=$secret" | Set-Content ".env"
    }
    docker compose --env-file .env -f aegis.compose.yml up -d
  }
  finally {
    Pop-Location
  }
}

if (-not $NoCli) {
  Install-AegisCli
}

if (-not $NoDocker) {
  Install-AegisCompose
}

Write-Host ""
Write-Host "Aegis install path is ready."
Write-Host "Next checks:"
Write-Host "  $AegisBinDir\aegis.exe status"
Write-Host "  $AegisBinDir\aegis.exe onboarding doctor"
Write-Host "  $AegisBinDir\aegis.exe worker tools --no-exec"

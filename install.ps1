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

function Verify-Checksum {
  param([string]$SumsPath, [string]$AssetName, [string]$AssetPath)
  $line = Get-Content $SumsPath | Where-Object { $_ -match [regex]::Escape($AssetName) } | Select-Object -First 1
  if (-not $line) {
    throw "Checksum for $AssetName was not found in SHA256SUMS."
  }
  $expected = ($line -split '\s+')[0].ToLowerInvariant()
  $actual = (Get-FileHash -Algorithm SHA256 $AssetPath).Hash.ToLowerInvariant()
  if ($actual -ne $expected) {
    throw "Checksum mismatch for $AssetName. Expected $expected, got $actual."
  }
}

function Ensure-PublicImageAvailable {
  $scope = [System.Uri]::EscapeDataString("repository:haloforgeai/aegis:pull")
  $url = "https://ghcr.io/token?service=ghcr.io&scope=$scope"
  try {
    $response = Invoke-RestMethod -Uri $url
    if (-not $response.token) {
      throw "No anonymous token returned."
    }
  }
  catch {
    throw "The GHCR image ghcr.io/haloforgeai/aegis:$AegisVersion is not anonymously pullable yet. Set the package visibility to Public, or run with -NoDocker to install only the local CLI for now."
  }
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
    Download-File "$ReleaseBase/SHA256SUMS" (Join-Path $tmp "SHA256SUMS")
    Verify-Checksum (Join-Path $tmp "SHA256SUMS") $asset $archive
    Expand-Archive -Path $archive -DestinationPath $tmp -Force
    $exe = Get-ChildItem -Path $tmp -Filter "aegis.exe" -Recurse | Select-Object -First 1
    if (-not $exe) {
      throw "Expanded archive did not contain aegis.exe."
    }
    New-Item -ItemType Directory -Force -Path $AegisBinDir | Out-Null
    Copy-Item $exe.FullName (Join-Path $AegisBinDir "aegis.exe") -Force
    Write-Host "Installed aegis CLI to $AegisBinDir\aegis.exe"
  }
  finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Install-AegisCompose {
  Require-Command "docker"
  Ensure-PublicImageAvailable
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

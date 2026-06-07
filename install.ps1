param(
  [string]$AegisVersion = $(if ($env:AEGIS_VERSION) { $env:AEGIS_VERSION } else { "v0.1.1" }),
  [string]$AegisHome = $(if ($env:AEGIS_HOME) { $env:AEGIS_HOME } else { Join-Path $HOME ".aegis\self-host" }),
  [string]$AegisRootFile = $(if ($env:AEGIS_ROOT_FILE) { $env:AEGIS_ROOT_FILE } else { Join-Path $HOME ".aegis\root.txt" }),
  [string]$AegisBinDir = $(if ($env:AEGIS_BIN_DIR) { $env:AEGIS_BIN_DIR } else { Join-Path $HOME ".aegis\bin" }),
  [string]$ReleaseRepo = $(if ($env:AEGIS_RELEASE_REPO) { $env:AEGIS_RELEASE_REPO } else { "HaloForgeAI/aegis-release" }),
  [string]$ReleaseBranch = $(if ($env:AEGIS_RELEASE_BRANCH) { $env:AEGIS_RELEASE_BRANCH } else { "main" }),
  [switch]$WorkerOnly,
  [switch]$NoDocker,
  [switch]$NoCli
)

$ErrorActionPreference = "Stop"

$RawBase = "https://raw.githubusercontent.com/$ReleaseRepo/$ReleaseBranch"
$ReleaseBase = "https://github.com/$ReleaseRepo/releases/download/$AegisVersion"
$TokenFile = Join-Path $AegisHome ".aegis\access-token.txt"
$WorkerInstall = [bool]$WorkerOnly -or [bool]$NoDocker

if ($NoDocker) {
  Write-Warning "-NoDocker is deprecated; use -WorkerOnly."
}
if ($WorkerInstall -and $NoCli) {
  throw "Worker-only install requires the aegis CLI; remove -NoCli."
}

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

function Ensure-RootScaffold {
  New-Item -ItemType Directory -Force -Path (Join-Path $AegisHome "docker") | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $AegisHome "scripts") | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $AegisHome ".aegis") | Out-Null
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $AegisRootFile) | Out-Null
  Set-Content -Path $AegisRootFile -Value $AegisHome -Encoding UTF8
  $cargoToml = Join-Path $AegisHome "Cargo.toml"
  if (-not (Test-Path $cargoToml)) {
    Set-Content -Path $cargoToml -Value "[workspace]`n# Public Aegis install root marker.`n" -Encoding UTF8
  }
}

function Install-RootFiles {
  Ensure-RootScaffold
  Download-File "$RawBase/compose/aegis.compose.yml" (Join-Path $AegisHome "docker\docker-compose.yml")
  try {
    Download-File "$RawBase/scripts/aegis-stop.ps1" (Join-Path $AegisHome "scripts\aegis-stop.ps1")
  }
  catch {
    Remove-Item (Join-Path $AegisHome "scripts\aegis-stop.ps1") -Force -ErrorAction SilentlyContinue
    Write-Warning "Could not download optional scripts/aegis-stop.ps1 helper."
  }
}

function Set-EnvKey {
  param([string]$Key, [string]$Value)
  $envPath = Join-Path $AegisHome ".env"
  if (-not (Test-Path $envPath)) {
    New-Item -ItemType File -Force -Path $envPath | Out-Null
  }
  $line = "$Key=`"$($Value.Replace('\', '\\').Replace('"', '\"').Replace('$', '\$').Replace('`', '\`'))`""
  $content = Get-Content $envPath
  $pattern = "^$([regex]::Escape($Key))="
  if ($content | Where-Object { $_ -match $pattern }) {
    $content = $content | ForEach-Object { if ($_ -match $pattern) { $line } else { $_ } }
  } else {
    $content += $line
  }
  Set-Content -Path $envPath -Value $content -Encoding UTF8
}

function Get-EnvFileValue {
  param([string]$Key, [string]$Default = "")
  $envPath = Join-Path $AegisHome ".env"
  if (-not (Test-Path $envPath)) { return $Default }
  $line = Get-Content $envPath | Where-Object { $_ -match "^$([regex]::Escape($Key))=" } | Select-Object -Last 1
  if (-not $line) { return $Default }
  $value = ($line -split "=", 2)[1].Trim()
  if ($value.StartsWith('"') -and $value.EndsWith('"')) {
    return $value.Substring(1, $value.Length - 2)
  }
  return $value
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
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $TokenFile) | Out-Null
  $secret = Get-EnvFileValue "AEGIS_AUTH_SECRET"
  $tenant = Get-EnvFileValue "AEGIS_BOOTSTRAP_TENANT" "studio-a"
  if ([string]::IsNullOrEmpty($secret)) {
    throw "Cannot mint owner token: AEGIS_AUTH_SECRET is missing."
  }
  $headerJson = '{"alg":"HS256","typ":"JWT"}'
  $payload = [ordered]@{
    sub = "bootstrap-owner"
    tid = $tenant
    role = "owner"
    typ = "access"
    exp = [int][double]::Parse((Get-Date -Date (Get-Date).AddDays(30).ToUniversalTime() -UFormat %s))
  }
  $payloadJson = $payload | ConvertTo-Json -Compress
  $signingInput = "$(ConvertStringTo-Base64Url $headerJson).$(ConvertStringTo-Base64Url $payloadJson)"
  $hmac = [System.Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($secret))
  try {
    $sig = $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($signingInput))
  }
  finally {
    $hmac.Dispose()
  }
  Set-Content -Path $TokenFile -Value "$signingInput.$(ConvertTo-Base64Url $sig)" -NoNewline -Encoding ASCII
}

function Configure-ExistingControlPlane {
  if ([string]::IsNullOrWhiteSpace($env:AEGIS_SERVER_URL) -or [string]::IsNullOrWhiteSpace($env:AEGIS_ACCESS_TOKEN)) {
    throw "Worker-only install requires AEGIS_SERVER_URL and AEGIS_ACCESS_TOKEN. This does not install a standalone non-Docker Aegis Server."
  }
  Install-RootFiles
  Set-EnvKey "AEGIS_API_URL" $env:AEGIS_SERVER_URL.TrimEnd("/")
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $TokenFile) | Out-Null
  Set-Content -Path $TokenFile -Value $env:AEGIS_ACCESS_TOKEN -NoNewline -Encoding ASCII
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
    Load-ImageArchive
  }
}

function Load-ImageArchive {
  $asset = "aegis-server-$AegisVersion-linux-amd64.docker.tar.gz"
  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("aegis-image-" + [System.Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  try {
    $archive = Join-Path $tmp $asset
    Write-Host "GHCR is not anonymously pullable yet; downloading $asset..."
    try {
      Download-File "$ReleaseBase/$asset" $archive
    }
    catch {
      throw "The GHCR image ghcr.io/haloforgeai/aegis:$AegisVersion is not anonymously pullable and $asset is not attached to the public release. Set the package visibility to Public, publish the Docker archive release asset, or run with -WorkerOnly to connect this machine to an existing Aegis Server."
    }
    Download-File "$ReleaseBase/SHA256SUMS" (Join-Path $tmp "SHA256SUMS")
    Verify-Checksum (Join-Path $tmp "SHA256SUMS") $asset $archive
    docker load --input $archive
  }
  finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
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
  Install-RootFiles
  Ensure-PublicImageAvailable
  New-Item -ItemType Directory -Force -Path $AegisHome | Out-Null
  Push-Location $AegisHome
  try {
    if (-not (Test-Path ".env")) {
      Download-File "$RawBase/.env.example" ".env"
      $secret = [System.Guid]::NewGuid().ToString("N") + [System.Guid]::NewGuid().ToString("N")
      (Get-Content ".env") -replace '^AEGIS_AUTH_SECRET=.*', "AEGIS_AUTH_SECRET=$secret" | Set-Content ".env"
    }
    (Get-Content ".env") `
      -replace '^AEGIS_VERSION=.*', "AEGIS_VERSION=$AegisVersion" `
      -replace '^AEGIS_IMAGE=.*', "AEGIS_IMAGE=ghcr.io/haloforgeai/aegis:$AegisVersion" |
      Set-Content ".env"
    Set-EnvKey "AEGIS_API_URL" $(if ($env:AEGIS_API_URL) { $env:AEGIS_API_URL } else { "http://localhost:8787" })
    Set-EnvKey "AEGIS_BOOTSTRAP_TENANT" $(if ($env:AEGIS_BOOTSTRAP_TENANT) { $env:AEGIS_BOOTSTRAP_TENANT } else { "studio-a" })
    Mint-Token
    docker compose -p aegis --env-file .env -f docker/docker-compose.yml up -d
  }
  finally {
    Pop-Location
  }
}

if (-not $NoCli) {
  Install-AegisCli
}

if ($WorkerInstall) {
  Configure-ExistingControlPlane
} else {
  Install-AegisCompose
}

Write-Host ""
if ($WorkerInstall) {
  Write-Host "Aegis worker-only install is ready."
  Write-Host "This machine is configured to connect to:"
  Write-Host "  $($env:AEGIS_SERVER_URL.TrimEnd('/'))"
  Write-Host "Next checks:"
  Write-Host "  $AegisBinDir\aegis.exe --root `"$AegisHome`" status --no-compose"
  Write-Host "  $AegisBinDir\aegis.exe --root `"$AegisHome`" worker tools --no-exec"
  Write-Host "  $AegisBinDir\aegis.exe --root `"$AegisHome`" local-gateway --workspace-root `"$HOME\work`" --max-workers 2"
} else {
  Write-Host "Aegis install path is ready."
  Write-Host "Next checks:"
  Write-Host "  $AegisBinDir\aegis.exe --root `"$AegisHome`" status"
  Write-Host "  $AegisBinDir\aegis.exe status"
  Write-Host "  $AegisBinDir\aegis.exe onboarding doctor"
  Write-Host "  $AegisBinDir\aegis.exe worker tools --no-exec"
}

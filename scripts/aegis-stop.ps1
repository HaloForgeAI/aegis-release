param(
  [switch]$Purge,
  [switch]$Remove
)

$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$EnvFile = Join-Path $RootDir ".env"
$ComposeFile = Join-Path $RootDir "docker/docker-compose.yml"
$ComposeProject = if ($env:AEGIS_COMPOSE_PROJECT_NAME) { $env:AEGIS_COMPOSE_PROJECT_NAME } else { "aegis" }
$PidFile = Join-Path $RootDir ".aegis\local-gateway.pid"

if (Test-Path $PidFile) {
  $pidText = (Get-Content $PidFile -Raw).Trim()
  if ($pidText) {
    try {
      Stop-Process -Id ([int]$pidText) -ErrorAction SilentlyContinue
    } catch {}
  }
  Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
}

if ($Purge) {
  docker compose -p $ComposeProject --env-file $EnvFile -f $ComposeFile down -v --remove-orphans
} elseif ($Remove) {
  docker compose -p $ComposeProject --env-file $EnvFile -f $ComposeFile down --remove-orphans
} else {
  docker compose -p $ComposeProject --env-file $EnvFile -f $ComposeFile stop
}

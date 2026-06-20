param([switch]$Purge)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Bin = if ($env:AEGIS_BIN) { $env:AEGIS_BIN } else { Join-Path $HOME ".aegis\bin\aegis.exe" }

if ($Purge) {
  & $Bin --root $RootDir down --purge
} else {
  & $Bin --root $RootDir down
}

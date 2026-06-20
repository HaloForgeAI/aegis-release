#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-${AEGIS_VERSION:-v0.1.2}}"
RELEASE_URL="https://github.com/HaloForgeAI/aegis-release/releases/download/${VERSION}"

check_asset() {
  local asset="$1"
  local code
  code="$(curl -fsSI -o /dev/null -w '%{http_code}' "${RELEASE_URL}/${asset}" 2>/dev/null || true)"
  if [ "$code" = "200" ] || [ "$code" = "302" ]; then
    printf 'ok   %s\n' "$asset"
  else
    printf 'fail %s HTTP %s\n' "$asset" "$code"
    return 1
  fi
}

check_asset "aegis-native-${VERSION}-x86_64-unknown-linux-gnu.tar.gz"
check_asset "aegis-native-${VERSION}-aarch64-apple-darwin.tar.gz"
check_asset "aegis-native-${VERSION}-x86_64-pc-windows-msvc.zip"
check_asset "SHA256SUMS"

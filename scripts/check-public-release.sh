#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-${AEGIS_VERSION:-v0.1.1}}"
REPO="${AEGIS_RELEASE_REPO:-HaloForgeAI/aegis-release}"
DOMAIN="${AEGIS_SITE_DOMAIN:-https://aegis.haloforge.dev}"
RELEASE_URL="https://github.com/${REPO}/releases/download/${VERSION}"

status=0

check_url() {
  local label="$1"
  local url="$2"
  local code
  code="$(curl -LsS -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || true)"
  if [[ "$code" == "200" ]]; then
    printf 'ok   %s\n' "$label"
  else
    printf 'fail %s HTTP %s\n' "$label" "$code"
    status=1
  fi
}

check_ghcr() {
  local response
  response="$(curl -fsSL 'https://ghcr.io/token?service=ghcr.io&scope=repository:haloforgeai/aegis:pull' 2>/dev/null || true)"
  if printf '%s' "$response" | grep -q '"token"'; then
    printf 'ok   ghcr anonymous pull token\n'
    return 0
  fi

  printf 'warn ghcr anonymous pull token unavailable\n'
  return 1
}

check_image_archive() {
  local url code
  url="${RELEASE_URL}/aegis-server-${VERSION}-linux-amd64.docker.tar.gz"
  code="$(curl -LsS -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || true)"
  if [[ "$code" == "200" ]]; then
    printf 'ok   Docker image archive fallback\n'
  else
    printf 'fail Docker image archive fallback HTTP %s\n' "$code"
    status=1
  fi
}

check_domain() {
  local code
  code="$(curl -LsS -o /dev/null -w '%{http_code}' --max-time 20 "$DOMAIN" 2>/dev/null || true)"
  if [[ "$code" == "200" ]]; then
    printf 'ok   %s\n' "$DOMAIN"
  else
    printf 'fail %s HTTP %s\n' "$DOMAIN" "$code"
    status=1
  fi
}

check_url "SHA256SUMS" "${RELEASE_URL}/SHA256SUMS"
check_url "macOS arm64 CLI" "${RELEASE_URL}/aegis-cli-${VERSION}-aarch64-apple-darwin.tar.gz"
check_url "Windows x64 CLI" "${RELEASE_URL}/aegis-cli-${VERSION}-x86_64-pc-windows-msvc.zip"
if ! check_ghcr; then
  check_image_archive
fi
check_domain

exit "$status"

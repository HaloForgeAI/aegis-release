#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-${AEGIS_VERSION:-v0.1.2}}"
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
  local response token code
  response="$(curl -fsSL 'https://ghcr.io/token?service=ghcr.io&scope=repository:haloforgeai/aegis:pull' 2>/dev/null || true)"
  token="$(printf '%s' "$response" | sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  if [[ -z "$token" ]]; then
    printf 'fail GHCR anonymous pull token unavailable\n'
    status=1
    return
  fi

  code="$(curl -LsS -o /dev/null -w '%{http_code}' \
    -H "Authorization: Bearer ${token}" \
    -H 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json' \
    "https://ghcr.io/v2/haloforgeai/aegis/manifests/${VERSION}" 2>/dev/null || true)"
  if [[ "$code" == "200" ]]; then
    printf 'ok   GHCR anonymous image manifest\n'
  else
    printf 'fail GHCR anonymous image manifest HTTP %s\n' "$code"
    status=1
  fi
}

check_image_archive() {
  local url code
  url="${RELEASE_URL}/aegis-server-${VERSION}-linux-amd64.docker.tar.gz"
  code="$(curl -LsS -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || true)"
  if [[ "$code" == "200" ]]; then
    printf 'ok   Docker image archive recovery asset\n'
  else
    printf 'fail Docker image archive recovery asset HTTP %s\n' "$code"
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
check_ghcr
check_image_archive
check_domain

exit "$status"

#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-${AEGIS_VERSION:-v0.1.5}}"
REPO="${AEGIS_RELEASE_REPO:-HaloForgeAI/aegis-release}"
DOMAIN="${AEGIS_SITE_DOMAIN:-https://aegis.haloforge.dev}"
RELEASE_URL="https://github.com/${REPO}/releases/download/${VERSION}"
EXPECT_IOS="${AEGIS_EXPECT_IOS_IPA:-1}"

status=0

check_url() {
  local label="$1"
  local url="$2"
  local code
  code="$(curl -LsS -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || true)"
  if [[ "$code" == "200" || "$code" == "302" ]]; then
    printf 'ok   %s\n' "$label"
  else
    printf 'fail %s HTTP %s\n' "$label" "$code"
    status=1
  fi
}

check_absent_url() {
  local label="$1"
  local url="$2"
  local code
  code="$(curl -LsS -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || true)"
  if [[ "$code" == "404" ]]; then
    printf 'ok   absent %s\n' "$label"
  elif [[ "$code" == "200" || "$code" == "302" ]]; then
    printf 'fail legacy asset is still public: %s\n' "$label"
    status=1
  else
    printf 'warn %s absence check HTTP %s\n' "$label" "$code"
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
check_url "macOS Apple Silicon DMG" "${RELEASE_URL}/Aegis-${VERSION}-macos-arm64.dmg"
check_url "Windows x64 signed MSIX" "${RELEASE_URL}/Aegis-${VERSION}-windows-x64.msix"
check_url "Android release AAB" "${RELEASE_URL}/Aegis-${VERSION}-android.aab"
check_url "Android signed APK" "${RELEASE_URL}/Aegis-${VERSION}-android.apk"
if [[ "$EXPECT_IOS" == "1" ]]; then
  check_url "iOS signed IPA" "${RELEASE_URL}/Aegis-${VERSION}-ios.ipa"
else
  printf 'skip iOS signed IPA (set AEGIS_EXPECT_IOS_IPA=1 when Apple export signing is configured)\n'
fi
check_absent_url "legacy Bash installer" "${RELEASE_URL}/install.sh"
check_absent_url "legacy PowerShell installer" "${RELEASE_URL}/install.ps1"
check_absent_url "Windows portable ZIP diagnostic" "${RELEASE_URL}/Aegis-${VERSION}-windows-x64.zip"
check_absent_url "Docker archive" "${RELEASE_URL}/Aegis-${VERSION}-docker.tar.gz"
check_domain

exit "$status"

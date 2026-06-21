#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-${AEGIS_VERSION:-v0.1.5}}"
REPO="${AEGIS_RELEASE_REPO:-HaloForgeAI/aegis-release}"
DOMAIN="${AEGIS_SITE_DOMAIN:-https://aegis.haloforge.dev}"
RELEASE_URL="https://github.com/${REPO}/releases/download/${VERSION}"
EXPECT_IOS="${AEGIS_EXPECT_IOS_IPA:-0}"
EXPECT_UNSIGNED_ANDROID="${AEGIS_EXPECT_UNSIGNED_ANDROID:-0}"

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
check_url "Windows x64 MSIX" "${RELEASE_URL}/Aegis-${VERSION}-windows-x64.msix"
check_url "Android release AAB" "${RELEASE_URL}/Aegis-${VERSION}-android.aab"
if [[ "$EXPECT_UNSIGNED_ANDROID" == "1" ]]; then
  check_url "Android unsigned APK build artifact" "${RELEASE_URL}/Aegis-${VERSION}-android-unsigned.apk"
else
  check_url "Android signed APK" "${RELEASE_URL}/Aegis-${VERSION}-android.apk"
fi
if [[ "$EXPECT_IOS" == "1" ]]; then
  check_url "iOS signed IPA" "${RELEASE_URL}/Aegis-${VERSION}-ios.ipa"
else
  printf 'skip iOS signed IPA (set AEGIS_EXPECT_IOS_IPA=1 when Apple export signing is configured)\n'
fi
check_domain

exit "$status"

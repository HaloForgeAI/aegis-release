#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-${AEGIS_VERSION:-v0.1.5}}"
REPO="${AEGIS_RELEASE_REPO:-HaloForgeAI/aegis-release}"
DOMAIN="${AEGIS_SITE_DOMAIN:-https://aegis.haloforge.dev}"
RELEASE_URL="https://github.com/${REPO}/releases/download/${VERSION}"
EXPECT_IOS="${AEGIS_EXPECT_IOS_IPA:-1}"
SHA256_FILE="$(mktemp "${TMPDIR:-/tmp}/aegis-release-sha256.XXXXXX")"

status=0

cleanup() {
  rm -f "$SHA256_FILE"
}
trap cleanup EXIT

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

fetch_sha256sums() {
  local code
  code="$(curl -LsS -o "$SHA256_FILE" -w '%{http_code}' "${RELEASE_URL}/SHA256SUMS" 2>/dev/null || true)"
  if [[ "$code" == "200" || "$code" == "302" ]]; then
    printf 'ok   SHA256SUMS\n'
  else
    printf 'fail SHA256SUMS HTTP %s\n' "$code"
    : > "$SHA256_FILE"
    status=1
  fi
}

sha256_has_asset() {
  local name="$1"
  awk '{print $NF}' "$SHA256_FILE" | sed 's#^\./##' | grep -Fxq "$name"
}

check_sha256_entry() {
  local label="$1"
  local name="$2"
  if sha256_has_asset "$name"; then
    printf 'ok   checksum entry %s\n' "$label"
  else
    printf 'fail missing checksum entry: %s\n' "$name"
    status=1
  fi
}

check_absent_sha256_entry() {
  local label="$1"
  local name="$2"
  if sha256_has_asset "$name"; then
    printf 'fail legacy checksum entry is still public: %s\n' "$label"
    status=1
  else
    printf 'ok   absent checksum entry %s\n' "$label"
  fi
}

fetch_sha256sums
check_url "macOS Apple Silicon PKG" "${RELEASE_URL}/Aegis-${VERSION}-macos-arm64.pkg"
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
check_absent_url "Windows portable ZIP diagnostic" "${RELEASE_URL}/Aegis-${VERSION}-windows-x64-portable.zip"
check_absent_url "Docker archive" "${RELEASE_URL}/Aegis-${VERSION}-docker.tar.gz"
check_absent_url "unsigned Windows MSIX diagnostic" "${RELEASE_URL}/Aegis-${VERSION}-windows-x64-unsigned.msix"
check_absent_url "unsigned Android APK diagnostic" "${RELEASE_URL}/Aegis-${VERSION}-android-unsigned.apk"
check_absent_url "unsigned Android AAB diagnostic" "${RELEASE_URL}/Aegis-${VERSION}-android-unsigned.aab"
check_domain

check_sha256_entry "macOS Apple Silicon PKG" "Aegis-${VERSION}-macos-arm64.pkg"
check_sha256_entry "macOS Apple Silicon DMG" "Aegis-${VERSION}-macos-arm64.dmg"
check_sha256_entry "Windows x64 signed MSIX" "Aegis-${VERSION}-windows-x64.msix"
check_sha256_entry "Android release AAB" "Aegis-${VERSION}-android.aab"
check_sha256_entry "Android signed APK" "Aegis-${VERSION}-android.apk"
if [[ "$EXPECT_IOS" == "1" ]]; then
  check_sha256_entry "iOS signed IPA" "Aegis-${VERSION}-ios.ipa"
fi

check_absent_sha256_entry "legacy Bash installer" "install.sh"
check_absent_sha256_entry "legacy PowerShell installer" "install.ps1"
check_absent_sha256_entry "Windows portable ZIP diagnostic" "Aegis-${VERSION}-windows-x64.zip"
check_absent_sha256_entry "Windows portable ZIP diagnostic" "Aegis-${VERSION}-windows-x64-portable.zip"
check_absent_sha256_entry "Docker archive" "Aegis-${VERSION}-docker.tar.gz"
check_absent_sha256_entry "unsigned Windows MSIX diagnostic" "Aegis-${VERSION}-windows-x64-unsigned.msix"
check_absent_sha256_entry "unsigned Android APK diagnostic" "Aegis-${VERSION}-android-unsigned.apk"
check_absent_sha256_entry "unsigned Android AAB diagnostic" "Aegis-${VERSION}-android-unsigned.aab"

exit "$status"

#!/usr/bin/env bash
set -euo pipefail

REPO="${AEGIS_RELEASE_REPO:-HaloForgeAI/aegis-release}"
BRANCH="${AEGIS_RELEASE_BRANCH:-main}"
VERSION="${AEGIS_VERSION:-v0.1.1}"
AEGIS_HOME="${AEGIS_HOME:-$HOME/.aegis/self-host}"
BIN_DIR="${AEGIS_BIN_DIR:-$HOME/.local/bin}"
BASE_RAW_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
RELEASE_URL="https://github.com/${REPO}/releases/download/${VERSION}"

usage() {
  cat <<'USAGE'
Usage: install.sh [--no-docker] [--no-cli]

Environment:
  AEGIS_VERSION        Release tag to install, default v0.1.1
  AEGIS_HOME           Self-host directory, default ~/.aegis/self-host
  AEGIS_BIN_DIR        CLI install directory, default ~/.local/bin
  AEGIS_RELEASE_REPO   Release repository, default HaloForgeAI/aegis-release
USAGE
}

NO_DOCKER=0
NO_CLI=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-docker)
      NO_DOCKER=1
      shift
      ;;
    --no-cli)
      NO_CLI=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

download() {
  local url="$1"
  local output="$2"
  curl -fsSL "$url" -o "$output"
}

verify_checksum() {
  local sums="$1"
  local asset="$2"
  local dir="$3"
  local expected actual

  expected="$(awk -v asset="$asset" '$2 == asset { print $1 }' "$sums")"
  if [[ -z "$expected" ]]; then
    echo "Checksum for ${asset} was not found in SHA256SUMS." >&2
    exit 1
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "${dir}/${asset}" | awk '{ print $1 }')"
  else
    actual="$(shasum -a 256 "${dir}/${asset}" | awk '{ print $1 }')"
  fi

  if [[ "$actual" != "$expected" ]]; then
    echo "Checksum mismatch for ${asset}." >&2
    echo "Expected: ${expected}" >&2
    echo "Actual:   ${actual}" >&2
    exit 1
  fi
}

ensure_public_image_available() {
  local image_scope token_response
  image_scope="repository:haloforgeai/aegis:pull"
  token_response="$(curl -fsSL "https://ghcr.io/token?service=ghcr.io&scope=${image_scope}" 2>/dev/null || true)"
  if ! printf '%s' "$token_response" | grep -q '"token"'; then
    cat >&2 <<EOF
The GHCR image is not anonymously pullable yet:
  ghcr.io/haloforgeai/aegis:${VERSION}

Set the GitHub Container Registry package visibility to Public, or run with
--no-docker to install only the local CLI for now.
EOF
    exit 1
  fi
}

secret_hex() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  else
    date +%s | shasum -a 256 | awk '{print $1}'
  fi
}

install_cli() {
  need curl
  need tar

  local os arch target asset tmp
  os="$(uname -s)"
  arch="$(uname -m)"

  if [[ "$os" == "Darwin" && "$arch" == "arm64" ]]; then
    target="aarch64-apple-darwin"
  else
    echo "This public installer currently supports macOS Apple Silicon for CLI install." >&2
    echo "Use install.ps1 on Windows or set --no-cli and install the CLI manually." >&2
    exit 1
  fi

  asset="aegis-cli-${VERSION}-${target}.tar.gz"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  echo "Downloading ${asset}..."
  download "${RELEASE_URL}/${asset}" "${tmp}/${asset}"
  download "${RELEASE_URL}/SHA256SUMS" "${tmp}/SHA256SUMS"
  verify_checksum "${tmp}/SHA256SUMS" "$asset" "$tmp"
  mkdir -p "$BIN_DIR"
  tar -xzf "${tmp}/${asset}" -C "$tmp"
  install -m 0755 "${tmp}/aegis-cli-${VERSION}-${target}/aegis" "${BIN_DIR}/aegis"
  echo "Installed aegis CLI to ${BIN_DIR}/aegis"
}

install_compose() {
  need curl
  need docker
  ensure_public_image_available

  mkdir -p "$AEGIS_HOME"
  cd "$AEGIS_HOME"

  download "${BASE_RAW_URL}/compose/aegis.compose.yml" "aegis.compose.yml"
  if [[ ! -f .env ]]; then
    download "${BASE_RAW_URL}/.env.example" ".env"
    auth_secret="$(secret_hex)"
    if [[ "$(uname -s)" == "Darwin" ]]; then
      sed -i '' "s/^AEGIS_AUTH_SECRET=.*/AEGIS_AUTH_SECRET=${auth_secret}/" .env
    else
      sed -i "s/^AEGIS_AUTH_SECRET=.*/AEGIS_AUTH_SECRET=${auth_secret}/" .env
    fi
  fi

  docker compose --env-file .env -f aegis.compose.yml up -d
}

if [[ "$NO_CLI" -eq 0 ]]; then
  install_cli
fi

if [[ "$NO_DOCKER" -eq 0 ]]; then
  install_compose
fi

cat <<EOF

Aegis install path is ready.

Next checks:
  ${BIN_DIR}/aegis status
  ${BIN_DIR}/aegis onboarding doctor
  ${BIN_DIR}/aegis worker tools --no-exec

If ${BIN_DIR} is not on PATH, add it to your shell profile.
EOF

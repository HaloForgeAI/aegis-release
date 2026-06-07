#!/usr/bin/env bash
set -euo pipefail

REPO="${AEGIS_RELEASE_REPO:-HaloForgeAI/aegis-release}"
BRANCH="${AEGIS_RELEASE_BRANCH:-main}"
VERSION="${AEGIS_VERSION:-v0.1.1}"
AEGIS_HOME="${AEGIS_HOME:-$HOME/.aegis/self-host}"
AEGIS_ROOT_FILE="${AEGIS_ROOT_FILE:-$HOME/.aegis/root.txt}"
BIN_DIR="${AEGIS_BIN_DIR:-$HOME/.local/bin}"
BASE_RAW_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
RELEASE_URL="https://github.com/${REPO}/releases/download/${VERSION}"
TOKEN_FILE="${AEGIS_TOKEN_FILE:-$AEGIS_HOME/.aegis/access-token.txt}"

usage() {
  cat <<'USAGE'
Usage: install.sh [--no-docker] [--no-cli]

Environment:
  AEGIS_VERSION        Release tag to install, default v0.1.1
  AEGIS_HOME           Self-host directory, default ~/.aegis/self-host
  AEGIS_BIN_DIR        CLI install directory, default ~/.local/bin
  AEGIS_RELEASE_REPO   Release repository, default HaloForgeAI/aegis-release
  AEGIS_ACCESS_TOKEN   Existing owner token for CLI/Local Gateway-only installs
  AEGIS_SERVER_URL     Existing Aegis API URL for CLI/Local Gateway-only installs
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
    load_image_archive
  fi
}

load_image_archive() {
  local asset tmp
  asset="aegis-server-${VERSION}-linux-amd64.docker.tar.gz"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  echo "GHCR is not anonymously pullable yet; downloading ${asset}..."
  if ! download "${RELEASE_URL}/${asset}" "${tmp}/${asset}"; then
    cat >&2 <<EOF
The GHCR image is not anonymously pullable and the public Docker archive was not found:
  ${RELEASE_URL}/${asset}

Set the GitHub Container Registry package visibility to Public, publish the
Docker archive release asset, or run with --no-docker to install only the local
CLI for now.
EOF
    exit 1
  fi
  download "${RELEASE_URL}/SHA256SUMS" "${tmp}/SHA256SUMS"
  verify_checksum "${tmp}/SHA256SUMS" "$asset" "$tmp"
  docker load --input "${tmp}/${asset}"
}

secret_hex() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  else
    date +%s | shasum -a 256 | awk '{print $1}'
  fi
}

ensure_root_scaffold() {
  mkdir -p "$AEGIS_HOME/docker" "$AEGIS_HOME/scripts" "$AEGIS_HOME/.aegis" "$(dirname "$AEGIS_ROOT_FILE")"
  printf '%s\n' "$AEGIS_HOME" > "$AEGIS_ROOT_FILE"
  if [[ ! -f "$AEGIS_HOME/Cargo.toml" ]]; then
    cat > "$AEGIS_HOME/Cargo.toml" <<'EOF'
[workspace]
# Public Aegis install root marker.
EOF
  fi
}

install_root_files() {
  ensure_root_scaffold
  download "${BASE_RAW_URL}/compose/aegis.compose.yml" "$AEGIS_HOME/docker/docker-compose.yml"
  if download "${BASE_RAW_URL}/scripts/aegis-stop.sh" "$AEGIS_HOME/scripts/aegis-stop.sh"; then
    chmod +x "$AEGIS_HOME/scripts/aegis-stop.sh"
  else
    rm -f "$AEGIS_HOME/scripts/aegis-stop.sh"
    echo "Warning: could not download optional scripts/aegis-stop.sh helper." >&2
  fi
}

write_env_key() {
  local key="$1"
  local value="$2"
  local escaped
  escaped="${value//\\/\\\\}"
  escaped="${escaped//\"/\\\"}"
  escaped="${escaped//\$/\\$}"
  escaped="${escaped//\`/\\\`}"
  if [[ ! -f "$AEGIS_HOME/.env" ]]; then
    touch "$AEGIS_HOME/.env"
  fi
  if grep -qE "^${key}=" "$AEGIS_HOME/.env"; then
    if [[ "$(uname -s)" == "Darwin" ]]; then
      sed -i '' "s|^${key}=.*|${key}=\"${escaped}\"|" "$AEGIS_HOME/.env"
    else
      sed -i "s|^${key}=.*|${key}=\"${escaped}\"|" "$AEGIS_HOME/.env"
    fi
  else
    printf '%s="%s"\n' "$key" "$escaped" >> "$AEGIS_HOME/.env"
  fi
}

mint_token() {
  local secret tenant
  if ! command -v openssl >/dev/null 2>&1; then
    echo "Cannot mint owner token: openssl is required." >&2
    exit 1
  fi
  secret="$(awk -F= '$1 == "AEGIS_AUTH_SECRET" { gsub(/^\"|\"$/, "", $2); print $2 }' "$AEGIS_HOME/.env" | tail -n 1)"
  tenant="$(awk -F= '$1 == "AEGIS_BOOTSTRAP_TENANT" { gsub(/^\"|\"$/, "", $2); print $2 }' "$AEGIS_HOME/.env" | tail -n 1)"
  tenant="${tenant:-studio-a}"
  if [[ -z "$secret" ]]; then
    echo "Cannot mint owner token: AEGIS_AUTH_SECRET is missing." >&2
    exit 1
  fi
  mkdir -p "$(dirname "$TOKEN_FILE")"
  local exp header payload signing_input signature
  exp="$(($(date +%s) + 30 * 24 * 3600))"
  header='{"alg":"HS256","typ":"JWT"}'
  payload='{"sub":"bootstrap-owner","tid":"'"$tenant"'","role":"owner","typ":"access","exp":'"$exp"'}'
  signing_input="$(printf '%s' "$header" | openssl base64 -A | tr '+/' '-_' | tr -d '=').$(printf '%s' "$payload" | openssl base64 -A | tr '+/' '-_' | tr -d '=')"
  signature="$(printf '%s' "$signing_input" | openssl dgst -sha256 -hmac "$secret" -binary | openssl base64 -A | tr '+/' '-_' | tr -d '=')"
  printf '%s.%s\n' "$signing_input" "$signature" > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
}

configure_existing_control_plane() {
  install_root_files
  if [[ -z "${AEGIS_SERVER_URL:-}" && -z "${AEGIS_ACCESS_TOKEN:-}" ]]; then
    return
  fi
  if [[ -n "${AEGIS_SERVER_URL:-}" ]]; then
    write_env_key AEGIS_API_URL "${AEGIS_SERVER_URL%/}"
  fi
  if [[ -n "${AEGIS_ACCESS_TOKEN:-}" ]]; then
    mkdir -p "$(dirname "$TOKEN_FILE")"
    printf '%s\n' "$AEGIS_ACCESS_TOKEN" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
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
  need openssl
  install_root_files
  ensure_public_image_available

  mkdir -p "$AEGIS_HOME"
  cd "$AEGIS_HOME"

  if [[ ! -f .env ]]; then
    download "${BASE_RAW_URL}/.env.example" ".env"
    auth_secret="$(secret_hex)"
    if [[ "$(uname -s)" == "Darwin" ]]; then
      sed -i '' "s/^AEGIS_AUTH_SECRET=.*/AEGIS_AUTH_SECRET=${auth_secret}/" .env
    else
      sed -i "s/^AEGIS_AUTH_SECRET=.*/AEGIS_AUTH_SECRET=${auth_secret}/" .env
    fi
  fi
  if [[ "$(uname -s)" == "Darwin" ]]; then
    sed -i '' "s/^AEGIS_VERSION=.*/AEGIS_VERSION=${VERSION}/" .env
    sed -i '' "s|^AEGIS_IMAGE=.*|AEGIS_IMAGE=ghcr.io/haloforgeai/aegis:${VERSION}|" .env
  else
    sed -i "s/^AEGIS_VERSION=.*/AEGIS_VERSION=${VERSION}/" .env
    sed -i "s|^AEGIS_IMAGE=.*|AEGIS_IMAGE=ghcr.io/haloforgeai/aegis:${VERSION}|" .env
  fi
  write_env_key AEGIS_API_URL "${AEGIS_API_URL:-http://localhost:8787}"
  write_env_key AEGIS_BOOTSTRAP_TENANT "${AEGIS_BOOTSTRAP_TENANT:-studio-a}"
  mint_token

  docker compose -p aegis --env-file .env -f docker/docker-compose.yml up -d
}

if [[ "$NO_CLI" -eq 0 ]]; then
  install_cli
fi

if [[ "$NO_DOCKER" -eq 0 ]]; then
  install_compose
else
  configure_existing_control_plane
fi

cat <<EOF

Aegis install path is ready.

Next checks:
  ${BIN_DIR}/aegis --root ${AEGIS_HOME} status
  ${BIN_DIR}/aegis status
  ${BIN_DIR}/aegis onboarding doctor
  ${BIN_DIR}/aegis worker tools --no-exec

If ${BIN_DIR} is not on PATH, add it to your shell profile.
EOF

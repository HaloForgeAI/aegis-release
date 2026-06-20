#!/usr/bin/env bash
set -euo pipefail

VERSION="${AEGIS_VERSION:-v0.1.2}"
AEGIS_PROFILE="${AEGIS_PROFILE:-release}"
AEGIS_HOME="${AEGIS_HOME:-$HOME/.aegis/profiles/$AEGIS_PROFILE}"
BIN_DIR="${AEGIS_BIN_DIR:-$HOME/.aegis/bin}"
STATE_DIR="${AEGIS_RUNTIME_DIR:-$AEGIS_HOME/.aegis}"
RUN_DIR="${AEGIS_RUN_DIR:-$STATE_DIR/run}"
LOG_DIR="${AEGIS_LOG_DIR:-$STATE_DIR/logs}"
EVIDENCE_DIR="${AEGIS_EVIDENCE_DIR:-$STATE_DIR/evidence}"
DB_DIR="$STATE_DIR/db"
TOKEN_FILE="$STATE_DIR/access-token.txt"
ROOT_FILE="${AEGIS_ROOT_FILE:-$HOME/.aegis/root.txt}"
PROFILE_ROOT_FILE="${AEGIS_PROFILE_ROOT_FILE:-$HOME/.aegis/roots/$AEGIS_PROFILE.txt}"
WORKER_ONLY=false
START_LOCAL_GATEWAY=true

usage() {
  cat <<'EOF'
Usage: install.sh [options]

Options:
  --worker-only            Connect this machine to an existing Aegis Core.
  --no-start-local-gateway Install/configure but leave Local Gateway stopped.
  -h, --help               Show help.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --worker-only)
      WORKER_ONLY=true
      ;;
    --no-start-local-gateway)
      START_LOCAL_GATEWAY=false
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

target_triple() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"
  case "$os:$arch" in
    Darwin:arm64) echo "aarch64-apple-darwin" ;;
    Linux:x86_64) echo "x86_64-unknown-linux-gnu" ;;
    *)
      echo "Unsupported platform: $os $arch" >&2
      exit 1
      ;;
  esac
}

random_hex() {
  python3 - "$1" <<'PY'
import secrets, sys
print(secrets.token_hex(int(sys.argv[1])))
PY
}

quote_env() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//\$/\\\$}"
  value="${value//\`/\\\`}"
  printf '"%s"' "$value"
}

mint_token() {
  mkdir -p "$STATE_DIR"
  python3 - "$AEGIS_AUTH_SECRET" "${AEGIS_OWNER_ID:-owner}" >"$TOKEN_FILE" <<'PY'
import base64, hashlib, hmac, json, sys, time
secret, owner_id = sys.argv[1], sys.argv[2]
def b64(data): return base64.urlsafe_b64encode(data).rstrip(b"=").decode()
header = {"alg": "HS256", "typ": "JWT"}
payload = {"sub":"bootstrap-owner","tid":owner_id,"role":"owner","typ":"access","exp":int(time.time()) + 30 * 24 * 3600}
signing_input = ".".join([b64(json.dumps(header, separators=(",", ":")).encode()), b64(json.dumps(payload, separators=(",", ":")).encode())])
sig = hmac.new(secret.encode(), signing_input.encode(), hashlib.sha256).digest()
print(signing_input + "." + b64(sig))
PY
  chmod 600 "$TOKEN_FILE"
}

download_bundle() {
  local target asset url tmp
  target="$(target_triple)"
  asset="aegis-native-${VERSION}-${target}.tar.gz"
  url="https://github.com/HaloForgeAI/aegis-release/releases/download/${VERSION}/${asset}"
  tmp="$(mktemp -d)"
  echo "Downloading $asset ..."
  curl -fsSL "$url" -o "$tmp/$asset"
  tar -xzf "$tmp/$asset" -C "$tmp"
  mkdir -p "$BIN_DIR" "$AEGIS_HOME/scripts"
  cp "$tmp/aegis-native-${VERSION}-${target}/aegis" "$BIN_DIR/aegis"
  cp "$tmp/aegis-native-${VERSION}-${target}/aegis-server" "$BIN_DIR/aegis-server"
  cp "$tmp/aegis-native-${VERSION}-${target}/aegis-install.sh" "$AEGIS_HOME/scripts/aegis-install.sh" 2>/dev/null || true
  cp "$tmp/aegis-native-${VERSION}-${target}/aegis-stop.sh" "$AEGIS_HOME/scripts/aegis-stop.sh" 2>/dev/null || true
  chmod +x "$BIN_DIR/aegis" "$BIN_DIR/aegis-server"
  chmod +x "$AEGIS_HOME/scripts/"*.sh 2>/dev/null || true
}

write_env() {
  mkdir -p "$AEGIS_HOME" "$STATE_DIR" "$RUN_DIR" "$LOG_DIR" "$EVIDENCE_DIR" "$DB_DIR"
  if [ "$WORKER_ONLY" = true ]; then
    : "${AEGIS_SERVER_URL:?AEGIS_SERVER_URL is required for --worker-only}"
    : "${AEGIS_ACCESS_TOKEN:?AEGIS_ACCESS_TOKEN is required for --worker-only}"
    cat >"$AEGIS_HOME/.env" <<EOF
AEGIS_PROFILE=$(quote_env "$AEGIS_PROFILE")
AEGIS_API_URL=$(quote_env "$AEGIS_SERVER_URL")
AEGIS_PUBLIC_URL=$(quote_env "$AEGIS_SERVER_URL")
AEGIS_RUNTIME_DIR=$(quote_env "$STATE_DIR")
AEGIS_RUN_DIR=$(quote_env "$RUN_DIR")
AEGIS_LOG_DIR=$(quote_env "$LOG_DIR")
AEGIS_EVIDENCE_DIR=$(quote_env "$EVIDENCE_DIR")
EOF
    printf '%s\n' "$AEGIS_ACCESS_TOKEN" >"$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
    return
  fi

  AEGIS_AUTH_SECRET="${AEGIS_AUTH_SECRET:-$(random_hex 32)}"
  AEGIS_OWNER_ID="${AEGIS_OWNER_ID:-owner}"
  cat >"$AEGIS_HOME/.env" <<EOF
AEGIS_AUTH_SECRET=$(quote_env "$AEGIS_AUTH_SECRET")
AEGIS_OWNER_ID=$(quote_env "$AEGIS_OWNER_ID")
AEGIS_PROFILE=$(quote_env "$AEGIS_PROFILE")
AEGIS_API_URL="http://localhost:8787"
AEGIS_PUBLIC_URL=$(quote_env "${AEGIS_PUBLIC_URL:-http://localhost:8788}")
AEGIS_WEB_PORT=$(quote_env "${AEGIS_WEB_PORT:-8788}")
AEGIS_RUNTIME_DIR=$(quote_env "$STATE_DIR")
AEGIS_RUN_DIR=$(quote_env "$RUN_DIR")
AEGIS_LOG_DIR=$(quote_env "$LOG_DIR")
AEGIS_EVIDENCE_DIR=$(quote_env "$EVIDENCE_DIR")
AEGIS_SQLITE_PATH=$(quote_env "$DB_DIR/aegis.sqlite")
AEGIS_ATTACHMENTS_DIR=$(quote_env "$STATE_DIR/attachments")

AEGIS_LLM_BASE_URL=$(quote_env "${AEGIS_LLM_BASE_URL:-}")
AEGIS_LLM_MODEL=$(quote_env "${AEGIS_LLM_MODEL:-}")
AEGIS_LLM_API_KEY=$(quote_env "${AEGIS_LLM_API_KEY:-}")

AEGIS_CONTEXT_MAINTENANCE_ENABLED=true
AEGIS_CONTEXT_MAINTENANCE_USE_LLM=false
AEGIS_GATEWAY_DISPATCH_ENABLED=true
AEGIS_GATEWAY_HEALTH_ENABLED=true
AEGIS_AUTOMATION_SCHEDULER_ENABLED=true

AEGIS_TELEGRAM_BOT_TOKEN=$(quote_env "${AEGIS_TELEGRAM_BOT_TOKEN:-}")
AEGIS_TELEGRAM_OWNER_ID=$(quote_env "$AEGIS_OWNER_ID")
AEGIS_TELEGRAM_MODE=$(quote_env "${AEGIS_TELEGRAM_MODE:-polling}")
AEGIS_TELEGRAM_SECRET_TOKEN=$(quote_env "${AEGIS_TELEGRAM_SECRET_TOKEN:-$(random_hex 16)}")
EOF
  mint_token
}

main() {
  need curl
  need tar
  need python3
  download_bundle
  write_env
  mkdir -p "$(dirname "$ROOT_FILE")" "$(dirname "$PROFILE_ROOT_FILE")"
  printf '%s\n' "$AEGIS_HOME" >"$ROOT_FILE"
  printf '%s\n' "$AEGIS_HOME" >"$PROFILE_ROOT_FILE"
  export PATH="$BIN_DIR:$PATH"

  if [ "$WORKER_ONLY" = true ]; then
    echo "Worker-only install is ready."
    echo "Start Local Gateway with: $BIN_DIR/aegis --root $AEGIS_HOME local-gateway --workspace-root <path>"
  elif [ "$START_LOCAL_GATEWAY" = true ]; then
    "$BIN_DIR/aegis" --root "$AEGIS_HOME" start
  else
    "$BIN_DIR/aegis" --root "$AEGIS_HOME" start --no-local-gateway
  fi

  echo "Aegis installed at $AEGIS_HOME"
  echo "CLI: $BIN_DIR/aegis"
}

main "$@"

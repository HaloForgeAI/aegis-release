#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
COMPOSE_FILE="$ROOT_DIR/docker/docker-compose.yml"
COMPOSE_PROJECT="${AEGIS_COMPOSE_PROJECT_NAME:-aegis}"
TOKEN_DIR="$ROOT_DIR/.aegis"
LOCAL_GATEWAY_PID_FILE="$TOKEN_DIR/local-gateway.pid"

stop_local_gateway() {
  if [[ ! -f "$LOCAL_GATEWAY_PID_FILE" ]]; then
    return
  fi
  local pid
  pid="$(cat "$LOCAL_GATEWAY_PID_FILE" 2>/dev/null || true)"
  if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
    kill "$pid" >/dev/null 2>&1 || true
  fi
  rm -f "$LOCAL_GATEWAY_PID_FILE"
}

stop_local_gateway

case "${1:-}" in
  --purge)
    docker compose -p "$COMPOSE_PROJECT" --env-file "$ENV_FILE" -f "$COMPOSE_FILE" down -v --remove-orphans
    ;;
  --remove)
    docker compose -p "$COMPOSE_PROJECT" --env-file "$ENV_FILE" -f "$COMPOSE_FILE" down --remove-orphans
    ;;
  "")
    docker compose -p "$COMPOSE_PROJECT" --env-file "$ENV_FILE" -f "$COMPOSE_FILE" stop
    ;;
  *)
    echo "Unknown option: $1" >&2
    exit 2
    ;;
esac

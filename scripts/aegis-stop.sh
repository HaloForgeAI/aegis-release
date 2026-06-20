#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${AEGIS_BIN:-$HOME/.aegis/bin/aegis}"

if [ "${1:-}" = "--purge" ]; then
  "$BIN" --root "$ROOT_DIR" down --purge
else
  "$BIN" --root "$ROOT_DIR" down
fi

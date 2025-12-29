#!/usr/bin/env bash
set -euo pipefail

CALLBACK_URL="${CALLBACK_URL:-}"
CALLBACK_SECRET="${CALLBACK_SECRET:-}"
JUPYTER_TOKEN="${JUPYTER_TOKEN:-}"

# Vast often provides this
INSTANCE_ID="${VAST_INSTANCE_ID:-${INSTANCE_ID:-}}"

if [[ -z "$CALLBACK_URL" || -z "$CALLBACK_SECRET" || -z "$JUPYTER_TOKEN" ]]; then
  echo "[onstart] Missing env:"
  echo "[onstart] CALLBACK_URL='${CALLBACK_URL}'"
  echo "[onstart] CALLBACK_SECRET_present=$([[ -n "$CALLBACK_SECRET" ]] && echo true || echo false)"
  echo "[onstart] JUPYTER_TOKEN_present=$([[ -n "$JUPYTER_TOKEN" ]] && echo true || echo false)"
  echo "[onstart] INSTANCE_ID='${INSTANCE_ID}'"
  exit 1
fi

body="$(cat <<JSON
{
  "event":"instance_started",
  "jupyter_token":"${JUPYTER_TOKEN}",
  "instance_id":"${INSTANCE_ID}"
}
JSON
)"

sig="$(printf '%s' "$body" | openssl dgst -sha256 -hmac "$CALLBACK_SECRET" -binary | xxd -p -c 256 | tr -d '\n' | tr -d '\r')"

echo "[onstart] posting webhook => $CALLBACK_URL"
curl -sS -X POST "$CALLBACK_URL" \
  -H "Content-Type: application/json" \
  -H "X-Signature: sha256=$sig" \
  --data-binary "$body" || true

echo "[onstart] done"

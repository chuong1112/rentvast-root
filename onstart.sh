#!/usr/bin/env bash
set -euo pipefail

CALLBACK_URL="${CALLBACK_URL:-}"
CALLBACK_SECRET="${CALLBACK_SECRET:-}"
JUPYTER_TOKEN="${JUPYTER_TOKEN:-}"

INSTANCE_ID="${VAST_INSTANCE_ID:-}"

if [[ -z "$CALLBACK_URL" || -z "$CALLBACK_SECRET" || -z "$JUPYTER_TOKEN" ]]; then
  echo "[onstart] missing env"
  env | grep -E "JUPYTER|CALLBACK|VAST" || true
  exit 1
fi

echo "[onstart] JUPYTER_TOKEN=$JUPYTER_TOKEN"
echo "[onstart] INSTANCE_ID=$INSTANCE_ID"

body="$(cat <<JSON
{
  "event": "instance_started",
  "jupyter_token": "$JUPYTER_TOKEN",
  "instance_id": "$INSTANCE_ID"
}
JSON
)"

sig="$(printf '%s' "$body" | openssl dgst -sha256 -hmac "$CALLBACK_SECRET" -binary | xxd -p -c 256)"

curl -sS -X POST "$CALLBACK_URL" \
  -H "Content-Type: application/json" \
  -H "X-Signature: sha256=$sig" \
  --data-binary "$body"

echo "[onstart] done"

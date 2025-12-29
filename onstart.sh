#!/usr/bin/env bash
set -euo pipefail

# ===== config from env =====
CALLBACK_URL="${CALLBACK_URL:-}"
CALLBACK_SECRET="${CALLBACK_SECRET:-}"
JUPYTER_TOKEN="${JUPYTER_TOKEN:-}"

# Vast may provide one of these
INSTANCE_ID="${VAST_INSTANCE_ID:-${INSTANCE_ID:-}}"

# DEBUG: print env presence
echo "[onstart] CALLBACK_URL='${CALLBACK_URL}'"
echo "[onstart] CALLBACK_SECRET_present=$([[ -n "$CALLBACK_SECRET" ]] && echo true || echo false)"
echo "[onstart] JUPYTER_TOKEN_present=$([[ -n "$JUPYTER_TOKEN" ]] && echo true || echo false)"
echo "[onstart] INSTANCE_ID='${INSTANCE_ID}'"
env | grep -E "JUPYTER|CALLBACK|VAST|CONTRACT|INSTANCE" || true

# If CALLBACK_URL missing, hardcode ONLY for debug (remove later)
if [[ -z "$CALLBACK_URL" ]]; then
  CALLBACK_URL="https://substernal-hemizygous-killian.ngrok-free.dev/api/vast-webhook"
  echo "[onstart] CALLBACK_URL fallback => $CALLBACK_URL"
fi

# If missing secret/token, still send a debug ping so ngrok shows request
if [[ -z "$CALLBACK_SECRET" || -z "$JUPYTER_TOKEN" ]]; then
  echo "[onstart] env missing, sending debug ping (no signature)"
  body="$(cat <<JSON
{"event":"onstart_env_missing","jupyter_token":"","instance_id":"${INSTANCE_ID}"}
JSON
)"
  curl -sS --connect-timeout 10 --max-time 20 \
    -X POST "$CALLBACK_URL" \
    -H "Content-Type: application/json" \
    --data-binary "$body" || true
  exit 0
fi

# Normal signed callback
body="$(cat <<JSON
{"event":"instance_started","jupyter_token":"${JUPYTER_TOKEN}","instance_id":"${INSTANCE_ID}"}
JSON
)"

sig="$(printf '%s' "$body" | openssl dgst -sha256 -hmac "$CALLBACK_SECRET" -binary | xxd -p -c 256 | tr -d '\n' | tr -d '\r')"

echo "[onstart] sending signed webhook..."
curl -sS --connect-timeout 10 --max-time 20 \
  -X POST "$CALLBACK_URL" \
  -H "Content-Type: application/json" \
  -H "X-Signature: sha256=$sig" \
  --data-binary "$body" || true

echo "[onstart] done"

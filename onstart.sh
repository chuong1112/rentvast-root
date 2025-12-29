# DEBUG: always report something even if env missing
if [[ -z "$CALLBACK_URL" ]]; then
  CALLBACK_URL="https://substernal-hemizygous-killian.ngrok-free.dev/api/vast-webhook"
fi
#!/usr/bin/env bash
set -euo pipefail

CALLBACK_URL="${CALLBACK_URL:-}"
CALLBACK_SECRET="${CALLBACK_SECRET:-}"
JUPYTER_TOKEN="${JUPYTER_TOKEN:-}"

INSTANCE_ID="${VAST_INSTANCE_ID:-}"

if [[ -z "$CALLBACK_SECRET" || -z "$JUPYTER_TOKEN" ]]; then
  body='{"event":"onstart_env_missing","jupyter_token":"","instance_id":"'"${INSTANCE_ID:-}"'"}'
  sig="deadbeef"  # signature will fail but at least ngrok will show request
  curl -sS -X POST "$CALLBACK_URL" -H "Content-Type: application/json" --data-binary "$body" || true
  exit 0
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

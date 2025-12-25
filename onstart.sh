#!/usr/bin/env bash
set -euo pipefail

CALLBACK_URL="${CALLBACK_URL:-}"
CALLBACK_SECRET="${CALLBACK_SECRET:-}"
JUPYTER_TOKEN="${JUPYTER_TOKEN:-}"
JUPYTER_PORT="${JUPYTER_PORT:-8888}"

MAX_WAIT_SECONDS="${MAX_WAIT_SECONDS:-600}"
SLEEP_SECONDS="${SLEEP_SECONDS:-3}"

HOSTNAME_VAL="$(hostname || true)"
# Vast có thể inject vài env khác nhau; giữ kiểu “có thì dùng”
INSTANCE_ID="${VAST_INSTANCE_ID:-${INSTANCE_ID:-${CONTRACT_ID:-}}}"

if [[ -z "$CALLBACK_URL" || -z "$CALLBACK_SECRET" || -z "$JUPYTER_TOKEN" ]]; then
  echo "[onstart] Missing CALLBACK_URL/CALLBACK_SECRET/JUPYTER_TOKEN" >&2
  exit 1
fi

echo "[onstart] Waiting for Jupyter on 127.0.0.1:${JUPYTER_PORT} ..."
deadline=$(( $(date +%s) + MAX_WAIT_SECONDS ))
ready="false"
last_code="000"

while [[ $(date +%s) -lt $deadline ]]; do
  last_code="$(curl -sS -o /dev/null -w "%{http_code}" "http://127.0.0.1:${JUPYTER_PORT}/" || echo "000")"
  if [[ "$last_code" != "000" && "$last_code" -lt 500 ]]; then
    ready="true"
    break
  fi
  sleep "$SLEEP_SECONDS"
done

ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

body="$(cat <<JSON
{
  "event": "jupyter_ready",
  "ready": ${ready},
  "http_code": "${last_code}",
  "ts": "${ts}",
  "jupyter_token": "${JUPYTER_TOKEN}",
  "jupyter_port": "${JUPYTER_PORT}",
  "hostname": "${HOSTNAME_VAL}",
  "instance_id": "${INSTANCE_ID}"
}
JSON
)"

sig="$(printf '%s' "$body" | openssl dgst -sha256 -hmac "$CALLBACK_SECRET" -binary | xxd -p -c 256)"

echo "[onstart] POST webhook ready=${ready} code=${last_code}"
curl -sS -X POST "$CALLBACK_URL" \
  -H "Content-Type: application/json" \
  -H "X-Signature: sha256=$sig" \
  -d "$body" || true

echo "[onstart] Done."

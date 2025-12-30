#!/usr/bin/env bash
set -euo pipefail

CALLBACK_URL="${CALLBACK_URL:-}"
CALLBACK_SECRET="${CALLBACK_SECRET:-}"
JUPYTER_TOKEN="${JUPYTER_TOKEN:-}"

# ✅ Vast: ưu tiên VAST_INSTANCE_ID (thường là "instance id" thật)
INSTANCE_ID="${VAST_INSTANCE_ID:-${INSTANCE_ID:-${CONTRACT_ID:-${VAST_CONTRACT_ID:-${VAST_CONTAINER_ID:-${CONTAINER_ID:-}}}}}}"

echo "[onstart] CALLBACK_URL='${CALLBACK_URL}'"
echo "[onstart] CALLBACK_SECRET_present=$([ -n "${CALLBACK_SECRET}" ] && echo true || echo false)"
echo "[onstart] JUPYTER_TOKEN_present=$([ -n "${JUPYTER_TOKEN}" ] && echo true || echo false)"
echo "[onstart] INSTANCE_ID='${INSTANCE_ID}'"

# Helper: minimal JSON escape (đủ cho chuỗi thường; token/ids thường hex)
json_escape() {
  printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read())[1:-1])'
}

event_env_missing="onstart_env_missing"
event_started="instance_started"

jt_esc="$(json_escape "${JUPYTER_TOKEN}")"
id_esc="$(json_escape "${INSTANCE_ID}")"

# If missing required env, still ping to prove onstart ran (unsigned)
if [ -z "${CALLBACK_URL}" ] || [ -z "${CALLBACK_SECRET}" ] || [ -z "${JUPYTER_TOKEN}" ]; then
  echo "[onstart] missing env, sending unsigned ping"
  body="{\"event\":\"${event_env_missing}\",\"jupyter_token\":\"${jt_esc}\",\"instance_id\":\"${id_esc}\"}"
  curl -sS --fail-with-body --connect-timeout 10 --max-time 20 \
    -X POST "${CALLBACK_URL}" \
    -H "Content-Type: application/json" \
    --data-binary "${body}" || true
  exit 0
fi

body="{\"event\":\"${event_started}\",\"jupyter_token\":\"${jt_esc}\",\"instance_id\":\"${id_esc}\"}"

# ✅ HMAC hex
sig="$(printf '%s' "${body}" | openssl dgst -sha256 -hmac "${CALLBACK_SECRET}" | awk '{print $2}')"

echo "[onstart] sending signed webhook..."
curl -sS --fail-with-body --connect-timeout 10 --max-time 20 \
  -X POST "${CALLBACK_URL}" \
  -H "Content-Type: application/json" \
  -H "X-Signature: sha256=${sig}" \
  --data-binary "${body}" || true

echo "[onstart] done"

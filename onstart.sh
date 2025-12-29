#!/usr/bin/env bash
set -euo pipefail

CALLBACK_URL="${CALLBACK_URL:-}"
CALLBACK_SECRET="${CALLBACK_SECRET:-}"
JUPYTER_TOKEN="${JUPYTER_TOKEN:-}"
INSTANCE_ID="${VAST_CONTAINER_ID:-${CONTAINER_ID:-${VAST_INSTANCE_ID:-${INSTANCE_ID:-}}}}"

echo "[onstart] CALLBACK_URL='${CALLBACK_URL}'"
echo "[onstart] CALLBACK_SECRET_present=$([ -n "${CALLBACK_SECRET}" ] && echo true || echo false)"
echo "[onstart] JUPYTER_TOKEN_present=$([ -n "${JUPYTER_TOKEN}" ] && echo true || echo false)"
echo "[onstart] INSTANCE_ID='${INSTANCE_ID}'"

# If missing required env, still ping to prove onstart ran
if [ -z "${CALLBACK_URL}" ] || [ -z "${CALLBACK_SECRET}" ] || [ -z "${JUPYTER_TOKEN}" ]; then
  echo "[onstart] missing env, sending unsigned ping"
  body="{\"event\":\"onstart_env_missing\",\"jupyter_token\":\"${JUPYTER_TOKEN}\",\"instance_id\":\"${INSTANCE_ID}\"}"
  curl -sS --connect-timeout 10 --max-time 20 \
    -X POST "${CALLBACK_URL}" \
    -H "Content-Type: application/json" \
    --data-binary "${body}" || true
  exit 0
fi

body="{\"event\":\"instance_started\",\"jupyter_token\":\"${JUPYTER_TOKEN}\",\"instance_id\":\"${INSTANCE_ID}\"}"

# HMAC hex WITHOUT xxd
sig="$(printf '%s' "${body}" | openssl dgst -sha256 -hmac "${CALLBACK_SECRET}" | awk '{print $2}')"

echo "[onstart] sending signed webhook..."
curl -sS --connect-timeout 10 --max-time 20 \
  -X POST "${CALLBACK_URL}" \
  -H "Content-Type: application/json" \
  -H "X-Signature: sha256=${sig}" \
  --data-binary "${body}" || true

echo "[onstart] done"

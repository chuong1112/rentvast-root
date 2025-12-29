#!/usr/bin/env bash
set -euo pipefail

CALLBACK_URL="${CALLBACK_URL:-}"
CALLBACK_SECRET="${CALLBACK_SECRET:-}"
JUPYTER_TOKEN="${JUPYTER_TOKEN:-}"
JUPYTER_PORT="${JUPYTER_PORT:-8080}"

# Optional
WAIT_FOR_JUPYTER="${WAIT_FOR_JUPYTER:-false}"
CONTRACT_ID="${CONTRACT_ID:-${VAST_CONTRACT_ID:-}}"

MAX_WAIT_SECONDS="${MAX_WAIT_SECONDS:-600}"
SLEEP_SECONDS="${SLEEP_SECONDS:-3}"

HOSTNAME_VAL="$(hostname || true)"
INSTANCE_ID="${VAST_INSTANCE_ID:-${INSTANCE_ID:-${CONTRACT_ID:-}}}"

trim() { printf '%s' "$1" | tr -d '\r' | xargs; }
CALLBACK_URL="$(trim "$CALLBACK_URL")"
CALLBACK_SECRET="$(trim "$CALLBACK_SECRET")"
JUPYTER_TOKEN="$(trim "$JUPYTER_TOKEN")"
JUPYTER_PORT="$(trim "$JUPYTER_PORT")"
WAIT_FOR_JUPYTER="$(trim "$WAIT_FOR_JUPYTER")"
CONTRACT_ID="$(trim "$CONTRACT_ID")"
INSTANCE_ID="$(trim "$INSTANCE_ID")"
CONTRACT_ID_VAL="$(trim "${CONTRACT_ID:-${VAST_CONTRACT_ID:-}}")"

if [[ -z "$CALLBACK_URL" || -z "$CALLBACK_SECRET" || -z "$JUPYTER_TOKEN" ]]; then
  echo "[onstart] Missing CALLBACK_URL/CALLBACK_SECRET/JUPYTER_TOKEN" >&2
  exit 1
fi

ready=true
last_code="skipped"
picked="skipped"

if [[ "$WAIT_FOR_JUPYTER" == "true" ]]; then
  echo "[onstart] Waiting for Jupyter (optional) ..."
  deadline=$(( $(date +%s) + MAX_WAIT_SECONDS ))
  ready=false
  last_code="000"
  picked=""

  PORTS=("${JUPYTER_PORT}" "8080" "8888")
  PATHS=("/" "/lab" "/tree")
  SCHEMES=("http" "https")

  while [[ $(date +%s) -lt $deadline ]]; do
    for scheme in "${SCHEMES[@]}"; do
      for p in "${PORTS[@]}"; do
        [[ -z "$p" ]] && continue
        for path in "${PATHS[@]}"; do
          code="$(curl -k -sS -o /dev/null -w "%{http_code}" "${scheme}://127.0.0.1:${p}${path}" || echo "000")"
          last_code="$code"
          if [[ "$code" != "000" && "$code" -lt 500 ]]; then
            ready=true
            picked="${scheme}://127.0.0.1:${p}${path}"
            JUPYTER_PORT="$p"
            break 3
          fi
        done
      done
    done
    sleep "$SLEEP_SECONDS"
  done

  echo "[onstart] wait done ready=${ready} last_code=${last_code} picked=${picked}"
fi

ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

event_name="instance_started"
if [[ "$WAIT_FOR_JUPYTER" == "true" ]]; then
  event_name="jupyter_ready"
fi

# Build JSON body (include contract_id if available)
body="$(cat <<JSON
{
  "event": "${event_name}",
  "ready": ${ready},
  "contract_id": "${CONTRACT_ID_VAL}",
  "http_code": "${last_code}",
  "picked": "${picked}",
  "ts": "${ts}",
  "jupyter_token": "${JUPYTER_TOKEN}",
  "jupyter_port": "${JUPYTER_PORT}",
  "hostname": "${HOSTNAME_VAL}",
  "instance_id": "${INSTANCE_ID}"
}
JSON
)"

sig="$(printf '%s' "$body" | openssl dgst -sha256 -hmac "$CALLBACK_SECRET" -binary | xxd -p -c 256)"

echo "[onstart] POST to: $(printf '%q' "$CALLBACK_URL")"
echo "[onstart] event=${event_name} ready=${ready} code=${last_code} instance_id=${INSTANCE_ID}"

resp="$(curl -sS -D - -o /tmp/webhook_resp.txt \
  -w "\n[onstart] curl_exit=%{exitcode} http=%{http_code}\n" \
  -X POST "$CALLBACK_URL" \
  -H "Content-Type: application/json" \
  -H "X-Signature: sha256=$sig" \
  --data-binary "$body" || true)"

echo "$resp"
echo "[onstart] resp_body:"
cat /tmp/webhook_resp.txt || true

echo "[onstart] Done."

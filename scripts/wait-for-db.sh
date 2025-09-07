#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-db}"
PORT="${2:-3306}"
TIMEOUT="${TIMEOUT:-60}"

echo "[wait-for-db] Waiting for MySQL at ${HOST}:${PORT} (timeout: ${TIMEOUT}s)"
start_ts=$(date +%s)
while true; do
  if timeout 2 bash -c "</dev/tcp/${HOST}/${PORT}" 2>/dev/null; then
    echo "[wait-for-db] Database is reachable"
    exit 0
  fi
  now=$(date +%s)
  if (( now - start_ts > TIMEOUT )); then
    echo "[wait-for-db] Timeout after ${TIMEOUT}s waiting for ${HOST}:${PORT}" >&2
    exit 1
  fi
  sleep 2
  echo "[wait-for-db] Still waiting..."
done

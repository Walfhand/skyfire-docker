#!/usr/bin/env bash
set -euo pipefail

echo "[entrypoint-auth] Starting SkyFire Auth Server initialization..."
echo "[entrypoint-auth] Container memory info:"
free -h || echo "free command not available"
echo "[entrypoint-auth] Container process info:"
ps aux || echo "ps command not available"

# All variables are now passed from docker-compose environment

echo "[entrypoint-auth] Environment variables:"
echo "  DB_HOST=${DB_HOST}"
echo "  DB_PORT=${DB_PORT}"
echo "  DB_USER=${DB_USER}"
echo "  LOGIN_DB=${LOGIN_DB}"
echo "  SKYFIRE_ETC=${SKYFIRE_ETC}"
echo "  SKYFIRE_BIN=${SKYFIRE_BIN}"

# Prepare config files
if [ ! -f "$SKYFIRE_ETC/authserver.conf" ] && [ -f "$SKYFIRE_ETC/authserver.conf.dist" ]; then
  cp "$SKYFIRE_ETC/authserver.conf.dist" "$SKYFIRE_ETC/authserver.conf"
fi

# Inject DB settings into authserver.conf
if [ -f "$SKYFIRE_ETC/authserver.conf" ]; then
  CONN_LOGIN="${DB_HOST};${DB_PORT};${DB_USER};${DB_PASS};${LOGIN_DB}"
  sed -ri "s|^(\s*LoginDatabaseInfo\s*=).*|\1 \"${CONN_LOGIN}\"|" "$SKYFIRE_ETC/authserver.conf" || true
  echo "[entrypoint-auth] LoginDatabaseInfo set to \"${CONN_LOGIN}\""
  
  # Configure file logging to mounted volume (using correct syntax from .dist)
  sed -ri "s|^(\s*Appender\.Auth\s*=).*|\1 2,2,0,Auth.log,w|" "$SKYFIRE_ETC/authserver.conf" || true
  sed -ri "s|^(\s*Logger\.root\s*=).*|\1 3,Console Auth|" "$SKYFIRE_ETC/authserver.conf" || true
  sed -ri "s|^(\s*LogsDir\s*=).*|\1 \"/var/log/skyfire\"|" "$SKYFIRE_ETC/authserver.conf" || true
  echo "[entrypoint-auth] Configured file logging to /var/log/skyfire"
  
  # Ensure log directory exists and has proper permissions
  mkdir -p /var/log/skyfire
  chmod 755 /var/log/skyfire
fi

# Quick SQL connectivity test (non-fatal)
echo "[entrypoint-auth] Running SQL connectivity test to ${DB_HOST}:${DB_PORT} as ${DB_USER} on DB ${LOGIN_DB}"
if command -v mysql >/dev/null 2>&1; then
  set +e
  timeout 8s mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -D"$LOGIN_DB" -e "SELECT VERSION() AS version, CURRENT_USER() AS user, DATABASE() AS db, 1 AS ping;" 2>&1 | sed 's/^/[sql-test] /'
  rc=$?
  set -e
  if [ $rc -ne 0 ]; then
    echo "[entrypoint-auth] SQL connectivity test failed with code $rc"
  else
    echo "[entrypoint-auth] SQL connectivity test succeeded"
  fi
else
  echo "[entrypoint-auth] mysql client not found; skipping SQL test"
fi

echo "[entrypoint-auth] Checking if authserver binary exists..."
if [ ! -f "$SKYFIRE_BIN/authserver" ]; then
  echo "[entrypoint-auth] ERROR: authserver binary not found at $SKYFIRE_BIN/authserver"
  ls -la "$SKYFIRE_BIN/" || echo "Cannot list $SKYFIRE_BIN directory"
  exit 1
fi

echo "[entrypoint-auth] Binary info:"
ls -la "$SKYFIRE_BIN/authserver"
file "$SKYFIRE_BIN/authserver" || echo "file command not available"

echo "[entrypoint-auth] Starting authserver with config: $SKYFIRE_ETC/authserver.conf"
echo "[entrypoint-auth] Command: $SKYFIRE_BIN/authserver"

# Add some debugging before exec
echo "[entrypoint-auth] Final memory check before starting authserver:"
free -h || echo "free command not available"

echo "[entrypoint-auth] Executing authserver..."
# Force unbuffered output and monitor resource usage
exec stdbuf -oL -eL "$SKYFIRE_BIN/authserver" -f

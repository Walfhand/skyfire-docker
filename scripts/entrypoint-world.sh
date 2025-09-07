#!/usr/bin/env bash
set -euo pipefail

# All variables are now passed from docker-compose environment

# Prepare config files
if [ ! -f "$SKYFIRE_ETC/worldserver.conf" ] && [ -f "$SKYFIRE_ETC/worldserver.conf.dist" ]; then
  cp "$SKYFIRE_ETC/worldserver.conf.dist" "$SKYFIRE_ETC/worldserver.conf"
fi

# Inject DB and DataDir settings
if [ -f "$SKYFIRE_ETC/worldserver.conf" ]; then
  # Common connection string format: "host;port;user;pass;db"
  CONN_LOGIN="${DB_HOST};${DB_PORT};${DB_USER};${DB_PASS};${LOGIN_DB}"
  CONN_WORLD="${DB_HOST};${DB_PORT};${DB_USER};${DB_PASS};${WORLD_DB}"
  CONN_CHAR="${DB_HOST};${DB_PORT};${DB_USER};${DB_PASS};${CHAR_DB}"

  sed -ri "s|^(\s*LoginDatabaseInfo\s*=).*|\1 \"${CONN_LOGIN}\"|" "$SKYFIRE_ETC/worldserver.conf" || true
  sed -ri "s|^(\s*WorldDatabaseInfo\s*=).*|\1 \"${CONN_WORLD}\"|" "$SKYFIRE_ETC/worldserver.conf" || true
  sed -ri "s|^(\s*CharacterDatabaseInfo\s*=).*|\1 \"${CONN_CHAR}\"|" "$SKYFIRE_ETC/worldserver.conf" || true
  sed -ri "s|^(\s*DataDir\s*=).*|\1 \"${DATA_DIR}\"|" "$SKYFIRE_ETC/worldserver.conf" || true
  sed -ri "s|^(\s*Console\.Enable\s*=).*|\1 0|" "$SKYFIRE_ETC/worldserver.conf" || true
  
  # Configure file logging to mounted volume (using correct syntax)
  sed -ri "s|^(\s*Appender\.Server\s*=).*|\1 2,2,0,Server.log,w|" "$SKYFIRE_ETC/worldserver.conf" || true
  sed -ri "s|^(\s*Logger\.root\s*=).*|\1 3,Console Server|" "$SKYFIRE_ETC/worldserver.conf" || true
  sed -ri "s|^(\s*LogsDir\s*=).*|\1 \"/var/log/skyfire\"|" "$SKYFIRE_ETC/worldserver.conf" || true
  echo "[entrypoint-world] Configured file logging to /var/log/skyfire"
  
  # Ensure log directory exists and has proper permissions
  mkdir -p /var/log/skyfire
  chmod 755 /var/log/skyfire

  echo "[entrypoint-world] LoginDatabaseInfo set to ${CONN_LOGIN}"
  echo "[entrypoint-world] WorldDatabaseInfo set to ${CONN_WORLD}"
  echo "[entrypoint-world] CharacterDatabaseInfo set to ${CONN_CHAR}"
fi

exec stdbuf -oL -eL "$SKYFIRE_BIN/worldserver" -f

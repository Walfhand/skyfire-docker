#!/usr/bin/env bash
set -euo pipefail

: "${DB_HOST:?missing DB_HOST}"
: "${DB_PORT:=3306}"
: "${DB_USER:?missing DB_USER}"
: "${DB_PASS:?missing DB_PASS}"
: "${LOGIN_DB:=auth}"
: "${WORLD_DB:=world}"
: "${CHAR_DB:=characters}"
: "${DATA_DIR:=/data}"
: "${SKYFIRE_ETC:=/usr/local/skyfire-server/etc}"
: "${SKYFIRE_BIN:=/usr/local/skyfire-server/bin}"

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

  echo "[entrypoint-world] LoginDatabaseInfo set to ${CONN_LOGIN}"
  echo "[entrypoint-world] WorldDatabaseInfo set to ${CONN_WORLD}"
  echo "[entrypoint-world] CharacterDatabaseInfo set to ${CONN_CHAR}"
fi

# NOTE: Skipping wait-for-db here as well to mirror auth behavior during debugging
echo "[entrypoint-world] Skipping wait-for-db step"

# Data extraction is now manual via 'make extract-force'
echo "[entrypoint-world] Skipping auto-extraction (use 'make extract-force' if needed)"

exec stdbuf -oL -eL "$SKYFIRE_BIN/worldserver" -f

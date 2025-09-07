#!/usr/bin/env bash
set -euo pipefail

: "${DB_HOST:=db}"
: "${DB_PORT:=3306}"
: "${DB_USER:=root}"
: "${DB_PASS:=Abc123Abcd}"
: "${LOGIN_DB:=auth}"
: "${WORLD_DB:=world}"
: "${CHAR_DB:=characters}"
: "${SQL_BASE_DIR:=/opt/skyfire/sql}"
: "${EXTRA_SQL_DIR:=/sql-extra}"

# Check if database is already initialized
check_db_initialized() {
  local result=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -D "$LOGIN_DB" -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$LOGIN_DB' AND table_name='realmlist';" 2>/dev/null | tail -n1 || echo "0")
  [ "$result" -gt 0 ]
}

# Check if database is already initialized
if check_db_initialized; then
  echo "[init-db] Database already initialized, skipping import"
  exit 0
fi

echo "[init-db] Database not initialized, proceeding with import..."

if [ -x "/opt/skyfire/scripts/wait-for-db.sh" ]; then
  /opt/skyfire/scripts/wait-for-db.sh "$DB_HOST" "$DB_PORT"
fi

mysql_exec() {
  mysql -h "$DB_HOST" -P "$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$@"
}

mysql_import() {
  local db="$1"; shift
  local file="$1"; shift || true
  if [ -f "$file" ]; then
    echo "[init-db] Importing $file into $db"
    mysql -h "$DB_HOST" -P "$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$db" < "$file"
  else
    echo "[init-db] Skipped missing $file"
  fi
}

# 1) Create schemas via create_mysql.sql
if [ -f "$SQL_BASE_DIR/create/create_mysql.sql" ]; then
  echo "[init-db] Creating schemas from create_mysql.sql (idempotent)"
  # Make idempotent: ignore 'database exists' errors
  set +e
  mysql_exec < "$SQL_BASE_DIR/create/create_mysql.sql"
  rc=$?
  set -e
  if [ $rc -ne 0 ]; then
    echo "[init-db] Schema creation returned non-zero (likely databases already exist). Continuing..."
  fi
fi

# Ensure databases exist even if previous script aborted early
echo "[init-db] Ensuring databases exist"
mysql_exec -e "CREATE DATABASE IF NOT EXISTS \`${LOGIN_DB}\`;"
mysql_exec -e "CREATE DATABASE IF NOT EXISTS \`${CHAR_DB}\`;"
mysql_exec -e "CREATE DATABASE IF NOT EXISTS \`${WORLD_DB}\`;"

# 1b) Ensure application user exists (admin/Abc123$$) compatible with MySQL 9.1
echo "[init-db] Ensuring MySQL user 'admin' exists with required privileges"
mysql_exec -e "CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED BY 'Abc123\$\$';"
mysql_exec -e "ALTER USER 'admin'@'%' IDENTIFIED BY 'Abc123\$\$';"
mysql_exec -e "GRANT ALL PRIVILEGES ON \`${LOGIN_DB}\`.* TO 'admin'@'%';"
mysql_exec -e "GRANT ALL PRIVILEGES ON \`${WORLD_DB}\`.* TO 'admin'@'%';"
mysql_exec -e "GRANT ALL PRIVILEGES ON \`${CHAR_DB}\`.* TO 'admin'@'%';"
mysql_exec -e "FLUSH PRIVILEGES;"

# 2) Import base schemas following official SkyFire procedure
echo "[init-db] Importing /opt/skyfire/sql/base/auth_database.sql into auth"
mysql_import "$LOGIN_DB" "$SQL_BASE_DIR/base/auth_database.sql"

echo "[init-db] Importing /opt/skyfire/sql/base/characters_database.sql into characters"
mysql_import "$CHAR_DB" "$SQL_BASE_DIR/base/characters_database.sql"

# Import official SFDB from local file (already downloaded)
echo "[init-db] Importing official SFDB into world database"
mysql_import "$WORLD_DB" "/sql-extra/world-base/SFDB_full_548_24.001_2024_09_04_Release.sql"

# 3) Apply updates
# 3a) User-provided updates first (override/precedence): /sql-extra/updates/{world,char}
for db in world characters; do
  dir="$EXTRA_SQL_DIR/updates/$db"
  if [ -d "$dir" ]; then
    echo "[init-db] Applying user-provided updates for $db from $dir"
    for f in $(ls "$dir"/*.sql 2>/dev/null | sort); do
      target_db="$WORLD_DB"
      [ "$db" = "characters" ] && target_db="$CHAR_DB"
      mysql_import "$target_db" "$f"
    done
  fi
done

# Apply core updates for world from /opt/skyfire/sql/updates/world
for sql_file in /opt/skyfire/sql/updates/world/*.sql; do
  if [ -f "$sql_file" ]; then
    echo "[init-db] Importing $(basename "$sql_file") into world"
    mysql_exec world < "$sql_file"
  fi
done


# 3b) Core updates from image: /opt/skyfire/sql/updates/{auth,world,characters}
for db in auth world characters; do
  dir="$SQL_BASE_DIR/updates/$db"
  if [ -d "$dir" ]; then
    echo "[init-db] Applying core updates for $db from $dir"
    for f in $(ls "$dir"/*.sql 2>/dev/null | sort); do
      target_db="$WORLD_DB"
      [ "$db" = "characters" ] && target_db="$CHAR_DB"
      [ "$db" = "auth" ] && target_db="$LOGIN_DB"
      mysql_import "$target_db" "$f"
    done
  fi
done

# Skip old patches - the SFDB file already contains all necessary updates
echo "[init-db] Skipping old patches - SFDB file contains all updates"

# 4) Optional: update realmlist address from env REALMLIST_ADDRESS
if [ -n "${REALMLIST_ADDRESS:-}" ]; then
  echo "[init-db] Setting realmlist address to ${REALMLIST_ADDRESS}"
  mysql_exec -D "$LOGIN_DB" -e "UPDATE realmlist SET address='${REALMLIST_ADDRESS}' WHERE id=1;" || true
fi

echo "[init-db] Database initialization completed"

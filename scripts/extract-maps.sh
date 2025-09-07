#!/usr/bin/env bash
set -euo pipefail

: "${WOW_CLIENT_DIR:=/wow_client}"
: "${DATA_DIR:=/data}"
: "${SKYFIRE_BIN:=/usr/local/skyfire-server/bin}"

if [ ! -d "$WOW_CLIENT_DIR" ]; then
  echo "[extract-maps] WOW client directory not found at $WOW_CLIENT_DIR" >&2
  exit 1
fi

mkdir -p "$DATA_DIR"

pushd "$WOW_CLIENT_DIR" >/dev/null

# Extract DBC/DB2/Cameras/Maps
"$SKYFIRE_BIN/extractor"
"$SKYFIRE_BIN/vmap4extractor"

# Move data into DATA_DIR
for d in dbc db2 cameras maps; do
  if [ -d "$d" ]; then
    echo "[extract-maps] Moving $d to $DATA_DIR/$d"
    rm -rf "$DATA_DIR/$d"
    mv "$d" "$DATA_DIR/$d"
  else
    echo "[extract-maps] Missing $d after extraction" >&2
  fi
done

# Assemble vmaps in DATA_DIR
pushd "$DATA_DIR" >/dev/null
"$SKYFIRE_BIN/vmap4assembler"
if [ -d "vmaps" ]; then
  echo "[extract-maps] vmaps assembled at $DATA_DIR/vmaps"
else
  echo "[extract-maps] vmaps assembly did not produce folder 'vmaps'" >&2
fi
popd >/dev/null

popd >/dev/null

echo "[extract-maps] Extraction completed. Ensure worldserver.conf DataDir points to $DATA_DIR"

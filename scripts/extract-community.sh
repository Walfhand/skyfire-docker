#!/usr/bin/env bash
set -euo pipefail

: "${WOW_CLIENT_DIR:=/wow_client}"
: "${DATA_DIR:=/data}"
TOOLS_DIR="/opt/SkyFire-Community-Tools"
REPO_URL="https://github.com/ProjectSkyfire/SkyFire-Community-Tools.git"

if [ ! -d "$WOW_CLIENT_DIR" ]; then
  echo "[extract-community] WOW client directory not found at $WOW_CLIENT_DIR" >&2
  exit 1
fi

mkdir -p "$DATA_DIR"

if [ ! -d "$TOOLS_DIR" ]; then
  echo "[extract-community] Cloning community tools from $REPO_URL"
  git clone "$REPO_URL" "$TOOLS_DIR"
fi

# Try to locate extractors within the community tools repo
EXTRACTOR="$(command -v extractor || true)"
VMAP_EXTRACTOR="$(command -v vmap4extractor || true)"
VMAP_ASSEMBLER="$(command -v vmap4assembler || true)"

# Search inside the repo for linux binaries if not in PATH
if [ -z "$EXTRACTOR" ]; then
  EXTRACTOR=$(find "$TOOLS_DIR" -type f -iname extractor -perm -u+x | head -n 1 || true)
fi
if [ -z "$VMAP_EXTRACTOR" ]; then
  VMAP_EXTRACTOR=$(find "$TOOLS_DIR" -type f -iname vmap4extractor -perm -u+x | head -n 1 || true)
fi
if [ -z "$VMAP_ASSEMBLER" ]; then
  VMAP_ASSEMBLER=$(find "$TOOLS_DIR" -type f -iname vmap4assembler -perm -u+x | head -n 1 || true)
fi

if [ -z "$EXTRACTOR" ] || [ -z "$VMAP_EXTRACTOR" ] || [ -z "$VMAP_ASSEMBLER" ]; then
  echo "[extract-community] Could not find prebuilt Linux extractors in the community tools repo." >&2
  echo "[extract-community] Please provide Linux binaries in the repo or use the 'extract' target to build tools from source." >&2
  exit 2
fi

pushd "$WOW_CLIENT_DIR" >/dev/null
"$EXTRACTOR"
"$VMAP_EXTRACTOR"

for d in dbc db2 cameras maps; do
  if [ -d "$d" ]; then
    echo "[extract-community] Moving $d to $DATA_DIR/$d"
    rm -rf "$DATA_DIR/$d"
    mv "$d" "$DATA_DIR/$d"
  else
    echo "[extract-community] Missing $d after extraction" >&2
  fi
done

pushd "$DATA_DIR" >/dev/null
"$VMAP_ASSEMBLER"
if [ -d "vmaps" ]; then
  echo "[extract-community] vmaps assembled at $DATA_DIR/vmaps"
else
  echo "[extract-community] vmaps assembly did not produce folder 'vmaps'" >&2
fi
popd >/dev/null

popd >/dev/null

echo "[extract-community] Extraction completed via Community Tools."

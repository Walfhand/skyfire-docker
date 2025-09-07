#!/usr/bin/env bash
set -euo pipefail

: "${WOW_CLIENT_DIR:=/wow_client}"
: "${DATA_DIR:=/data}"

echo "[auto-extract] Checking if extraction is needed..."

# Function to check if extraction is complete
check_extraction_complete() {
    local required_dirs=("dbc" "db2" "cameras" "maps" "vmaps")
    local required_files=("$DATA_DIR/dbc/Achievement.dbc" "$DATA_DIR/maps/0004331.map" "$DATA_DIR/vmaps/0004331.vmtree")
    
    # Check if all required directories exist and have content
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$DATA_DIR/$dir" ]] || [[ -z "$(ls -A "$DATA_DIR/$dir" 2>/dev/null)" ]]; then
            echo "[auto-extract] Missing or empty directory: $DATA_DIR/$dir"
            return 1
        fi
    done
    
    # Check if key files exist
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo "[auto-extract] Missing key file: $file"
            return 1
        fi
    done
    
    echo "[auto-extract] Extraction appears complete"
    return 0
}

# Function to run extraction
run_extraction() {
    echo "[auto-extract] Starting extraction process..."
    
    # Check if WoW client is available
    if [[ ! -d "$WOW_CLIENT_DIR" ]] || [[ -z "$(ls -A "$WOW_CLIENT_DIR" 2>/dev/null)" ]]; then
        echo "[auto-extract] ERROR: WoW client directory not found or empty: $WOW_CLIENT_DIR"
        exit 1
    fi
    
    # Create data directories with proper permissions
    mkdir -p "$DATA_DIR"/{dbc,db2,cameras,maps,vmaps,Buildings}
    chmod -R 777 "$DATA_DIR"
    
    # Extract directly in WoW client directory (read-only mount)
    # Create temp extraction directories in /tmp with proper permissions
    TEMP_EXTRACT_DIR="/tmp/wow_extract_$$"
    mkdir -p "$TEMP_EXTRACT_DIR"
    chmod 777 "$TEMP_EXTRACT_DIR"
    
    # Create extraction output directories in temp
    mkdir -p "$TEMP_EXTRACT_DIR"/{dbc,db2,cameras,maps,vmaps,Buildings}
    chmod -R 777 "$TEMP_EXTRACT_DIR"
    
    # Run mapextractor from WoW client dir but output to temp
    cd "$WOW_CLIENT_DIR"
    echo "[auto-extract] Extracting basic data..."
    
    # Create symlinks in WoW client dir pointing to temp output dirs
    ln -sf "$TEMP_EXTRACT_DIR/dbc" ./dbc
    ln -sf "$TEMP_EXTRACT_DIR/db2" ./db2  
    ln -sf "$TEMP_EXTRACT_DIR/cameras" ./cameras
    ln -sf "$TEMP_EXTRACT_DIR/maps" ./maps
    ln -sf "$TEMP_EXTRACT_DIR/Buildings" ./Buildings
    
    /usr/local/bin/mapextractor
    
    # Move extracted data to data directory
    [[ -d "$TEMP_EXTRACT_DIR/dbc" ]] && cp -r "$TEMP_EXTRACT_DIR/dbc"/* "$DATA_DIR/dbc/" 2>/dev/null || true
    [[ -d "$TEMP_EXTRACT_DIR/db2" ]] && cp -r "$TEMP_EXTRACT_DIR/db2"/* "$DATA_DIR/db2/" 2>/dev/null || true
    [[ -d "$TEMP_EXTRACT_DIR/cameras" ]] && cp -r "$TEMP_EXTRACT_DIR/cameras"/* "$DATA_DIR/cameras/" 2>/dev/null || true
    [[ -d "$TEMP_EXTRACT_DIR/maps" ]] && cp -r "$TEMP_EXTRACT_DIR/maps"/* "$DATA_DIR/maps/" 2>/dev/null || true
    [[ -d "$TEMP_EXTRACT_DIR/Buildings" ]] && cp -r "$TEMP_EXTRACT_DIR/Buildings"/* "$DATA_DIR/Buildings/" 2>/dev/null || true
    
    # Extract vmaps (skip if it fails - not critical for basic server operation)
    echo "[auto-extract] Extracting vmaps..."
    if ! /usr/local/bin/vmap4extractor; then
        echo "[auto-extract] WARNING: vmap4extractor failed, skipping vmaps extraction"
        echo "[auto-extract] Server will work without vmaps but some collision detection may be missing"
    else
        # Assemble vmaps
        echo "[auto-extract] Assembling vmaps..."
        mkdir -p vmaps
        if ! /usr/local/bin/vmap4assembler Buildings vmaps; then
            echo "[auto-extract] WARNING: vmap4assembler failed, skipping vmaps assembly"
        fi
    fi
    
    # Move vmaps to data directory
    [[ -d "vmaps" ]] && cp -r vmaps/* "$DATA_DIR/vmaps/"
    
    # Clean up temporary extraction directory
    cd /
    rm -rf "$TEMP_EXTRACT_DIR" 2>/dev/null || true
    
    echo "[auto-extract] Extraction completed successfully"
}

# Main logic
if check_extraction_complete; then
    echo "[auto-extract] Extraction already complete, skipping"
    exit 0
else
    echo "[auto-extract] Extraction needed, starting process"
    run_extraction
fi

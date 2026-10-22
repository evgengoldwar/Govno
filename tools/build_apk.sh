#!/bin/sh
# Builds and signs build/StihiiBezdny.apk.
# Needs: Godot 4.7.2 in PATH with Android export templates installed,
# editor settings pointing export/android/android_sdk_path to an SDK dir that has
# build-tools/<ver>/apksigner (can be a wrapper around tools/apksign.py) and a JDK.
set -e
cd "$(dirname "$0")/.."
KEY_DIR="${KEY_DIR:-$HOME/.local/share/godot/keystores}"
mkdir -p build "$KEY_DIR"
[ -f "$KEY_DIR/abyss_key.pem" ] || python3 tools/apksign.py genkey "$KEY_DIR/abyss_key.pem" "$KEY_DIR/abyss_cert.pem"
godot --headless --export-release "Android" build/unsigned.apk
python3 tools/apksign.py sign build/unsigned.apk build/StihiiBezdny.apk "$KEY_DIR/abyss_key.pem" "$KEY_DIR/abyss_cert.pem"
echo "build/StihiiBezdny.apk"

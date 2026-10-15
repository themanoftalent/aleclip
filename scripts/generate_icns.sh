#!/bin/bash
set -e

SRC_IMAGE="$1"
OUT_ICNS="$2"

if [ -z "$SRC_IMAGE" ] || [ -z "$OUT_ICNS" ]; then
    echo "Usage: $0 <source_1024x1024.png> <output.icns>"
    exit 1
fi

ICONSET_DIR="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"

echo "🎨 Generating iconset resolutions from $SRC_IMAGE..."

sips -z 16 16     "$SRC_IMAGE" --out "$ICONSET_DIR/icon_16x16.png" > /dev/null
sips -z 32 32     "$SRC_IMAGE" --out "$ICONSET_DIR/icon_16x16@2x.png" > /dev/null
sips -z 32 32     "$SRC_IMAGE" --out "$ICONSET_DIR/icon_32x32.png" > /dev/null
sips -z 64 64     "$SRC_IMAGE" --out "$ICONSET_DIR/icon_32x32@2x.png" > /dev/null
sips -z 128 128   "$SRC_IMAGE" --out "$ICONSET_DIR/icon_128x128.png" > /dev/null
sips -z 256 256   "$SRC_IMAGE" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null
sips -z 256 256   "$SRC_IMAGE" --out "$ICONSET_DIR/icon_256x256.png" > /dev/null
sips -z 512 512   "$SRC_IMAGE" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null
sips -z 512 512   "$SRC_IMAGE" --out "$ICONSET_DIR/icon_512x512.png" > /dev/null
sips -z 1024 1024 "$SRC_IMAGE" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null

echo "🛠 Creating .icns file with iconutil..."
iconutil -c icns "$ICONSET_DIR" -o "$OUT_ICNS"

rm -rf "$(dirname "$ICONSET_DIR")"
echo "✅ Successfully created $OUT_ICNS!"

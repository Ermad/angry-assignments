#!/bin/bash
set -euo pipefail

ADDON_NAME="AngryAssignments"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION=$(grep -oP '## Version:\s*\K\S+' "$SCRIPT_DIR/$ADDON_NAME.toc")

if [ -z "$VERSION" ]; then
  echo "ERROR: Could not parse version from .toc file" >&2
  exit 1
fi

DIST_DIR="$SCRIPT_DIR/dist"
STAGE_DIR="$DIST_DIR/$ADDON_NAME"
ZIP_NAME="${ADDON_NAME}-${VERSION}.zip"

rm -rf "$DIST_DIR"
mkdir -p "$STAGE_DIR"

# Copy only addon-relevant files (.lua, .toc, .xml)
# Includes libs/ if present (populated by make libs or CurseForge packager)
cd "$SCRIPT_DIR"
find . \( -name '*.lua' -o -name '*.toc' -o -name '*.xml' \) \
  -not -path './.git/*' \
  -not -path './dist/*' \
  -print0 | while IFS= read -r -d '' file; do
    dir="$STAGE_DIR/$(dirname "$file")"
    mkdir -p "$dir"
    cp "$file" "$dir/"
  done

cd "$DIST_DIR"
zip -r "$ZIP_NAME" "$ADDON_NAME"

echo ""
echo "Packaged: $DIST_DIR/$ZIP_NAME"
echo "Version:  $VERSION"
echo "Size:     $(du -h "$ZIP_NAME" | cut -f1)"

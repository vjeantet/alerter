#!/bin/bash
set -euo pipefail

PRODUCT_NAME="alerter"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_DIR/dist"
PORTFILE="$PROJECT_DIR/macports/Portfile"

# Get version from AlerterCommand.swift
VERSION=$(grep 'version:' "$PROJECT_DIR/Sources/Alerter/AlerterCommand.swift" | head -1 | sed 's/.*"\(.*\)".*/\1/')
ZIP_FILE="$DIST_DIR/$PRODUCT_NAME-$VERSION.zip"

if [ ! -f "$ZIP_FILE" ]; then
    echo "Error: $ZIP_FILE not found. Run release.sh first."
    exit 1
fi

if [ ! -f "$PORTFILE" ]; then
    echo "Error: $PORTFILE not found."
    exit 1
fi

ZIP_SHA256=$(shasum -a 256 "$ZIP_FILE" | awk '{print $1}')
echo "==> Version: $VERSION"
echo "==> SHA256:  $ZIP_SHA256"

# Update Portfile
echo "==> Updating macports/Portfile..."
sed -i '' "s|^version .*|version             $VERSION|" "$PORTFILE"
sed -i '' "s|^revision .*|revision            0|" "$PORTFILE"
sed -i '' "s|^checksums .*|checksums           sha256 $ZIP_SHA256|" "$PORTFILE"

echo "==> Done!"
echo ""
echo "  macports/Portfile updated to version $VERSION"
echo ""
echo "  To submit to MacPorts, copy macports/Portfile to a PR against:"
echo "  https://github.com/macports/macports-ports/tree/master/sysutils/alerter"

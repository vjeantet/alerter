#!/bin/bash
set -euo pipefail

PRODUCT_NAME="alerter"
TAP_REPO="vjeantet/homebrew-tap"
FORMULA_PATH="Formula/alerter.rb"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_DIR/dist"

# Get version from AlerterCommand.swift
VERSION=$(grep 'version:' "$PROJECT_DIR/Sources/Alerter/AlerterCommand.swift" | head -1 | sed 's/.*"\(.*\)".*/\1/')
ZIP_FILE="$DIST_DIR/$PRODUCT_NAME-$VERSION.zip"

if [ ! -f "$ZIP_FILE" ]; then
    echo "Error: $ZIP_FILE not found. Run release.sh first."
    exit 1
fi

ZIP_SHA256=$(shasum -a 256 "$ZIP_FILE" | awk '{print $1}')
echo "==> Version: $VERSION"
echo "==> SHA256:  $ZIP_SHA256"

# Clone or update the tap repo
TAP_DIR=$(mktemp -d)
echo "==> Cloning $TAP_REPO into $TAP_DIR..."
gh repo clone "$TAP_REPO" "$TAP_DIR"

# Update formula
echo "==> Updating $FORMULA_PATH..."
sed -i '' "s|version \".*\"|version \"$VERSION\"|" "$TAP_DIR/$FORMULA_PATH"
sed -i '' "s|sha256 \".*\"|sha256 \"$ZIP_SHA256\"|" "$TAP_DIR/$FORMULA_PATH"

# Commit and push
cd "$TAP_DIR"
git add "$FORMULA_PATH"
if git diff --cached --quiet; then
    echo "==> No changes to commit — formula is already up to date."
else
    git commit -m "Update alerter to $VERSION"
    git push origin main
    echo "==> Formula updated and pushed to $TAP_REPO."
fi

# Cleanup
rm -rf "$TAP_DIR"
echo "==> Done!"

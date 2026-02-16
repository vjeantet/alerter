#!/bin/bash
set -euo pipefail

# Configuration
SIGNING_IDENTITY="Developer ID Application: Valere JEANTET (NQLLJK2GK3)"
INSTALLER_IDENTITY="Developer ID Installer: Valere JEANTET (NQLLJK2GK3)"
TEAM_ID="NQLLJK2GK3"
APPLE_ID="valere.jeantet@gmail.com"
PRODUCT_NAME="alerter"
BUNDLE_ID="fr.vjeantet.alerter"
INSTALL_PATH="/usr/local/bin"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/release"
DIST_DIR="$PROJECT_DIR/dist"
PKG_ROOT="$DIST_DIR/pkg-root"
VERSION_FILE="$PROJECT_DIR/Sources/Alerter/AlerterCommand.swift"

# --- Auto version bump (YY.N format) ---
YEAR_PREFIX=$(date +%y)

# Find the highest tag for the current year (e.g. v26.*)
LAST_TAG=$(git tag -l "v${YEAR_PREFIX}.*" --sort=-v:refname | head -1)

if [ -z "$LAST_TAG" ]; then
    VERSION="${YEAR_PREFIX}.1"
else
    LAST_INCREMENT=$(echo "$LAST_TAG" | sed "s/v${YEAR_PREFIX}\.//")
    VERSION="${YEAR_PREFIX}.$(( LAST_INCREMENT + 1 ))"
fi

echo "==> Bumping version to $VERSION"
sed -i '' "s/version: \".*\"/version: \"$VERSION\"/" "$VERSION_FILE"

git -C "$PROJECT_DIR" add "$VERSION_FILE"
git -C "$PROJECT_DIR" commit -m "Bump version to $VERSION"

# Clean
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR" "$PKG_ROOT/$INSTALL_PATH"

# Build
echo "==> Building release..."
swift build -c release --package-path "$PROJECT_DIR"

# Sign binary
echo "==> Signing binary..."
codesign --force --options runtime \
    --sign "$SIGNING_IDENTITY" \
    --identifier "$BUNDLE_ID" \
    "$BUILD_DIR/$PRODUCT_NAME"

codesign --verify --verbose "$BUILD_DIR/$PRODUCT_NAME"

# --- ZIP ---
echo "==> Creating zip..."
zip -j "$DIST_DIR/$PRODUCT_NAME-$VERSION.zip" "$BUILD_DIR/$PRODUCT_NAME"

echo "==> Notarizing zip..."
xcrun notarytool submit "$DIST_DIR/$PRODUCT_NAME-$VERSION.zip" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --keychain-profile "alerter-notarize" \
    --wait

# --- PKG ---
echo "==> Creating pkg..."
cp "$BUILD_DIR/$PRODUCT_NAME" "$PKG_ROOT/$INSTALL_PATH/"

pkgbuild --root "$PKG_ROOT" \
    --identifier "$BUNDLE_ID" \
    --version "$VERSION" \
    --install-location "/" \
    --sign "$INSTALLER_IDENTITY" \
    "$DIST_DIR/$PRODUCT_NAME-$VERSION.pkg"

echo "==> Notarizing pkg..."
xcrun notarytool submit "$DIST_DIR/$PRODUCT_NAME-$VERSION.pkg" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --keychain-profile "alerter-notarize" \
    --wait

echo "==> Stapling pkg..."
xcrun stapler staple "$DIST_DIR/$PRODUCT_NAME-$VERSION.pkg"

# Cleanup
rm -rf "$PKG_ROOT"

# --- GitHub Release ---
TAG="v$VERSION"
ZIP_FILE="$DIST_DIR/$PRODUCT_NAME-$VERSION.zip"
PKG_FILE="$DIST_DIR/$PRODUCT_NAME-$VERSION.pkg"

echo "==> Creating git tag $TAG..."
git tag -f "$TAG"
git push origin "$TAG"

echo "==> Creating GitHub Release $TAG..."
gh release create "$TAG" \
    "$ZIP_FILE" \
    "$PKG_FILE" \
    --title "$VERSION" \
    --generate-notes

# Display SHA256 for Homebrew formula
ZIP_SHA256=$(shasum -a 256 "$ZIP_FILE" | awk '{print $1}')
echo ""
echo "==> Done!"
echo "  dist/$PRODUCT_NAME-$VERSION.zip  (notarized)"
echo "  dist/$PRODUCT_NAME-$VERSION.pkg  (notarized + stapled)"
echo ""
echo "  GitHub Release: $TAG"
echo "  ZIP SHA256: $ZIP_SHA256"
echo ""
echo "  Next steps:"
echo "    ./scripts/update-homebrew-formula.sh"
echo "    ./scripts/update-macports-portfile.sh"

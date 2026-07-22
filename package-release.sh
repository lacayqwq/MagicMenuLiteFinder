#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h}"
PROJECT="$ROOT_DIR/MagicMenuLiteFinder.xcodeproj"
DERIVED_DATA="$ROOT_DIR/build/ReleaseDerivedData"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="MagicMenu.app"
APP_PATH="$DERIVED_DATA/Build/Products/Release/$APP_NAME"

VERSION="$(awk '/MARKETING_VERSION =/ { value = $3; sub(/;$/, "", value); print value; exit }' "$PROJECT/project.pbxproj")"
if [[ -z "$VERSION" ]]; then
  echo "Could not read MARKETING_VERSION from the Xcode project."
  exit 1
fi

mkdir -p "$DIST_DIR" "$ROOT_DIR/build"
STAGING_DIR="$(mktemp -d "$ROOT_DIR/build/ReleaseStaging.XXXXXX")"
STAGED_APP="$STAGING_DIR/$APP_NAME"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

cleanup() {
  "$LSREGISTER" -u "$APP_PATH" >/dev/null 2>&1 || true
  "$LSREGISTER" -u "$STAGED_APP" >/dev/null 2>&1 || true
  rm -rf "$STAGING_DIR" "$DERIVED_DATA"
}
trap cleanup EXIT

xcodebuild \
  -project "$PROJECT" \
  -scheme MagicMenuLiteFinder \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

ditto "$APP_PATH" "$STAGED_APP"

codesign --force --sign - --options runtime \
  --entitlements "$ROOT_DIR/FinderExtension/FinderExtension.entitlements" \
  "$STAGED_APP/Contents/PlugIns/MagicMenuLiteFinderExtension.appex"
codesign --force --sign - --options runtime \
  --entitlements "$ROOT_DIR/App/MagicMenuLiteFinder.entitlements" \
  "$STAGED_APP"
codesign --verify --deep --strict --verbose=2 "$STAGED_APP"

ARCHIVE_NAME="MagicMenu-v$VERSION-macos.zip"
ARCHIVE="$DIST_DIR/$ARCHIVE_NAME"
CHECKSUM="$DIST_DIR/MagicMenu-v$VERSION-macos.sha256"
ditto -c -k --sequesterRsrc --keepParent "$STAGED_APP" "$ARCHIVE"
(cd "$DIST_DIR" && shasum -a 256 "$ARCHIVE_NAME") > "$CHECKSUM"

echo "Release artifacts:"
echo "  $ARCHIVE"
echo "  $CHECKSUM"

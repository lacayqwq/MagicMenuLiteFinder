#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h}"
PROJECT="$ROOT_DIR/MagicMenuLiteFinder.xcodeproj"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
APP_NAME="MagicMenuLiteFinder.app"
APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
INSTALLED_APP="$INSTALL_DIR/$APP_NAME"
EXTENSION_ID="dev.codex.MagicMenuLiteFinder.FinderExtension"

if [[ ! -d /Applications/Xcode.app ]]; then
  echo "Xcode is not installed at /Applications/Xcode.app."
  echo "Install Xcode from the App Store first, then run this script again."
  exit 1
fi

if [[ "$(xcode-select -p)" != "/Applications/Xcode.app/Contents/Developer" ]]; then
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
fi

xcodebuild \
  -project "$PROJECT" \
  -scheme MagicMenuLiteFinder \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  build

mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALLED_APP"
cp -R "$APP_PATH" "$INSTALLED_APP"

codesign --force --sign - --options runtime --preserve-metadata=identifier,entitlements --requirements '=designated => identifier "dev.codex.MagicMenuLiteFinder.FinderExtension"' "$INSTALLED_APP/Contents/PlugIns/MagicMenuLiteFinderExtension.appex"
codesign --force --sign - --options runtime --preserve-metadata=identifier,entitlements --requirements '=designated => identifier "dev.codex.MagicMenuLiteFinder"' "$INSTALLED_APP"

/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -u "$APP_PATH" >/dev/null 2>&1 || true
rm -rf "$ROOT_DIR/build"
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R -trusted "$INSTALLED_APP"
/usr/bin/pluginkit -e use -i "$EXTENSION_ID" || true
killall Finder >/dev/null 2>&1 || true

cat <<DONE
MagicMenu Lite Finder installed.

App:
  $INSTALLED_APP

If the Finder menu does not appear:
  1. Open System Settings > Login Items & Extensions > Finder Extensions.
  2. Enable MagicMenu Lite.
  3. Relaunch Finder: killall Finder
DONE

#!/usr/bin/env bash
# Собирает .dmg для macOS с ad-hoc подписью (запуск после снятия карантина).
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="PlannerApp"
PROJECT="PlannerApp.xcodeproj"
BUILD_DIR="build"
DERIVED="$BUILD_DIR/derived-mac"

rm -rf "$DERIVED"
mkdir -p "$BUILD_DIR"

xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=YES

APP_PATH=$(find "$DERIVED/Build/Products/Release" -maxdepth 1 -name "*.app" | head -n1)
if [ -z "$APP_PATH" ]; then
    echo "Не найден .app" >&2
    exit 1
fi

# Ad-hoc подпись, чтобы приложение запускалось на Apple Silicon.
codesign --force --deep --sign - "$APP_PATH"

STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
    -volname "Планер" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$BUILD_DIR/PlannerApp-macOS.dmg"

rm -rf "$STAGING"
echo "Готово: $BUILD_DIR/PlannerApp-macOS.dmg"

#!/usr/bin/env bash
# Собирает неподписанный .ipa для iOS (для установки через AltStore/Sideloadly).
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="PlannerApp"
PROJECT="PlannerApp.xcodeproj"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/PlannerApp-iOS.xcarchive"

rm -rf "$ARCHIVE_PATH"
mkdir -p "$BUILD_DIR"

xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

APP_DIR="$ARCHIVE_PATH/Products/Applications"
PAYLOAD_DIR="$BUILD_DIR/Payload"
rm -rf "$PAYLOAD_DIR"
mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_DIR/"*.app "$PAYLOAD_DIR/"

( cd "$BUILD_DIR" && zip -qr -y "PlannerApp-unsigned.ipa" "Payload" )
rm -rf "$PAYLOAD_DIR"

echo "Готово: $BUILD_DIR/PlannerApp-unsigned.ipa"

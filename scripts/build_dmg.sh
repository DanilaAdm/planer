#!/usr/bin/env bash
# Собирает universal .dmg для macOS с ad-hoc подписью.
#
# Приложение не нотаризовано (для этого нужен платный Apple Developer Program),
# поэтому при первом запуске пользователь разрешает его вручную в разделе
# «Системные настройки → Конфиденциальность и безопасность».
#
# Версию можно задать переменными окружения MARKETING_VERSION и
# CURRENT_PROJECT_VERSION — этим пользуется релизный workflow.
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="PlannerApp"
PROJECT="PlannerApp.xcodeproj"
BUILD_DIR="build"
DERIVED="$BUILD_DIR/derived-mac"
DMG_PATH="$BUILD_DIR/PlannerApp-macOS.dmg"
# Имя тома оставляем латиницей: кириллица в volname ломает монтирование
# на части систем. Пользователь всё равно видит «Планер» — это CFBundleDisplayName.
VOLNAME="Planer"

if [ ! -d "$PROJECT" ]; then
    echo "Не найден $PROJECT. Сначала выполните ./scripts/generate_project.sh" >&2
    exit 1
fi

VERSION_ARGS=""
if [ -n "${MARKETING_VERSION:-}" ]; then
    VERSION_ARGS="$VERSION_ARGS MARKETING_VERSION=$MARKETING_VERSION"
fi
if [ -n "${CURRENT_PROJECT_VERSION:-}" ]; then
    VERSION_ARGS="$VERSION_ARGS CURRENT_PROJECT_VERSION=$CURRENT_PROJECT_VERSION"
fi

rm -rf "$DERIVED"
mkdir -p "$BUILD_DIR"

# ARCHS задаём явно: иначе на arm64-раннере может собраться только Apple Silicon,
# и на Intel-маках приложение не запустится вообще.
# shellcheck disable=SC2086
xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=YES \
    $VERSION_ARGS

APP_PATH=$(find "$DERIVED/Build/Products/Release" -maxdepth 1 -name "*.app" | head -n1)
if [ -z "$APP_PATH" ]; then
    echo "Не найден .app после сборки" >&2
    exit 1
fi
APP_NAME=$(basename "$APP_PATH")
EXECUTABLE="$APP_PATH/Contents/MacOS/${APP_NAME%.app}"

echo "==> Проверка архитектур"
if [ ! -f "$EXECUTABLE" ]; then
    echo "Не найден исполняемый файл $EXECUTABLE" >&2
    exit 1
fi
FOUND_ARCHS=$(lipo -archs "$EXECUTABLE")
echo "Собрано для: $FOUND_ARCHS"
for want in arm64 x86_64; do
    case " $FOUND_ARCHS " in
        *" $want "*) ;;
        *)
            echo "В бинарнике нет архитектуры $want — на таких Mac приложение не запустится" >&2
            exit 1
            ;;
    esac
done

# Ad-hoc подпись обязательна: на Apple Silicon бинарник без валидной подписи
# не запускается в принципе. Вложенный код подписываем отдельно и до основного
# бандла — флаг --deep для подписи устарел и делает это некорректно.
echo "==> Подпись"
FRAMEWORKS_DIR="$APP_PATH/Contents/Frameworks"
if [ -d "$FRAMEWORKS_DIR" ]; then
    while IFS= read -r nested; do
        echo "  подписываю $(basename "$nested")"
        codesign --force --options runtime --sign - "$nested"
    done < <(find "$FRAMEWORKS_DIR" -maxdepth 1 \( -name "*.framework" -o -name "*.dylib" \))
fi
codesign --force --options runtime --sign - "$APP_PATH"

echo "==> Проверка подписи"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG_PATH"
hdiutil create \
    -volname "$VOLNAME" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING"
echo "Готово: $DMG_PATH"

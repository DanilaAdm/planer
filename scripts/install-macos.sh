#!/usr/bin/env bash
# Устанавливает «Планер» на macOS одной командой:
#
#   curl -fsSL https://github.com/DanilaAdm/planer/releases/latest/download/install-macos.sh | bash
#
# Скачивает последний релиз, снимает карантин и кладёт приложение в «Программы».
# Снятие карантина здесь заменяет ручной поход в «Системные настройки →
# Конфиденциальность и безопасность»: приложение не нотаризовано, потому что
# у проекта нет платного Apple Developer Program.
set -euo pipefail

REPO="DanilaAdm/planer"
DMG_NAME="PlannerApp-macOS.dmg"
APP_NAME="PlannerApp.app"
DEST_DIR="/Applications"
DOWNLOAD_URL="https://github.com/$REPO/releases/latest/download/$DMG_NAME"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "Этот установщик только для macOS." >&2
    exit 1
fi

WORK_DIR=$(mktemp -d)
MOUNT_POINT="$WORK_DIR/mnt"

cleanup() {
    if [ -d "$MOUNT_POINT" ]; then
        hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    fi
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

echo "==> Скачиваю последнюю версию"
if ! curl -fL --progress-bar -o "$WORK_DIR/$DMG_NAME" "$DOWNLOAD_URL"; then
    echo "Не удалось скачать $DOWNLOAD_URL" >&2
    echo "Проверьте, что релиз опубликован: https://github.com/$REPO/releases" >&2
    exit 1
fi

echo "==> Монтирую образ"
hdiutil attach "$WORK_DIR/$DMG_NAME" -nobrowse -readonly -quiet -mountpoint "$MOUNT_POINT"

if [ ! -d "$MOUNT_POINT/$APP_NAME" ]; then
    echo "В образе нет $APP_NAME" >&2
    exit 1
fi

if pgrep -x "${APP_NAME%.app}" >/dev/null 2>&1; then
    echo "==> Закрываю запущенное приложение"
    osascript -e 'quit app id "com.planner.repetitor"' 2>/dev/null || true
    sleep 2
fi

echo "==> Копирую в $DEST_DIR"
rm -rf "${DEST_DIR:?}/$APP_NAME"
if ! cp -R "$MOUNT_POINT/$APP_NAME" "$DEST_DIR/"; then
    echo "Нет прав на запись в $DEST_DIR. Повторите с sudo." >&2
    exit 1
fi

echo "==> Снимаю карантин"
xattr -dr com.apple.quarantine "$DEST_DIR/$APP_NAME" 2>/dev/null || true

if ! codesign --verify --deep --strict "$DEST_DIR/$APP_NAME" 2>/dev/null; then
    echo "Предупреждение: подпись приложения не прошла проверку." >&2
fi

echo "Готово. Запускаю «Планер»."
open "$DEST_DIR/$APP_NAME"

#!/usr/bin/env bash
# Перегенерирует иконку приложения в App/Resources/Assets.xcassets.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Рисую иконку"
swift scripts/make_icons.swift

# Та же иконка используется на странице загрузки.
cp App/Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png docs/icon.png
echo "docs/icon.png обновлён"

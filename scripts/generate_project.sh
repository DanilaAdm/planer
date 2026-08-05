#!/usr/bin/env bash
# Генерирует PlannerApp.xcodeproj из project.yml через XcodeGen.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "XcodeGen не установлен. Установите: brew install xcodegen" >&2
    exit 1
fi

xcodegen generate
echo "PlannerApp.xcodeproj сгенерирован."

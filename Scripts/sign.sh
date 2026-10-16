#!/bin/bash
set -euo pipefail
: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to your installed Developer ID Application identity}"
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$TASK_ROOT/dist/DevPet.app}"
codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$APP_PATH"
codesign --verify --strict --verbose=2 "$APP_PATH"

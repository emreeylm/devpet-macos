#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$TASK_ROOT/dist/DevPet.app}"
DMG_PATH="${2:-$TASK_ROOT/dist/DevPet.dmg}"
codesign --verify --strict --verbose=2 "$APP_PATH"
lipo -info "$APP_PATH/Contents/MacOS/DevPet"
plutil -lint "$APP_PATH/Contents/Info.plist"
hdiutil verify "$DMG_PATH"
if [[ "${REQUIRE_NOTARIZATION:-0}" == 1 ]]; then
  xcrun stapler validate "$DMG_PATH"
  spctl --assess --type execute --verbose=2 "$APP_PATH"
else
  printf 'Local artifact validation only. Developer ID / notarization have not been asserted.\n'
fi
shasum -a 256 "$DMG_PATH"

#!/bin/bash
set -euo pipefail
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a notarytool Keychain profile}"
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DMG_PATH="${1:-$TASK_ROOT/dist/DevPet.dmg}"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

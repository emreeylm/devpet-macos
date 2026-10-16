#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$TASK_ROOT/dist/DevPet.app}"
DMG_PATH="${2:-$TASK_ROOT/dist/DevPet.dmg}"
[[ -d "$APP_PATH" ]] || { printf 'Missing app: %s\n' "$APP_PATH"; exit 1; }
mkdir -p "$(dirname "$DMG_PATH")"
STAGE_PATH="$(mktemp -d "${TMPDIR:-/tmp}/devpet-dmg.XXXXXX")"
detach_image() {
  for attempt in 1 2 3; do
    if hdiutil detach "$1"; then return 0; fi
    sleep 2
  done
  hdiutil detach -force "$1"
}
cleanup() { [[ -n "${MOUNT_PATH:-}" ]] && detach_image "$MOUNT_PATH" || true; }
trap cleanup EXIT
/usr/bin/ditto "$APP_PATH" "$STAGE_PATH/DevPet.app"
ln -s /Applications "$STAGE_PATH/Applications"
printf 'Install DevPet\n\nDrag DevPet.app to Applications. Launch it from Applications.\nUnsigned/ad-hoc builds are not notarized; do not disable Gatekeeper.\n' > "$STAGE_PATH/Install DevPet.txt"
if [[ -f "$TASK_ROOT/Scripts/DMGBackground.png" ]]; then
  mkdir -p "$STAGE_PATH/.background"
  cp "$TASK_ROOT/Scripts/DMGBackground.png" "$STAGE_PATH/.background/background.png"
fi
# Use a reviewed Finder layout if one has been saved. CI does not need GUI automation.
if [[ -f "$TASK_ROOT/Scripts/DMG.DS_Store" ]]; then cp "$TASK_ROOT/Scripts/DMG.DS_Store" "$STAGE_PATH/.DS_Store"; fi
if [[ "${DMG_LAYOUT:-0}" == 1 ]]; then
  RW_IMAGE="${DMG_PATH%.dmg}-layout.dmg"
  hdiutil create -volname DevPet -srcfolder "$STAGE_PATH" -format UDRW -ov "$RW_IMAGE"
  MOUNT_PATH="$(hdiutil attach -nobrowse -noautoopen -plist "$RW_IMAGE" | python3 -c 'import plistlib,sys; p=plistlib.loads(sys.stdin.buffer.read()); print(next(e["mount-point"] for e in p["system-entities"] if "mount-point" in e))')"
  osascript "$TASK_ROOT/Scripts/layout-dmg.applescript" "$(basename "$MOUNT_PATH")"
  sync
  if [[ -f "$MOUNT_PATH/.DS_Store" ]]; then cp "$MOUNT_PATH/.DS_Store" "$TASK_ROOT/Scripts/DMG.DS_Store"; fi
  detach_image "$MOUNT_PATH"
  MOUNT_PATH=""
  hdiutil convert "$RW_IMAGE" -format UDZO -ov -o "$DMG_PATH"
else
  hdiutil create -volname DevPet -srcfolder "$STAGE_PATH" -format UDZO -ov "$DMG_PATH"
fi
hdiutil verify "$DMG_PATH"
printf 'Created %s\n' "$DMG_PATH"
# Temporary staging is intentionally left for the OS to clean; no broad deletion commands.

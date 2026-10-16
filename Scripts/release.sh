#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$TASK_ROOT/Scripts/build.sh"
if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then "$TASK_ROOT/Scripts/sign.sh"; fi
"$TASK_ROOT/Scripts/dmg.sh"
if [[ -n "${DEVELOPER_ID_APPLICATION:-}" && -n "${NOTARY_PROFILE:-}" ]]; then
  "$TASK_ROOT/Scripts/notarize.sh"
  REQUIRE_NOTARIZATION=1 "$TASK_ROOT/Scripts/validate.sh"
else
  "$TASK_ROOT/Scripts/validate.sh"
  printf 'Local release only: not notarized.\n'
fi

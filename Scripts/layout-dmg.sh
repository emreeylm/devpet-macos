#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DMG_LAYOUT=1 "$TASK_ROOT/Scripts/dmg.sh"

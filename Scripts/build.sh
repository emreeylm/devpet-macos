#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TASK_ROOT"
mkdir -p dist
xcodebuild -project DevPet.xcodeproj -scheme DevPet -configuration Release -derivedDataPath build/DerivedData ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build >build-release.log 2>&1 || { tail -80 build-release.log; exit 1; }
/usr/bin/ditto build/DerivedData/Build/Products/Release/DevPet.app dist/DevPet.app
/usr/bin/codesign --force --sign - dist/DevPet.app
/usr/bin/codesign --verify --strict dist/DevPet.app
/usr/bin/lipo -info dist/DevPet.app/Contents/MacOS/DevPet
printf 'Built %s/dist/DevPet.app (ad-hoc signed, not notarized)\n' "$TASK_ROOT"

#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/.build"
DEST="${1:-$ROOT/dist}"
APP="$DEST/掰.app"
mkdir -p "$BUILD/ModuleCache" "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc -O -swift-version 5 -target arm64-apple-macosx14.0 \
  -module-cache-path "$BUILD/ModuleCache" \
  "$ROOT"/Sources/*.swift -o "$APP/Contents/MacOS/AngleParty"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/BrandIcon.png" "$APP/Contents/Resources/"
cp "$ROOT"/Resources/*.wav "$APP/Contents/Resources/"
cp "$ROOT"/Resources/*.txt "$APP/Contents/Resources/"
cp "$ROOT/README.md" "$APP/Contents/Resources/使用说明.md"
mkdir -p "$BUILD/IconAssets"
xcrun actool "$ROOT/Resources/AppIcon.icon" --compile "$BUILD/IconAssets" \
  --app-icon AppIcon --enable-on-demand-resources NO \
  --minimum-deployment-target 14.0 --platform macosx \
  --output-partial-info-plist "$BUILD/IconAssets/icon-info.plist" --output-format human-readable-text
cp "$BUILD/IconAssets/Assets.car" "$APP/Contents/Resources/"
cp "$BUILD/IconAssets/AppIcon.icns" "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
printf 'Built: %s\n' "$APP"

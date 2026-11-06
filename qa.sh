#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
QA="$ROOT/.build/QA.app"
mkdir -p "$QA/Contents/MacOS" "$QA/Contents/Resources" "$ROOT/.build/ModuleCache"
cp "$ROOT/Resources/BrandIcon.png" "$QA/Contents/Resources/"
cp "$ROOT/Resources/Creak.wav" "$QA/Contents/Resources/"
xcrun swiftc -D DEBUG -swift-version 5 -module-cache-path "$ROOT/.build/ModuleCache" \
  "$ROOT/Sources/GameEngine.swift" "$ROOT/Sources/Sensor.swift" \
  "$ROOT/Sources/MotionSound.swift" "$ROOT/Sources/CreakAudio.swift" \
  "$ROOT/Sources/Appearance.swift" "$ROOT/Sources/GameSession.swift" "$ROOT/Sources/ContentView.swift" \
  "$ROOT/Tools/RenderPreviews.swift" -o "$QA/Contents/MacOS/QA"
"$QA/Contents/MacOS/QA" "${1:-$ROOT/.build/previews}"

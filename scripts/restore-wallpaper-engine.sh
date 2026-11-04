#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
ORIG_SHA="583c5bf5ad4204ddb8696c562b3c85eba4d4723e"
BASE="https://raw.githubusercontent.com/kawaiiepic/SekaiPop/${ORIG_SHA}"

echo "Restoring wallpaper files from ${ORIG_SHA}..."
curl -fsSL "$BASE/sekaipop/modules/sekai/background/WallpaperLayer.qml" \
  -o sekaipop/modules/sekai/background/WallpaperLayer.qml
curl -fsSL "$BASE/sekaipop/services/WallpaperService.qml" \
  -o sekaipop/services/WallpaperService.qml
curl -fsSL "$BASE/sekaipop/modules/sekai/wallpaperSelector/WallpaperFace.qml" \
  -o sekaipop/modules/sekai/wallpaperSelector/WallpaperFace.qml

echo "Applying wallpaper-engine patches..."
patch -p1 < scripts/wallpaper-engine.patch

rm -f scripts/size-test.txt

echo "Done. Review with: git status && git diff"

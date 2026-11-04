#!/usr/bin/env bash
# Restores full WallpaperLayer / WallpaperService / WallpaperFace from a known-good
# commit, then applies scripts/wallpaper-engine.patch (engineActive hide-layer,
# stop-on-setWallpaper, Engine gallery + previews).
#
# Required once after cloning/pulling umbriel-port until those three files are
# committed at full size (GitHub tool size limits left stubs on the branch).
#
# Usage (from repo root):
#   bash scripts/restore-wallpaper-engine.sh
#   git add sekaipop/modules/sekai/background/WallpaperLayer.qml \
#           sekaipop/services/WallpaperService.qml \
#           sekaipop/modules/sekai/wallpaperSelector/WallpaperFace.qml
#   git commit -m "Restore wallpaper files + linux-wallpaperengine integration"
#   git push

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
ORIG_SHA="583c5bf5ad4204ddb8696c562b3c85eba4d4723e"
BASE="https://raw.githubusercontent.com/kawaiiepic/SekaiPop/${ORIG_SHA}"

if [[ ! -f scripts/wallpaper-engine.patch ]]; then
  echo "error: scripts/wallpaper-engine.patch missing" >&2
  exit 1
fi

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

echo ""
echo "Done. Review with: git status && git diff --stat"
echo "Then commit and push the three restored .qml files."

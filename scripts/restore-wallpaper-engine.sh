#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
LAYER="sekaipop/modules/sekai/background/WallpaperLayer.qml"
SERVICE="sekaipop/services/WallpaperService.qml"
ORIG_SHA="583c5bf5ad4204ddb8696c562b3c85eba4d4723e"

echo "Restoring WallpaperLayer + WallpaperService from ${ORIG_SHA}..."
curl -fsSL "https://raw.githubusercontent.com/kawaiiepic/SekaiPop/${ORIG_SHA}/${LAYER}" -o "$LAYER"
curl -fsSL "https://raw.githubusercontent.com/kawaiiepic/SekaiPop/${ORIG_SHA}/${SERVICE}" -o "$SERVICE"

echo "Applying wallpaper-engine patches..."
patch -p1 < scripts/wallpaper-engine.patch

echo "Done. Review and commit."

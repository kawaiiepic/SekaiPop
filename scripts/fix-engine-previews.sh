#!/usr/bin/env bash
# 1) Restore Face + Wheel from last good full versions
# 2) Apply Engine preview loading fixes
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GOOD_SHA="2b9fca9e8e7fb635dac343d3d6aa0918ceded910"
BASE="https://raw.githubusercontent.com/kawaiiepic/SekaiPop/${GOOD_SHA}"

FACE="sekaipop/modules/sekai/wallpaperSelector/WallpaperFace.qml"
WHEEL="sekaipop/modules/sekai/wallpaperSelector/WallpaperWheel.qml"

echo "Restoring Face + Wheel from ${GOOD_SHA}..."
curl -fsSL "$BASE/$FACE" -o "$FACE"
curl -fsSL "$BASE/$WHEEL" -o "$WHEEL"

echo "Applying Engine preview fixes..."
python3 - "$FACE" "$WHEEL" <<'PY'
import sys
from pathlib import Path

face_path, wheel_path = Path(sys.argv[1]), Path(sys.argv[2])

t = face_path.read_text()

old_items = """    function engineItems() {
        const out = []
        for (const it of WallpaperEngineService.entries) {
            const prevs = WallpaperEngineService.previewCandidates(it.path)
            out.push({
                fileName: it.name || it.id,
                filePath: it.path,
                fileSize: 0,
                fileModified: 0,
                engine: true,
                engineId: it.id,
                previewPath: prevs.length ? prevs[0] : ""
            })
        }
        return out
    }"""
new_items = """    function engineItems() {
        const out = []
        for (const it of WallpaperEngineService.entries) {
            const prevs = WallpaperEngineService.previewCandidates(it.path)
            out.push({
                fileName: it.name || it.id,
                filePath: it.path,
                fileSize: 0,
                fileModified: 0,
                engine: true,
                engineId: it.id,
                previewCandidates: prevs,
                previewPath: prevs.length ? prevs[0] : ""
            })
        }
        return out
    }"""
if old_items not in t:
    raise SystemExit("engineItems block not found")
t = t.replace(old_items, new_items, 1)

old_src = "source: cell.wh ? cell.wh.thumb : WallpaperService.thumbUrl(cell.path)"
new_src = """source: {
                            if (cell.wh)
                                return cell.wh.thumb
                            if (cell.modelData.engine) {
                                const cands = cell.modelData.previewCandidates || []
                                if (thumb.enginePreviewIdx < cands.length)
                                    return "file://" + cands[thumb.enginePreviewIdx]
                                return ""
                            }
                            return WallpaperService.thumbUrl(cell.path)
                        }
                        property int enginePreviewIdx: 0
                        onStatusChanged: {
                            if (status === Image.Error && cell.modelData && cell.modelData.engine) {
                                const cands = cell.modelData.previewCandidates || []
                                if (thumb.enginePreviewIdx + 1 < cands.length)
                                    thumb.enginePreviewIdx++
                            }
                        }
                        property string engineKey: cell.modelData && cell.modelData.engine
                            ? (cell.modelData.engineId || cell.modelData.filePath || "") : ""
                        onEngineKeyChanged: thumb.enginePreviewIdx = 0"""
if old_src not in t:
    raise SystemExit("grid thumb source not found")
t = t.replace(old_src, new_src, 1)

old_view = '            face.viewPath = (it && it.engine && it.previewPath) ? it.previewPath : (it ? it.filePath : "")'
new_view = """            if (it && it.engine) {
                const cands = it.previewCandidates || (it.previewPath ? [it.previewPath] : [])
                face.viewPath = cands.length ? cands[0] : ""
            } else {
                face.viewPath = it ? it.filePath : ""
            }"""
if old_view not in t:
    raise SystemExit("viewPath line not found")
t = t.replace(old_view, new_view, 1)
face_path.write_text(t)
print("Face OK")

t = wheel_path.read_text()
old = 'source: !gon.valid ? "" : (gon.entry && gon.entry.wh ? gon.entry.wh.thumb : WallpaperService.thumbUrl(gon.path))'
new = """source: {
                            if (!gon.valid)
                                return ""
                            if (gon.entry && gon.entry.wh)
                                return gon.entry.wh.thumb
                            if (gon.entry && gon.entry.engine) {
                                const cands = gon.entry.previewCandidates || []
                                if (thumb.enginePreviewIdx < cands.length)
                                    return "file://" + cands[thumb.enginePreviewIdx]
                                return ""
                            }
                            return WallpaperService.thumbUrl(gon.path)
                        }
                        property int enginePreviewIdx: 0
                        onStatusChanged: {
                            if (status === Image.Error && gon.entry && gon.entry.engine) {
                                const cands = gon.entry.previewCandidates || []
                                if (thumb.enginePreviewIdx + 1 < cands.length)
                                    thumb.enginePreviewIdx++
                            }
                        }
                        property string engineKey: gon.entry && gon.entry.engine
                            ? (gon.entry.engineId || gon.entry.filePath || "") : ""
                        onEngineKeyChanged: thumb.enginePreviewIdx = 0"""
if old not in t:
    raise SystemExit("wheel thumb source not found")
t = t.replace(old, new, 1)

old_sharp = 'source: gon.sharpOn && gon.valid && gon.path !== "" ? "file://" + gon.path : ""'
new_sharp = """source: {
                            if (!gon.sharpOn || !gon.valid)
                                return ""
                            if (gon.entry && gon.entry.engine) {
                                const cands = gon.entry.previewCandidates || []
                                return cands.length ? ("file://" + cands[0]) : ""
                            }
                            return gon.path !== "" ? ("file://" + gon.path) : ""
                        }"""
if old_sharp not in t:
    raise SystemExit("wheel sharp source not found")
t = t.replace(old_sharp, new_sharp, 1)
wheel_path.write_text(t)
print("Wheel OK")
print("Done. Commit with:")
print("  git add sekaipop/modules/sekai/wallpaperSelector/WallpaperFace.qml sekaipop/modules/sekai/wallpaperSelector/WallpaperWheel.qml")
print("  git commit -m 'fix(wallpaper): Engine gallery previews from preview.jpg/png'")
print("  git push")
PY

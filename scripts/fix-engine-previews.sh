#!/usr/bin/env bash
# Patch WallpaperFace.qml + WallpaperWheel.qml so Engine gallery previews load.
# WallpaperEngineService.qml (preview.jpg-first candidates) is already on the branch.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FACE="sekaipop/modules/sekai/wallpaperSelector/WallpaperFace.qml"
WHEEL="sekaipop/modules/sekai/wallpaperSelector/WallpaperWheel.qml"

python3 - "$FACE" "$WHEEL" <<'PY'
import sys
from pathlib import Path

face_path, wheel_path = Path(sys.argv[1]), Path(sys.argv[2])

# --- Face ---
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
                // full candidate list so the Image can fall through on Error
                previewCandidates: prevs,
                previewPath: prevs.length ? prevs[0] : ""
            })
        }
        return out
    }"""
if old_items not in t:
    print("WARN: engineItems block not found (already patched?)", file=sys.stderr)
else:
    t = t.replace(old_items, new_items, 1)
    print("patched engineItems")

old_src = "source: cell.wh ? cell.wh.thumb : WallpaperService.thumbUrl(cell.path)"
new_src = """source: {
                            if (cell.wh)
                                return cell.wh.thumb
                            // Engine packages are folders; try preview.* candidates in order.
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
                        // Reset when the cell's package changes (not when we advance candidates).
                        property string engineKey: cell.modelData && cell.modelData.engine
                            ? (cell.modelData.engineId || cell.modelData.filePath || "") : ""
                        onEngineKeyChanged: thumb.enginePreviewIdx = 0"""
if old_src not in t:
    print("WARN: grid thumb source not found (already patched?)", file=sys.stderr)
else:
    t = t.replace(old_src, new_src, 1)
    print("patched grid thumb source")

old_view = '            face.viewPath = (it && it.engine && it.previewPath) ? it.previewPath : (it ? it.filePath : "")'
new_view = """            // Engine packages: first preview candidate (Image falls through if missing).
            if (it && it.engine) {
                const cands = it.previewCandidates || (it.previewPath ? [it.previewPath] : [])
                face.viewPath = cands.length ? cands[0] : ""
            } else {
                face.viewPath = it ? it.filePath : ""
            }"""
if old_view not in t:
    print("WARN: viewPath line not found (already patched?)", file=sys.stderr)
else:
    t = t.replace(old_view, new_view, 1)
    print("patched viewPath")

face_path.write_text(t)

# --- Wheel ---
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
    print("WARN: wheel thumb source not found (already patched?)", file=sys.stderr)
else:
    t = t.replace(old, new, 1)
    print("patched wheel thumb source")

old_sharp = 'source: gon.sharpOn && gon.valid && gon.path !== "" ? "file://" + gon.path : ""'
new_sharp = """source: {
                            if (!gon.sharpOn || !gon.valid)
                                return ""
                            // Engine packages have no full image path — preview is the sharp source.
                            if (gon.entry && gon.entry.engine) {
                                const cands = gon.entry.previewCandidates || []
                                return cands.length ? ("file://" + cands[0]) : ""
                            }
                            return gon.path !== "" ? ("file://" + gon.path) : ""
                        }"""
if old_sharp not in t:
    print("WARN: wheel sharp source not found (already patched?)", file=sys.stderr)
else:
    t = t.replace(old_sharp, new_sharp, 1)
    print("patched wheel sharp source")

wheel_path.write_text(t)
print("Done. Review with: git diff -- sekaipop/modules/sekai/wallpaperSelector/")
PY

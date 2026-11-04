import QtQuick
import qs.services

// STUB — run: bash scripts/restore-wallpaper-engine.sh
Item {
    id: face
    property string source: "folder"
    readonly property bool onEngine: face.source === "engine"
    Component.onCompleted: console.warn("WallpaperFace stub — run scripts/restore-wallpaper-engine.sh")
}

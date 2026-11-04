pragma Singleton
import QtQuick
import qs.services

// STUB — run: bash scripts/restore-wallpaper-engine.sh
Singleton {
    id: root
    readonly property bool engineActive: WallpaperEngineService.active
    function stopEngineIfNeeded() {
        if (WallpaperEngineService.active)
            WallpaperEngineService.stop()
    }
    property string defaultPath: ""
    property var screenPaths: ({})
    property bool restoring: true
    readonly property bool ready: false
    readonly property string themeScreen: ""
    readonly property string currentPath: ""
    function pathFor(name) { return "" }
    function imageFor(path) { return "" }
    function setWallpaper(path, screenName) {}
    function isVideo(path) { return false }
    Component.onCompleted: console.warn("WallpaperService stub — run scripts/restore-wallpaper-engine.sh")
}

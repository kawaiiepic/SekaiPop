import QtQuick
import Quickshell
import qs.services
import Quickshell.Wayland
import qs.modules.common
import qs.modules.sekai.editMode

// TEMP: full file will be restored by scripts/restore-wallpaper-engine.sh
// Run: bash scripts/restore-wallpaper-engine.sh
PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "sekaipop-wallpaper"
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }

    readonly property bool wallpaperEnabled: SettingsService.flag("wallpaper.enabled")
    readonly property bool engineActive: WallpaperService.engineActive
    readonly property bool layerActive: win.wallpaperEnabled && !win.engineActive

    Component.onCompleted: console.warn("WallpaperLayer stub — run scripts/restore-wallpaper-engine.sh")
}

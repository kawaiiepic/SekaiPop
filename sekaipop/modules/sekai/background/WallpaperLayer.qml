import QtQuick
import Quickshell
import qs.services
import Quickshell.Wayland
import qs.modules.common
import qs.modules.sekai.editMode

// Restored base; engine hide applied in follow-up if needed.
// See commit 583c5bf for full history before accidental placeholder.
PanelWindow {
    id: win

    readonly property var mt: Theme.of(screen)

    readonly property bool wallpaperEnabled: SettingsService.flag("wallpaper.enabled")
    readonly property bool engineActive: WallpaperService.engineActive
    readonly property bool layerActive: win.wallpaperEnabled && !win.engineActive
    onLayerActiveChanged: {
        if (win.layerActive)
            restoreWallpaperResources();
        else
            releaseWallpaperResources();
    }
    onWallpaperEnabledChanged: {
        if (win.layerActive)
            restoreWallpaperResources();
        else
            releaseWallpaperResources();
    }

    required property var modelData
    screen: modelData

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "sekaipop-wallpaper"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Minimal stub body so the shell can load; replace with full WallpaperLayer from 583c5bf
    // plus the engineActive/layerActive wiring above when re-applying the full file.
    function releaseWallpaperResources() {}
    function restoreWallpaperResources() {}
}

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common

// Separate from desktop widget loaders: this must survive wallpaper ownership
// hiding the widgets, otherwise the user has no way to hand clicks back.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    visible: WallpaperService.engineActive && LockState.phase === "idle" && !EditMode.active
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "sekaipop-engine-input"
    // Above the background renderer, below application windows/fullscreen apps.
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { bottom: true; right: true }

    readonly property var mt: Theme.of(screen)
    readonly property real uiScale: ShellScale.forScreen(screen)
    readonly property bool wallpaperOwnsClicks: SettingsService.flag("wallpaper.engine.interactive")
    readonly property bool barVisible: SettingsService.flag("bar.visible")
    margins.bottom: Math.round((14 + (barVisible && BarPositionService.position === "bottom" ? BarPositionService.thickness : 0)) * uiScale)
    margins.right: Math.round((14 + (barVisible && BarPositionService.position === "right" ? BarPositionService.thickness : 0)) * uiScale)
    implicitWidth: Math.ceil((pointer.containsMouse ? actionLabel.implicitWidth + 48 * uiScale : 34 * uiScale))
    implicitHeight: Math.ceil(30 * uiScale)
    mask: Region { item: button }

    Rectangle {
        id: button
        anchors.fill: parent
        radius: 6 * win.uiScale
        color: pointer.pressed ? win.mt.surfaceHover : win.mt.surface
        border.width: 1
        border.color: pointer.containsMouse ? win.mt.accentCyan : win.mt.surfaceDivider
        opacity: pointer.containsMouse ? 1 : 0.8
        Accessible.role: Accessible.Button
        Accessible.name: win.wallpaperOwnsClicks
            ? "Give Quickshell desktop clicks and show widgets"
            : "Give wallpaper desktop clicks and hide widgets"
        Accessible.onPressAction: SettingsService.toggle("wallpaper.engine.interactive")

        Text {
            id: actionLabel
            visible: pointer.containsMouse
            anchors.left: parent.left
            anchors.leftMargin: 10 * win.uiScale
            anchors.verticalCenter: parent.verticalCenter
            text: win.wallpaperOwnsClicks ? "Show widgets · Quickshell clicks" : "Hide widgets · wallpaper clicks"
            color: win.mt.ink
            font.family: win.mt.fontFamily
            font.pixelSize: 11 * win.uiScale
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 8 * win.uiScale
            anchors.verticalCenter: parent.verticalCenter
            text: win.wallpaperOwnsClicks ? "WE" : "QS"
            color: win.wallpaperOwnsClicks ? win.mt.accentCyan : win.mt.ink
            font.family: "monospace"
            font.pixelSize: 11 * win.uiScale
            font.bold: true
        }
        MouseArea {
            id: pointer
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: SettingsService.toggle("wallpaper.engine.interactive")
        }
    }
}

pragma Singleton
import Quickshell
// Kept as the geometry service name used by the existing board and screenshot picker.
Singleton {
    property bool active: false
    readonly property var windowList: Compositor.clients
    readonly property var windowByAddress: Compositor.windowByAddress
    readonly property var monitors: Compositor.monitorData
    function updateAll() {}
}

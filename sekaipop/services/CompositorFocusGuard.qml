import QtQuick
import Quickshell
import Quickshell.Wayland

// Layer focus comes from Umbriel; xdg-popup dismissal comes from PopupWindow.grabFocus.
Scope {
    id: root
    property bool active: false
    property var windows: []
    property var namespaces: []
    property bool hadFocus: false
    signal cleared()
    onActiveChanged: { hadFocus = false; if (active) check() }
    function check() {
        if (!root.active) return
        const names = root.namespaces
        const focused = Compositor.layerSnapshot.some(l => l.focused && names.indexOf(l.namespace) >= 0)
        if (focused) root.hadFocus = true
        else if (root.hadFocus) { root.hadFocus = false; root.cleared() }
    }
    Connections { target: Compositor; function onLayerSnapshotChanged() { root.check() } }
    Instantiator {
        model: root.windows
        delegate: Connections {
            required property var modelData
            target: modelData
            function onVisibleChanged() {
                // Only popups have grabFocus. Layer windows dismiss through focus snapshots.
                if (root.active && modelData && modelData.grabFocus === true && !modelData.visible)
                    root.cleared()
            }
        }
    }
}

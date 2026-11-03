pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// The two things the dock (Dock.qml) needs from Hyprland that Quickshell's own
// window list does not give it:
//
// 1. MINIMIZING. Hyprland has no "minimize". The usual answer, and the one used
//    here: send the window to a hidden special workspace ("special:dockmin"). It
//    vanishes from the screen but stays open, and the dock still lists it (its
//    key shows a hollow dot). Restoring sends it back to the workspace it came
//    from (remembered in `origins`, in memory — after a shell reload it comes
//    back to the workspace you are on instead) and focuses it.
//
// 2. WINDOW GEOMETRY, for "Smart hide": the dock hides only while a window is
//    in its way. `hyprctl clients -j` / `monitors -j` are read (and only while at
//    least one dock is in smart-hide mode) whenever Hyprland says a window
//    opened, moved, resized or went full screen.
//
//   import qs.services
//   DockService.minimize(toplevel) / restore(toplevel) / isMinimized(toplevel)
//   DockService.covers("DP-1", { x, y, w, h })   // a window overlaps this rect (screen pixels)
Singleton {
    id: root

    function isMinimized(t) { return !!t && t.lastIpcObject.minimized === true }
    function addrOf(t) { return t.address }
    function hexAddr(address) { return String(address || "") }
    function focusAddress(address, workspace) { Compositor.action("window-focus", { window: String(address) }) }
    function minimize(t) {
        if (!t) return
        if (!t.lastIpcObject.minimizable) {
            Quickshell.execDetached(["notify-send", "SekaiPop", "Umbriel can minimize floating windows. Float this window first."])
            return
        }
        Compositor.action("window-minimize", { window: t.address })
    }
    function restore(t, focus) {
        if (t) Compositor.action("window-focus", { window: t.address })
    }

    // ===== geometry for smart hide =====
    property var holders: ({})
    readonly property bool wanted: Object.keys(root.holders).length > 0

    // Each dock that is in smart-hide mode holds a key while it is. The key is the
    // dock window's own (newHoldKey), never one it shares with another dock: keyed by
    // monitor, a dock rebuilt on the same monitor (the shell builds it twice at startup)
    // found the key already held and skipped its own claim, and the old dock let go of it
    // on its way out. With nobody holding, the window list was never asked for again and
    // window events were ignored, so Smart hide stayed on whatever it had last seen, or on
    // nothing at all: the dock stood over a maximized window (issue #116).
    property int keysGiven: 0

    // A key for a new holder, unique for the life of the shell. Call it once, when the
    // holder is built (not from a binding: it counts up).
    function newHoldKey(prefix) {
        root.keysGiven += 1
        return prefix + "#" + root.keysGiven
    }

    function hold(key, on) {
        if (!key)
            return
        const has = key in root.holders
        if (has === on)
            return
        const next = Object.assign({}, root.holders)
        if (on)
            next[key] = true
        else
            delete next[key]
        root.holders = next
    }

    readonly property var clients: Compositor.clients
    readonly property var monitors: Compositor.monitorData
    readonly property bool clientsSeen: Compositor.windowsSeen
    readonly property bool monitorsSeen: Compositor.outputsSeen
    readonly property bool ready: clientsSeen && monitorsSeen
    function refresh() {}

    // Does any window on the monitor's visible workspace overlap `rect`
    // ({ x, y, w, h } in that monitor's own pixels, the top-left corner being 0,0)?
    // Minimized and hidden windows never count.
    function covers(screenName, rect) {
        let mon = null
        for (const m of root.monitors) {
            if (m.name === screenName) {
                mon = m
                break
            }
        }
        if (!mon || !mon.activeWorkspace)
            return false
        const ws = mon.activeWorkspace.id
        for (const c of root.clients) {
            if (c.mapped === false || c.hidden === true)
                continue
            if (!c.workspace || c.workspace.id !== ws)
                continue
            const cx = c.at[0] - mon.x
            const cy = c.at[1] - mon.y
            if (cx < rect.x + rect.w && cx + c.size[0] > rect.x
                    && cy < rect.y + rect.h && cy + c.size[1] > rect.y)
                return true
        }
        return false
    }
}

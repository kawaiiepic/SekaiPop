pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import "../modules/common/functions/UmbrielMath.js" as UM

// One event stream owns compositor state. The shell-facing models retain object identity
// between snapshots, so consumers and Connections can follow individual windows.
Singleton {
    id: root
    readonly property string socketPath: Quickshell.env("UMBRIEL_SOCKET") ||
        ((Quickshell.env("XDG_RUNTIME_DIR") && Quickshell.env("WAYLAND_DISPLAY"))
            ? Quickshell.env("XDG_RUNTIME_DIR") + "/umbriel-" + Quickshell.env("WAYLAND_DISPLAY") + ".sock" : "")
    readonly property bool usingLua: false
    property bool connected: false
    property bool outputsSeen: false
    property bool windowsSeen: false
    property var outputSnapshot: []
    property var workspaceSnapshot: []
    property var windowSnapshot: []
    property var keyboardLayout: ({ names: [], current_index: 0 })
    property var layerSnapshot: []
    property bool overviewOpen: false
    property QtObject toplevels: QtObject { property var values: [] }
    property QtObject monitors: QtObject { property var values: [] }
    property QtObject workspaces: QtObject { property var values: [] }
    property var focusedMonitor: null
    property var focusedWorkspace: null
    property var activeToplevel: null
    property var clients: []
    property var monitorData: []
    property var windowByAddress: ({})
    property var cache: ({})
    property var workspaceIds: ({})
    property int nextWorkspaceId: 0
    property var actionQueue: []
    signal rawEvent(var event)
    signal actionError(string message)

    Component {
        id: entry
        QtObject {
            property string address: ""
            property string title: ""
            property string name: ""
            property int id: 0
            property int index: 0
            property bool focused: false
            property bool activated: false
            property bool urgent: false
            property var monitor: null
            property var workspace: null
            property var activeWorkspace: null
            property var lastIpcObject: ({})
            property var wayland: null
            property QtObject toplevels: QtObject { property var values: [] }
        }
    }

    function object(key, live) {
        live[key] = true
        if (!root.cache[key]) root.cache[key] = entry.createObject(root)
        return root.cache[key]
    }
    function localId(id) {
        if (!id) return 0
        if (!root.workspaceIds[id]) root.workspaceIds[id] = ++root.nextWorkspaceId
        return root.workspaceIds[id]
    }
    function rebuild() {
        const live = {}, wsById = {}, monByName = {}
        const ms = root.outputSnapshot.filter(o => o.enabled).map((o, i) => {
            const m = root.object("output:" + o.name, live)
            m.id = i; m.name = o.name; m.focused = o.focused === true
            monByName[o.name] = m
            return m
        })
        const ws = root.workspaceSnapshot.map(w => {
            const v = root.object("workspace:" + w.id, live)
            v.id = root.localId(w.id); v.index = w.index; v.name = w.name
            v.monitor = monByName[w.output] || null; v.focused = w.focused === true
            v.urgent = w.urgent === true
            v.lastIpcObject = Object.assign({}, w, { hasfullscreen: root.windowSnapshot.some(window =>
                window.workspace === w.id && window.fullscreen === true && window.visible !== false) })
            wsById[w.id] = v
            return v
        })
        const md = root.outputSnapshot.filter(o => o.enabled).map((o, i) => {
            const m = monByName[o.name]
            m.activeWorkspace = wsById[o.active_workspace] || null
            const d = UM.monitor(o, i, m.activeWorkspace ? m.activeWorkspace.id : 0)
            m.lastIpcObject = d
            return d
        })
        const byAddress = {}, clients = []
        const ts = root.windowSnapshot.map(w => {
            const t = root.object("window:" + w.id, live)
            const m = monByName[w.output]
            t.address = w.id; t.title = w.title || ""; t.activated = w.active === true
            t.workspace = wsById[w.workspace] || null; t.monitor = m || null
            const d = UM.windowData(w, t.workspace ? t.workspace.id : 0, m ? m.id : -1)
            t.lastIpcObject = d
            byAddress[w.id] = d; clients.push(d)
            return t
        })
        for (const w of ws) w.toplevels.values = ts.filter(t => t.workspace === w)
        root.monitors.values = ms; root.workspaces.values = ws; root.toplevels.values = ts
        root.focusedMonitor = ms.find(m => m.focused) || null
        root.focusedWorkspace = root.focusedMonitor ? root.focusedMonitor.activeWorkspace : null
        root.activeToplevel = ts.find(t => t.activated) || null
        root.clients = clients; root.monitorData = md; root.windowByAddress = byAddress
        for (const key of Object.keys(root.cache)) {
            if (!live[key]) { root.cache[key].destroy(); delete root.cache[key] }
        }
    }
    function monitorFor(screen) {
        return screen ? root.monitors.values.find(m => m.name === screen.name) || null : null
    }
    function workspaceAction(action, id) {
        const w = root.workspaces.values.find(v => v.id === Number(id))
        if (!w) { root.actionError("Workspace is no longer available"); return }
        root.action(action, { workspace: UM.workspaceSelector(w.lastIpcObject), output: w.lastIpcObject.output })
    }
    function focusWorkspace(output, index) {
        root.action("workspace-switch", { workspace: index, output: output })
    }
    function action(name, fields) {
        if (!root.connected) { root.actionError("Umbriel IPC is disconnected"); return }
        if (root.actionQueue.length >= 128) { root.actionError("Too many queued Umbriel actions"); return }
        root.actionQueue = root.actionQueue.concat([Object.assign({ cmd: "action", action: name }, fields || {})])
        root.pumpRequests()
    }
    function pumpRequests() {
        if (requester.running || root.actionQueue.length === 0) return
        const request = root.actionQueue[0]
        root.actionQueue = root.actionQueue.slice(1)
        requester.exec(["python3", Directories.script("umbriel/request.py"), root.socketPath, JSON.stringify(request)])
    }
    function requestFinished(code, message) {
        if (code !== 0) {
            // A failed focus must not be followed by a move of some other focused window.
            root.actionQueue = []
            root.actionError(message.trim() || "Umbriel action failed")
        }
        Qt.callLater(root.pumpRequests)
    }
    // Legacy refresh hooks are intentionally empty: subscriptions already provide full snapshots.
    function refreshToplevels() {}
    function refreshMonitors() {}
    function refreshWorkspaces() {}
    // Small adapter for existing shell actions. New callers should use typed action().
    function dispatch(command) {
        let match
        if ((match = /^(focuswindow|closewindow) address:(.+)$/.exec(command))) {
            root.action(match[1] === "focuswindow" ? "window-focus" : "window-close", { window: match[2] })
        } else if ((match = /^workspace (\d+)$/.exec(command))) {
            root.workspaceAction("workspace-switch", Number(match[1]))
        } else if ((match = /^focusmonitor (.+)$/.exec(command))) {
            const m = root.monitors.values.find(m => m.name === match[1])
            if (m && m.activeWorkspace) root.workspaceAction("workspace-switch", m.activeWorkspace.id)
        } else if ((match = /^movetoworkspacesilent (\d+),address:(.+)$/.exec(command))) {
            // Umbriel's move action targets the focused window; requests on this socket are ordered.
            root.action("window-focus", { window: match[2] })
            root.workspaceAction("window-move-to-workspace-silent", Number(match[1]))
        } else if ((match = /^movewindowpixel exact (-?\d+) (-?\d+),address:(.+)$/.exec(command))) {
            const t = root.toplevels.values.find(t => t.address === match[3])
            const o = t && t.monitor ? root.outputSnapshot.find(o => o.name === t.monitor.name) : null
            if (o) root.action("window-move-to", { anchor: "top_left", x: Number(match[1]) - o.usable_area.x,
                y: Number(match[2]) - o.usable_area.y, window: match[3] })
        } else {
            root.actionError("Unsupported compositor action: " + command)
        }
    }
    function consume(line) {
        let message
        try { message = JSON.parse(line) } catch (e) { console.warn("Umbriel: malformed IPC line"); return }
        if (message.err) { root.actionError(String(message.err)); return }
        switch (message.event) {
        case "windows": root.windowSnapshot = message.data; root.windowsSeen = true; break
        case "workspaces": root.workspaceSnapshot = message.data; break
        case "outputs": root.outputSnapshot = message.data; root.outputsSeen = true; break
        case "keyboard_layout": root.keyboardLayout = message.data; return
        case "overview": root.overviewOpen = message.data.open === true; return
        case "layers": root.layerSnapshot = message.data; return
        default: return
        }
        root.rebuild()
        root.rawEvent({ name: message.event === "windows" ? "openwindow" : "workspacev2",
            data: root.focusedWorkspace ? root.focusedWorkspace.id + "," + root.focusedWorkspace.name : "" })
    }
    function clear() {
        root.connected = false; root.outputsSeen = false; root.windowsSeen = false
        root.actionQueue = []
        root.windowSnapshot = []; root.workspaceSnapshot = []; root.outputSnapshot = []
        root.layerSnapshot = []; root.keyboardLayout = ({ names: [], current_index: 0 })
        root.rebuild()
    }
    Component.onCompleted: {
        if (root.socketPath !== "") { events.connected = true }
    }
    Socket {
        id: events
        path: root.socketPath
        onConnectedChanged: {
            if (connected) {
                root.connected = true; retry.stop()
                write(JSON.stringify({cmd: "subscribe", events: ["workspaces", "windows", "outputs", "keyboard_layout", "overview", "layers"]}) + "\n")
                flush()
            } else { root.clear(); retry.restart() }
        }
        // Quickshell 0.3.2 cleans up its QLocalSocket after emitting error.
        // Setting connected=false here re-enters cleanup and can dereference null.
        onError: { root.clear(); retry.restart() }
        parser: SplitParser { onRead: data => root.consume(data) }
    }
    // Umbriel closes ordinary IPC connections after one reply. A short-lived
    // helper owns each request; serial execution also preserves focus/move order.
    Process {
        id: requester
        stderr: StdioCollector { id: requestErrors }
        onExited: (code, status) => root.requestFinished(code, requestErrors.text)
    }
    Timer { id: retry; interval: 1000; onTriggered: { if (root.socketPath !== "") events.connected = true } }
    onActionError: message => console.warn("Umbriel: " + message)
}

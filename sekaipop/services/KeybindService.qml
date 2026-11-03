pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import "../modules/common/functions/KeyBinds.js" as KB

// Read-only shortcuts view. Umbriel owns bindings and configuration reloads.
Singleton {
    id: root
    readonly property string mode: "toml"
    readonly property bool linked: false
    readonly property bool configReadOnly: true
    readonly property bool available: false
    readonly property bool paused: false
    readonly property bool busy: reader.running
    readonly property int changedCount: 0
    property var binds: []
    property var state: ({})
    property bool loaded: false
    readonly property var rows: KB.rows(root.binds, root.state)
    function row(id) { return root.rows.find(r => r.id === id) || null }
    function conflict(combo, id) { return KB.conflict(root.binds, combo, id, root.rows) }
    function refresh() { if (!reader.running) reader.running = true }
    function editConfig() {
        Quickshell.execDetached(["xdg-open", Quickshell.env("UMBRIEL_CONFIG") ||
            (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/umbriel/config.toml"])
    }
    function setKeys(id, combo, taken) { root.editConfig() }
    function reset(id) { root.editConfig() }
    function resetAll() { root.editConfig() }
    function pause() {}
    function resume() {}
    Process {
        id: reader
        command: ["python3", Directories.script("umbriel/config.py"), "binds"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.binds = JSON.parse(text); root.loaded = true }
                catch (e) { console.warn("Could not read Umbriel bindings") }
            }
        }
    }
    Component.onCompleted: root.refresh()
}

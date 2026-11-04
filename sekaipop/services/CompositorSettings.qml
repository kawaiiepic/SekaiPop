pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// Read Umbriel's merged configuration for shell spacing. Editing remains in config.toml.
Singleton {
    id: root
    property var values: ({})
    function num(path, fallback) {
        let value = root.values
        for (const part of path.split(".")) value = value && value[part]
        return typeof value === "number" ? value : (fallback === undefined ? 0 : fallback)
    }
    function refresh() { if (!reader.running) reader.running = true }
    Process {
        id: reader
        command: ["python3", Directories.script("umbriel/config.py"), "config"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.values = JSON.parse(text) }
                catch (e) { console.warn("Could not read Umbriel configuration for shell spacing") }
            }
        }
    }
    Component.onCompleted: root.refresh()
}

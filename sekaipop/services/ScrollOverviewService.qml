pragma Singleton
import Quickshell
import Quickshell.Io

// Umbriel draws its own live overview; no Hyprland plugin is involved.
Singleton {
    readonly property bool available: Compositor.connected
    readonly property bool checked: true
    readonly property bool wanted: true
    readonly property bool loading: false
    readonly property bool loadTried: true
    readonly property string loadLog: "Umbriel built-in overview"
    function dispatch(action) {
        Compositor.action(action === "on" ? "overview-open" : action === "off" ? "overview-close" : "overview-toggle")
    }
    function run(action, fallback) { dispatch(action) }
    function refresh() {}
    function recheck() {}
    function option(name) { return "" }
    function setOption(name, value) {}
    IpcHandler {
        target: "scrolloverview"
        function toggle(): void { dispatch("toggle") }
        function show(): void { dispatch("on") }
        function hide(): void { dispatch("off") }
        function status(): string { return Compositor.overviewOpen ? "open" : "closed" }
    }
}

pragma Singleton
import Quickshell
// Output state is pushed by Umbriel. Edit output configuration in config.toml.
Singleton {
    readonly property var live: Compositor.outputSnapshot
    function refresh() {}
}

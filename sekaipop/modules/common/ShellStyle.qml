pragma Singleton
import QtQuick
import qs.services

// Shell-only skin. The user's palette, mode and system application theme
// remain independent, so disabling a skin restores them without a snapshot.
QtObject {
    readonly property string current: SettingsService.get("appearance.shellTheme") === "cyberpunk" ? "cyberpunk" : "default"
    readonly property bool cyberpunk: current === "cyberpunk"
    readonly property var palette: ({
        border: "#26d9ed", A: "#00edff", B: "#ff3dbb", deep: "#090e1c",
        rimHi: "#548bb3", bezel: "#172c43", wallLight: "#36546e",
        wallMid: "#20384e", wallDark: "#101d30", hardware: "#070b14",
        divider: "#e0f7ff", lens: "#ff3dbb", glint: "#f5ed58",
        hoverTint: "#18344a", boardBg: "#0b1220", boardDot: "#23465b",
        lockMint: "#00edff", lockPink: "#ff3dbb"
    })
    function radius(value) { return cyberpunk ? Math.min(Number(value), 5) : value }
}

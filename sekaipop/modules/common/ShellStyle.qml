pragma Singleton
import QtQuick
import qs.services

// Shell-only skin. The user's palette, mode and system application theme
// remain independent, so disabling a skin restores them without a snapshot.
QtObject {
    readonly property string current: SettingsService.get("appearance.shellTheme") === "cyberpunk" ? "cyberpunk" : "default"
    readonly property bool cyberpunk: current === "cyberpunk"
    readonly property var palette: ({
        border: "#66768d", A: "#d397bd", B: "#91b4d4", deep: "#0b0e16",
        rimHi: "#657389", bezel: "#202630", wallLight: "#66718b",
        wallMid: "#30394b", wallDark: "#19202e", hardware: "#080b10",
        divider: "#d4dae5", lens: "#91b4d4", glint: "#deb2d0",
        hoverTint: "#292437", boardBg: "#0d1119", boardDot: "#303747",
        lockMint: "#d397bd", lockPink: "#91b4d4"
    })
    function radius(value) { return cyberpunk ? Math.min(Number(value), 5) : value }
}

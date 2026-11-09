pragma Singleton
import QtQuick
import qs.services

// Palette for the paper-styled surfaces in the shell that aren't part
// of the navy/cyan/mint Virtual Singer look: the film-strip Overview
// (Overview.qml / FilmStrip.qml), the cork-board cheat sheet
// (CheatSheet.qml / CorkBoard.qml) and the wallpaper board
// (the wallpaper board, now WallpaperFace.qml, and the small pieces it's built from). Kept
// separate from Theme.qml on purpose — nothing here should leak into
// Theme.qml, and nothing in Theme.qml should leak in here.
//
// Auto-registered the same way Theme.qml is (a pragma Singleton file at
// the config's root) — every file just uses `ScrapbookTheme.foo`, no
// import needed.
QtObject {
    id: root

    // ===== paper =====
    readonly property color page: ShellStyle.cyberpunk ? "#19202e" : "#f5eeda"        // cream paper
    readonly property color ink: ShellStyle.cyberpunk ? "#d4dae5" : "#4a4536"         // warm near-black ink

    // ===== accents =====
    readonly property color tapeTeal: ShellStyle.cyberpunk ? "#d397bd" : "#7fb8bd"
    readonly property color tapeCoral: ShellStyle.cyberpunk ? "#91b4d4" : "#e8886f"
    readonly property color tapeMint: ShellStyle.cyberpunk ? "#deb2d0" : "#b7d99a"
    readonly property color tag: ShellStyle.cyberpunk ? "#deb2d0" : "#eec25e"          // mustard hang-tag
    readonly property color accentCurrent: ShellStyle.cyberpunk ? "#d397bd" : "#3fa7c4" // "this one's picked" ring + marker

    // ===== cork board =====
    readonly property color cork: ShellStyle.cyberpunk ? "#19202e" : "#c99a63"
    readonly property color corkLight: ShellStyle.cyberpunk ? "#30394b" : "#dfb883"
    readonly property color corkDark: ShellStyle.cyberpunk ? "#0d1119" : "#a97b48"
    readonly property color corkSpeck: ShellStyle.cyberpunk ? "#303747" : "#6f4a29"
    readonly property color frameWood: ShellStyle.cyberpunk ? "#66768d" : "#9b6a3f"
    readonly property color frameHighlight: ShellStyle.cyberpunk ? "#657389" : "#bd8a58"
    readonly property color frameShade: ShellStyle.cyberpunk ? "#080b10" : "#5b3c22"
    readonly property color noteShadow: ShellStyle.cyberpunk ? "#080b10" : "#4d3220"   // pinned paper's drop shadow
    readonly property color pinPink: ShellStyle.cyberpunk ? "#91b4d4" : "#d98cc0"

    // ===== film strip (the Overview) =====
    readonly property color filmBase: "#18171c"        // the film itself
    readonly property color filmEdge: "#0b0a0e"        // its dark outline / gaps between frames
    readonly property color filmFrame: "#232229"       // one frame's slightly lighter box
    readonly property color filmScreen: "#2b2a33"      // the picture area inside a frame
    readonly property color filmScreenHover: "#2f4a3a" // ...while a window is dragged over it
    readonly property color filmHole: "#e9e3d2"        // sprocket holes (light, like the lamp behind)
    readonly property color filmHoleShade: "#a39d8b"   // their inner shadow
    readonly property color filmPrint: ShellStyle.cyberpunk ? "#deb2d0" : "#f0a63c"       // amber edge print (frame numbers)
    readonly property color filmPrintSoft: ShellStyle.cyberpunk ? "#a0e0f7ff" : "#88f0e8d6" // faint text on the picture area

    // ===== wallpaper board =====
    readonly property color boardBg: (ShellStyle.cyberpunk ? ShellStyle.palette : ThemeService.palette).boardBg            // the tray behind the cards
    readonly property color boardBgClear: Qt.rgba(boardBg.r, boardBg.g, boardBg.b, 0)  // same colour, no alpha (edge fades)
    readonly property color boardDot: (ShellStyle.cyberpunk ? ShellStyle.palette : ThemeService.palette).boardDot           // the dot grid on it
    readonly property color tapePink: ShellStyle.cyberpunk ? "#91b4d4" : "#f4a3c8"           // 4th tape colour (others above)
    readonly property color accentPink: ShellStyle.cyberpunk ? "#91b4d4" : "#ff8fd6"         // same pink as Theme.irisColorPink
    readonly property color labelPaper: ShellStyle.cyberpunk ? "#19202e" : "#fffdf7"         // name tags
    readonly property color inkSoft: ShellStyle.cyberpunk ? "#9ab8cd" : "#8b8aa6"            // captions
}

pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.services

// linux-wallpaperengine (Steam Workshop app 431960) as a wallpaper source.
//
// When active, the image WallpaperLayer is hidden and linux-wallpaperengine
// draws the background. Static / video picks via WallpaperService.stop the
// engine process again.
//
//   WallpaperEngineService.setWallpaper(idOrPath)   start / switch
//   WallpaperEngineService.stop()                   stop and show image layer
//   WallpaperEngineService.entries                  workshop folders (id, path, name)
//
// CLI flags default to the proven set from the quickshell example; override with
// Settings key wallpaper.engine.flags (space-separated, no --screen-root / --bg).
Singleton {
    id: root

    readonly property string defaultFlags: "--layer background --fullscreen-pause-only-active --fullscreen-pause-ignore-appid kitty -v 60 --scaling fit --fps 30"

    // Free-form extra/base flags (no screen roots / --bg). Empty = use defaultFlags.
    readonly property string flagsSetting: {
        const s = String(SettingsService.get("wallpaper.engine.flags") || "").trim()
        return s !== "" ? s : root.defaultFlags
    }

    // Optional override of the Workshop content folder. Empty = auto-detect.
    readonly property string pathOverride: String(SettingsService.get("wallpaper.engine.workshopPath") || "").trim()

    readonly property var candidateRoots: [
        Quickshell.env("HOME") + "/.local/share/Steam/steamapps/workshop/content/431960",
        Quickshell.env("HOME") + "/.steam/steam/steamapps/workshop/content/431960",
        Quickshell.env("HOME") + "/.var/app/com.valvesoftware.Steam/data/Steam/steamapps/workshop/content/431960",
        Quickshell.env("HOME") + "/.steam/root/steamapps/workshop/content/431960"
    ]

    property string workshopPath: ""
    readonly property string workshopUrl: root.workshopPath !== "" ? ("file://" + root.workshopPath) : ""
    readonly property bool available: root.workshopPath !== ""

    property bool active: false
    property string currentId: ""
    property string currentPath: ""
    property string currentName: ""

    // { id, path, name } for each workshop package folder
    property var entries: []

    Process {
        id: engineProc
    }

    Process {
        id: helper
    }

    FolderListModel {
        id: workshopList
        folder: root.workshopUrl
        showDirs: true
        showFiles: false
        sortField: FolderListModel.Name

        onStatusChanged: {
            if (status === FolderListModel.Ready)
                root.rebuildEntries()
        }
        onCountChanged: {
            if (status === FolderListModel.Ready)
                root.rebuildEntries()
        }
    }

    function rebuildEntries() {
        const out = []
        for (let i = 0; i < workshopList.count; i++) {
            const name = workshopList.get(i, "fileName") || ""
            const path = workshopList.get(i, "filePath") || ""
            if (!name || !path)
                continue
            out.push({ id: name, path: path, name: name })
        }
        root.entries = out
    }

    function detectWorkshopPath() {
        if (root.pathOverride !== "") {
            root.workshopPath = root.pathOverride
            return
        }
        detectProc.command = ["sh", "-c",
            "for d in " + root.candidateRoots.map(p => "'" + p.replace(/'/g, "'\\''") + "'").join(" ") + "; do "
            + "[ -d \"$d\" ] && echo \"$d\" && exit 0; done; exit 1"]
        detectProc.running = true
    }

    Process {
        id: detectProc
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim().split("\n")[0] || ""
                if (line !== "")
                    root.workshopPath = line
            }
        }
        onExited: (code) => {
            if (code !== 0 && root.pathOverride === "" && root.workshopPath === "")
                root.workshopPath = root.candidateRoots[0]
        }
    }

    // Most workshop packages ship preview.jpg (project.json "preview");
    // gif/png/webp are less common. Callers try previewCandidates() in order
    // and advance on Image.Error — we cannot stat() from pure QML here.
    function previewPathFor(folderPath) {
        if (!folderPath)
            return ""
        return folderPath + "/preview.jpg"
    }

    function previewCandidates(folderPath) {
        if (!folderPath)
            return []
        return ["preview.jpg", "preview.jpeg", "preview.png", "preview.webp", "preview.gif"]
            .map(n => folderPath + "/" + n)
    }

    function splitFlags(s) {
        return String(s || "").trim().split(/\s+/).filter(a => a.length > 0)
    }

    function buildCommand(bg) {
        const args = ["linux-wallpaperengine"]
        args.push(...root.splitFlags(root.flagsSetting))
        for (const screen of Quickshell.screens) {
            args.push("--screen-root")
            args.push(screen.name)
        }
        args.push("--bg")
        args.push(String(bg))
        return args
    }

    function stop() {
        if (engineProc.running)
            engineProc.running = false
        root.active = false
        root.currentId = ""
        root.currentPath = ""
        root.currentName = ""
        SettingsService.set("wallpaper.engine.active", false)
    }

    function setWallpaper(idOrPath, displayName) {
        if (!idOrPath || String(idOrPath).length === 0)
            return

        const raw = String(idOrPath)
        let bg = raw
        let path = ""
        let name = displayName || ""

        if (raw.indexOf("/") >= 0) {
            path = raw
            const parts = raw.split("/")
            bg = parts[parts.length - 1] || raw
            if (!name)
                name = bg
        } else {
            bg = raw
            if (root.workshopPath !== "")
                path = root.workshopPath + "/" + bg
            if (!name)
                name = bg
        }

        if (engineProc.running)
            engineProc.running = false

        engineProc.command = root.buildCommand(bg)
        engineProc.running = true

        root.active = true
        root.currentId = bg
        root.currentPath = path
        root.currentName = name

        SettingsService.set("wallpaper.engine.active", true)
        SettingsService.set("wallpaper.engine.currentId", bg)
        SettingsService.set("wallpaper.engine.currentPath", path)

        helper.command = ["notify-send", "-i", "preferences-desktop-wallpaper",
            "Wallpaper Engine", "Wallpaper has been updated:\n" + name]
        helper.running = true
    }

    function restoreIfNeeded() {
        if (!SettingsService.flag("wallpaper.engine.active"))
            return
        const id = String(SettingsService.get("wallpaper.engine.currentId") || "")
        if (id === "")
            return
        root.setWallpaper(id)
    }

    Component.onCompleted: {
        root.detectWorkshopPath()
        Qt.callLater(() => Qt.callLater(root.restoreIfNeeded))
    }

    onPathOverrideChanged: root.detectWorkshopPath()
}

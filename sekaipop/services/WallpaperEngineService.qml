pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common

// linux-wallpaperengine (Steam Workshop app 431960) as a wallpaper source.
//
// When active, only WallpaperLayer's image content is hidden and linux-wallpaperengine
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
    property bool restorePending: true

    // React to the renderer actually mapping, including slow starts and output
    // changes. Ignore unrelated layer changes to avoid a restacking feedback loop.
    readonly property string rendererLayers: {
        const pid = Number(engineProc.processId || 0)
        if (!root.active || pid <= 1) return ""
        return Compositor.layerSnapshot.filter(l => Number(l.pid) === pid && l.mapped)
            .map(l => l.output + ":" + l.namespace).sort().join("|")
    }
    onRendererLayersChanged: {
        if (root.rendererLayers !== "") WallpaperService.restackWidgets()
    }

    property string currentId: ""
    property string currentPath: ""
    property string currentName: ""

    // { id, path, name } for each workshop package folder
    property var entries: []
    property var entryTitles: ({})
    property bool metadataPending: false

    Process {
        id: engineProc
        onStarted: {
            // Fallbacks for compositor versions without layer PID reporting.
            lateRestack.restart()
            laterRestack.restart()
        }
    }
    Timer { id: lateRestack; interval: 800; onTriggered: { if (root.active) WallpaperService.restackWidgets() } }
    Timer { id: laterRestack; interval: 2500; onTriggered: { if (root.active) WallpaperService.restackWidgets() } }

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
        root.publishEntries()
        metadataDebounce.restart()
    }

    function publishEntries() {
        const out = []
        for (let i = 0; i < workshopList.count; i++) {
            const name = workshopList.get(i, "fileName") || ""
            const path = workshopList.get(i, "filePath") || ""
            if (!name || !path)
                continue
            out.push({ id: name, path: path, name: root.entryTitles[name] || name })
        }
        root.entries = out
    }

    function readMetadata() {
        if (metadataReader.running) { root.metadataPending = true; return }
        if (root.workshopPath === "") return
        root.metadataPending = false
        metadataReader.scanningPath = root.workshopPath
        metadataReader.exec(["python3", Directories.script("umbriel/engine-metadata.py"), root.workshopPath])
    }
    Timer { id: metadataDebounce; interval: 50; onTriggered: root.readMetadata() }
    Process {
        id: metadataReader
        property string scanningPath: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (metadataReader.scanningPath !== root.workshopPath) return
                try {
                    root.entryTitles = JSON.parse(text)
                    root.publishEntries()
                    if (root.active && root.entryTitles[root.currentId])
                        root.currentName = root.entryTitles[root.currentId]
                } catch (e) { console.warn("Wallpaper Engine: could not read project titles") }
            }
        }
        onExited: {
            if (root.metadataPending || scanningPath !== root.workshopPath)
                Qt.callLater(root.readMetadata)
        }
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
                if (line !== "" && root.pathOverride === "")
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
        root.restorePending = false
        lateRestack.stop()
        laterRestack.stop()
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

        root.restorePending = false
        const raw = String(idOrPath)
        let bg = raw
        let path = ""
        let name = displayName || ""
        const known = (root.entries || []).find(entry => entry.id === raw || entry.path === raw)
        if (!name && known) name = known.name

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

        engineProc.command = root.buildCommand(path || bg)
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
        // Settings and normal wallpaper picks are restored asynchronously. Do
        // not consume the one-shot restore until both readers and Workshop
        // detection have finished, and never overwrite an explicit new pick.
        if (!root.restorePending || !SettingsService.loaded || !WallpaperService.ready
                || root.workshopPath === "")
            return
        root.restorePending = false
        if (!SettingsService.flag("wallpaper.engine.active"))
            return
        const path = String(SettingsService.get("wallpaper.engine.currentPath") || "")
        const id = String(SettingsService.get("wallpaper.engine.currentId") || "")
        if (path !== "" || id !== "") root.setWallpaper(path || id)
    }

    Connections {
        target: SettingsService
        function onLoadedChanged() { root.restoreIfNeeded() }
    }
    Connections {
        target: WallpaperService
        function onReadyChanged() { root.restoreIfNeeded() }
    }
    onWorkshopPathChanged: {
        root.entryTitles = ({})
        metadataDebounce.restart()
        root.restoreIfNeeded()
    }
    Component.onCompleted: {
        root.detectWorkshopPath()
        root.restoreIfNeeded()
    }

    onPathOverrideChanged: root.detectWorkshopPath()
}

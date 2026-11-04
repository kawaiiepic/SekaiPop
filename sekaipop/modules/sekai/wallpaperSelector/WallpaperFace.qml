import QtQuick
import QtQuick.Effects
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.launcher
import qs.modules.sekai.phone

// The screen of the Wallpapers phone (WallpaperStage.qml): what is drawn inside
// the flat landscape PhoneBody. A gallery app, with everything the wallpaper
// board (the old WallpaperGallery.qml, now removed) had:
//
//   GALLERY  (camera)  <Wallpapers banner>                   clock   <x>
//            (cut-out) [Desktop|Lockscreen]  12 wallpapers   [search] [Newest] (o)(o)(o)
//                      ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐
//                      │ pic  │ │ pic  │ │ pic  │ ...        a grid of thumbnails,
//                      └──────┘ └──────┘ └──────┘            scrolling
//
//   VIEWER   (camera)  <Wallpapers banner>        [Gallery]  clock   <x>
//            (cut-out) ┌──────────────────────┐   name
//                      │   the picture        │   [ Set as Desktop    ]
//                      └──────────────────────┘   [ Set as Lockscreen ]   < >
//
// The toolbar is the board's header: the Desktop | Lockscreen switch (only with
// Separate Lockscreen Wallpaper on; it chooses which side's applied picture the
// gallery marks, and the lockscreen side wears the lockscreen's own colours), a
// search field (or just start typing), the sort menu, "jump to applied",
// shuffle (jumps to a random one) and refresh (the dot says the folder changed
// since the list was made; sorting never reads the folder).
//
// Tap a picture to open it in the viewer. The viewer has the two actions:
// Set as Desktop (WallpaperService.setWallpaper) and Set as Lockscreen
// (WallpaperService.setLockWallpaper). With "One wallpaper per monitor" on they
// change this monitor only, and Shift+click changes every monitor. Set as
// Lockscreen turns "Separate Lockscreen Wallpaper" on if it is off (the
// lockscreen would otherwise just follow the desktop), keeping what the
// lockscreen shows now.
//
// The gallery has two looks, switched by the round button at the end of the
// toolbar: the WHEEL (WallpaperWheel.qml, the default: a Ferris wheel the
// pictures hang from; spin it, click the one in front to open it, or set it
// straight from the two keys under it) and the plain GRID above.
//
// Keys: arrows move (on the wheel Left / Right turn it), Enter opens, Escape
// steps back (sort menu, search, viewer, then the launcher phone), Tab flips
// Desktop / Lockscreen, Home / End.
// In the viewer: Left / Right = previous / next, Enter = Set as Desktop.
//
// The camera cut-out is on the left edge, so everything beside it keeps
// `safeLeft` clear. Pure UI apart from WallpaperService: the only thing it
// asks of the outside is `closeRequested()`.
Item {
    id: face

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    // Keeps the classic (white) look in the first dark mode; see Theme.classicFor.
    readonly property bool classicPanel: true

    width: 1440
    height: 760

    // ===== given by WallpaperStage.qml =====
    property string screenName: ""
    property string clockText: "00:00AM"
    property string dateText: "Sun, 20  Sep"
    property real screenInset: 26
    property real cornerRadius: 92
    property real renderScale: 1

    // Back to the launcher phone.
    signal closeRequested()

    // ===== layout (design units) =====
    readonly property real safeLeft: 96
    readonly property real safeRight: 50
    readonly property real pageX: safeLeft
    readonly property real pageTop: 114
    readonly property real pageWidth: width - safeLeft - safeRight
    readonly property real pageHeight: 594

    // The toolbar sits on top of the page; the grid under it holds three rows.
    readonly property real toolbarH: 46
    readonly property real galleryTop: pageTop + 58
    readonly property real galleryHeight: pageHeight - 58

    readonly property int columns: 5
    readonly property real cellW: Math.floor(pageWidth / columns)
    readonly property real cellH: 178

    // ===== state =====
    // The picture open in the viewer: its place in `matched` (-1 = the gallery).
    property int viewIndex: -1
    property string viewPath: ""
    property string viewName: ""
    readonly property bool viewing: viewIndex >= 0

    property real viewP: viewing ? 1 : 0
    Behavior on viewP {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    // The gallery as a wheel (WallpaperWheel.qml) instead of the grid.
    property bool carousel: true
    property real carouselP: carousel ? 1 : 0
    Behavior on carouselP {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutCubic
        }
    }

    // The pick comes from the arrow keys (not the mouse).
    property bool keyNav: false
    // "desktop" / "lock" for a moment after one was set.
    property string justSet: ""

    // Which side the gallery is choosing for / marking (the Desktop |
    // Lockscreen switch; only there with Separate Lockscreen Wallpaper on).
    property string target: "desktop"
    readonly property bool lockMode: WallpaperService.separateLock && face.target === "lock"

    // What is on this monitor right now.
    readonly property string desktopPath: WallpaperService.pathFor(face.screenName)
    readonly property string lockPath: WallpaperService.lockPathFor(face.screenName)
    readonly property string currentPath: face.lockMode ? face.lockPath : face.desktopPath
    readonly property string otherPath: !WallpaperService.separateLock ? ""
                                        : (face.lockMode ? face.desktopPath : face.lockPath)

    readonly property bool viewIsVideo: face.viewPath !== "" && WallpaperService.isVideo(face.viewPath)

    // ===== where the pictures come from: My folder or Wallhaven =====
    // The header's switch (WallpaperSourceSwitch.qml), or Ctrl+Tab. On Wallhaven the gallery
    // shows WallhavenService's results in the same `matched` list, each with a `wh` (the
    // result: thumbnails, size, colours...); `filePath` is where its download is, once there
    // is one, so the applied / other marks work for those as for any other picture. Setting
    // one downloads it first, into the folder itself (so it is in My folder from then on).
    // Opens on the folder every time.
    // The design: docs/handoffs/wallhaven; docs/WALLHAVEN.md says where it departs.
    property string source: "folder"
    readonly property bool onWallhaven: face.source === "wallhaven"
    readonly property bool onEngine: face.source === "engine"
    property bool filtersOpen: false
    // The picture open in the viewer, when it is a Wallhaven one.
    readonly property var viewWh: face.viewIndex >= 0 && face.viewIndex < face.matched.length
        ? (face.matched[face.viewIndex].wh || null) : null
    // This monitor in pixels: Wallhaven's "This screen" minimum size.
    readonly property var screenObj: Quickshell.screens.find(sc => sc.name === face.screenName) ?? null
    readonly property int screenPxW: face.screenObj ? Math.round(face.screenObj.width * (face.screenObj.devicePixelRatio ?? 1)) : 0
    readonly property int screenPxH: face.screenObj ? Math.round(face.screenObj.height * (face.screenObj.devicePixelRatio ?? 1)) : 0

    function setSource(src) {
        if (src === face.source)
            return
        face.sortOpen = false
        face.filtersOpen = false
        face.closeViewer()
        face.source = src
        search.clear()
        face.searchText = ""
        whSearchDelay.stop()
        if (face.onWallhaven && (WallhavenService.page === 0 || WallhavenService.query !== ""))
            WallhavenService.search("", face.screenPxW, face.screenPxH)
        // Back on the folder with something new in it (a Wallhaven download): read it again,
        // so the download is there at once rather than behind the Refresh dot.
        if (!face.onWallhaven && !face.onEngine && face.hasNew)
            face.refresh()
        else
            face.recompute()
        Qt.callLater(() => grid.positionViewAtBeginning())
    }

    // Wallhaven's results, in the gallery's item shape. Nothing to show yet (the first search
    // on its way): empty frames instead, in whichever look is on (the wheel's or the grid's),
    // so the gallery is never a blank screen while it loads.
    function wallhavenItems() {
        const out = []
        if (WallhavenService.items.length === 0 && WallhavenService.loading) {
            for (let i = 0; i < face.columns * 3; i++)
                out.push({ fileName: "", filePath: "", fileSize: 0, fileModified: 0,
                           wh: { placeholder: true, id: "", thumb: "", colours: [], resolution: "" } })
            return out
        }
        for (const it of WallhavenService.items) {
            const have = WallhavenService.downloaded(it)
            out.push({
                fileName: "#" + it.id,
                filePath: have ? WallhavenService.folder + "/" + WallhavenService.fileNameOf(it) : "",
                fileSize: it.size,
                fileModified: 0,
                wh: it
            })
        }
        return out
    }

    Connections {
        target: WallpaperEngineService
        function onEntriesChanged() {
            if (face.onEngine)
                face.recompute()
        }
        function onActiveChanged() {
            if (face.onEngine)
                face.recompute()
        }
    }

    Connections {
        target: WallhavenService
        function onItemsChanged() {
            if (face.onWallhaven)
                face.recompute()
        }
        function onLoadingChanged() {
            if (face.onWallhaven)
                face.recompute()
        }
        function onHaveChanged() {
            if (!face.onWallhaven)
                return
            face.recompute()
            // The picture open in the viewer was just downloaded: it is a file now.
            if (face.viewIndex >= 0 && face.viewIndex < face.matched.length)
                face.viewPath = face.matched[face.viewIndex].filePath
        }
    }

    // Typing on Wallhaven searches it, a moment after the last key.
    Timer {
        id: whSearchDelay
        interval: 450
        onTriggered: WallhavenService.search(face.searchText, face.screenPxW, face.screenPxH)
    }

    // A new search is on its way: what is shown is the previous one's, dimmed.
    property real staleK: face.onWallhaven && WallhavenService.refreshing && WallhavenService.items.length > 0 ? 0.5 : 1
    Behavior on staleK { NumberAnimation { duration: 160 } }

    // Near the end of what is loaded: the next page.
    function nearEnd(i) {
        if (face.onWallhaven && i >= face.matched.length - 6)
            WallhavenService.more()
    }

    // ===== the list =====
    // Same idea as the wallpaper picker's: the folder is read into a snapshot
    // (`items`, in the chosen order) and the gallery shows what matches the
    // search. Sorting re-orders the snapshot without reading the folder, and a
    // file added later only lights the dot on Refresh until it is pressed.
    property var items: []
    property var matched: []
    property string searchText: ""
    property string sortMode: "date_desc"
    property bool sortOpen: false
    property bool hasNew: false
    property bool listed: false

    readonly property var sortOptions: [
        { mode: "date_desc", label: "Date added (newest first)", short: "Newest" },
        { mode: "date_asc",  label: "Date added (oldest first)", short: "Oldest" },
        { mode: "name_asc",  label: "Name (A to Z)",             short: "A\u2013Z" },
        { mode: "name_desc", label: "Name (Z to A)",             short: "Z\u2013A" },
        { mode: "size_desc", label: "Size (largest first)",      short: "Largest" },
        { mode: "size_asc",  label: "Size (smallest first)",     short: "Smallest" }
    ]

    readonly property string sortShort: {
        for (const o of face.sortOptions) {
            if (o.mode === face.sortMode)
                return o.short
        }
        return ""
    }

    readonly property string subtitle: (WallpaperService.separateLock ? (face.lockMode ? "Lockscreen only  \u00b7  " : "Desktop only  \u00b7  ") : "")
        + (face.searchText.trim() !== ""
            ? face.matched.length + " of " + face.items.length + " match"
            : face.items.length + (face.items.length === 1 ? " wallpaper" : " wallpapers"))
        + (WallpaperService.perMonitor && face.screenName !== "" ? "  \u00b7  for " + face.screenName : "")
        + (WallpaperService.customFolder ? "  \u00b7  " + WallpaperService.directoryShort : "")

    FolderListModel {
        id: files
        folder: WallpaperService.directoryUrl
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp",
                      "*.mp4", "*.webm", "*.mkv", "*.mov", "*.avi"]
        showDirs: false
        sortField: FolderListModel.Name

        onStatusChanged: {
            if (status === FolderListModel.Ready && !face.listed)
                face.refresh()
        }
        onCountChanged: {
            // Before the first listing the count is still filling in; after it,
            // a change only lights the dot on Refresh.
            if (!face.listed) {
                if (status === FolderListModel.Ready)
                    face.refresh()
            } else {
                face.hasNew = true
            }
        }
    }

    // A different wallpaper folder was chosen: read it from scratch (the first
    // listing of it refreshes the gallery by itself) instead of lighting the
    // dot on Refresh as if a file had been added to the old one.
    Connections {
        target: WallpaperService

        function onDirectoryChanged() {
            face.listed = false
            face.searchText = ""
            if (files.status === FolderListModel.Ready)
                Qt.callLater(face.refresh)
        }
    }

    Component.onCompleted: {
        if (files.status === FolderListModel.Ready)
            face.refresh()
    }

    function sortItems(list, mode) {
        const sorted = list.slice()
        if (mode === "name_asc")
            sorted.sort((a, b) => a.fileName.localeCompare(b.fileName, undefined, { numeric: true, sensitivity: "base" }))
        else if (mode === "name_desc")
            sorted.sort((a, b) => b.fileName.localeCompare(a.fileName, undefined, { numeric: true, sensitivity: "base" }))
        else if (mode === "size_desc")
            sorted.sort((a, b) => b.fileSize - a.fileSize)
        else if (mode === "size_asc")
            sorted.sort((a, b) => a.fileSize - b.fileSize)
        else if (mode === "date_asc")
            sorted.sort((a, b) => a.fileModified - b.fileModified)
        else
            sorted.sort((a, b) => b.fileModified - a.fileModified)
        return sorted
    }

    // Read the folder again.
    function refresh() {
        const list = []
        for (let i = 0; i < files.count; i++) {
            const mod = files.get(i, "fileModified")
            list.push({
                fileName: files.get(i, "fileName") || "",
                filePath: files.get(i, "filePath") || "",
                fileSize: files.get(i, "fileSize") || 0,
                fileModified: mod ? new Date(mod).getTime() : 0
            })
        }
        face.items = face.sortItems(list, face.sortMode)
        face.listed = true
        face.hasNew = false
        face.recompute()
    }

    // Re-order what is already listed (never reads the folder).
    function setSort(mode) {
        face.sortMode = mode
        face.items = face.sortItems(face.items, mode)
        face.recompute()
        grid.positionViewAtBeginning()
    }

    function engineItems() {
        const out = []
        for (const it of WallpaperEngineService.entries) {
            const prevs = WallpaperEngineService.previewCandidates(it.path)
            out.push({
                fileName: it.name || it.id,
                filePath: it.path,
                fileSize: 0,
                fileModified: 0,
                engine: true,
                engineId: it.id,
                previewCandidates: prevs,
                previewPath: prevs.length ? prevs[0] : ""
            })
        }
        return out
    }

    function recompute() {
        if (face.onWallhaven) {
            face.matched = face.wallhavenItems()
            return
        }
        if (face.onEngine) {
            const list = face.engineItems()
            const q = face.searchText.trim().toLowerCase()
            face.items = list
            face.matched = q === "" ? list
                : list.filter(it => it.fileName.toLowerCase().indexOf(q) !== -1)
            return
        }
        const q = face.searchText.trim().toLowerCase()
        face.matched = q === "" ? face.items
            : face.items.filter(it => it.fileName.toLowerCase().indexOf(q) !== -1)
    }

    onSearchTextChanged: {
        if (face.onWallhaven) {
            whSearchDelay.restart()
            return
        }
        face.recompute()
        Qt.callLater(() => grid.positionViewAtBeginning())
    }

    function baseName(fileName) {
        const i = fileName.lastIndexOf(".")
        return i > 0 ? fileName.slice(0, i) : fileName
    }

    // ===== the toolbar's buttons =====
    function goTo(i) {
        if (i < 0 || i >= face.matched.length)
            return
        if (face.carousel) {
            wheelView.rotateTo(i)
            return
        }
        grid.currentIndex = i
        face.keyNav = true
        grid.positionViewAtIndex(i, GridView.Center)
    }

    function jumpToApplied() {
        face.sortOpen = false
        for (let i = 0; i < face.matched.length; i++) {
            if (face.matched[i].filePath === face.currentPath) {
                face.goTo(i)
                return
            }
        }
    }

    function shuffle() {
        face.sortOpen = false
        if (face.matched.length > 0)
            face.goTo(Math.floor(Math.random() * face.matched.length))
    }

    // ===== actions =====
    function showIndex(i) {
        const n = face.matched.length
        if (n <= 0)
            return
        const k = ((i % n) + n) % n
        // an empty frame while Wallhaven loads: nothing to open
        if (face.matched[k].wh && face.matched[k].wh.placeholder)
            return
        face.sortOpen = false
        face.viewIndex = k
        {
            const it = face.matched[k]
            // Engine packages are folders; show preview.* in the viewer.
            face.viewPath = it && it.engine
                ? ((it.previewCandidates || [])[0] || it.previewPath || "")
                : (it ? it.filePath : "")
            face.viewName = it ? it.fileName : ""
        }
        face.nearEnd(k)
        grid.currentIndex = k
        // the wheel follows the viewer's Left / Right, so Gallery lands on it
        wheelView.rotateTo(k)
        face.justSet = ""
    }

    // The round button at the toolbar's end: wheel <-> grid, keeping the place.
    function toggleLook() {
        face.sortOpen = false
        if (face.carousel) {
            const i = wheelView.centerIndex
            if (i >= 0) {
                grid.currentIndex = i
                grid.positionViewAtIndex(i, GridView.Center)
            }
        } else if (grid.currentIndex >= 0) {
            wheelView.rotateTo(grid.currentIndex)
        }
        face.carousel = !face.carousel
    }

    function closeViewer() {
        if (face.viewIndex >= 0)
            grid.positionViewAtIndex(face.viewIndex, GridView.Contain)
        face.viewIndex = -1
        face.justSet = ""
    }

    // Escape: one step back.
    function back() {
        if (face.sortOpen)
            face.sortOpen = false
        else if (face.filtersOpen)
            face.filtersOpen = false
        else if (WallhavenService.fetching !== "")
            WallhavenService.cancelFetch()
        else if (face.viewing)
            face.closeViewer()
        else if (face.searchText !== "")
            search.clear()
        else
            face.closeRequested()
    }

    // `all`: every monitor (only means something with One wallpaper per monitor on).
    // `path`: the picture to set (the wheel passes the one in front); the
    // viewer's keys leave it out and mean the one it has open.
    function setDesktop(all, path) {
        // Wallpaper Engine package: hand off to linux-wallpaperengine.
        if (face.onEngine || (face.viewIndex >= 0 && face.matched[face.viewIndex] && face.matched[face.viewIndex].engine)) {
            const it = face.viewIndex >= 0 ? face.matched[face.viewIndex] : null
            const bg = (path !== undefined && path !== "") ? path : (it ? (it.engineId || it.filePath) : face.viewPath)
            if (!bg)
                return
            WallpaperEngineService.setWallpaper(bg, it ? it.fileName : "")
            face.flash("desktop")
            return
        }
        // A Wallhaven picture that isn't downloaded yet: download it, then this again.
        if ((path === undefined || path === "") && face.viewWh && face.viewPath === "") {
            const wh = face.viewWh
            WallhavenService.fetch(wh, p => face.setDesktop(all, p))
            return
        }
        const p = (path !== undefined && path !== "") ? path : face.viewPath
        if (p === "")
            return
        if (all)
            WallpaperService.setWallpaper(p)
        else
            WallpaperService.setWallpaper(p, face.screenName)
        face.flash("desktop")
    }

    function setLock(all, path) {
        if ((path === undefined || path === "") && face.viewWh && face.viewPath === "") {
            const wh = face.viewWh
            WallhavenService.fetch(wh, p => face.setLock(all, p))
            return
        }
        const p = (path !== undefined && path !== "") ? path : face.viewPath
        if (p === "")
            return
        // Without a lockscreen of its own the lockscreen just follows the
        // desktop, so picking one here has to turn that on.
        if (!WallpaperService.separateLock)
            WallpaperService.setSeparateLock(true)
        if (all)
            WallpaperService.setLockWallpaper(p)
        else
            WallpaperService.setLockWallpaper(p, face.screenName)
        face.flash("lock")
    }

    function flash(which) {
        face.justSet = which
        flashTimer.restart()
    }

    // The wheel's set keys, for the picture in front (by its place, so a Wallhaven one
    // that isn't downloaded yet can be).
    function setFromWheel(which, all) {
        const i = wheelView.shownIndex
        if (i < 0 || i >= face.matched.length)
            return
        const it = face.matched[i]
        const go = p => which === "lock" ? face.setLock(all, p) : face.setDesktop(all, p)
        if (it.filePath !== "")
            go(it.filePath)
        else if (it.wh)
            WallhavenService.fetch(it.wh, p => go(p))
    }

    // Spin the wheel in from the left again (the phone showing a gallery that was
    // built while it was out of sight; see SettingsStage.dealIfWarm).
    function replayDeal() {
        if (face.carousel)
            wheelView.deal()
    }

    Timer {
        id: flashTimer
        interval: 1500
        onTriggered: face.justSet = ""
    }

    focus: true

    Keys.onPressed: event => {
        const k = event.key
        if (k === Qt.Key_Escape) {
            face.back()
            event.accepted = true
            return
        }
        if (face.viewing) {
            if (k === Qt.Key_Left) {
                face.showIndex(face.viewIndex - 1)
                event.accepted = true
            } else if (k === Qt.Key_Right) {
                face.showIndex(face.viewIndex + 1)
                event.accepted = true
            } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                face.setDesktop((event.modifiers & Qt.ShiftModifier) !== 0)
                event.accepted = true
            }
            return
        }
        // Ctrl+Tab flips My folder <-> Wallhaven.
        if ((event.modifiers & Qt.ControlModifier) && (k === Qt.Key_Tab || k === Qt.Key_Backtab)) {
            face.setSource(face.onWallhaven ? "folder" : "wallhaven")
            event.accepted = true
            return
        }
        // Tab flips Desktop <-> Lockscreen (only there with Separate Lockscreen Wallpaper on).
        if (WallpaperService.separateLock && (k === Qt.Key_Tab || k === Qt.Key_Backtab)) {
            face.sortOpen = false
            face.target = face.lockMode ? "desktop" : "lock"
            event.accepted = true
            return
        }
        if (face.carousel) {
            if (k === Qt.Key_Left) {
                wheelView.stepBy(-1)
            } else if (k === Qt.Key_Right) {
                wheelView.stepBy(1)
            } else if (k === Qt.Key_Home) {
                wheelView.toStart()
            } else if (k === Qt.Key_End) {
                wheelView.toEnd()
            } else if ((k === Qt.Key_Return || k === Qt.Key_Enter) && wheelView.centerIndex >= 0) {
                face.showIndex(wheelView.centerIndex)
            } else if (k === Qt.Key_Up || k === Qt.Key_Down) {
                // nothing to move through on a wheel
            } else {
                // typing still searches, same as the grid
                if (!(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                    const tc = event.text
                    if (tc.length === 1 && tc.charCodeAt(0) > 32 && tc.charCodeAt(0) !== 127) {
                        face.sortOpen = false
                        search.begin(tc)
                        event.accepted = true
                    }
                }
                return
            }
            event.accepted = true
            return
        }
        if (k === Qt.Key_Home) {
            grid.positionViewAtBeginning()
            event.accepted = true
            return
        }
        if (k === Qt.Key_End) {
            grid.positionViewAtEnd()
            event.accepted = true
            return
        }
        if (k === Qt.Key_Left || k === Qt.Key_Right || k === Qt.Key_Up || k === Qt.Key_Down) {
            if (face.matched.length > 0) {
                if (!face.keyNav || grid.currentIndex < 0) {
                    face.keyNav = true
                    if (grid.currentIndex < 0)
                        grid.currentIndex = 0
                } else if (k === Qt.Key_Left) {
                    grid.moveCurrentIndexLeft()
                } else if (k === Qt.Key_Right) {
                    grid.moveCurrentIndexRight()
                } else if (k === Qt.Key_Up) {
                    grid.moveCurrentIndexUp()
                } else {
                    grid.moveCurrentIndexDown()
                }
            }
            event.accepted = true
            return
        }
        if ((k === Qt.Key_Return || k === Qt.Key_Enter) && grid.currentIndex >= 0) {
            face.showIndex(grid.currentIndex)
            event.accepted = true
            return
        }
        // Just start typing to search.
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return
        const t = event.text
        if (t.length === 1 && t.charCodeAt(0) > 32 && t.charCodeAt(0) !== 127) {
            face.sortOpen = false
            search.begin(t)
            event.accepted = true
        }
    }

    // ===== backdrop, inside the glass =====
    Item {
        id: screenArea

        x: face.screenInset
        y: face.screenInset
        width: face.width - 2 * face.screenInset
        height: face.height - 2 * face.screenInset
        z: -10

        layer.enabled: true
        layer.smooth: true
        layer.textureSize: Qt.size(Math.ceil(width * face.renderScale * 2),
                                   Math.ceil(height * face.renderScale * 2))
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: screenMask
        }

        SekaiBackdrop {
            x: -face.screenInset
            y: -face.screenInset
            width: face.width
            height: face.height
        }
    }

    Item {
        id: screenMask
        width: screenArea.width
        height: screenArea.height
        visible: false
        layer.enabled: true
        layer.smooth: true
        layer.textureSize: Qt.size(Math.ceil(width * face.renderScale * 2),
                                   Math.ceil(height * face.renderScale * 2))

        Rectangle {
            anchors.fill: parent
            color: "black"
            radius: Math.max(0, face.cornerRadius - face.screenInset)
            antialiasing: true
        }
    }

    // ===== header =====
    Item {
        id: banner

        x: face.safeLeft - 8
        y: 28
        height: 70
        width: bannerKey.capW + 8

        SekaiKey {
            id: bannerKey

            capW: 420
            capH: 66
            radius: 26
            lit: true
            litP: 1
            borderBase: 4
            borderLit: 4
            ringExtra: 5
            shadowBaseX: 5
            shadowBaseY: 4

            Rectangle {
                x: 54 - width / 2
                y: (bannerKey.capH - height) / 2
                width: 34
                height: 34
                radius: 10
                rotation: 45
                color: mt.colBg
                border.width: 3
                border.color: mt.colBorder
                antialiasing: true
            }

            MaterialIcon {
                x: 54 - width / 2
                y: (bannerKey.capH - height) / 2
                size: 24
                name: face.lockMode ? "lock" : "wallpaper"
                color: mt.colBorder
            }

            Column {
                x: 92
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: "Wallpapers"
                    color: mt.colBorder
                    font.family: mt.fontFamily
                    font.pixelSize: 28
                    font.weight: Font.ExtraBold
                    font.styleName: mt.fontStyleBold
                    lineHeight: 29
                    lineHeightMode: Text.FixedHeight
                }

                Text {
                    text: face.viewing ? "Preview" : (face.carousel ? "Spin the wheel" : "Pick a picture")
                    color: Qt.rgba(mt.colBorder.r, mt.colBorder.g, mt.colBorder.b, 0.78)
                    font.family: mt.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    lineHeight: 17
                    lineHeightMode: Text.FixedHeight
                }
            }

            MaterialIcon {
                x: bannerKey.capW - 52
                y: 8
                size: 24
                name: "star"
                rotation: 14
                color: mt.colBg
            }
        }
    }

    // My folder | Wallhaven, beside the title (not in the viewer).
    WallpaperSourceSwitch {
        id: sourceSwitch
        x: banner.x + banner.width + 22
        y: banner.y + (bannerKey.capH - height) / 2
        current: face.source
        opacity: 1 - face.viewP
        visible: opacity > 0.01
        enabled: !face.viewing
        onPicked: id => face.setSource(id)
    }

    // ...and the keys that flip it.
    Pill {
        x: sourceSwitch.x + sourceSwitch.width + 12
        y: sourceSwitch.y + (sourceSwitch.height - height) / 2
        width: ctrlTab.implicitWidth + 16
        height: 26
        cornerRadius: 8
        ringWidth: 3
        shadowDy: 3
        fillColor: mt.chipFill
        opacity: sourceSwitch.opacity
        visible: sourceSwitch.visible

        Text {
            id: ctrlTab
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -1
            text: "Ctrl Tab"
            color: mt.chipInk
            font.family: mt.fontFamily
            font.pixelSize: 11
            font.weight: Font.ExtraBold
            font.styleName: mt.fontStyleBold
        }
    }

    SekaiKey {
        id: clockChip

        x: closeButton.x - 16 - capW - 6
        y: 34
        capW: Math.max(clockLabel.implicitWidth, dateLabel.implicitWidth) + 62
        capH: 56
        radius: 20

        Column {
            anchors.centerIn: parent

            Text {
                id: clockLabel
                anchors.horizontalCenter: parent.horizontalCenter
                text: face.clockText
                color: mt.pInk
                font.family: mt.fontFamily
                font.pixelSize: 21
                font.weight: Font.ExtraBold
                font.styleName: mt.fontStyleBold
                lineHeight: 24
                lineHeightMode: Text.FixedHeight
            }

            Text {
                id: dateLabel
                anchors.horizontalCenter: parent.horizontalCenter
                text: face.dateText
                color: mt.pInkSub
                font.family: mt.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
                lineHeight: 16
                lineHeightMode: Text.FixedHeight
            }
        }
    }

    // The X turns the phone back into the launcher phone.
    SettingRoundButton {
        id: closeButton
        x: face.width - face.safeRight - width
        y: 33
        size: 58
        icon: "close"
        onClicked: face.closeRequested()
    }

    // Back to the gallery, while a picture is open.
    SekaiNavKey {
        x: clockChip.x - 24 - width
        y: 38
        icon: "arrow_back"
        label: "Gallery"
        opacity: face.viewP
        visible: opacity > 0.01
        enabled: face.viewing
        onClicked: face.closeViewer()
    }

    // ===== the gallery =====
    WheelScroll { scroller: grid }
    GridView {
        id: grid

        x: face.pageX
        y: face.galleryTop
        width: face.pageWidth
        height: face.galleryHeight
        clip: true
        cellWidth: face.cellW
        cellHeight: face.cellH
        model: face.matched
        currentIndex: -1
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: false
        maximumFlickVelocity: 3200

        opacity: (1 - face.viewP) * (1 - face.carouselP) * face.staleK
        scale: 0.97 + 0.03 * (1 - face.viewP)
        visible: opacity > 0.01
        enabled: !face.viewing && !face.carousel

        // Near the bottom of what is loaded: Wallhaven's next page.
        onContentYChanged: {
            if (face.onWallhaven && contentHeight > 0 && contentY + height > contentHeight - 2 * face.cellH)
                WallhavenService.more()
        }

        delegate: Item {
            id: cell

            required property int index
            required property var modelData

            width: grid.cellWidth
            height: grid.cellHeight

            readonly property string path: cell.modelData.filePath
            // A Wallhaven result (null for a picture in the folder).
            readonly property var wh: cell.modelData.wh || null
            readonly property bool applied: cell.path !== "" && cell.path === face.currentPath
            readonly property bool other: face.otherPath !== "" && cell.path === face.otherPath
            readonly property bool picked: face.keyNav && GridView.isCurrentItem
            readonly property bool hot: area.containsMouse || picked
            readonly property bool video: WallpaperService.isVideo(cell.path)
            readonly property real tw: cell.width - 22
            readonly property real th: cell.height - 22

            // The side being marked wears its own colour (the lockscreen's, on its tab).
            readonly property color markColor: face.lockMode ? LockPalette.pink : mt.accentMint
            readonly property color otherColor: face.lockMode ? mt.accentCyan : LockPalette.pink

            // pushes into its shadow while pressed, lifts a hair when hot
            readonly property real push: area.pressed ? 5 : (cell.hot ? -2 : 0)

            Rectangle {
                x: 9
                y: 9
                width: cell.tw
                height: cell.th
                radius: 16
                color: mt.pLineShadow
            }

            Rectangle {
                id: body

                x: 4 + cell.push
                y: 4 + cell.push
                width: cell.tw
                height: cell.th
                radius: 16
                color: mt.pSurface
                border.width: 4
                border.color: cell.hot ? mt.accentCyan : mt.pLine

                Behavior on x {
                    NumberAnimation {
                        duration: area.pressed ? 70 : 220
                        easing.type: area.pressed ? Easing.OutQuad : Easing.OutBack
                        easing.overshoot: 2.0
                    }
                }

                Behavior on y {
                    NumberAnimation {
                        duration: area.pressed ? 70 : 220
                        easing.type: area.pressed ? Easing.OutQuad : Easing.OutBack
                        easing.overshoot: 2.0
                    }
                }

                ClippingRectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 12
                    // A Wallhaven picture still on its way: its own main colour.
                    color: cell.wh && cell.wh.colours.length > 0 ? cell.wh.colours[0] : mt.pSurfaceHover

                    // an empty frame while Wallhaven loads: it breathes
                    SequentialAnimation on opacity {
                        running: cell.wh !== null && cell.wh.placeholder === true
                        loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 0.55; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.55; to: 1; duration: 700; easing.type: Easing.InOutSine }
                    }

                    WallpaperPreview {
                        id: thumb

                        anchors.fill: parent
                        previewEntry: cell.modelData
                        fallbackSource: previewEntry && previewEntry.engine ? ""
                            : (cell.wh ? cell.wh.thumb : WallpaperService.thumbUrl(cell.path))
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        // Decoded as dense as the screen it lands in (the phone's
                        // screen layer is renderScale x 2 texels per design unit);
                        // a fixed 520 was too few once the picture is cropped to
                        // the cell and the phone is shown at full size or bigger.
                        sourceSize.width: Math.ceil(Math.max(cell.tw, cell.th * 1.8) * face.renderScale * 2)
                        opacity: status === Image.Ready ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation { duration: 180 }
                        }
                    }

                    // a video with no thumbnail yet
                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: thumb.status !== Image.Ready && !(cell.wh && cell.wh.placeholder)
                        size: 40
                        name: cell.video ? "movie" : "image"
                        color: mt.pInkSub
                    }

                    // a video wears a play badge
                    Rectangle {
                        visible: cell.video
                        x: parent.width - width - 10
                        y: parent.height - height - 10
                        width: 30
                        height: 30
                        radius: 15
                        color: mt.pSurface
                        border.width: 3
                        border.color: mt.pLine

                        MaterialIcon {
                            anchors.centerIn: parent
                            size: 18
                            name: "play_arrow"
                            color: mt.colBorder
                        }
                    }
                }

                // the applied picture (of the side being marked): a ring ...
                Rectangle {
                    visible: cell.applied
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 12
                    color: "transparent"
                    border.width: 5
                    border.color: cell.markColor
                }

                // ... and a check
                Rectangle {
                    visible: cell.applied
                    x: parent.width - width - 8
                    y: 8
                    width: 34
                    height: 34
                    radius: 17
                    color: cell.markColor
                    border.width: 3
                    border.color: mt.colBorder

                    MaterialIcon {
                        anchors.centerIn: parent
                        size: 20
                        name: "check"
                        weight: 700
                        color: mt.colBorder
                    }
                }

                // also what the other side shows
                Rectangle {
                    visible: cell.other
                    x: 8
                    y: 8
                    width: 34
                    height: 34
                    radius: 17
                    color: cell.otherColor
                    border.width: 3
                    border.color: mt.colBorder

                    MaterialIcon {
                        anchors.centerIn: parent
                        size: 19
                        name: face.lockMode ? "desktop_windows" : "lock"
                        color: mt.colBorder
                    }
                }

                // a Wallhaven picture that is already in the folder (when it isn't the
                // applied one, which wears the check there instead)
                Rectangle {
                    visible: cell.wh !== null && cell.path !== "" && !cell.applied
                    x: parent.width - width - 8
                    y: 8
                    width: 30
                    height: 30
                    radius: 15
                    color: mt.pSurface
                    border.width: 3
                    border.color: mt.pLine

                    MaterialIcon {
                        anchors.centerIn: parent
                        size: 16
                        name: "folder"
                        color: mt.pInk
                    }
                }

                // the name, while hot
                Rectangle {
                    x: 10
                    y: parent.height - height - 10
                    width: Math.min(parent.width - 20 - (cell.video ? 40 : 0), nameText.implicitWidth + 22)
                    height: 28
                    radius: 14
                    color: mt.pSurface
                    border.width: 3
                    border.color: mt.pLine
                    opacity: cell.hot && nameText.text !== "" ? 1 : 0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation { duration: 120 }
                    }

                    Text {
                        id: nameText
                        anchors.centerIn: parent
                        width: parent.width - 18
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.wh ? cell.wh.resolution.replace("x", "\u00d7") : face.baseName(cell.modelData.fileName)
                        elide: Text.ElideMiddle
                        color: mt.pInk
                        font.family: mt.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                }
            }

            MouseArea {
                id: area

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: face.keyNav = false
                onClicked: face.showIndex(cell.index)
            }
        }
    }

    // scroll position
    Rectangle {
        visible: face.viewP < 0.5 && !face.carousel && grid.contentHeight > grid.height + 1
        x: grid.x + grid.width - 8
        y: grid.y + grid.visibleArea.yPosition * grid.height
        width: 6
        height: Math.max(40, grid.visibleArea.heightRatio * grid.height)
        radius: 3
        color: mt.pSurfaceRing
        opacity: 1 - face.viewP
    }

    // Wallhaven: the next page is on its way.
    Rectangle {
        visible: face.onWallhaven && WallhavenService.loading && WallhavenService.page > 0 && face.viewP < 0.5
        x: face.pageX + (face.pageWidth - width) / 2
        y: face.galleryTop + face.galleryHeight - height - 10
        z: 3
        width: pageRow.implicitWidth + 28
        height: 34
        radius: 17
        color: mt.pSurface
        border.width: 3
        border.color: mt.pLine

        Row {
            id: pageRow
            anchors.centerIn: parent
            spacing: 7

            MaterialIcon {
                id: pageSpin
                anchors.verticalCenter: parent.verticalCenter
                name: "sync"
                size: 15
                weight: 700
                color: mt.pInk
                transformOrigin: Item.Center
                RotationAnimator on rotation {
                    running: pageSpin.visible
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 800
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Page " + (WallhavenService.page + 1) + " of " + WallhavenService.lastPage
                color: mt.pInk
                font.family: mt.fontFamily
                font.pixelSize: 13
                font.weight: Font.ExtraBold
                font.styleName: mt.fontStyleBold
            }
        }
    }

    // ===== the wheel =====
    WallpaperWheel {
        id: wheelView

        x: face.pageX
        y: face.galleryTop
        width: face.pageWidth
        height: face.galleryHeight
        items: face.matched
        currentPath: face.currentPath
        otherPath: face.otherPath
        desktopPath: face.desktopPath
        lockPath: face.lockPath
        lockMode: face.lockMode
        justSet: face.justSet
        renderScale: face.renderScale
        active: face.carousel && !face.viewing

        opacity: face.carouselP * (1 - face.viewP) * face.staleK
        scale: 0.97 + 0.03 * (1 - face.viewP)
        visible: opacity > 0.01
        enabled: face.carousel && !face.viewing

        onOpened: index => face.showIndex(index)
        onSetDesktopRequested: (path, all) => face.setFromWheel("desktop", all)
        onSetLockRequested: (path, all) => face.setFromWheel("lock", all)
        // Wallhaven: an open-ended list (no wrapping, no fresh spin when a page is added),
        // and the next page only once the wheel has come to rest near the end, never while
        // it is turning (a deal spins in from "before the start").
        allowWrap: !face.onWallhaven
        keepOnGrow: face.onWallhaven
        onRestedChanged: {
            if (rested)
                face.nearEnd(centerIndex)
        }
    }

    // an empty folder, or nothing matches the search
    Column {
        x: face.pageX + (face.pageWidth - width) / 2
        y: face.galleryTop + (face.galleryHeight - height) / 2
        visible: !face.onWallhaven && face.listed && face.matched.length === 0 && face.viewP < 0.5
        spacing: 8

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            size: 54
            name: face.items.length === 0 ? "photo_library" : "search_off"
            color: mt.pInkSub
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, Math.max(120, face.pageWidth - 120))
            elide: Text.ElideMiddle
            text: face.items.length === 0 ? "No wallpapers yet" : "No wallpapers match \u201c" + face.searchText + "\u201d"
            color: mt.pInk
            font.family: mt.fontFamily
            font.pixelSize: 26
            font.weight: Font.ExtraBold
            font.styleName: mt.fontStyleBold
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: face.items.length === 0
            width: Math.min(implicitWidth, Math.max(120, face.pageWidth - 120))
            elide: Text.ElideMiddle
            text: "Put pictures or videos in " + WallpaperService.directoryShort + ", or choose another folder"
            color: mt.pInkSub
            font.family: mt.fontFamily
            font.pixelSize: 17
            font.weight: Font.DemiBold
        }
    }

    // Wallhaven: nothing found, too many requests, offline, or not answering.
    WallhavenMessage {
        readonly property bool nothing: !WallhavenService.loading && WallhavenService.error === ""
            && WallhavenService.page > 0 && WallhavenService.items.length === 0
        visible: face.onWallhaven && face.viewP < 0.5 && (WallhavenService.error !== "" || nothing)
        x: face.pageX + (face.pageWidth - width) / 2
        y: face.galleryTop + (face.galleryHeight - height) / 2
        maxWidth: Math.min(640, face.pageWidth - 120)
        kind: WallhavenService.error !== "" ? WallhavenService.error : "empty"
        query: WallhavenService.query
        filters: WallhavenService.filters
        retryIn: WallhavenService.retryIn
        onRetry: WallhavenService.retry()
        onClearFilters: WallhavenService.resetFilters()
        onEditSearch: search.begin("")
        onBackToFolder: face.setSource("folder")
    }

    // ===== the toolbar =====
    // The wallpaper board's header, laid along the top of the gallery.
    Item {
        id: toolbar

        x: face.pageX
        y: face.pageTop
        width: face.pageWidth
        height: face.toolbarH
        z: 5
        opacity: 1 - face.viewP
        visible: opacity > 0.01
        enabled: !face.viewing

        // Desktop | Lockscreen (Separate Lockscreen Wallpaper on)
        WallpaperTargetSwitch {
            id: targetSwitch

            visible: WallpaperService.separateLock
            x: 2
            y: 2
            current: face.target
            onPicked: id => {
                face.sortOpen = false
                face.target = id
            }
        }

        Text {
            x: (targetSwitch.visible ? targetSwitch.x + targetSwitch.width + 18 : 4)
            y: 2
            height: 40
            width: Math.max(0, controls.x - x - 14)
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: !face.onWallhaven ? face.subtitle
                : (WallhavenService.loading && WallhavenService.page === 0 ? "Searching Wallhaven\u2026"
                : (WallhavenService.error !== "" ? "Wallhaven" : WallhavenService.description))
            color: mt.pInkSub
            font.family: mt.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Row {
            id: controls

            anchors.right: parent.right
            anchors.rightMargin: 8
            y: 2
            spacing: 12

            SearchPill {
                id: search

                placeholder: face.onWallhaven ? "Search Wallhaven" : "Search wallpapers"
                onTextChanged: face.searchText = text
                onLeave: face.forceActiveFocus()
            }

            SortChip {
                id: sortChip

                label: face.onWallhaven ? WallhavenService.sortLabel : face.sortShort
                active: face.sortOpen
                onClicked: {
                    face.filtersOpen = false
                    face.sortOpen = !face.sortOpen
                }
            }

            WallhavenFilterChip {
                id: filterChip
                visible: face.onWallhaven
                count: WallhavenService.filterCount
                active: face.filtersOpen
                onClicked: {
                    face.sortOpen = false
                    face.filtersOpen = !face.filtersOpen
                }
            }

            // Which folder the wallpapers come from. Lit while it is not the
            // default one. The phone steps aside while the chooser is open and comes
            // back on this same side (WallpaperService.pickFolder).
            MagnetButton {
                visible: !face.onWallhaven
                icon: "folder_open"
                label: "Wallpaper folder"
                active: WallpaperService.customFolder
                onClicked: {
                    face.sortOpen = false
                    WallpaperService.pickFolder(face.lockMode ? "lock" : "desktop")
                }
            }

            MagnetButton {
                visible: !face.onWallhaven
                icon: "my_location"
                label: "Jump to applied"
                onClicked: face.jumpToApplied()
            }

            MagnetButton {
                visible: !face.onWallhaven
                icon: "shuffle"
                label: "Shuffle"
                onClicked: face.shuffle()
            }

            MagnetButton {
                visible: !face.onWallhaven
                icon: "refresh"
                label: "Refresh"
                badge: face.hasNew
                onClicked: {
                    face.sortOpen = false
                    face.refresh()
                }
            }

            // wheel <-> grid
            MagnetButton {
                icon: face.carousel ? "grid_view" : "view_carousel"
                label: face.carousel ? "Grid" : "Wheel"
                onClicked: face.toggleLook()
            }
        }

        // The sort menu: click anywhere else on the screen to close it.
        GallerySortCard {
            x: controls.x + sortChip.x + sortChip.width - width
            y: face.toolbarH + 6
            shown: face.sortOpen && !face.onWallhaven
            sortMode: face.sortMode
            options: face.sortOptions
            onSelected: mode => {
                face.setSort(mode)
                face.sortOpen = false
            }
        }

        // Wallhaven's sort menu and Filters card, each under its own key, kept inside the
        // page (never past its right edge).
        WallhavenSortCard {
            x: Math.min(toolbar.width - width, controls.x + sortChip.x + sortChip.width - width)
            y: face.toolbarH + 6
            shown: face.sortOpen && face.onWallhaven
            sort: WallhavenService.sortInUse
            range: WallhavenService.topRange
            hasQuery: face.searchText.trim() !== ""
            onSelected: (sort, range) => {
                WallhavenService.setSort(sort, range)
                if (sort !== "toplist")
                    face.sortOpen = false
            }
        }

        WallhavenFilterCard {
            x: Math.max(0, Math.min(toolbar.width - width, controls.x + filterChip.x + filterChip.width - width))
            y: face.toolbarH + 6
            shown: face.filtersOpen && face.onWallhaven
            filters: WallhavenService.filters
            screenLabel: face.screenPxW > 0 ? face.screenPxW + "\u00d7" + face.screenPxH : ""
            onCategoriesPicked: list => WallhavenService.setFilter("categories", list)
            onPicked: (key, value) => WallhavenService.setFilter(key, value)
            onResetRequested: WallhavenService.resetFilters()
        }
    }

    // Catches the click that closes the sort menu or the Filters card.
    MouseArea {
        anchors.fill: parent
        z: 4
        enabled: face.sortOpen || face.filtersOpen
        onClicked: {
            face.sortOpen = false
            face.filtersOpen = false
        }
    }

    // ===== the viewer =====
    Item {
        id: viewerArea

        x: face.pageX
        y: face.pageTop
        width: face.pageWidth
        height: face.pageHeight
        opacity: face.viewP
        scale: 0.96 + 0.04 * face.viewP
        visible: opacity > 0.01
        enabled: face.viewing

        readonly property real cardW: 830
        readonly property real cardH: Math.round(cardW / 1.6)
        readonly property real panelX: cardW + 42
        readonly property real panelW: width - panelX - 6

        // the picture
        Rectangle {
            x: 9
            y: 15
            width: viewerArea.cardW
            height: viewerArea.cardH
            radius: 24
            color: mt.pLineShadow
        }

        Rectangle {
            x: 0
            y: 6
            width: viewerArea.cardW
            height: viewerArea.cardH
            radius: 24
            color: mt.pSurface
            border.width: 5
            border.color: mt.pLine

            ClippingRectangle {
                anchors.fill: parent
                anchors.margins: 5
                radius: 19
                color: mt.pSurfaceHover

                // A Wallhaven picture: its thumbnail at once, the full picture over it.
                Image {
                    anchors.fill: parent
                    visible: face.viewWh !== null
                    source: face.viewWh ? face.viewWh.thumb : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }

                WallpaperPreview {
                    id: bigPicture

                    anchors.fill: parent
                    previewEntry: face.viewIndex >= 0 && face.viewIndex < face.matched.length
                        ? face.matched[face.viewIndex] : null
                    fallbackSource: previewEntry && previewEntry.engine ? ""
                        : (face.viewPath === "" ? (face.viewWh ? face.viewWh.full : "")
                            : (face.viewIsVideo ? WallpaperService.thumbUrl(face.viewPath) : "file://" + face.viewPath))
                    onPreviewPathChanged: {
                        if (previewEntry && previewEntry.engine)
                            face.viewPath = previewPath
                    }
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    // As dense as the screen it lands in (was a fixed 1680 x 1050,
                    // which is short of it above about 100% scale).
                    sourceSize: Qt.size(Math.min(3840, Math.ceil(viewerArea.cardW * face.renderScale * 2)),
                                        Math.min(2400, Math.ceil(viewerArea.cardH * face.renderScale * 2)))
                    opacity: status === Image.Ready ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: 200 }
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: bigPicture.status !== Image.Ready && face.viewWh === null
                    size: 64
                    name: face.viewIsVideo ? "movie" : "image"
                    color: mt.pInkSub
                }

                // where it comes from
                Rectangle {
                    visible: face.viewWh !== null
                    x: 14
                    y: 14
                    width: whBadge.implicitWidth + 22
                    height: 30
                    radius: 15
                    color: mt.pSurface
                    border.width: 3
                    border.color: mt.pLine

                    Row {
                        id: whBadge
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "travel_explore"
                            size: 16
                            color: mt.pInk
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Wallhaven"
                            color: mt.pInk
                            font.family: mt.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.ExtraBold
                            font.styleName: mt.fontStyleBold
                        }
                    }
                }

                // downloading: a bar along the bottom of the picture
                Rectangle {
                    visible: face.viewWh !== null && WallhavenService.fetching === face.viewWh.id
                    x: 18
                    y: parent.height - height - 18
                    width: parent.width - 36
                    height: 12
                    radius: 6
                    color: mt.pSurface
                    border.width: 2
                    border.color: mt.pLine

                    Rectangle {
                        x: 2
                        y: 2
                        height: parent.height - 4
                        width: (parent.width - 4) * WallhavenService.progress
                        radius: height / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: mt.accentCyan }
                            GradientStop { position: 1.0; color: mt.accentMint }
                        }
                        Behavior on width { NumberAnimation { duration: 250 } }
                    }
                }
            }
        }

        // the name and what it is
        Column {
            id: infoCol
            x: viewerArea.panelX
            y: 6
            width: viewerArea.panelW
            spacing: 8

            Text {
                visible: face.viewWh !== null
                text: "WALLHAVEN"
                color: mt.pInkSub
                font.family: mt.fontFamily
                font.pixelSize: 11
                font.weight: Font.ExtraBold
                font.styleName: mt.fontStyleBold
                font.letterSpacing: 1.4
            }

            Text {
                width: parent.width
                text: face.viewName
                color: mt.pInk
                font.family: mt.fontFamily
                font.pixelSize: 28
                font.weight: Font.ExtraBold
                font.styleName: mt.fontStyleBold
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                visible: face.viewWh === null
                text: face.viewIsVideo ? "Video wallpaper" : "Picture"
                color: mt.pInkSub
                font.family: mt.fontFamily
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }

            // Wallhaven: what it is (wraps rather than run past the panel), its colours,
            // and how liked it is.
            Flow {
                visible: face.viewWh !== null
                width: parent.width
                spacing: 6

                Repeater {
                    model: face.viewWh ? [
                        face.viewWh.category ? face.viewWh.category.charAt(0).toUpperCase() + face.viewWh.category.slice(1) : "",
                        face.viewWh.resolution.replace("x", " \u00d7 "),
                        face.viewWh.type.toUpperCase(),
                        WallhavenService.humanSize(face.viewWh.size)
                    ].filter(t => t !== "") : []

                    delegate: Rectangle {
                        required property string modelData
                        width: tag.implicitWidth + 20
                        height: 28
                        radius: 9
                        color: mt.pSurface
                        border.width: 2.5
                        border.color: mt.pLine

                        Text {
                            id: tag
                            anchors.centerIn: parent
                            text: modelData
                            color: mt.pInk
                            font.family: mt.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.ExtraBold
                            font.styleName: mt.fontStyleBold
                        }
                    }
                }
            }

            Row {
                visible: face.viewWh !== null && face.viewWh.colours.length > 0
                spacing: 6
                Repeater {
                    model: face.viewWh ? face.viewWh.colours : []
                    delegate: Rectangle {
                        required property string modelData
                        width: 26
                        height: 26
                        radius: 8
                        color: modelData
                        border.width: 2.5
                        border.color: mt.pLine
                    }
                }
            }

            Row {
                visible: face.viewWh !== null
                spacing: 14
                Repeater {
                    model: face.viewWh ? [
                        { icon: "visibility", text: face.viewWh.views.toLocaleString() + " views" },
                        { icon: "favorite", text: face.viewWh.favourites.toLocaleString() + " favourites" }
                    ] : []
                    delegate: Row {
                        required property var modelData
                        spacing: 4
                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: modelData.icon
                            size: 14
                            color: mt.pInkSub
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.text
                            color: mt.pInkSub
                            font.family: mt.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            Row {
                spacing: 10

                Rectangle {
                    visible: face.viewPath !== "" && face.viewPath === face.desktopPath
                    width: onDesk.implicitWidth + 28
                    height: 32
                    radius: 16
                    color: mt.accentMint
                    border.width: 3
                    border.color: mt.colBorder

                    Text {
                        id: onDesk
                        anchors.centerIn: parent
                        text: "On your desktop"
                        color: mt.colBorder
                        font.family: mt.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.ExtraBold
                        font.styleName: mt.fontStyleBold
                    }
                }

                Rectangle {
                    visible: face.viewPath !== "" && face.viewPath === face.lockPath
                    width: onLock.implicitWidth + 28
                    height: 32
                    radius: 16
                    color: LockPalette.pink
                    border.width: 3
                    border.color: mt.colBorder

                    Text {
                        id: onLock
                        anchors.centerIn: parent
                        text: "On your lockscreen"
                        color: mt.colBorder
                        font.family: mt.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.ExtraBold
                        font.styleName: mt.fontStyleBold
                    }
                }
            }
        }

        // the two actions. On Wallhaven everything below the details follows them down
        // (they can wrap), instead of sitting at fixed heights.
        readonly property bool whDownloading: face.viewWh !== null && WallhavenService.fetching === face.viewWh.id

        WallpaperActionKey {
            id: deskKey
            x: viewerArea.panelX
            y: face.viewWh ? infoCol.y + infoCol.height + 14 : 214
            capW: viewerArea.panelW - 8
            icon: viewerArea.whDownloading ? "download" : "desktop_windows"
            label: viewerArea.whDownloading
                ? "Downloading \u00b7 " + WallhavenService.humanSize(WallhavenService.fetched) + " of " + WallhavenService.humanSize(face.viewWh.size)
                : "Set as Desktop"
            progress: viewerArea.whDownloading ? WallhavenService.progress : -1
            done: face.justSet === "desktop"
            onClicked: all => face.setDesktop(all)
        }

        WallpaperActionKey {
            id: lockKey
            x: viewerArea.panelX
            y: face.viewWh ? deskKey.y + deskKey.implicitHeight + 10 : 312
            capW: viewerArea.panelW - 8
            icon: "lock"
            label: "Set as Lockscreen"
            available: !viewerArea.whDownloading
            done: face.justSet === "lock"
            onClicked: all => face.setLock(all)
        }

        Text {
            id: viewerNote
            x: viewerArea.panelX
            y: face.viewWh ? lockKey.y + lockKey.implicitHeight + 10 : 410
            width: viewerArea.panelW
            wrapMode: Text.WordWrap
            color: mt.pInkSub
            font.family: mt.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
            text: {
                const lines = []
                if (viewerArea.whDownloading)
                    lines.push("Esc stops the download. It goes on when it\u2019s done.")
                else if (face.viewWh && face.viewPath !== "")
                    lines.push("In your folder, sets at once: " + WallhavenService.fileNameOf(face.viewWh))
                if (WallpaperService.perMonitor && face.screenName !== "")
                    lines.push("Changes this monitor (" + face.screenName + ") only. Shift+click: every monitor.")
                if (!WallpaperService.separateLock)
                    lines.push("Set as Lockscreen turns on a separate lockscreen wallpaper.")
                return lines.join("\n")
            }
        }

        // Wallhaven: keep it without setting it, or see it on the site.
        Row {
            id: whRow
            visible: face.viewWh !== null
            x: viewerArea.panelX
            y: viewerNote.y + (viewerNote.text !== "" ? viewerNote.height + 12 : 0)
            spacing: 10

            WallhavenChip {
                icon: face.viewPath !== "" ? "check" : "download"
                text: face.viewPath !== "" ? "Saved" : "Save to folder"
                available: face.viewPath === "" && !viewerArea.whDownloading
                onClicked: WallhavenService.fetch(face.viewWh, null)
            }

            WallhavenChip {
                icon: "open_in_new"
                text: "wallhaven.cc"
                onClicked: Qt.openUrlExternally(face.viewWh.page)
            }
        }

        // previous / next (through what the search and sort show)
        Row {
            x: viewerArea.panelX
            y: face.viewWh ? Math.max(viewerArea.cardH - 40, whRow.y + whRow.height + 14) : viewerArea.cardH - 40
            spacing: 14

            SekaiNavKey {
                icon: "chevron_left"
                label: "Previous"
                onClicked: face.showIndex(face.viewIndex - 1)
            }

            SekaiNavKey {
                icon: "chevron_right"
                label: "Next"
                onClicked: face.showIndex(face.viewIndex + 1)
            }
        }
    }
}

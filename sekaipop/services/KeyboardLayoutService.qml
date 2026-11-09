pragma Singleton
import QtQuick
import Quickshell
import qs.services
import Quickshell.Io

// Which keyboard layout is active ("us", "ru", ...), read from Compositor. State only,
// no window: the bar's layout pill (Bar.qml) and both lockscreen looks (LockSurface.qml,
// LockCalendar.qml) read it, so they always agree and Hyprland is asked once, not once
// per bar.
//
//   import qs.services
//   ...
//   text: KeyboardLayoutService.code      // "EN", or "" when there is nothing to switch between
//
// Only worth showing when more than one layout is configured: on a one-layout system a
// pill would permanently say "EN". So `code` is empty then, and every pill hides itself.
Singleton {
    id: root

    // Hyprland's name for the active keymap, "English (US)", "Russian", ...
    property string layoutName: ""
    // How many layouts kb_layout lists ("us,ru" is two).
    property int layoutCount: 0

    // Which of them is on, as its place in the list ("us,ru": us is 0).
    property int activeIndex: 0
    // kb_layout as the codes it lists, in order.
    property var layoutIds: []

    // The layouts people reach for, by their xkb code, in the order the Hyprland page lists
    // them. Names for the rows of a layout list; a code that is not here (a layout of your
    // own) is shown as the code. Not the keymap name Hyprland gives: it only names the
    // active one, so a row would change its writing as you pick.
    readonly property var commonLayouts: [
        { id: "us", label: "English (US)" }, { id: "gb", label: "English (UK)" },
        { id: "ph", label: "Filipino" }, { id: "es", label: "Spanish" },
        { id: "fr", label: "French" }, { id: "de", label: "German" },
        { id: "it", label: "Italian" }, { id: "pt", label: "Portuguese" },
        { id: "br", label: "Brazilian" }, { id: "ru", label: "Russian" },
        { id: "ua", label: "Ukrainian" }, { id: "tr", label: "Turkish" },
        { id: "jp", label: "Japanese" }, { id: "kr", label: "Korean" },
        { id: "ara", label: "Arabic" }
    ]

    // What a list of layouts shows: [{ index, id, label }].
    readonly property var layouts: root.layoutIds.map((id, i) => {
        const known = root.commonLayouts.find(c => c.id === id)
        return {
            index: i,
            id: id,
            label: known ? known.label : id
        }
    })

    readonly property string code: root.layoutCount > 1 && root.layoutName !== ""
        ? root.layoutName.slice(0, 2).toUpperCase() : ""

    function cycle() { Compositor.action("keyboard-layout-next") }
    function select(index) {
        const count = root.layoutCount
        if (index < 0 || index >= count) return
        const steps = (index - root.activeIndex + count) % count
        for (let i = 0; i < steps; ++i) root.cycle()
    }
    function refresh() {}
    function sync() {
        const state = Compositor.keyboardLayout
        root.layoutIds = state.names || []
        root.layoutCount = root.layoutIds.length
        root.activeIndex = state.current_index || 0
        root.layoutName = root.layoutIds[root.activeIndex] || ""
    }
    Connections { target: Compositor; function onKeyboardLayoutChanged() { root.sync() } }
    Component.onCompleted: root.sync()
}

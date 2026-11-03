import Quickshell
import qs.services
import Quickshell.Wayland
import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.settings
import "../../common/functions/KeyBinds.js" as KB
import "KeybindsLayout.js" as KL

// The keybinds panel: change what SekaiPop's shortcuts are on, on a keyboard slab.
//
//   Board   a 75% keyboard that shows what is on every key; hold Super / Ctrl / Alt / Shift
//           (they are the layers) to see that layer. Click a key to pick its action.
//   List    the actions by group, with their keys, and a search.
//
// Pick an action, press "Press keys", then either press the new keys for real or switch the
// modifiers on and click a key on the board. A free combination is saved straight away; a
// taken one asks first. KeybindService does the work (reading Hyprland's binds, writing the
// override file, pausing every shortcut while a combination is recorded) and KeyBinds.js has
// the rules, exactly as the Settings page this replaced did.
//
// Ways to open it:
//   qs -c sekaipop ipc call keybinds toggle       (also show / hide)
//   Settings > Hyprland > Keybinds
// Ways to close it: Escape (it backs out one step at a time), the X, click outside the
// slab, or the call again.
//
// Built only while it is open (services/ComponentActivation.qml, ActivationEntry.qml).
Scope {
    id: root

    property bool open: false
    property bool closing: false
    // The phone (QuickPanel.qml), when the shell hands it over: while it is up the slab steps
    // down a layer so the phone is drawn over it, like the cheatsheet.
    property var quickPanel: null
    readonly property bool shown: root.open || root.closing
    property var targetScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(root.targetScreen)

    // ===== state =====
    property string view: "board"           // board | list
    property int layer: KB.SUPER            // the modifiers the board shows (and a click records)
    property string group: "Shell"          // the List's group
    property string query: ""
    property string selectedId: ""
    property bool capturing: false          // "Press the new keys"
    property int heldMods: 0                // modifiers physically held while capturing
    property int tapKey: 0                  // a modifier key pressed first, for a tap
    property bool tapDirty: false           // ...and something else was pressed meanwhile
    property string refusal: ""
    property var wanted: null               // a combination asked for that is taken...
    property var taken: null                // ...and who has it
    property string infoText: ""
    property bool confirmReset: false

    readonly property var selRow: root.selectedId === "" ? null : KeybindService.row(root.selectedId)
    readonly property bool conflicting: root.wanted !== null && root.taken !== null
    // "Open apps" is a modifier tapped on its own (Super by default), not a combination.
    readonly property bool tapAction: root.selRow !== null && root.selRow.tap === true
    // What the strip shows for a combination being built.
    readonly property int previewMods: root.heldMods !== 0 ? root.heldMods : root.layer

    // ===== open / close =====
    function focusedScreen() {
        const name = Compositor.focusedMonitor ? Compositor.focusedMonitor.name : ""
        for (const s of Quickshell.screens) {
            if (s.name === name)
                return s
        }
        return Quickshell.screens[0]
    }

    function openOn(screen) {
        console.log("[keybinds] openOn", screen ? screen.name : "(no screen)")
        if (screen)
            root.targetScreen = screen
        root.cancelCapture()
        root.selectedId = ""
        root.query = ""
        root.infoText = ""
        root.confirmReset = false
        root.layer = KB.SUPER
        KeybindService.refresh()
        root.open = true
    }

    function close() {
        console.log("[keybinds] close() called from:\n" + new Error().stack)
        root.cancelCapture()
        root.open = false
    }

    function toggleOn(screen) {
        if (root.open && (!screen || screen === root.targetScreen))
            root.close()
        else
            root.openOn(screen)
    }

    // ===== choosing and changing =====
    function toggleMod(bit) {
        // recording a tap: a click on Super / Alt / Ctrl is the tap
        if (root.capturing && root.tapAction) {
            const tap = KB.tapForMod(bit)
            if (tap === null)
                root.refuse("Shift can't be tapped on its own here. Use Super, Alt or Ctrl.")
            else
                root.offer(tap)
            return
        }
        root.layer = root.layer ^ bit
        root.refusal = ""
    }

    function select(id) {
        root.cancelCapture()
        root.confirmReset = false
        root.selectedId = id
        const r = KeybindService.row(id)
        if (r !== null) {
            if (r.combos.length > 0)
                root.layer = r.combos[0].mods
            root.group = r.group
        }
        stage.forceActiveFocus()
    }

    function deselect() {
        root.cancelCapture()
        root.selectedId = ""
        searchField.forceActiveFocus()
    }

    function startCapture() {
        if (root.selRow === null)
            return
        root.wanted = null
        root.taken = null
        root.heldMods = 0
        root.tapKey = 0
        root.tapDirty = false
        root.refusal = ""
        root.capturing = true
        KeybindService.pause()
        stage.forceActiveFocus()
    }

    // Also what the conflict question's Cancel does, and what Escape does to a recording.
    function cancelCapture() {
        root.capturing = false
        root.wanted = null
        root.taken = null
        root.heldMods = 0
        root.tapKey = 0
        root.tapDirty = false
        root.refusal = ""
        KeybindService.resume()
    }

    function refuse(text) {
        root.refusal = text
        refusalTimer.restart()
    }

    // A combination from the keys or from the board: save it, or ask.
    function offer(combo) {
        const row = root.selRow
        if (row === null)
            return
        const t = KeybindService.conflict(combo, row.id)
        if (t === null) {
            KeybindService.setKeys(row.id, combo, null)
            root.layer = combo.mods
            root.cancelCapture()
        } else {
            root.wanted = combo
            root.taken = t
            root.capturing = false
            root.heldMods = 0
            KeybindService.resume()
        }
    }

    function takeOver() {
        const row = root.selRow
        if (row === null || root.wanted === null)
            return
        KeybindService.setKeys(row.id, root.wanted, root.taken)
        root.layer = root.wanted.mods
        root.cancelCapture()
    }

    // A board key was clicked. `entry` is what is on it right now (or undefined).
    function boardKey(key, entry) {
        const combo = { mods: root.layer, key: key.id }
        if (root.capturing) {
            if (root.tapAction) {
                root.refuse("This one opens on a modifier tapped alone. Click Super, Alt or Ctrl.")
                return
            }
            if (KB.needsModifier(combo)) {
                root.refuse(KB.showCombo(combo) + " on its own would stop it typing. Switch a modifier on first.")
                return
            }
            root.offer(combo)
            return
        }
        if (entry !== undefined && entry.kind === "action") {
            root.select(entry.id)
        } else if (entry !== undefined) {
            root.say(entry.name + " is a Umbriel shortcut. Change it in "
                     + (KeybindService.mode === "lua" ? "keybinds.lua" : "your Umbriel config.toml") + ".")
        } else if (root.selectedId === "") {
            root.say(KB.showCombo(combo) + " is free. Pick an action, then Press keys.")
        }
    }

    function say(text) {
        root.infoText = text
        infoTimer.restart()
    }

    function clearSearchField() {
        searchField.text = ""
    }

    function resetAllNow() {
        if (!root.confirmReset) {
            root.confirmReset = true
            confirmTimer.restart()
            return
        }
        root.confirmReset = false
        root.deselect()
        KeybindService.resetAll()
    }

    // Escape backs out one step: a recording or a question, the chosen action, the search,
    // then the panel.
    function backOut() {
        if (root.capturing || root.conflicting)
            root.cancelCapture()
        else if (root.selectedId !== "")
            root.deselect()
        else if (root.query !== "") {
            root.query = ""
            searchField.text = ""
        } else
            root.close()
    }

    onViewChanged: {
        root.confirmReset = false
    }

    // Typing in the search shows its results in the List.
    onQueryChanged: {
        if (root.query.trim() !== "")
            root.view = "list"
    }

    // Escape ended the pause (the submap's own bind): that is a cancel.
    Connections {
        target: KeybindService
        function onPausedChanged() {
            if (!KeybindService.paused && root.capturing)
                root.cancelCapture()
        }
    }

    Timer {
        id: refusalTimer
        interval: 3200
        onTriggered: root.refusal = ""
    }

    Timer {
        id: infoTimer
        interval: 4200
        onTriggered: root.infoText = ""
    }

    Timer {
        id: confirmTimer
        interval: 3500
        onTriggered: root.confirmReset = false
    }

    // The shortcuts must never stay paused behind a closed panel.
    onShownChanged: {
        if (!root.shown)
            KeybindService.resume()
    }

    // (`ipc call keybinds toggle | show | hide` is answered in shell.qml, by the entry point
    // that builds this screen on demand: a handler in here would vanish with it.)

    // ===== enter / exit =====
    property real openT: 0
    property real closeT: 0

    NumberAnimation {
        id: enterAnim
        target: root
        property: "openT"
        to: 1
        duration: 320
        easing.type: Easing.OutBack
        easing.overshoot: 1.1
    }

    NumberAnimation {
        id: exitAnim
        target: root
        property: "closeT"
        from: 0
        to: 1
        duration: 160
        easing.type: Easing.OutQuad
        onStopped: {
            root.closing = false
            root.closeT = 0
            root.openT = 0
        }
    }

    onOpenChanged: {
        console.log("[keybinds] open =", root.open)
        if (root.open) {
            exitAnim.stop()
            root.closing = false
            enterAnim.restart()
        } else {
            enterAnim.stop()
            root.closing = true
            exitAnim.restart()
        }
    }

    // ===== the window =====
    PanelWindow {
        id: win

        screen: root.targetScreen
        visible: root.open || root.closing
        color: "transparent"

        // Full screen so a click outside the slab reaches us (and closes it).
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.keyboardFocus: win.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.layer: (root.quickPanel && (root.quickPanel.up || root.quickPanel.onScreen)) ? WlrLayer.Top : WlrLayer.Overlay
        WlrLayershell.namespace: "sekaipop-keybinds"

        onVisibleChanged: {
            console.log("[keybinds] window visible =", visible)
            if (visible)
                Qt.callLater(() => searchField.forceActiveFocus())
        }

        ScaleHost {
            anchors.fill: parent
            factor: ShellScale.forScreen(root.targetScreen)

            Item {
                id: stage
                anchors.fill: parent
                focus: true

                readonly property real appear: Math.min(1, root.openT) * (1 - root.closeT)

                // Recording: every key reaches us (the shortcuts are paused).
                Keys.onPressed: event => {
                    console.log("[keybinds] key pressed", event.key, "capturing:", root.capturing)
                    if (!root.capturing) {
                        if (event.key === Qt.Key_Escape) {
                            event.accepted = true
                            root.backOut()
                        }
                        return
                    }
                    event.accepted = true
                    // Escape reaches us only if the pause did not take; it still cancels.
                    if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) {
                        root.cancelCapture()
                        return
                    }
                    const combo = KB.comboFromKeyEvent(event.key, event.modifiers, event.nativeScanCode)
                    if (combo.key === "") {
                        root.heldMods = combo.mods
                        // a tap starts with a modifier alone; a second key spoils it
                        if (root.tapAction) {
                            if (root.tapKey === 0 && !event.isAutoRepeat) {
                                root.tapKey = event.key
                                root.tapDirty = false
                            } else if (event.key !== root.tapKey) {
                                root.tapDirty = true
                            }
                        }
                        return
                    }
                    if (root.tapAction) {
                        root.tapDirty = true
                        root.refuse("This one opens on a modifier tapped alone: Super, Alt or Ctrl, with no other key.")
                        return
                    }
                    if (KB.needsModifier(combo)) {
                        root.refuse(KB.showCombo(combo) + " on its own would stop it typing. Hold a modifier with it.")
                        return
                    }
                    root.heldMods = 0
                    root.offer(combo)
                }

                Keys.onReleased: event => {
                    if (!root.capturing)
                        return
                    event.accepted = true
                    root.heldMods = KB.comboFromKeyEvent(0, event.modifiers, 0).mods & ~KB.modOfKey(event.key)
                    // let go of the modifier that was pressed first, with nothing else in between
                    if (root.tapAction && root.tapKey !== 0 && event.key === root.tapKey) {
                        const dirty = root.tapDirty
                        root.tapKey = 0
                        root.tapDirty = false
                        const tap = dirty ? null : KB.tapCombo(event.key)
                        if (tap !== null)
                            root.offer(tap)
                        else
                            root.refuse("Tap Super, Alt or Ctrl on its own, with no other key.")
                    }
                }

                // Click outside the slab backs out (a recording first), then closes.
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        console.log("[keybinds] click outside the slab")
                        if (root.capturing || root.conflicting)
                            root.cancelCapture()
                        else
                            root.close()
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Theme.colDeep
                    opacity: 0.26 * stage.appear
                }

                // ===== everything, centred and fitted to the screen =====
                Item {
                    id: frame
                    width: 1200
                    height: 812
                    anchors.centerIn: parent

                    readonly property real fit: Math.max(0.3, Math.min(1, (stage.width * 0.96) / frame.width,
                                                                        (stage.height * 0.94) / frame.height))
                    scale: frame.fit * (0.94 + 0.06 * Math.min(1, root.openT))
                    transformOrigin: Item.Center
                    opacity: stage.appear
                    transform: Translate { y: (1 - Math.min(1, root.openT)) * 26 - 14 * root.closeT }

                    // clicks on the slab's own empty spots stay on the slab
                    MouseArea {
                        anchors.fill: parent
                    }

                    // ===== header: title, view switch, close =====
                    Pill {
                        id: titlePlate
                        x: 0
                        y: 0
                        width: titleText.implicitWidth + 64
                        height: 52 + root.mt.shadowOffset
                        cornerRadius: 24
                        ringWidth: 5
                        fillColor: root.mt.accentCyan

                        Text {
                            id: titleText
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -root.mt.shadowOffset / 2 + 1
                            text: "KEYBINDS"
                            color: root.mt.colBorder
                            font.family: root.mt.fontFamily
                            font.pixelSize: 28
                            font.weight: Font.Black
                            font.letterSpacing: 1
                        }
                    }

                    Text {
                        anchors.left: titlePlate.right
                        anchors.leftMargin: 22
                        anchors.verticalCenter: titlePlate.verticalCenter
                        text: root.capturing ? "Recording: every shortcut is paused until you are done."
                              : "Hold a layer, tap a key. Plain keys are free."
                        color: root.mt.pInk
                        font.family: root.mt.fontFamily
                        font.pixelSize: 17
                        font.weight: Font.Bold
                    }

                    KeyRoundButton {
                        id: closeBtn
                        anchors.right: parent.right
                        y: 4
                        icon: "close"
                        tip: "Close"
                        onClicked: root.close()
                    }

                    SegmentSwitch {
                        anchors.right: closeBtn.left
                        anchors.rightMargin: 18
                        anchors.verticalCenter: closeBtn.verticalCenter
                        width: 190
                        height: 40
                        options: [{ id: "board", label: "Board" }, { id: "list", label: "List" }]
                        current: root.view
                        onPicked: id => root.view = id
                    }

                    // ===== the slab =====
                    Pill {
                        id: slab
                        x: 0
                        y: 78
                        width: frame.width
                        height: 664
                        cornerRadius: 56
                        ringWidth: 10
                        shadowDy: 12
                        fillColor: root.mt.pSurface

                        Item {
                            id: inner
                            anchors.fill: parent
                            anchors.margins: 16

                            // ----- the modifier keys: the layers -----
                            Column {
                                id: modBlock
                                width: 176
                                spacing: 2

                                Repeater {
                                    model: [[["Super", KB.SUPER], ["Ctrl", KB.CTRL]], [["Alt", KB.ALT], ["Shift", KB.SHIFT]]]

                                    delegate: Row {
                                        required property var modelData
                                        spacing: 10

                                        Repeater {
                                            model: parent.modelData

                                            delegate: SlabKey {
                                                required property var modelData

                                                width: 83
                                                keyHeight: 31
                                                ringWidth: 5
                                                label: modelData[0]
                                                labelSize: 14
                                                active: (root.layer & modelData[1]) !== 0
                                                fill: active ? root.mt.accentCyan : root.mt.pSurface
                                                ink: active ? root.mt.colBorder : root.mt.pInk
                                                onClicked: root.toggleMod(modelData[1])
                                            }
                                        }
                                    }
                                }
                            }

                            // ----- the strip: search, the chosen action, recording, a question -----
                            Rectangle {
                                id: strip
                                x: modBlock.width + 16
                                width: parent.width - x
                                height: 74
                                radius: 34
                                color: Qt.darker(root.mt.colBorder, 1.5)
                                border.width: 4
                                border.color: root.mt.colBorder

                                // idle: search
                                Item {
                                    anchors.fill: parent
                                    visible: root.selectedId === ""

                                    MaterialIcon {
                                        x: 22
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: "search"
                                        size: 26
                                        color: root.mt.accentMint
                                    }

                                    TextInput {
                                        id: searchField
                                        x: 62
                                        width: parent.width - 62 - 24
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: "#ffffff"
                                        selectionColor: root.mt.accentMint
                                        selectedTextColor: root.mt.colBorder
                                        font.family: root.mt.fontFamily
                                        font.pixelSize: 22
                                        font.weight: Font.Bold
                                        clip: true
                                        onTextEdited: root.query = text
                                        Keys.onEscapePressed: event => {
                                            event.accepted = true
                                            root.backOut()
                                        }

                                        Text {
                                            visible: searchField.text === ""
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width
                                            elide: Text.ElideRight
                                            text: root.infoText !== "" ? root.infoText : "Search actions, or a key like \u201csuper v\u201d"
                                            color: root.infoText !== "" ? root.mt.accentMint : "#b9b8d8"
                                            font: searchField.font
                                        }
                                    }
                                }

                                // chosen action (not recording, nothing asked)
                                Item {
                                    anchors.fill: parent
                                    visible: root.selectedId !== "" && !root.capturing && !root.conflicting

                                    Text {
                                        id: selName
                                        x: 26
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.min(implicitWidth, strip.width - 26 - selRight.width - 40)
                                        elide: Text.ElideRight
                                        text: root.selRow ? root.selRow.name : ""
                                        color: "#ffffff"
                                        font.family: root.mt.fontFamily
                                        font.pixelSize: 24
                                        font.weight: Font.ExtraBold
                                    }

                                    Row {
                                        id: selRight
                                        anchors.right: parent.right
                                        anchors.rightMargin: 20
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 14

                                        KeyCaps {
                                            anchors.verticalCenter: parent.verticalCenter
                                            combos: root.selRow ? root.selRow.combos : []
                                            onColour: true
                                        }
                                        SlabButton {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: root.selRow !== null && root.selRow.combos.length > 0
                                            label: "Clear"
                                            onClicked: KeybindService.setKeys(root.selectedId, null, null)
                                        }
                                        SlabButton {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: root.selRow !== null && root.selRow.changed
                                            label: "Reset"
                                            onClicked: KeybindService.reset(root.selectedId)
                                        }
                                        SlabButton {
                                            anchors.verticalCenter: parent.verticalCenter
                                            label: KeybindService.busy ? "Saving\u2026" : "Press keys"
                                            fill: root.mt.accentCyan
                                            onClicked: root.startCapture()
                                        }
                                        KeyRoundButton {
                                            anchors.verticalCenter: parent.verticalCenter
                                            icon: "close"
                                            tip: "Done"
                                            onClicked: root.deselect()
                                        }
                                    }
                                }

                                // recording
                                Item {
                                    anchors.fill: parent
                                    visible: root.capturing

                                    Text {
                                        id: recText
                                        x: 26
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.verticalCenterOffset: root.refusal !== "" ? -10 : 0
                                        text: root.tapAction ? "Tap Super, Alt or Ctrl alone" : "Press the new keys"
                                        color: "#ffffff"
                                        font.family: root.mt.fontFamily
                                        font.pixelSize: 24
                                        font.weight: Font.ExtraBold
                                    }
                                    Text {
                                        visible: root.refusal !== ""
                                        x: 26
                                        width: parent.width - 52 - 200
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.verticalCenterOffset: 14
                                        elide: Text.ElideRight
                                        text: root.refusal
                                        color: "#ffd2e4"
                                        font.family: root.mt.fontFamily
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                    }

                                    Row {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 20
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 14

                                        KeyCaps {
                                            anchors.verticalCenter: parent.verticalCenter
                                            combos: [{ mods: root.previewMods, key: "" }]
                                            waiting: root.tapAction ? "tapped alone" : "then a key"
                                            held: true
                                            onColour: true
                                        }
                                        SlabButton {
                                            anchors.verticalCenter: parent.verticalCenter
                                            label: "Cancel"
                                            onClicked: root.cancelCapture()
                                        }
                                    }
                                }

                                // a question: those keys are taken
                                Item {
                                    anchors.fill: parent
                                    visible: root.conflicting

                                    Text {
                                        x: 26
                                        width: parent.width - 52 - 380
                                        anchors.verticalCenter: parent.verticalCenter
                                        elide: Text.ElideRight
                                        text: (root.wanted ? KB.showCombo(root.wanted) : "") + " is "
                                              + (root.taken && root.taken.kind === "action" ? "on " : "Umbriel's: ")
                                              + (root.taken ? root.taken.name : "")
                                        color: "#ffffff"
                                        font.family: root.mt.fontFamily
                                        font.pixelSize: 21
                                        font.weight: Font.ExtraBold
                                    }

                                    Row {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 20
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 12

                                        SlabButton {
                                            anchors.verticalCenter: parent.verticalCenter
                                            label: "Take them"
                                            fill: root.mt.accentCyan
                                            onClicked: root.takeOver()
                                        }
                                        SlabButton {
                                            anchors.verticalCenter: parent.verticalCenter
                                            label: "Other keys"
                                            onClicked: root.startCapture()
                                        }
                                        SlabButton {
                                            anchors.verticalCenter: parent.verticalCenter
                                            label: "Cancel"
                                            onClicked: root.cancelCapture()
                                        }
                                    }
                                }
                            }

                            // ----- the body: board or list, or the one-time setup -----
                            Item {
                                id: body
                                y: 100
                                width: parent.width
                                height: parent.height - 100

                                KeybindsBoard {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    height: implicitHeight
                                    visible: KeybindService.available && root.view === "board"
                                    panel: root
                                }

                                KeybindsList {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    height: implicitHeight
                                    visible: KeybindService.available && root.view === "list"
                                    panel: root
                                }

                                Column {
                                    id: setup
                                    visible: !KeybindService.available
                                    width: Math.min(parent.width, 820)
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 40
                                    spacing: 18

                                    readonly property string line: KeybindService.mode === "lua"
                                        ? "pcall(require, \"sekaipop_overrides\")"
                                        : "source = ~/.config/hypr/sekaipop_overrides.conf"

                                    Text {
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                        text: KeybindService.configReadOnly ? "Umbriel owns your shortcuts" : "Umbriel owns your shortcuts"
                                        color: root.mt.pInk
                                        font.family: root.mt.fontFamily
                                        font.pixelSize: 28
                                        font.weight: Font.Black
                                    }
                                    Text {
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.2
                                        text: KeybindService.configReadOnly
                                            ? "Edit the [keybinds] section in your Umbriel config.toml."
                                            : "Changes made here are saved in a file of SekaiPop's, and your config doesn't load that file yet. Add this line to "
                                              + (KeybindService.mode === "lua" ? "hyprland.lua" : "hyprland.conf") + " once, and this panel switches on by itself:"
                                        color: root.mt.pInk
                                        font.family: root.mt.fontFamily
                                        font.pixelSize: 17
                                        font.weight: Font.Bold
                                    }
                                    Rectangle {
                                        visible: !KeybindService.configReadOnly
                                        width: setupCode.implicitWidth + 36
                                        height: 40
                                        radius: 20
                                        color: root.mt.pSurfaceDivider
                                        Text {
                                            id: setupCode
                                            anchors.centerIn: parent
                                            text: setup.line
                                            color: root.mt.pInk
                                            font.family: "monospace"
                                            font.pixelSize: 16
                                        }
                                    }
                                    SlabButton {
                                        visible: !KeybindService.configReadOnly
                                        label: "Copy the line"
                                        fill: root.mt.accentCyan
                                        onClicked: Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", setup.line])
                                    }
                                }
                            }
                        }
                    }

                    // ===== footer: the legend and reset all =====
                    Row {
                        x: 8
                        y: 770
                        height: 36
                        spacing: 26

                        Repeater {
                            model: ["Shell", "Utilities", "Media", "Session", "Windows", "Workspaces", "Apps"]

                            delegate: Row {
                                required property string modelData
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: KL.colorOf(modelData)
                                    border.width: 3
                                    border.color: root.mt.pLine
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData
                                    color: root.mt.pInk
                                    font.family: root.mt.fontFamily
                                    font.pixelSize: 14
                                    font.weight: Font.ExtraBold
                                }
                            }
                        }
                    }

                    SlabButton {
                        anchors.right: parent.right
                        y: 768
                        visible: KeybindService.available && KeybindService.changedCount > 0
                        label: root.confirmReset ? "Reset all " + KeybindService.changedCount + "? Click again"
                                                 : "Reset all (" + KeybindService.changedCount + " changed)"
                        fill: root.confirmReset ? root.mt.accentCyan : root.mt.pSurface
                        onClicked: root.resetAllNow()
                    }
                }
            }
        }
    }
}

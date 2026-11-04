import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Where the gallery's pictures come from: My folder | Wallhaven | Engine.
// In the header, beside the "Wallpapers" title; Ctrl+Tab flips it too (WallpaperFace.qml).
//
// The same pill as WallpaperTargetSwitch (outline, hard shadow, a thumb that slides and
// overshoots a little), but each half is as wide as the wider label needs, so nothing
// is cut whatever the font.
//
// Pure UI: it only says picked("folder") / picked("wallhaven") / picked("engine").
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property string current: "folder"      // "folder" | "wallhaven" | "engine"
    signal picked(string id)

    readonly property var choices: [
        { id: "folder", label: "My folder", icon: "folder" },
        { id: "wallhaven", label: "Wallhaven", icon: "travel_explore" },
        { id: "engine", label: "Engine", icon: "movie" }
    ]
    readonly property int currentIndex: root.current === "wallhaven" ? 1 : (root.current === "engine" ? 2 : 0)

    // icon 20 + gap 7 + the label, 16 each side
    readonly property real slot: Math.ceil(Math.max(m0.width, m1.width, m2.width) + 20 + 7 + 32)

    width: root.choices.length * root.slot + 6
    height: 40

    TextMetrics {
        id: m0
        text: root.choices[0].label
        font.family: mt.fontFamily
        font.styleName: mt.fontStyleBold
        font.weight: Font.ExtraBold
        font.pixelSize: 14
    }
    TextMetrics {
        id: m1
        text: root.choices[1].label
        font: m0.font
    }
    TextMetrics {
        id: m2
        text: root.choices[2].label
        font: m0.font
    }

    // hard shadow
    Rectangle {
        x: mt.shadowOffset - 1
        y: mt.shadowOffset - 1
        width: root.width
        height: root.height
        radius: height / 2
        color: mt.lineShadow
        antialiasing: true
    }

    // the pill
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "#ffffff"
        border.width: mt.borderWidth
        border.color: mt.line
        antialiasing: true
    }

    // the thumb
    Rectangle {
        y: 3
        height: root.height - 6
        width: root.slot
        x: 3 + root.currentIndex * root.slot
        radius: height / 2
        antialiasing: true
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: mt.accentCyan }
            GradientStop { position: 1.0; color: mt.accentMint }
        }

        Behavior on x {
            NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }
    }

    Repeater {
        model: root.choices

        delegate: Item {
            id: seg
            required property var modelData
            required property int index
            readonly property bool on: seg.index === root.currentIndex

            x: 3 + seg.index * root.slot
            width: root.slot
            height: root.height

            Row {
                anchors.centerIn: parent
                spacing: 7

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: seg.modelData.icon
                    size: 20
                    weight: 600
                    color: seg.on ? mt.colBorder : mt.colSubText
                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: seg.modelData.label
                    color: seg.on ? mt.colBorder : mt.colSubText
                    font: m0.font
                    Behavior on color { ColorAnimation { duration: 140 } }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(seg.modelData.id)
            }
        }
    }
}
